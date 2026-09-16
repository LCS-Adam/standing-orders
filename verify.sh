#!/bin/bash
PATH="/usr/local/bin:/usr/bin:/bin:/opt/homebrew/bin:${PATH:-}"; export PATH
set -uo pipefail

# verify.sh - the scrub gate. Fails the build rather than leaking.
#
# A fail-open scrub looks exactly like a passing one, so every check increments
# a counter and the run asserts at the end that it actually ran them all.
#
# The personal-marker denylist deliberately does NOT live in this repo: a list of
# personal markers is itself the leak. Point --denylist at a file outside the
# repo, one case-insensitive term or regex per line, blank lines and # ignored.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DENYLIST="${HARNESS_DENYLIST:-$HOME/.agent-harness-denylist}"
FAIL=0
RAN=0
EXPECTED_CHECKS=11

while [ $# -gt 0 ]; do
  case "$1" in
    --denylist) DENYLIST="${2:-}"; shift 2 ;;
    --denylist=*) DENYLIST="${1#*=}"; shift ;;
    -h|--help) echo "usage: verify.sh [--denylist PATH]"; exit 0 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

pass() { RAN=$((RAN+1)); printf '  \033[32mPASS\033[0m %s\n' "$1"; }
fail() { RAN=$((RAN+1)); FAIL=$((FAIL+1)); printf '  \033[31mFAIL\033[0m %s\n' "$1"; }
show() { printf '         %s\n' "$1"; }

cd "$ROOT"

# Exemptions are PER CHECK on purpose. A single shared exemption list was the
# original bug: docs/ was exempted so the docs could discuss model names, which
# silently also disabled the absolute-path and denylist checks for every file
# under docs/, and a real home path shipped there. Never widen this.
EXEMPT='^verify\.sh:'

# Every scan below runs over TRACKED files, never the working tree. grep -r walks
# .worktrees/, which holds checkouts of this same repo (ignored at .gitignore:6,
# but grep does not read .gitignore), so the gate was scanning copies of itself:
# its own regex source reported as an absolute-path leak, its own docs/ as vendor
# model names. Excluding .worktrees/ by name would fix exactly today's directory
# and go red again on the next untracked node_modules/, .venv/ or build/. Tracked
# files are also the right SCOPE: this gate scrubs what gets carried to another
# machine, and an untracked file is not carried.
# Ceiling: a real source file is exempt until it is git-added. Accepted, because
# an un-added file cannot reach anyone else.
tracked() { git ls-files -z -- "$@"; }
CODEISH=('*.md' '*.sh' '*.json')

# An empty file list means "scanned nothing", not "clean". Without this, running
# the gate outside a checkout would turn seven checks into permanent passes.
NTRACKED=$(git ls-files 2>/dev/null | wc -l | tr -d ' ')
if [ "${NTRACKED:-0}" -lt 2 ]; then
  printf '\033[31mGATE ERROR\033[0m git ls-files returned %s files - scanning nothing, not clean\n' "${NTRACKED:-0}"
  exit 2
fi

echo "Scrubbing $ROOT"
echo

# 1 -------------------------------------------------- absolute home paths
hits=$(tracked "${CODEISH[@]}" | xargs -0r grep -HnE '(/Users/|/home/[a-z]|C:\\Users\\)' 2>/dev/null \
       | grep -vE "$EXEMPT" || true)
if [ -n "$hits" ]; then
  fail "absolute home paths"; printf '%s\n' "$hits" | head -10 | while IFS= read -r l; do show "$l"; done
else pass "no absolute home paths"; fi

# 2 -------------------------------------------------- vendor model names
# Prose must name tiers. Only models.conf binds literals.
# adapters/README.md is exempt from THIS check alone: it carries the old-name ->
# new-name migration table, which has to quote the retired model-named agents.
# It stays subject to every other check, including paths and the denylist.
# docs/ and adapters/README.md must name real models to teach the tier binding
# and to carry the old-name migration table. They stay subject to every OTHER
# check, including absolute paths and the denylist.
VENDOR_EXEMPT="$EXEMPT|^adapters/README\.md|^docs/|^config/models\.conf"
hits=$(tracked "${CODEISH[@]}" | xargs -0r grep -HniE '\b(fable|opus|sonnet|haiku)\b' 2>/dev/null \
       | grep -vE "$VENDOR_EXEMPT" || true)
if [ -n "$hits" ]; then
  fail "vendor model names outside config/models.conf"; printf '%s\n' "$hits" | head -10 | while IFS= read -r l; do show "$l"; done
else pass "no vendor model names outside config/models.conf"; fi

