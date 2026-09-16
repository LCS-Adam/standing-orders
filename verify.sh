#!/bin/bash
PATH="/usr/local/bin:/usr/bin:/bin:/opt/homebrew/bin:${PATH:-}"; export PATH
set -uo pipefail

# verify.sh - the scrub gate. Fails the build rather than leaking.
#
# A fail-open scrub looks exactly like a passing one, so every check increments
# a counter and the run asserts at the end that it actually ran them all.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SELF="$ROOT/${BASH_SOURCE[0]##*/}"
FAIL=0
RAN=0
EXPECTED_CHECKS=12

while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help) echo "usage: verify.sh"; exit 0 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

pass() { RAN=$((RAN+1)); printf '  \033[32mPASS\033[0m %s\n' "$1"; }
fail() { RAN=$((RAN+1)); FAIL=$((FAIL+1)); printf '  \033[31mFAIL\033[0m %s\n' "$1"; }
show() { printf '         %s\n' "$1"; }
gate_error() { printf '\033[31mGATE ERROR\033[0m %s\n' "$1"; exit 2; }

cd "$ROOT"

# ---------------------------------------------------------------- THE SHIPPED SET
#
# THE INVARIANT: nothing can reach ~/.claude that this gate did not scan.
#
# One definition of "the repo", used by this gate AND by `harness install`
# (bin/harness, function `shipped`). Check 11 fails the build when the two
# disagree, so if you change this line, change that one in the same commit.
#
# It is every file a clone gets, plus every file present and not ignored.
#   - The working tree alone was wrong: it walks .worktrees/, which holds
#     checkouts of this same repo (ignored at .gitignore:6, but grep -r does not
#     read .gitignore), so the gate scanned copies of itself and its own regex
#     source reported as an absolute-path leak.
#   - Tracked alone was wrong, and the comment that called it an acceptable
#     ceiling ("an un-added file cannot reach anyone else") was false: cmd_install
#     copied the WORKING TREE, so an untracked hooks/leak-hook.sh installed
#     straight into ~/.claude/hooks/ with every check blind to it.
#   - Ignored files are out of BOTH sets: this gate does not scan them and the
#     installer does not ship them. That is the only divergence permitted, and it
#     is safe in the one direction that matters.
shipped()   { git ls-files -z --cached --others --exclude-standard -- "$@"; }
shipped_l() { git ls-files    --cached --others --exclude-standard -- "$@"; }

# EVERY check reads this set. It used to be two systems: checks 3, 4, 5 and 6
# globbed the FILESYSTEM while every other check read the INDEX, so
# shrinking one while leaving the other alone turned the whole gate green on
# three committed violations - checks 3 and 4 cheerfully reporting "all 11
# agents" over files the other half could no longer see. Three patches would
# have left three mechanisms free to drift apart again, which is how the shared
# exemption came back after d271923 fixed it.
#
# Exactly two things are NOT this set, each for a stated reason:
#   - check 10's RESOLVER (not its scan) is `git ls-files`, a strict subset. It
#     answers "would a clone have this command file", and a clone gets tracked
#     files only. Scanning more can only find more references; resolving against
#     less can only be stricter.
#   - checks 3 and 4 glob the same directories on disk. That is not a second
#     scan set - it is the assertion that this one set still matches reality,
#     and it is the only way a check can notice its own scan set silently
#     shrinking. It reports, it never scans.

# An empty file list means "scanned nothing", not "clean". Without this, running
# the gate outside a checkout would turn most of these checks into permanent
# passes. The per-check guards below cover the partial case, which is the one
# that actually happens.
NSHIPPED=$(shipped_l 2>/dev/null | wc -l | tr -d ' ')
[ "${NSHIPPED:-0}" -ge 2 ] || gate_error "git ls-files returned ${NSHIPPED:-0} files - scanning nothing, not clean"

