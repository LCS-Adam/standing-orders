#!/bin/bash
PATH="/usr/local/bin:/usr/bin:/bin:/opt/homebrew/bin:${PATH:-}"; export PATH
set -uo pipefail

# external-review.sh - run one external review round and judge it.
#
# usage:
#   scripts/external-review.sh <artifact-path> <round-output-path> [focus]
#   scripts/external-review.sh --probe
#   scripts/external-review.sh --check <round-output-path>
#   scripts/external-review.sh --selftest [--live]
#
# exit: 0 round PASSED | 1 round FAILED | 2 usage | 3 UNAVAILABLE
#
# THE LOAD-BEARING PART OF THIS SCRIPT IS THE PASS CONDITION, NOT THE INVOCATION.
# A round is FAILED unless line 1 of the output matches `VERDICT: CLEAN` or
# `VERDICT: FINDINGS`. SIZE IS NOT EVIDENCE. A 70KB output with no VERDICT line
# is a refusal or a narration, not a pass, and that has actually happened on this
# codebase. Every trap in the skill's "Harness traps that fake a verdict"
# section - the macOS `timeout` stub producing a 38-byte file with exit 0, a
# reconnect loop growing a file forever, a CLI that emits metadata JSON and
# nothing else - passes `wc -c > 0` and fails here.
#
# WHICH MODEL RUNS THE ROUND
#   config/reviewer.conf binds the CLI and optionally pins the model; the
#   REVIEWER_CLI and REVIEWER_MODEL environment variables override it, which is
#   priority 1 in the skill's resolution table. With auggie and no pin, the model
#   is discovered by scripts/resolve-tier.sh REVIEWER, which refuses to return a
#   same-family model and never falls back to the account default. With any
#   other CLI and no pin the round is UNAVAILABLE: discovery is auggie-only, and
#   omitting the model flag would hand the round to that tool's default, which is
#   a same-family model on more than one of them.
#
# Every round writes <round-output-path>.meta carrying the id, where it came
# from and which predicate chain chose it, so the binding a gate ran on is
# auditable afterwards without parsing the CLI's output.
#
# WHAT ACTUALLY EXECUTES WITHOUT THE VENDOR CLI INSTALLED
#   The auggie branch runs here only under --selftest, which puts a stub auggie
#   on PATH from a temp dir and drives the whole matrix through it. The real
#   round against a live reviewer is --selftest --live, which is a separate flag
#   because it costs a real call and real minutes.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SELF="$ROOT/scripts/${BASH_SOURCE[0]##*/}"
REVIEWER_CONF="${HARNESS_REVIEWER_CONF:-$ROOT/config/reviewer.conf}"
PROMPT_FILE="$ROOT/skills/external-llm-review/attack-prompt.md"
MAX_TURNS="${REVIEW_MAX_TURNS:-12}"

die()  { printf 'external-review: %s\n' "$1" >&2; exit "${2:-2}"; }
note() { printf 'external-review: %s\n' "$1" >&2; }

conf_get() { # conf_get <file> <key> - the normalisation bin/harness' load_models uses
  [ -f "$1" ] || return 1
  local k v
  while IFS='=' read -r k v; do
    k="${k%%#*}"; k="$(printf '%s' "$k" | tr -d '[:space:]')"
    [ -n "$k" ] || continue
    v="${v%%#*}"; v="$(printf '%s' "$v" | tr -d '[:space:]')"
    [ "$k" = "$2" ] || continue
    printf '%s\n' "$v"; return 0
  done < "$1"
  return 1
}

# ---------------------------------------------------------------- the verdict
#
# ONE function, used by the review path, by --check on a hand-pasted file, and
# by the selftest. Two callers judging a round two ways is how a gate ends up
# passing something it would have failed on the other path.
#
# A non-zero CLI exit never reaches here: the caller maps that to UNAVAILABLE,
# because a tool that did not run to completion produced no review at all and
# the operator has to decide what to do about it. What reaches here is always a
# CLI that claimed success, and the question is whether it actually reviewed.
SEVERITY='^(BLOCKER|CRITICAL|HIGH|MAJOR|MEDIUM|MINOR|NIT)([^[:alnum:]_]|$)'