# 3 -------------------------------------------------- every agent pins a tier
missing=""; n=0
for f in agents/*.md; do
  [ -e "$f" ] || continue
  n=$((n+1))
  grep -qE '^model:[[:space:]]*\{\{TIER_(FRONTIER_THINK|FRONTIER_DO|MID|SMALL)\}\}' "$f" || missing="$missing $f"
done
if [ "$n" -eq 0 ]; then fail "no agent definitions found - scanned nothing, which is not the same as clean"
elif [ -n "$missing" ]; then fail "agent definitions missing a {{TIER_*}} model pin:$missing"
else pass "all $n agent definitions pin a tier"; fi

# 4 -------------------------------------------------- skill frontmatter
bad=""; n=0
for f in skills/*/SKILL.md; do
  [ -e "$f" ] || continue
  n=$((n+1))
  head -20 "$f" | grep -q '^name:' || bad="$bad $f(name)"
  head -20 "$f" | grep -q '^description:' || bad="$bad $f(description)"
done
if [ "$n" -eq 0 ]; then fail "no SKILL.md files found - scanned nothing, which is not the same as clean"
elif [ -n "$bad" ]; then fail "SKILL.md missing required frontmatter:$bad"
else pass "all $n skills have name and description"; fi

# 5 -------------------------------------------------- CLAUDE.md imports AGENTS.md
if [ -f CLAUDE.md ] && head -1 CLAUDE.md | grep -q '^@AGENTS\.md$'; then
  pass "CLAUDE.md imports AGENTS.md on line 1"
else
  fail "CLAUDE.md must start with '@AGENTS.md' (symlinks break on Windows)"
fi

# 6 -------------------------------------------------- unsafe settings keys
if [ ! -f config/settings.portable.json ]; then
  fail "config/settings.portable.json is missing - nothing to check, which is not the same as safe"
else
unsafe=$(grep -oE '"(skipDangerousModePermissionPrompt|skipAutoPermissionPrompt|dangerouslySkipPermissions)"' \
         config/settings.portable.json 2>/dev/null || true)
acceptmode=$(jq -r '.permissions.defaultMode // empty' config/settings.portable.json 2>/dev/null || true)
if [ -n "$unsafe" ] || [ "$acceptmode" = "acceptEdits" ] || [ "$acceptmode" = "bypassPermissions" ]; then
  fail "unsafe permission defaults in settings.portable.json: ${unsafe:-} ${acceptmode:-}"
else pass "no permission-bypass defaults in shipped settings"; fi
fi

# 7 -------------------------------------------------- shell script portability
bad=""; n=0
while IFS= read -r f; do
  n=$((n+1))
  head -1 "$f" | grep -q '^#!/bin/bash' || bad="$bad $f"
done < <(git ls-files -- '*.sh')
if [ "$n" -eq 0 ]; then fail "no shell scripts found - scanned nothing, which is not the same as clean"
elif [ -n "$bad" ]; then fail "scripts without an absolute-path shebang:$bad"
else pass "all $n shell scripts use an absolute-path shebang"; fi

# 8 -------------------------------------------------- banned glyphs, client-facing
# Client-facing surfaces only. Agent, skill and template definitions are framework
# config and are exempt from the prose-glyph rule.
targets=$(git ls-files -- 'README.md' 'INSTALL.md' 'docs/*.md' 'adapters/*.md')
glyphs=""
if [ -n "$targets" ]; then
  glyphs=$(printf '%s\n' "$targets" | while IFS= read -r f; do
    perl -CSD -ne 'print "$ARGV:$.\n" if /[\x{2014}\x{2013}\x{2012}\x{2015}\x{2018}\x{2019}\x{201C}\x{201D}\x{2026}\x{00A0}\x{200B}\x{00D7}\x{00B7}]/' "$f"
  done)
fi
if [ -z "$targets" ]; then
  fail "no client-facing docs found - scanned nothing, which is not the same as clean"
elif [ -n "$glyphs" ]; then
  fail "banned glyphs in client-facing docs"; printf '%s\n' "$glyphs" | head -10 | while IFS= read -r l; do show "$l"; done
else pass "no banned glyphs in client-facing docs"; fi

# 9 -------------------------------------------------- personal-marker denylist
if [ -f "$DENYLIST" ]; then
  terms=$(grep -vE '^[[:space:]]*(#|$)' "$DENYLIST" || true)
  if [ -z "$terms" ]; then
    pass "denylist $DENYLIST is empty (no terms to check)"
  else
    hits=$(printf '%s\n' "$terms" | while IFS= read -r t; do
             [ -n "$t" ] || continue
             tracked "${CODEISH[@]}" | xargs -0r grep -HniE "$t" 2>/dev/null | grep -vE "$EXEMPT" || true
           done)
    if [ -n "$hits" ]; then
      fail "denylist matches"; printf '%s\n' "$hits" | head -10 | while IFS= read -r l; do show "$l"; done
    else pass "no denylist matches ($(printf '%s\n' "$terms" | wc -l | tr -d ' ') terms checked)"; fi
  fi
else
  # Not a pass and not a silent skip: an unconfigured denylist is a real gap.
  RAN=$((RAN+1))
  printf '  \033[33mWARN\033[0m no denylist at %s - personal-marker check did not run\n' "$DENYLIST"
  show "create one (outside this repo), one term per line, or pass --denylist PATH"
fi