# ------------------------------------------------------------ THE TWO BYTE SOURCES
#
# The set above is PATHNAMES. Which BYTES live at those paths is a separate
# question with TWO answers, because there are two consumers:
#   - `harness install` copies the WORKING TREE. Those bytes reach ~/.claude.
#   - a colleague who clones gets the INDEX. Those bytes reach everyone else.
# They diverge routinely, and a gate that takes paths from git but bytes from
# only one source is blind to the other: stage a leak, restore the working copy
# without staging the cleanup, and a disk-reading gate passes while the commit
# carries the leak to every clone. Reproduced before this line existed.
#
# So every LEAK check - 1 (paths), 2 (model names), 7 (shebangs) - reads BOTH.
# Same pathnames, two blobs, one merged hit list.
#
# Rejecting index-vs-worktree divergence outright would be the other fix. It is
# not this one: any unstaged edit to any tracked file is a divergence, so that
# gate would fail on the ordinary pre-commit state.
#
# CEILING, stated because it is real and chosen: checks 3, 4, 5, 6, 8 and 12
# read the working tree only. A staged-but-not-checked-out divergence can hand a
# colleague a stale count or a SKILL.md missing its frontmatter. It cannot hand
# them a leak, because every check that looks for one reads both sources.
cached() { git ls-files -z --cached -- "$@"; }

# scan <exempt-ere> <extra-grep-flags> <pattern> - grep both byte sources.
# Both emit path:line:text, so one exemption filter covers both and sort -u
# collapses the usual case where the two blobs are identical. An EMPTY exempt
# means no exemption, and must not become `grep -vE ""`, which would discard
# every line and pass everything.
# No caller passes an empty one today, so that branch is currently unreached. It
# stays anyway: the guard costs one line, and its absence costs a check that
# silently passes everything.
scan() {
  local exempt="$1" flags="$2" pat="$3"
  { shipped | xargs -0r grep -HnE $flags -e "$pat" 2>/dev/null
    git -c grep.column=false grep --cached --no-color -nE $flags -e "$pat" 2>/dev/null
  } | sort -u | if [ -n "$exempt" ]; then grep -vE "$exempt"; else cat; fi
}

# ------------------------------------------------------------ the shipped set is text
# grep -I means "treat a binary file as having no matches". One NUL byte
# anywhere therefore removed a file from every content check below while the
# installer copied it into ~/.claude regardless - a silent exclusion, which is
# the exact failure this gate exists to refuse. So a binary in the shipped set
# is a gate error and no grep below carries -I. Both byte sources, for the same
# reason as scan(): a NUL staged and cleaned on disk is the same bypass.
binary=$( { shipped | xargs -0r perl -0777 -ne 'print "$ARGV (working tree)\n" if /\x00/' 2>/dev/null
            while IFS= read -r -d '' f; do
              git cat-file blob ":$f" 2>/dev/null | perl -0777 -ne 'exit 1 if /\x00/' \
                || printf '%s (index)\n' "$f"
            done < <(cached)
          } | sort -u)
[ -z "$binary" ] || gate_error "binary files in the shipped set - every content check would skip them: $(printf '%s ' $binary)"

# Client-facing surfaces: what a reader outside this repo ends up reading.
# DENY BY DEFAULT. A new top-level doc, or a renamed docs/, is client-facing
# until someone lists its directory here; the previous allowlist
# (README.md INSTALL.md docs/*.md adapters/*.md) went green on one file when the
# other nine left the scan set.
#
# This is a TARGET SET, not an exemption. Checks 8 and 12 share it because they
# make the SAME claim about the SAME surface. An exemption - "this file is out of
# THIS check" - stays inside the check that owns it. See the gate-integrity
# assertion below.
FRAMEWORK_PROSE='^(agents|commands|hooks|rules|config|templates|skills)/|^(AGENTS|CLAUDE)\.md$'
CLIENT_DOCS=$(shipped_l '*.md' | grep -vE "$FRAMEWORK_PROSE")