round_verdict() { # round_verdict <file> -> 0 pass, 1 FAILED (reason on stderr)
  local f="$1" line1 bytes
  [ -f "$f" ] || { note "FAILED: no round output at $f"; return 1; }
  bytes=$(wc -c < "$f" | tr -d ' ')
  # A reconnect loop is a failed round, not a slow one, and the file grows the
  # whole time it is failing. Checked before size for exactly that reason.
  if grep -q 'Connection lost, reconnecting' "$f"; then
    note "FAILED: reviewer emitted a reconnect loop ($bytes bytes); kill and re-run rather than waiting"
    return 1
  fi
  # head -1 on the FILE, not `cat "$f" | head -1`: under pipefail the producer
  # takes SIGPIPE and a passing round comes back as exit 141.
  line1="$(head -1 "$f" 2>/dev/null)"
  if ! printf '%s' "$line1" | grep -qE '^VERDICT: (CLEAN|FINDINGS)$'; then
    note "FAILED: line 1 is not a verdict ($bytes bytes). Got: ${line1:0:80}"
    return 1
  fi
  # Size is the LAST check and never the only one. It is here to catch a bare
  # verdict line with no review behind it, which is 15 bytes.
  if [ "${bytes:-0}" -le 200 ]; then
    note "FAILED: verdict line with no review behind it ($bytes bytes)"
    return 1
  fi
  if [ "$line1" = "VERDICT: FINDINGS" ] && ! grep -qE "$SEVERITY" "$f"; then
    note "FAILED: VERDICT: FINDINGS with no severity block"
    return 1
  fi
  note "PASSED: $line1 ($bytes bytes)"
  return 0
}

# ---------------------------------------------------------------- model binding
# Sets RV_MODEL / RV_SOURCE / RV_RULE, or exits 3.
resolve_model() { # resolve_model <cli>
  local cli="$1" pinned rerr rrc
  pinned="${REVIEWER_MODEL:-}"
  if [ -n "$pinned" ]; then
    RV_MODEL="$pinned"; RV_SOURCE="pinned"; RV_RULE="REVIEWER_MODEL from the environment"
    return 0
  fi
  pinned="$(conf_get "$REVIEWER_CONF" REVIEWER_MODEL || true)"
  if [ -n "$pinned" ]; then
    RV_MODEL="$pinned"; RV_SOURCE="pinned"; RV_RULE="REVIEWER_MODEL in ${REVIEWER_CONF##*/}"
    return 0
  fi
  if [ "$cli" != "auggie" ]; then
    die "no REVIEWER_MODEL pinned and discovery is auggie-only, so there is no model for $cli. UNAVAILABLE. Pin one in ${REVIEWER_CONF##*/} or export REVIEWER_MODEL; this never falls back to the CLI default, which is same-family on several of these tools." 3
  fi
  rerr="$("$ROOT/scripts/resolve-tier.sh" REVIEWER 2>&1 >/dev/null)"; rrc=$?
  RV_MODEL="$("$ROOT/scripts/resolve-tier.sh" REVIEWER 2>/dev/null)"
  if [ $rrc -ne 0 ] || [ -z "$RV_MODEL" ]; then
    printf '%s\n' "$rerr" >&2
    die "scripts/resolve-tier.sh REVIEWER exited $rrc - no eligible reviewer model. UNAVAILABLE." 3
  fi
  # The resolver already printed its audit line; lift source and rule out of it
  # rather than re-deriving them here and risking the two disagreeing.
  RV_SOURCE="$(printf '%s' "$rerr" | sed -n 's/.*(source=\([^;]*\);.*/\1/p' | tail -1)"
  RV_RULE="$(printf '%s' "$rerr" | sed -n 's/.*; rule=\(.*\); excluded=.*/\1/p' | tail -1)"
  [ -n "$RV_SOURCE" ] || RV_SOURCE="discovered"
  [ -n "$RV_RULE" ] || RV_RULE="scripts/resolve-tier.sh REVIEWER"
  return 0
}

# ---------------------------------------------------------------- invocation
# The skill records that `timeout` does not exist on macOS and that wrapping the
# reviewer in the shell builtin's absence produces a ~38-byte file with exit 0 -
# a fake pass. So: gtimeout if it is really there, nothing otherwise.
timeout_prefix() {
  if command -v gtimeout >/dev/null 2>&1; then printf 'gtimeout\n%s\n' "${REVIEW_TIMEOUT:-1800}"; fi
}