# 10 ------------------------------------------------- dangling file references
# Instructions that point at a file which will not exist after install are worse
# than no instruction: the agent is told to go read something and finds nothing.
# Only these land in ~/.claude/rules/ (see cmd_install in bin/harness).
INSTALLED_RULES="00-harness-core.md 10-claude-specifics.md shell-portability.md"
dangling=""
while IFS= read -r ref; do
  base="${ref##*/}"
  case " $INSTALLED_RULES " in *" $base "*) ;; *) dangling="$dangling $ref" ;; esac
done < <(tracked '*.md' '*.sh' | xargs -0r grep -hoE '~/\.claude/rules/[A-Za-z0-9._-]+\.md' 2>/dev/null | sort -u)
if [ -n "$dangling" ]; then
  fail "references to ~/.claude/rules files that install never creates:$dangling"
else
  pass "no dangling ~/.claude/rules references"
fi

# 11 ------------------------------------------------- dangling slash commands
# The harness shipped docs naming slash commands that do not exist. A reader
# types one, nothing happens, and every other instruction in that doc loses its
# credibility. So every backticked /token has to resolve to something real.
#
# Two allowlists on purpose: they make different claims and merging them would
# make the first claim false. BUILTIN_SLASH is commands the HOST tool provides,
# which is why no file in this repo backs them. NOT_A_COMMAND is tokens that are
# not commands at all and only look like one to a matcher that works on shape.
# A reason per term, because the lists are the checkable part of this check:
#   clear compact loop agents help  host built-ins
#   plan status                     host built-ins, and the two names the phase
#                                   commands were deliberately NOT given
#   tmp                             the /tmp directory, not a command
#   something notes-repo-recon      docs/choosing-your-tools.md:245,251 names
#                                   both as commands that do NOT exist; that is
#                                   the point the passage is making
# Ceiling: backticked tokens only. A bare slash command in prose or a heading is
# invisible here (docs/handoff-and-resume.md:83 has one). Backticks are the
# repo's convention, so this catches what is written, not what could be.
SLASH_SCAN="README.md docs adapters agents skills commands AGENTS.md CLAUDE.md templates"
BUILTIN_SLASH="clear compact loop agents help plan status"
NOT_A_COMMAND="tmp something notes-repo-recon"
tokens=$(tracked $SLASH_SCAN | xargs -0r grep -hoE '`/[a-z][a-z0-9-]*`' 2>/dev/null \
         | sed -e 's|^`/||' -e 's|`$||' | sort -u)
dangling=""
while IFS= read -r tok; do
  [ -n "$tok" ] || continue
  [ -f "commands/$tok.md" ] && continue
  [ -f "skills/$tok/SKILL.md" ] && continue
  case " $BUILTIN_SLASH $NOT_A_COMMAND " in *" $tok "*) continue ;; esac
  dangling="$dangling $tok"
done <<< "$tokens"
if [ -z "$tokens" ]; then
  # Zero tokens means the scan reached nothing, not that the repo is clean. A
  # renamed directory would otherwise turn this check into a permanent PASS,
  # which is the exact failure this whole file exists to refuse.
  fail "slash-command scan matched nothing - the scan set is broken, not clean"
  show "expected at least one backticked slash command across: $SLASH_SCAN"
elif [ -n "$dangling" ]; then
  # -o drops the filename, so re-grep each offender with -n: a gate that cannot
  # say WHERE sends you searching the whole repo for a token.
  fail "slash commands referenced but not defined:$dangling"
  for tok in $dangling; do
    tracked $SLASH_SCAN | xargs -0r grep -HnF "\`/$tok\`" 2>/dev/null || true
  done | head -10 | while IFS= read -r l; do show "$l"; done
else
  pass "every backticked slash command resolves to commands/, skills/, or an allowlist"
fi

# ---------------------------------------------------- docs must not go stale
# Not a numbered check (it would have to count itself). The enumerated list in
# getting-started.md drifted from the gate the first time a check was added, so
# this warns rather than letting a reader trust a stale number.
doclist=$(awk '/silently passing nothing:/,/^Read the output/' docs/getting-started.md 2>/dev/null \
          | grep -cE '^[0-9]+\. ' || echo 0)
if [ "$doclist" -gt 0 ] && [ "$doclist" -ne "$EXPECTED_CHECKS" ]; then
  printf '  \033[33mWARN\033[0m docs/getting-started.md enumerates %s checks, the gate runs %s\n' \
    "$doclist" "$EXPECTED_CHECKS"
fi

# ---------------------------------------------------- assert the gate ran
echo
if [ "$RAN" -ne "$EXPECTED_CHECKS" ]; then
  printf '\033[31mGATE ERROR\033[0m ran %d of %d checks - the gate itself is broken\n' "$RAN" "$EXPECTED_CHECKS"
  exit 2
fi

if [ "$FAIL" -gt 0 ]; then
  printf '\033[31mFAILED\033[0m %d of %d checks\n' "$FAIL" "$RAN"
  exit 1
fi
printf '\033[32mOK\033[0m all %d checks passed\n' "$RAN"