# ---------------------------------------------------------------- gate integrity
# No exemption may be shared between checks. That has been the bug twice: once
# when docs/ was exempted so the docs could name models and the absolute-path
# check silently went with it, and again when a second leak check reused check
# 1's EXEMPT and so stopped looking at verify.sh, the one file check 1 has a
# reason to skip. A comment saying "never widen this" did not hold either time,
# so it is machine-checked now:
# every *EXEMPT* variable may be REFERENCED from at most one numbered check.
shared_exempt=$(awk '
  /^# [0-9]+ -+/ { blk = $2 }
  blk != "" {
    line = $0
    while (match(line, /\$\{?[A-Za-z_]*EXEMPT[A-Za-z_]*\}?/)) {
      v = substr(line, RSTART, RLENGTH); gsub(/[$\{\}]/, "", v)
      if (!((v SUBSEP blk) in seen)) { seen[v SUBSEP blk] = 1; n[v]++; where[v] = where[v] " " blk }
      line = substr(line, RSTART + RLENGTH)
    }
  }
  END { for (v in n) if (n[v] > 1) printf "%s is used by checks%s\n", v, where[v] }
' "$SELF")
[ -z "$shared_exempt" ] || gate_error "exemption shared between checks: $shared_exempt"

echo "Scrubbing $ROOT"
echo

# 1 -------------------------------------------------- absolute home paths
# No extension filter: bin/harness is the largest script in the repo and had no
# extension, so it was invisible to every grep-based check. Binaries are not
# skipped here either; they are refused above.
EXEMPT_PATHS='^verify\.sh:'
# /root is a home directory too, a Linux username can start with a digit, and a
# Windows path is case-insensitive and not always on C:. The old expression
# covered /Users/, /home/[a-z] and C:\Users\ only, while the PASS line below
# claimed every absolute home path.
HOME_PATHS='(/Users/|/home/[^/[:space:]]|/root/|[A-Za-z]:[\\/]+[Uu][Ss][Ee][Rr][Ss][\\/])'
# LIVENESS. Two engines now - BSD grep on disk, git's own on the index - and a
# pattern one accepts can be dead in the other: \b matches nothing in git grep
# -E on git 2.54, which would have made every index-side scan a permanent pass.
# verify.sh's own source contains a literal home path, so this pattern MUST hit
# it here. Top level, not inside $(): gate_error's exit has to kill the gate,
# not a subshell.
git -c grep.column=false grep --cached --no-color -qE "$HOME_PATHS" -- verify.sh \
  || gate_error "home-path pattern matches nothing in verify.sh's own index blob - the index-side scan is dead"
hits=$(scan "$EXEMPT_PATHS" '' "$HOME_PATHS")
# A symlink's blob content IS the path it points at. grep reads THROUGH the link
# (or errors past a missing target), so the stored string is the one leak shape
# the scan above cannot see, and the one where the path itself is the payload.
linkhits=$(shipped_l | while IFS= read -r f; do
             [ -L "$f" ] || continue
             t=$(readlink "$f" 2>/dev/null || true)
             case "$t" in
               (/Users/*|/home/*|/root/*) printf '%s: symlink -> %s\n' "$f" "$t" ;;
             esac
           done)
hits="${hits}${hits:+$'\n'}${linkhits}"
hits="${hits#$'\n'}"
if [ -n "$hits" ]; then
  fail "absolute home paths (working tree or index)"; printf '%s\n' "$hits" | head -10 | while IFS= read -r l; do show "$l"; done
else pass "no absolute home paths"; fi

# 2 -------------------------------------------------- vendor model names
# Prose must name tiers. Only models.conf binds literals. docs/ and
# adapters/README.md must name real models to teach the tier binding and to carry
# the old-name migration table; verify.sh names them in this regex. All of them
# stay subject to every OTHER check, including paths - this
# exemption is written out in full here rather than reusing check 1's, because
# sharing one is how both of the last two leaks happened.
# scripts/resolve-tier.sh is the fifth and last. It is the one file whose JOB is
# to classify a model by FAMILY, so the family patterns are its source code, and
# its selftest fixture is a stub vendor allowlist whose entries carry the vendor
# DISPLAY NAMES as test data. Weakening the family regex to dodge this check is
# the one thing that must never happen here: a dropped family pattern is exactly
# how a same-family reviewer gets through the gate Wave R exists to build.
# One exact path, never a directory prefix.
EXEMPT_VENDOR='^verify\.sh:|^adapters/README\.md|^docs/|^config/models\.conf|^scripts/resolve-tier\.sh:'
# -w, not \b: git grep -E does not implement \b, so the index side of this scan
# would have matched nothing and passed forever. Both engines implement -w and
# both return the same hits on this repo.
VENDOR_NAMES='(fable|opus|sonnet|haiku)'
git -c grep.column=false grep --cached --no-color -qiwE -e "$VENDOR_NAMES" -- verify.sh \
  || gate_error "vendor pattern matches nothing in verify.sh's own index blob - the index-side scan is dead"
hits=$(scan "$EXEMPT_VENDOR" '-iw' "$VENDOR_NAMES")
if [ -n "$hits" ]; then
  fail "vendor model names outside config/models.conf (working tree or index)"; printf '%s\n' "$hits" | head -10 | while IFS= read -r l; do show "$l"; done
else pass "no vendor model names outside config/models.conf"; fi

# Checks 3 and 4 both need "scan a glob, then prove the scan set still matches
# disk" before they can trust a content predicate over it - that comparison is
# the part that drifted between them before (see the shipped-set comment
# above), so it is written once here and each check supplies only its own
# predicate and messages. Sets $n/$scanned/$ondisk/$unscanned for the caller.
scan_vs_disk() {
  n=0; scanned=""
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    n=$((n+1)); scanned="$scanned $f"
  done < <(shipped_l "$1")
  ondisk=0; unscanned=""
  for f in $1; do
    [ -e "$f" ] || continue
    ondisk=$((ondisk+1))
    case " $scanned " in *" $f "*) ;; *) unscanned="$unscanned $f" ;; esac
  done
}

# 3 -------------------------------------------------- every agent pins a tier
# Guard is a COMPARISON against what is on disk, not a test for zero. A scan set
# of 1 agent out of 11 reported PASS on almost nothing and printed a reassuring
# "all 1 agent definitions pin a tier" while it did it.
scan_vs_disk 'agents/*.md'
if [ "$ondisk" -eq 0 ]; then fail "no agent definitions found - scanned nothing, which is not the same as clean"
elif [ -n "$unscanned" ]; then fail "agent definitions on disk that the scan set does not cover ($n of $ondisk):$unscanned"
else
  missing=""
  for f in $scanned; do
    grep -qE '^model:[[:space:]]*\{\{TIER_(FRONTIER_THINK|FRONTIER_DO|MID|SMALL)\}\}' "$f" 2>/dev/null || missing="$missing $f"
  done
  if [ -n "$missing" ]; then fail "agent definitions missing a {{TIER_*}} model pin:$missing"
  else pass "all $n agent definitions pin a tier"; fi
fi

# 4 -------------------------------------------------- skill frontmatter
scan_vs_disk 'skills/*/SKILL.md'
if [ "$ondisk" -eq 0 ]; then fail "no SKILL.md files found - scanned nothing, which is not the same as clean"
elif [ -n "$unscanned" ]; then fail "SKILL.md files on disk that the scan set does not cover ($n of $ondisk):$unscanned"
else
  bad=""
  for f in $scanned; do
    head -20 "$f" 2>/dev/null | grep -q '^name:' || bad="$bad $f(name)"
    head -20 "$f" 2>/dev/null | grep -q '^description:' || bad="$bad $f(description)"
  done
  if [ -n "$bad" ]; then fail "SKILL.md missing required frontmatter:$bad"
  else pass "all $n skills have name and description"; fi
fi

# 5 -------------------------------------------------- CLAUDE.md imports AGENTS.md
if [ -z "$(shipped_l 'CLAUDE.md')" ]; then
  fail "CLAUDE.md is not in the shipped set - a clone would not get one at all"
elif head -1 CLAUDE.md 2>/dev/null | grep -q '^@AGENTS\.md$'; then
  pass "CLAUDE.md imports AGENTS.md on line 1"
else
  fail "CLAUDE.md must start with '@AGENTS.md' (symlinks break on Windows)"
fi

# 6 -------------------------------------------------- unsafe settings keys
if [ -z "$(shipped_l 'config/settings.portable.json')" ]; then
  fail "config/settings.portable.json is not in the shipped set - nothing to check, which is not the same as safe"
elif [ ! -r config/settings.portable.json ]; then
  fail "config/settings.portable.json is not readable - the check did not run, which is not the same as safe"
else
unsafe=$(grep -oE '"(skipDangerousModePermissionPrompt|skipAutoPermissionPrompt|dangerouslySkipPermissions)"' \
         config/settings.portable.json 2>/dev/null || true)
acceptmode=$(jq -r '.permissions.defaultMode // empty' config/settings.portable.json 2>/dev/null || true)
if [ -n "$unsafe" ] || [ "$acceptmode" = "acceptEdits" ] || [ "$acceptmode" = "bypassPermissions" ]; then
  fail "unsafe permission defaults in settings.portable.json: ${unsafe:-} ${acceptmode:-}"
else pass "no permission-bypass defaults in shipped settings"; fi
fi

# 7 -------------------------------------------------- shell script portability
# The candidate set is a UNION of four sources, not one heuristic. Selecting by
# first-line-shebang alone was self-fulfilling: a hooks/new-hook.sh with NO
# shebang was invisible here, did not reduce the count of scripts found, and was
# still installed and chmod +x'd by cmd_install. A check that only inspects the
# files that already pass it is not a check.
#   - hooks/*.sh and bin/*: install chmod +x's the first and the second is where
#     bin/harness lives, extensionless.
#   - anything executable on disk, tracked or not, and anything the INDEX marks
#     100755 - the executable bit is the whole reason this matters, and the two
#     disagree for a staged-then-cleaned file.
#   - anything whose first line is already a shebang, wherever it lives.
# This repo is bash-only by rule (rules/shell-portability.md), so a non-bash
# executable failing here is the correct answer, not a false positive.
candidates=$( { shipped_l 'hooks/*.sh' 'bin/*'
                shipped_l | while IFS= read -r f; do
                  [ -f "$f" ] && [ -x "$f" ] && printf '%s\n' "$f"
                done
                git ls-files -s | awk -F'\t' '$1 ~ /^100755 /{print $2}'
                shipped | xargs -0r awk 'FNR==1 && /^#!/{print FILENAME}' 2>/dev/null
                # ...and the same first-line test against the INDEX blob. The awk
                # above reads disk, so a file staged with a shebang whose working
                # copy is no longer a script was selected by nothing: not the two
                # path globs, not either exec bit (mode 100644), not the disk
                # first-line test. Its staged shebang reached a colleague while
                # the gate said "all N shell scripts". Same shape as the leak
                # checks: moving the byte-read to two sources is not enough while
                # candidate SELECTION still only looks at one.
                shipped_l | while IFS= read -r f; do
                  git ls-files --error-unmatch -- "$f" >/dev/null 2>&1 || continue
                  git cat-file blob ":$f" 2>/dev/null | head -1 | grep -q '^#!' \
                    && printf '%s\n' "$f"
                done
              } | grep -v '^$' | sort -u)
# Both byte sources: a staged script with a fragile shebang reaches a colleague
# even when the working copy has been fixed.
SHEBANG='^#!/bin/bash([[:space:]].*)?$'
bad=""; n=0
while IFS= read -r f; do
  [ -n "$f" ] || continue
  n=$((n+1))
  if [ -f "$f" ]; then
    head -1 "$f" 2>/dev/null | grep -qE "$SHEBANG" || bad="$bad $f"
  fi
  if git ls-files --error-unmatch -- "$f" >/dev/null 2>&1; then
    git cat-file blob ":$f" 2>/dev/null | head -1 | grep -qE "$SHEBANG" || bad="$bad $f(index)"
  fi
done <<< "$candidates"
if [ "$n" -eq 0 ]; then fail "no shell scripts found - scanned nothing, which is not the same as clean"
elif [ -n "$bad" ]; then fail "scripts without an absolute-path shebang:$bad"
else pass "all $n shell scripts use an absolute-path shebang"; fi

# 8 -------------------------------------------------- banned glyphs, client-facing
# CLIENT_DOCS plus the README templates the readme-coauthoring skill hands a user
# to publish. Those live under skills/, but they are OUTPUT, not framework config:
# whatever survives placeholder substitution lands verbatim in someone's README.
# Framework prose keeps its exemption - AGENTS.md's own rule text and the skill
# that teaches the rule have to be able to discuss the glyphs.
targets=$(printf '%s\n%s\n' "$CLIENT_DOCS" "$(shipped_l 'skills/readme-coauthoring/assets/templates/*.md')" \
          | grep -v '^$' | sort -u)
glyphs=""
if [ -n "$targets" ]; then
  glyphs=$(printf '%s\n' "$targets" | while IFS= read -r f; do
    perl -CSD -ne 'print "$ARGV:$.\n" if /[\x{2014}\x{2013}\x{2012}\x{2015}\x{2018}\x{2019}\x{201C}\x{201D}\x{2026}\x{00A0}\x{200B}\x{00D7}\x{00B7}]/' "$f"
    # AGENTS.md bans the HTML entities too, and GitHub renders all of them as the
    # banned glyph. The codepoint class above cannot see them.
    grep -nE '&(mdash|ndash|hellip|nbsp|times|middot|#8212|#8211|#8230|#160|#183|#215|#x201[4-9CDcd]|#x2026|#x00[AaBb][0-9A-Fa-f]);' "$f" \
      | sed "s|^|$f:|" | cut -d: -f1,2
  done)
fi
if [ -z "$targets" ]; then
  fail "no client-facing docs found - scanned nothing, which is not the same as clean"
elif ! printf '%s\n' "$targets" | grep -qx 'README.md'; then
  fail "README.md is not in the client-facing scan set - the set is broken, not clean"
elif [ -n "$glyphs" ]; then
  fail "banned glyphs in client-facing docs"; printf '%s\n' "$glyphs" | head -10 | while IFS= read -r l; do show "$l"; done
else pass "no banned glyphs in client-facing docs ($(printf '%s\n' "$targets" | wc -l | tr -d ' ') files)"; fi

# 9 -------------------------------------------------- dangling file references
# Instructions that point at a file which will not exist after install are worse
# than no instruction: the agent is told to go read something and finds nothing.
# Only these land in ~/.claude/rules/ (see cmd_install in bin/harness).
INSTALLED_RULES="00-harness-core.md 10-claude-specifics.md shell-portability.md"
dangling=""
while IFS= read -r ref; do
  base="${ref##*/}"
  case " $INSTALLED_RULES " in *" $base "*) ;; *) dangling="$dangling $ref" ;; esac
done < <(shipped | xargs -0r grep -Ihof '~/\.claude/rules/[A-Za-z0-9._-]*\.md' 2>/dev/null | sort -u)
if [ -n "$dangling" ]; then
  fail "references to ~/.claude/rules files that install never creates:$dangling"
else
  pass "no dangling ~/.claude/rules references"
fi

# 10 ------------------------------------------------- dangling slash commands
# The harness shipped docs naming slash commands that do not exist. A reader
# types one, nothing happens, and every other instruction in that doc loses its
# credibility. So every backticked /token has to resolve to something real.
#
# Scan set is everything shipped; resolver is what is TRACKED. The two differ on
# purpose: an untracked commands/ghostcmd.md turned a dangling reference green
# for its author and left it dangling for everyone who clones. Scanning more can
# only find more references; resolving against less can only be stricter.
#
# One allowlist, one claim: commands the HOST tool provides, which is why no file
# in this repo backs them. /plan and /status used to sit here with the written
# reason "the two names the phase commands were deliberately NOT given" - a
# reason that is not "the host provides it", on a list whose whole claim is that
# it does. Nothing references either token, so they are gone rather than
# re-justified. NOT_A_COMMAND is tokens that are not commands at all and only
# look like one to a matcher that works on shape.
#   clear compact loop agents help model resume  host built-ins
#   tmp                                          the /tmp directory
#   something notes-repo-recon                   docs/choosing-your-tools.md:245,251
#                                                names both as commands that do NOT
#                                                exist; that is the passage's point
# Ceiling: backticked tokens only. A bare slash command in prose or a heading is
# invisible here (docs/handoff-and-resume.md:83 has one). Backticks are the
# repo's convention, so this catches what is written, not what could be.
BUILTIN_SLASH="clear compact loop agents help model resume"
NOT_A_COMMAND="tmp something notes-repo-recon"
# Trailing [^`]* so a command documented WITH ITS ARGUMENT is still seen. The old
# matcher required the closing backtick right after the token, so `/deep-plan
# rescope ...` - the normal way to document a command - was invisible.
tokens=$(shipped | xargs -0r grep -Ihao '`/[A-Za-z][A-Za-z0-9_-]*[^`]*`' 2>/dev/null \
         | sed -e 's|^`/||' -e 's|[^A-Za-z0-9_-].*$||' -e 's|`$||' | sort -u)
defined=$(git ls-files -- 'commands/*.md' 'skills/*/SKILL.md' \
          | sed -e 's|^commands/||' -e 's|\.md$||' -e 's|^skills/||' -e 's|/SKILL$||' | sort -u)
dangling=""; seen=0
while IFS= read -r tok; do
  [ -n "$tok" ] || continue
  seen=$((seen+1))
  printf '%s\n' "$defined" | grep -qxF "$tok" && continue
  case " $BUILTIN_SLASH $NOT_A_COMMAND " in *" $tok "*) continue ;; esac
  dangling="$dangling $tok"