run_round() { # run_round <cli> <model> <artifact> <out> <focus>
  local cli="$1" model="$2" art="$3" out="$4" focus="$5" rc
  local task="Review the artifact at $art.${focus:+ $focus}"
  # STDIN IS CLOSED BY DEFAULT, and this is not cosmetic. Reproduced: with stdin
  # inherited, `codex exec` prints "Reading additional input from stdin..." and
  # blocks forever on a pipe nobody is writing to, which on a detached gate run
  # is an unbounded hang that looks exactly like a slow review. The skill's
  # affordance of feeding a diff on stdin survives as an explicit opt-in rather
  # than as the default that hangs.
  local in=/dev/null; [ "${REVIEW_STDIN:-0}" != "1" ] || in=/dev/stdin
  # ${TO[@]+...}, not "${TO[@]}": the shebang is /bin/bash, which on macOS is
  # 3.2, and there an EMPTY array expanded under `set -u` is an unbound
  # variable. Without gtimeout installed that is the normal case, so the plain
  # spelling made every round die before the CLI was ever invoked.
  local -a TO=(); while IFS= read -r t; do TO+=("$t"); done < <(timeout_prefix)
  case "$cli" in
    auggie)
      # --permission launch-process:deny because whether --ask alone blocks
      # shell is NOT FOUND in the vendor docs. It costs the reviewer rg and
      # git show, the same trade the cursor-agent branch makes with
      # --sandbox enabled.
      # ponytail: drop the deny once the runbook's --ask probe shows it
      # already blocks launch-process.
      ${TO[@]+"${TO[@]}"} auggie --print --quiet --ask --dont-save-session \
        --max-turns "$MAX_TURNS" --model "$model" \
        --workspace-root "$ROOT" \
        --permission launch-process:deny \
        --instruction-file "$PROMPT_FILE" \
        "$task" > "$out" < "$in"; rc=$?
      ;;
    codex)
      # No instruction-file flag here, so the same prompt goes inline. Same
      # bytes, same contract, one source of truth on disk.
      ${TO[@]+"${TO[@]}"} codex exec --sandbox read-only -C "$ROOT" -m "$model" \
        "$(cat "$PROMPT_FILE")

$task" > "$out" < "$in"; rc=$?
      ;;
    cursor-agent)
      ${TO[@]+"${TO[@]}"} cursor-agent -p --mode ask --trust --sandbox enabled \
        --model "$model" --output-format text --workspace "$ROOT" \
        "$(cat "$PROMPT_FILE")

$task" > "$out" < "$in"; rc=$?
      ;;
    gemini)
      # -m is not in the skill's one-line example, and it is not optional: an
      # unpinned gemini takes its own default.
      ${TO[@]+"${TO[@]}"} gemini -m "$model" -p "$(cat "$PROMPT_FILE")

$task" > "$out" < "$in"; rc=$?
      ;;
    *) die "unknown REVIEWER_CLI: $cli (expected auggie, codex, cursor-agent or gemini)" ;;
  esac
  return $rc
}

degrade_note() { # degrade_note <cli> <artifact> <out>
  local cli="$1" art="$2" out="$3"
  printf 'external-review: the gate is HUMAN-ASSISTED now, not skipped. Run this by hand:\n\n' >&2
  case "$cli" in
    auggie) printf '  auggie --ask --instruction-file %s "Review the artifact at %s"\n\n' \
              "skills/external-llm-review/attack-prompt.md" "$art" >&2 ;;
    *)      printf '  run %s interactively against %s with the prompt at %s\n\n' \
              "$cli" "$art" "skills/external-llm-review/attack-prompt.md" >&2 ;;
  esac
  printf 'Paste the reviewer final message into:\n  %s\nthen re-run:\n  scripts/external-review.sh --check %s\n' \
    "$out" "$out" >&2
}

probe() { # probe <cli> -> 0 alive, 3 UNAVAILABLE
  local cli="$1" out rc
  command -v "$cli" >/dev/null 2>&1 || { note "UNAVAILABLE: $cli is not on PATH"; return 3; }
  case "$cli" in
    auggie)       out="$(auggie --print --quiet --max-turns 1 "reply PING" 2>&1)"; rc=$? ;;
    codex)        out="$(codex login status 2>&1)"; rc=$? ;;
    cursor-agent) out="$(cursor-agent status 2>&1)"; rc=$? ;;
    gemini)       out="$(gemini --version 2>&1)"; rc=$? ;;
    *) die "unknown REVIEWER_CLI: $cli" ;;
  esac
  if [ $rc -ne 0 ]; then
    # Quoted verbatim: "logged in" is not "has credit", and the CLI's own words
    # are what tell the two apart.
    printf 'external-review: UNAVAILABLE: %s probe exited %d:\n' "$cli" "$rc" >&2
    printf '%s\n' "$out" | head -5 | sed 's/^/  /' >&2
    return 3
  fi
  note "probe OK: $cli ($(printf '%s' "$out" | head -1 | cut -c1-60))"
  return 0
}

