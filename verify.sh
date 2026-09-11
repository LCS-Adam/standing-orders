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
EXPECTED_CHECKS=10

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

# Files that may legitimately contain otherwise-banned strings.
EXEMPT='^\./(config/models\.conf|verify\.sh|docs/|\.git/)'

echo "Scrubbing $ROOT"
echo

# 1 -------------------------------------------------- absolute home paths
hits=$(grep -rnE '(/Users/|/home/[a-z]|C:\\Users\\)' --include='*.md' --include='*.sh' --include='*.json' . 2>/dev/null \
       | grep -vE "$EXEMPT" || true)
if [ -n "$hits" ]; then
  fail "absolute home paths"; printf '%s\n' "$hits" | head -10 | while IFS= read -r l; do show "$l"; done
else pass "no absolute home paths"; fi

# 2 -------------------------------------------------- vendor model names
# Prose must name tiers. Only models.conf binds literals.
# adapters/README.md is exempt from THIS check alone: it carries the old-name ->
# new-name migration table, which has to quote the retired model-named agents.
# It stays subject to every other check, including paths and the denylist.
VENDOR_EXEMPT="$EXEMPT|^\./adapters/README\.md"
hits=$(grep -rniE '\b(fable|opus|sonnet|haiku)\b' --include='*.md' --include='*.sh' --include='*.json' . 2>/dev/null \
       | grep -vE "$VENDOR_EXEMPT" || true)
if [ -n "$hits" ]; then
  fail "vendor model names outside config/models.conf"; printf '%s\n' "$hits" | head -10 | while IFS= read -r l; do show "$l"; done
else pass "no vendor model names outside config/models.conf"; fi

# 3 -------------------------------------------------- every agent pins a tier
missing=""
for f in agents/*.md; do
  [ -e "$f" ] || continue
  grep -qE '^model:[[:space:]]*\{\{TIER_(FRONTIER_THINK|FRONTIER_DO|MID|SMALL)\}\}' "$f" || missing="$missing $f"
done
if [ -n "$missing" ]; then fail "agent definitions missing a {{TIER_*}} model pin:$missing"
else pass "all $(ls -1 agents/*.md 2>/dev/null | wc -l | tr -d ' ') agent definitions pin a tier"; fi

# 4 -------------------------------------------------- skill frontmatter
bad=""
for f in skills/*/SKILL.md; do
  [ -e "$f" ] || continue
  head -20 "$f" | grep -q '^name:' || bad="$bad $f(name)"
  head -20 "$f" | grep -q '^description:' || bad="$bad $f(description)"
done
if [ -n "$bad" ]; then fail "SKILL.md missing required frontmatter:$bad"
else pass "all $(ls -1 skills/*/SKILL.md 2>/dev/null | wc -l | tr -d ' ') skills have name and description"; fi

# 5 -------------------------------------------------- CLAUDE.md imports AGENTS.md
if [ -f CLAUDE.md ] && head -1 CLAUDE.md | grep -q '^@AGENTS\.md$'; then
  pass "CLAUDE.md imports AGENTS.md on line 1"
else
  fail "CLAUDE.md must start with '@AGENTS.md' (symlinks break on Windows)"
fi

# 6 -------------------------------------------------- unsafe settings keys
unsafe=$(grep -oE '"(skipDangerousModePermissionPrompt|skipAutoPermissionPrompt|dangerouslySkipPermissions)"' \
         config/settings.portable.json 2>/dev/null || true)
acceptmode=$(jq -r '.permissions.defaultMode // empty' config/settings.portable.json 2>/dev/null || true)
if [ -n "$unsafe" ] || [ "$acceptmode" = "acceptEdits" ] || [ "$acceptmode" = "bypassPermissions" ]; then
  fail "unsafe permission defaults in settings.portable.json: ${unsafe:-} ${acceptmode:-}"
else pass "no permission-bypass defaults in shipped settings"; fi

# 7 -------------------------------------------------- shell script portability
bad=""
while IFS= read -r f; do
  head -1 "$f" | grep -q '^#!/bin/bash' || bad="$bad $f"
done < <(find . -name '*.sh' -not -path './.git/*')
if [ -n "$bad" ]; then fail "scripts without an absolute-path shebang:$bad"
else pass "all shell scripts use an absolute-path shebang"; fi

# 8 -------------------------------------------------- banned glyphs, client-facing
# Client-facing surfaces only. Agent, skill and template definitions are framework
# config and are exempt from the prose-glyph rule.
targets=$(find . -maxdepth 2 \( -name 'README.md' -o -name 'INSTALL.md' -o -path './docs/*.md' -o -path './adapters/*.md' \) -not -path './.git/*' 2>/dev/null)
glyphs=""
if [ -n "$targets" ]; then
  glyphs=$(printf '%s\n' "$targets" | while IFS= read -r f; do
    perl -CSD -ne 'print "$ARGV:$.\n" if /[\x{2014}\x{2013}\x{2012}\x{2015}\x{2018}\x{2019}\x{201C}\x{201D}\x{2026}\x{00A0}\x{200B}\x{00D7}\x{00B7}]/' "$f"
  done)
fi
if [ -n "$glyphs" ]; then
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
             grep -rniE "$t" --include='*.md' --include='*.sh' --include='*.json' . 2>/dev/null | grep -vE "$EXEMPT" || true
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
done < <(grep -rhoE '~/\.claude/rules/[A-Za-z0-9._-]+\.md' --include='*.md' --include='*.sh' . 2>/dev/null | sort -u)
if [ -n "$dangling" ]; then
  fail "references to ~/.claude/rules files that install never creates:$dangling"
else
  pass "no dangling ~/.claude/rules references"
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