done <<< "$tokens"
ntokens=$(printf '%s\n' "$tokens" | grep -c . || true)
if [ -z "$tokens" ]; then
  # Zero tokens means the scan reached nothing, not that the repo is clean.
  fail "slash-command scan matched nothing - the scan set is broken, not clean"
elif [ "$seen" -ne "${ntokens:-0}" ]; then
  # An empty $dangling because the loop never ran reads exactly like an empty
  # $dangling because every token resolved. Count what went through it.
  fail "slash-command loop processed $seen of ${ntokens:-0} tokens - the check did not run to completion"
elif [ -n "$dangling" ]; then
  # -o drops the filename, so re-grep each offender with -n: a gate that cannot
  # say WHERE sends you searching the whole repo for a token.
  fail "slash commands referenced but not defined:$dangling"
  for tok in $dangling; do
    shipped | xargs -0r grep -IHnF "\`/$tok" 2>/dev/null || true
  done | head -10 | while IFS= read -r l; do show "$l"; done
else
  pass "every backticked slash command resolves to commands/, skills/, or the built-in allowlist"
fi

# 11 ------------------------------------------------- installer and gate agree
# THE INVARIANT, asserted rather than commented: nothing reaches ~/.claude that
# this gate did not scan. `harness install --dry-run` is asked what it would
# write, and every agents/, skills/, commands/ or hooks/ file in that answer must
# be in the shipped set above. Subset, not equality: a file that is scanned but
# deliberately not installed is not a leak.
instout=$(CLAUDE_CONFIG_DIR="$(mktemp -d)" "$ROOT/bin/harness" install --dry-run 2>&1); instrc=$?
# A dry run that died after printing some recognizable labels used to pass on
# whatever it managed to print. Its exit status is part of the answer.
# Filenames run to the end of the line, minus put()'s trailing "(dry run)" and
# friends: cutting at the first space turned "agents/good leak.md" into
# "agents/good" and let a prefix collision hide the real path.
labels=$(printf '%s\n' "$instout" | sed $'s/\033\\[[0-9;]*m//g' \
         | sed -n -E 's#^  [+=] ((agents|skills|commands|hooks)/.+)$#\1#p' \
         | sed -E 's# \([^)]*\)$##' | sort -u)