review() { # review <artifact> <out> <focus>
  local art="$1" out="$2" focus="${3:-}" cli rc
  [ -f "$art" ] || die "no artifact at $art"
  [ -f "$PROMPT_FILE" ] || die "no attack prompt at $PROMPT_FILE"
  cli="${REVIEWER_CLI:-}"
  [ -n "$cli" ] || cli="$(conf_get "$REVIEWER_CONF" REVIEWER_CLI || true)"
  [ -n "$cli" ] || die "no REVIEWER_CLI in the environment or ${REVIEWER_CONF##*/}"
  command -v "$cli" >/dev/null 2>&1 || {
    note "UNAVAILABLE: $cli is not on PATH"
    degrade_note "$cli" "$art" "$out"
    exit 3
  }
  resolve_model "$cli"
  note "round: cli=$cli model=$RV_MODEL source=$RV_SOURCE"
  mkdir -p "$(dirname "$out")" 2>/dev/null
  run_round "$cli" "$RV_MODEL" "$art" "$out" "$focus"; rc=$?
  # Written whatever the verdict: a FAILED round is exactly the one you want to
  # know the model binding for afterwards.
  printf 'model=%s source=%s rule=%s\n' "$RV_MODEL" "$RV_SOURCE" "$RV_RULE" > "$out.meta"
  if [ $rc -ne 0 ]; then
    note "UNAVAILABLE: $cli exited $rc - it did not run to completion, so there is no review to judge"
    degrade_note "$cli" "$art" "$out"
    exit 3
  fi
  round_verdict "$out" || exit 1
  exit 0
}

# ---------------------------------------------------------------- selftest
SELFTEST_TMP=""
selftest_cleanup() { [ -z "$SELFTEST_TMP" ] || rm -rf "$SELFTEST_TMP"; }

selftest() { # selftest <live:0|1>
  local live="$1" tmp T=0 F=0
  tmp="$(mktemp -d)" || die "mktemp -d failed"
  SELFTEST_TMP="$tmp"; trap selftest_cleanup EXIT
  # This machine exports a real reviewer binding. Left set, the stub matrix
  # below would quietly drive the real CLI and every .meta assertion would read
  # source=pinned while the discovery wiring went untested.
  unset REVIEWER_MODEL HARNESS_AUGGIE_CONF REVIEW_TIMEOUT
  export REVIEWER_CLI=auggie
  : > "$tmp/reviewer.conf"
  printf 'REVIEWER_CLI=auggie\nREVIEWER_MODEL=\n' > "$tmp/reviewer.conf"
  export HARNESS_REVIEWER_CONF="$tmp/reviewer.conf"
  export HARNESS_AUGGIE_CONF="$tmp/models.auggie.conf"   # never created; keeps discovery live

  mkdir -p "$tmp/bin"
  # The stub answers two things: the model list the resolver asks for, and the
  # review call itself. The list carries no same-family display names on
  # purpose - this file is not exempt from the gate's vendor-name check, and a
  # fixture is the easiest way to leak one.
  cat > "$tmp/bin/auggie" <<'STUB'
#!/bin/bash
if [ "$*" = "models list --full-info" ]; then
  cat <<'JSON'
{"models":[
 {"id":"gpt-6-astra","displayName":"GPT-6 Astra","costTier":5,"effortLevels":["low","medium","high","max"]},
 {"id":"gpt-5.6-sol","displayName":"GPT-5.6 Sol","costTier":4,"effortLevels":["low","medium","high"]},
 {"id":"gemini-3.8-pro","displayName":"Gemini 3.8 Pro","costTier":3,"effortLevels":["low","medium","high"]}
]}
JSON
  exit 0
fi
cat "$STUB_BODY"
exit "${STUB_RC:-0}"
STUB
  chmod +x "$tmp/bin/auggie"
  PATH="$tmp/bin:$PATH"; export PATH
  printf 'artifact under review\n' > "$tmp/artifact.md"

  local BODY='The gate reads pathnames from one source and bytes from another, so a
staged leak whose working copy was cleaned reaches every clone while the
scan reports green. Reproduced by staging the string and restoring the
working file. This paragraph exists to carry the round past the size floor,
which is the last check and never the only one.'

  # case bodies. Each is a full reviewer output file.
  printf 'VERDICT: CLEAN\n\n%s\n' "$BODY"                                   > "$tmp/c1"
  printf 'VERDICT: FINDINGS\n\nMAJOR gate reads two byte sources\n%s\n' "$BODY" > "$tmp/c2"
  : > "$tmp/c3"
  printf 'Filing the defects now, one moment.\n\n%s\n' "$BODY"              > "$tmp/c4"
  { printf 'Connection lost, reconnecting ... (attempt 1)\n'
    printf 'Connection lost, reconnecting ... (attempt 2)\n'
    printf '%s\n' "$BODY"; }                                                 > "$tmp/c5"
  printf 'non-interactive mode is not available on this account\n'          > "$tmp/c6"
  printf 'VERDICT: FINDINGS\n\n%s\n' "$BODY"                                > "$tmp/c7"
  printf 'Here is the review.\nVERDICT: CLEAN\n\n%s\n' "$BODY"              > "$tmp/c8"
  printf 'VERDICT: CLEAN\n'                                                  > "$tmp/c9"
  printf '{"type":"result","subtype":"success","duration_ms":419000,"num_turns":7,"total_cost_usd":0.41}\n{"session":"abcd"}\n%s\n' "$BODY" > "$tmp/c10"
  printf 'VERDICT: CLEAN\n\n%s\nConnection lost, reconnecting ... (attempt 9)\n' "$BODY" > "$tmp/c11"

  ok()  { T=$((T+1)); printf '  ok   %s\n' "$1"; }
  no()  { T=$((T+1)); F=$((F+1)); printf '  FAIL %s\n' "$1"; }

  verdict_of() { case "$1" in 0) printf 'pass\n' ;; 1) printf 'FAILED\n' ;; 3) printf 'UNAVAILABLE\n' ;; *) printf 'exit-%s\n' "$1" ;; esac; }

  echo "scripts/external-review.sh --selftest"
  echo
  echo "  the stub matrix: one reviewer output per row, judged by round_verdict"
  echo

  # TABLE DRIVEN, and every row gets an expected verdict. The first six rows are
  # the six the plan names, in its order; the rest close the same class by the
  # other routes an adversary would take.
  local row body rc label expect got
  while IFS='|' read -r body rc expect label; do
    [ -n "$body" ] || continue
    STUB_BODY="$tmp/$body" STUB_RC="$rc" "$SELF" "$tmp/artifact.md" "$tmp/out" "find one unverifiable claim" \
      >/dev/null 2>"$tmp/err"
    got="$(verdict_of $?)"
    if [ "$got" = "$expect" ]; then ok "$(printf '%-11s %s' "$got" "$label")"
    else no "$(printf '%-11s %s -- expected %s' "$got" "$label" "$expect")"; fi
  done <<'ROWS'