shipset=$(shipped_l 'agents' 'skills' 'commands' 'hooks')
unscanned=$(printf '%s\n' "$labels" | grep -v '^$' | while IFS= read -r l; do
              printf '%s\n' "$shipset" | grep -qxF "$l" || printf '%s\n' "$l"
            done)
if [ "$instrc" -ne 0 ]; then
  fail "harness install --dry-run exited $instrc - the check could not run"
  printf '%s\n' "$instout" | tail -3 | while IFS= read -r l; do show "$l"; done
elif [ -z "$labels" ]; then
  fail "harness install --dry-run named no files to install - the check could not run"
  printf '%s\n' "$instout" | head -3 | while IFS= read -r l; do show "$l"; done
elif [ -n "$unscanned" ]; then
  fail "harness install would ship files this gate never scanned"
  printf '%s\n' "$unscanned" | head -10 | while IFS= read -r l; do show "$l"; done
else
  pass "all $(printf '%s\n' "$labels" | wc -l | tr -d ' ') files harness install would ship are in the scanned set"
fi

# 12 ------------------------------------------------- documented counts
# A count asserted in prose that nothing checks is drift waiting to happen: the
# commit that added a check left README.md saying the gate has ten, and
# the anti-drift WARN below could not see it because it watches one file.
#
# The patterns are deliberately broad. If a future sentence legitimately counts a
# SUBSET ("four skills are vendored"), it fails here - reword it rather than
# adding an exemption, because an exemption list on a count check is the shared
# EXEMPT bug in a new costume.
n_agents=$(shipped_l 'agents/*.md' | wc -l | tr -d ' ')
n_skills=$(shipped_l 'skills/*/SKILL.md' | wc -l | tr -d ' ')
n_cmds=$(shipped_l 'commands/*.md' | wc -l | tr -d ' ')
# tr to NUL + xargs -0: plain xargs splits on whitespace, so a client doc named
# "setup guide.md" became two nonexistent arguments, perl warned to stderr, and
# the stale count inside it was never read.
countbad=$(printf '%s\n' "$CLIENT_DOCS" | grep -v '^$' | tr '\n' '\0' | xargs -0r perl -CSD -e '
  my %want = (agents => shift, skills => shift, commands => shift, checks => shift);
  # An unopenable doc is a doc that was not checked. Report it, do not warn.
  print "cannot read $_ - the count check did not run over it\n" for grep { !-r $_ } @ARGV;
  my %num = (one=>1,two=>2,three=>3,four=>4,five=>5,six=>6,seven=>7,eight=>8,nine=>9,
             ten=>10,eleven=>11,twelve=>12,thirteen=>13,fourteen=>14,fifteen=>15,
             sixteen=>16,seventeen=>17,eighteen=>18,nineteen=>19,twenty=>20);
  # Anchored on the NUMBER, so a sentence with no count in it can never match,
  # with one optional word between ("12 invocable skills", "eleven other checks").
  # CEILING: the noun must follow the number. A bare "it ran all thirteen" is not
  # matched and would ship stale behind a green gate. Docs are written so every
  # count carries its noun; this comment exists so nobody reads a PASS here as
  # proof that no unanchored count exists anywhere.
  my $n = join "|", "[0-9]+", keys %num;
  my %pat = (agents   => qr/\b($n)\b(?:\s+[\w-]+)?\s+(?:subagent definitions|agents in this repo)\b/i,
             skills   => qr/\b($n)\b(?:\s+[\w-]+)?\s+skills\b/i,
             commands => qr/\b($n)\b(?:\s+[\w-]+)?\s+slash commands\b/i,
             checks   => qr/\b($n)\b(?:\s+[\w-]+)?\s+checks\b/i);
  my %seen;
  while (<>) {
    for my $k (sort keys %pat) {
      while (/$pat{$k}/g) {
        my $said = $1;
        my $v = lc($said) =~ /^[0-9]+$/ ? $said : $num{lc $said};
        next unless defined $v;
        $seen{$k}++;
        printf "%s:%d: says %s %s, actual %d\n", $ARGV, $., $said, $k, $want{$k} if $v != $want{$k};
      }
    }
  } continue { close ARGV if eof }
  for my $k (sort keys %want) {
    print "no $k count claim found in any client-facing doc - the pattern is dead, not the docs clean\n"
      unless $seen{$k};
  }
' "$n_agents" "$n_skills" "$n_cmds" "$EXPECTED_CHECKS")
if [ -n "$countbad" ]; then
  fail "documented counts do not match the repo"
  printf '%s\n' "$countbad" | head -10 | while IFS= read -r l; do show "$l"; done
else
  pass "documented counts match ($n_agents agents, $n_skills skills, $n_cmds commands, $EXPECTED_CHECKS checks)"
fi

# ---------------------------------------------------- docs must not go stale
# Not a numbered check (it would have to count itself). The enumerated list in
# getting-started.md drifted from the gate the first time a check was added, so
# this warns rather than letting a reader trust a stale number. Check 12 covers
# the counts asserted in prose; this covers the list's length.
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