c1|0|pass|a CLEAN verdict with a review behind it
c2|0|pass|a FINDINGS verdict with a MAJOR block
c3|0|FAILED|an empty file
c4|0|FAILED|narration only ("Filing the defects...")
c5|0|FAILED|a reconnect loop
c6|1|UNAVAILABLE|a non-zero exit ("non-interactive mode is not available")
c7|0|FAILED|FINDINGS with no severity block
c8|0|FAILED|a verdict on line 2 instead of line 1
c9|0|FAILED|a bare verdict line, 15 bytes, nothing behind it
c10|0|FAILED|metadata JSON and nothing else
c11|0|FAILED|a CLEAN verdict with a reconnect loop buried in the body
ROWS

  echo
  # The .meta line is the whole audit trail for which model a gate ran on.
  STUB_BODY="$tmp/c1" STUB_RC=0 "$SELF" "$tmp/artifact.md" "$tmp/out" >/dev/null 2>&1
  local meta; meta="$(cat "$tmp/out.meta" 2>/dev/null)"
  case "$meta" in
    "model=gpt-6-astra source=discovered rule="*) ok "the round records the model it actually ran on: $meta" ;;
    *) no "the .meta line must name the discovered model -- got: $meta" ;;
  esac
  STUB_BODY="$tmp/c3" STUB_RC=0 "$SELF" "$tmp/artifact.md" "$tmp/failed-out" >/dev/null 2>&1
  [ -s "$tmp/failed-out.meta" ] && ok "a FAILED round still records its binding" \
    || no "a FAILED round must still record its binding"

  # A pin beats discovery and is never second-guessed.
  REVIEWER_MODEL=an-explicit-pin STUB_BODY="$tmp/c1" STUB_RC=0 \
    "$SELF" "$tmp/artifact.md" "$tmp/out" >/dev/null 2>&1
  grep -q '^model=an-explicit-pin source=pinned' "$tmp/out.meta" \
    && ok "an explicit REVIEWER_MODEL is used and recorded as pinned" \
    || no "an explicit REVIEWER_MODEL must be used untouched -- got: $(cat "$tmp/out.meta")"

  # THE RULE THAT MAKES THIS GATE WORTH RUNNING: no pin and no discovery means
  # UNAVAILABLE, never the CLI's own default model.
  ( unset REVIEWER_MODEL
    printf 'REVIEWER_CLI=codex\nREVIEWER_MODEL=\n' > "$tmp/codex.conf"
    HARNESS_REVIEWER_CONF="$tmp/codex.conf" REVIEWER_CLI=codex \
      "$SELF" "$tmp/artifact.md" "$tmp/out2" >/dev/null 2>"$tmp/err2" )
  local rc2=$?
  if [ "$rc2" = "3" ] && grep -q 'discovery is auggie-only' "$tmp/err2"; then
    ok "a non-auggie CLI with no pin is UNAVAILABLE, not the CLI default"
  else
    no "a non-auggie CLI with no pin must exit 3 -- got $rc2: $(head -2 "$tmp/err2" | tr '\n' ' ')"
  fi

  # --check applies the SAME function to a hand-pasted file, which is the
  # degraded path's whole premise.
  "$SELF" --check "$tmp/c1" >/dev/null 2>&1 && ok "--check passes a good pasted round" || no "--check must pass a good pasted round"
  "$SELF" --check "$tmp/c4" >/dev/null 2>&1 && no "--check must fail a narration-only pasted round" || ok "--check fails a narration-only pasted round"

  if [ "$live" = "1" ]; then
    echo
    echo "  --live: one real round against the configured reviewer"
    unset REVIEWER_CLI HARNESS_REVIEWER_CONF
    PATH="${PATH#"$tmp/bin:"}"; export PATH
    local lrc
    "$SELF" "$ROOT/README.md" "$tmp/live" "Find one claim in this README that the repo does not support." >/dev/null 2>"$tmp/liveerr"
    lrc=$?
    printf '  live round exited %s\n' "$lrc"
    sed 's/^/    /' "$tmp/liveerr" | head -8
    if [ "$lrc" = "0" ]; then
      head -1 "$tmp/live" | grep -q '^VERDICT: ' && ok "the live round returned a VERDICT line" || no "the live round returned no VERDICT line"
      [ -s "$tmp/live.meta" ] && ok "the live round wrote its .meta: $(cat "$tmp/live.meta")" || no "the live round wrote no .meta"
      cp "$tmp/live" "$ROOT/runtime/verify/live-round.txt" 2>/dev/null || true
      cp "$tmp/live.meta" "$ROOT/runtime/verify/live-round.txt.meta" 2>/dev/null || true
    else
      no "the live round did not pass (exit $lrc) -- see the stderr above"
    fi
  fi

  echo
  if [ "$F" -gt 0 ]; then printf 'FAILED %d of %d assertions\n' "$F" "$T"; return 1; fi
  printf 'OK all %d assertions passed\n' "$T"
  return 0
}

# ---------------------------------------------------------------- arg handling
[ $# -gt 0 ] || die "usage: external-review.sh <artifact> <round-output> [focus] | --probe | --check <file> | --selftest [--live]"
case "$1" in
  --selftest)
    LIVE=0; [ "${2:-}" != "--live" ] || LIVE=1
    selftest "$LIVE"; exit $? ;;
  --check)
    [ -n "${2:-}" ] || die "--check needs a round output path"
    round_verdict "$2" && exit 0 || exit 1 ;;
  --probe)
    CLI="${REVIEWER_CLI:-}"
    [ -n "$CLI" ] || CLI="$(conf_get "$REVIEWER_CONF" REVIEWER_CLI || true)"
    [ -n "$CLI" ] || die "no REVIEWER_CLI in the environment or ${REVIEWER_CONF##*/}"
    probe "$CLI"; exit $? ;;
  -h|--help) sed -n '5,12p' "$SELF"; exit 0 ;;
  -*) die "unknown option: $1" ;;
esac
[ $# -ge 2 ] || die "usage: external-review.sh <artifact> <round-output> [focus]"
review "$1" "$2" "${3:-}"
