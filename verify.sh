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
SELF="$ROOT/${BASH_SOURCE[0]##*/}"
DENYLIST="${HARNESS_DENYLIST:-$HOME/.agent-harness-denylist}"
FAIL=0
RAN=0
EXPECTED_CHECKS=13

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
gate_error() { printf '\033[31mGATE ERROR\033[0m %s\n' "$1"; exit 2; }

cd "$ROOT"

# ---------------------------------------------------------------- THE SHIPPED SET
#
# THE INVARIANT: nothing can reach ~/.claude that this gate did not scan.
#
# One definition of "the repo", used by this gate AND by `harness install`
# (bin/harness, function `shipped`). Check 12 fails the build when the two
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
# globbed the FILESYSTEM while 1, 2, 7, 8, 9, 10 and 11 read the INDEX, so
# shrinking one while leaving the other alone turned the whole gate green on
# three committed violations - checks 3 and 4 cheerfully reporting "all 11
# agents" over files the other half could no longer see. Three patches would
# have left three mechanisms free to drift apart again, which is how the shared
# exemption came back after d271923 fixed it.
#
# Exactly three things are NOT this set, each for a stated reason:
#   - check 11's RESOLVER (not its scan) is `git ls-files`, a strict subset. It
#     answers "would a clone have this command file", and a clone gets tracked
#     files only. Scanning more can only find more references; resolving against
#     less can only be stricter.
#   - checks 3 and 4 glob the same directories on disk. That is not a second
#     scan set - it is the assertion that this one set still matches reality,
#     and it is the only way a check can notice its own scan set silently
#     shrinking. It reports, it never scans.
#   - the denylist is operator-supplied and lives OUTSIDE the repo on purpose
#     (a committed list of personal markers is itself the leak).

# An empty file list means "scanned nothing", not "clean". Without this, running
# the gate outside a checkout would turn most of these checks into permanent
# passes. The per-check guards below cover the partial case, which is the one
# that actually happens.
NSHIPPED=$(shipped_l 2>/dev/null | wc -l | tr -d ' ')
[ "${NSHIPPED:-0}" -ge 2 ] || gate_error "git ls-files returned ${NSHIPPED:-0} files - scanning nothing, not clean"

# Client-facing surfaces: what a reader outside this repo ends up reading.
# DENY BY DEFAULT. A new top-level doc, or a renamed docs/, is client-facing
# until someone lists its directory here; the previous allowlist
# (README.md INSTALL.md docs/*.md adapters/*.md) went green on one file when the
# other nine left the scan set.
#
# This is a TARGET SET, not an exemption. Checks 8 and 13 share it because they
# make the SAME claim about the SAME surface. An exemption - "this file is out of
# THIS check" - stays inside the check that owns it. See the gate-integrity
# assertion below.
FRAMEWORK_PROSE='^(agents|commands|hooks|rules|config|templates|skills)/|^(AGENTS|CLAUDE)\.md$'
CLIENT_DOCS=$(shipped_l '*.md' | grep -vE "$FRAMEWORK_PROSE")

# ---------------------------------------------------------------- gate integrity
# No exemption may be shared between checks. That has been the bug twice: once
# when docs/ was exempted so the docs could name models and the absolute-path
# check silently went with it, and again when checks 1 and 9 shared an EXEMPT so
# a personal marker committed to verify.sh passed the denylist. A comment saying
# "never widen this" did not hold either time, so it is machine-checked now:
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
# extension, so it was invisible to every grep-based check. grep -I skips
# binaries, which is the only thing the extension list was really buying.
EXEMPT_PATHS='^verify\.sh:'
hits=$(shipped | xargs -0r grep -IHnE '(/Users/|/home/[a-z]|C:\\Users\\)' 2>/dev/null \
       | grep -vE "$EXEMPT_PATHS" || true)
# A symlink's blob content IS the path it points at. grep reads THROUGH the link
# (or errors past a missing target), so the stored string is the one leak shape
# the scan above cannot see, and the one where the path itself is the payload.
linkhits=$(shipped_l | while IFS= read -r f; do
             [ -L "$f" ] || continue
             t=$(readlink "$f" 2>/dev/null || true)
             case "$t" in
               (/Users/*|/home/*) printf '%s: symlink -> %s\n' "$f" "$t" ;;
             esac
           done)
hits="${hits}${hits:+$'\n'}${linkhits}"
hits="${hits#$'\n'}"
if [ -n "$hits" ]; then
  fail "absolute home paths"; printf '%s\n' "$hits" | head -10 | while IFS= read -r l; do show "$l"; done
else pass "no absolute home paths"; fi

# 2 -------------------------------------------------- vendor model names
# Prose must name tiers. Only models.conf binds literals. docs/ and
# adapters/README.md must name real models to teach the tier binding and to carry
# the old-name migration table; verify.sh names them in this regex. All of them
# stay subject to every OTHER check, including paths and the denylist - this
# exemption is written out in full here rather than reusing check 1's, because
# sharing one is how both of the last two leaks happened.
EXEMPT_VENDOR='^verify\.sh:|^adapters/README\.md|^docs/|^config/models\.conf'
hits=$(shipped | xargs -0r grep -IHniE '\b(fable|opus|sonnet|haiku)\b' 2>/dev/null \
       | grep -vE "$EXEMPT_VENDOR" || true)
if [ -n "$hits" ]; then
  fail "vendor model names outside config/models.conf"; printf '%s\n' "$hits" | head -10 | while IFS= read -r l; do show "$l"; done
else pass "no vendor model names outside config/models.conf"; fi

# 3 -------------------------------------------------- every agent pins a tier
# Guard is a COMPARISON against what is on disk, not a test for zero. A scan set
# of 1 agent out of 11 reported PASS on almost nothing and printed a reassuring
# "all 1 agent definitions pin a tier" while it did it.
missing=""; n=0; scanned=""
while IFS= read -r f; do
  [ -n "$f" ] || continue
  n=$((n+1)); scanned="$scanned $f"
  grep -qE '^model:[[:space:]]*\{\{TIER_(FRONTIER_THINK|FRONTIER_DO|MID|SMALL)\}\}' "$f" 2>/dev/null || missing="$missing $f"
done < <(shipped_l 'agents/*.md')
ondisk=0; unscanned=""
for f in agents/*.md; do
  [ -e "$f" ] || continue
  ondisk=$((ondisk+1))
  case " $scanned " in *" $f "*) ;; *) unscanned="$unscanned $f" ;; esac
done
if [ "$ondisk" -eq 0 ]; then fail "no agent definitions found - scanned nothing, which is not the same as clean"
elif [ -n "$unscanned" ]; then fail "agent definitions on disk that the scan set does not cover ($n of $ondisk):$unscanned"
elif [ -n "$missing" ]; then fail "agent definitions missing a {{TIER_*}} model pin:$missing"
else pass "all $n agent definitions pin a tier"; fi

# 4 -------------------------------------------------- skill frontmatter
bad=""; n=0; scanned=""
while IFS= read -r f; do
  [ -n "$f" ] || continue
  n=$((n+1)); scanned="$scanned $f"
  head -20 "$f" 2>/dev/null | grep -q '^name:' || bad="$bad $f(name)"
  head -20 "$f" 2>/dev/null | grep -q '^description:' || bad="$bad $f(description)"
done < <(shipped_l 'skills/*/SKILL.md')
ondisk=0; unscanned=""
for f in skills/*/SKILL.md; do
  [ -e "$f" ] || continue
  ondisk=$((ondisk+1))
  case " $scanned " in *" $f "*) ;; *) unscanned="$unscanned $f" ;; esac
done
if [ "$ondisk" -eq 0 ]; then fail "no SKILL.md files found - scanned nothing, which is not the same as clean"
elif [ -n "$unscanned" ]; then fail "SKILL.md files on disk that the scan set does not cover ($n of $ondisk):$unscanned"
elif [ -n "$bad" ]; then fail "SKILL.md missing required frontmatter:$bad"
else pass "all $n skills have name and description"; fi

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
# Selected by CONTENT, not by extension. '*.sh' missed bin/harness entirely and
# left a two-file scan set that goes green on one file the moment the other
# leaves it. A file is a script if its first line is a shebang; there is no
# pathspec here to shrink or mistype.
bad=""; n=0
while IFS= read -r f; do
  [ -n "$f" ] || continue
  n=$((n+1))
  head -1 "$f" 2>/dev/null | grep -q '^#!/bin/bash' || bad="$bad $f"
done < <(shipped | xargs -0r awk 'FNR==1 && /^#!/{print FILENAME}' 2>/dev/null)
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

# 9 -------------------------------------------------- personal-marker denylist
# NO exemption here, deliberately. verify.sh needs one from check 1 because its
# own regex contains the literal /Users/; it does not need, and must not have,
# one from the personal-marker denylist. Sharing check 1's list meant a personal
# marker committed to this very file passed the gate.
if [ -e "$DENYLIST" ] && [ ! -r "$DENYLIST" ]; then
  # Unreadable is a gate error, not an empty list. grep on an unreadable file
  # returns nothing, which read as "no terms configured" and passed.
  fail "denylist $DENYLIST exists but is not readable - the check did not run"
elif [ -f "$DENYLIST" ]; then
  terms=$(grep -vE '^[[:space:]]*(#|$)' "$DENYLIST" || true)
  if [ -z "$terms" ]; then
    pass "denylist $DENYLIST is empty (no terms to check)"
  else
    # A term that is not a valid ERE makes grep exit 2 and check nothing, while
    # the count below still counted it. Silently checking zero markers is the
    # failure this gate exists to refuse.
    badterms=""
    while IFS= read -r t; do
      [ -n "$t" ] || continue
      printf '' | grep -qE "$t" 2>/dev/null
      [ $? -ge 2 ] && badterms="$badterms $t"
    done <<< "$terms"
    hits=$(printf '%s\n' "$terms" | while IFS= read -r t; do
             [ -n "$t" ] || continue
             shipped | xargs -0r grep -IHniE "$t" 2>/dev/null || true
           done)
    if [ -n "$badterms" ]; then
      fail "denylist terms that are not valid regexes and were never checked:$badterms"
    elif [ -n "$hits" ]; then
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
done < <(shipped | xargs -0r grep -Ihof '~/\.claude/rules/[A-Za-z0-9._-]*\.md' 2>/dev/null | sort -u)
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
dangling=""
while IFS= read -r tok; do
  [ -n "$tok" ] || continue
  printf '%s\n' "$defined" | grep -qxF "$tok" && continue
  case " $BUILTIN_SLASH $NOT_A_COMMAND " in *" $tok "*) continue ;; esac
  dangling="$dangling $tok"
done <<< "$tokens"
if [ -z "$tokens" ]; then
  # Zero tokens means the scan reached nothing, not that the repo is clean.
  fail "slash-command scan matched nothing - the scan set is broken, not clean"
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

# 12 ------------------------------------------------- installer and gate agree
# THE INVARIANT, asserted rather than commented: nothing reaches ~/.claude that
# this gate did not scan. `harness install --dry-run` is asked what it would
# write, and every agents/, skills/, commands/ or hooks/ file in that answer must
# be in the shipped set above. Subset, not equality: a file that is scanned but
# deliberately not installed is not a leak.
instout=$(CLAUDE_CONFIG_DIR="$(mktemp -d)" "$ROOT/bin/harness" install --dry-run 2>&1)
labels=$(printf '%s\n' "$instout" | sed $'s/\033\\[[0-9;]*m//g' \
         | grep -oE '^  [+=] (agents|skills|commands|hooks)/[^ ]+' | sed 's|^  [+=] ||' | sort -u)
shipset=$(shipped_l 'agents' 'skills' 'commands' 'hooks')
unscanned=$(printf '%s\n' "$labels" | grep -v '^$' | while IFS= read -r l; do
              printf '%s\n' "$shipset" | grep -qxF "$l" || printf '%s\n' "$l"
            done)
if [ -z "$labels" ]; then
  fail "harness install --dry-run named no files to install - the check could not run"
  printf '%s\n' "$instout" | head -3 | while IFS= read -r l; do show "$l"; done
elif [ -n "$unscanned" ]; then
  fail "harness install would ship files this gate never scanned"
  printf '%s\n' "$unscanned" | head -10 | while IFS= read -r l; do show "$l"; done
else
  pass "all $(printf '%s\n' "$labels" | wc -l | tr -d ' ') files harness install would ship are in the scanned set"
fi

# 13 ------------------------------------------------- documented counts
# A count asserted in prose that nothing checks is drift waiting to happen: the
# commit that added check 11 left README.md saying the gate has ten checks, and
# the anti-drift WARN below could not see it because it watches one file.
#
# The patterns are deliberately broad. If a future sentence legitimately counts a
# SUBSET ("four skills are vendored"), it fails here - reword it rather than
# adding an exemption, because an exemption list on a count check is the shared
# EXEMPT bug in a new costume.
n_agents=$(shipped_l 'agents/*.md' | wc -l | tr -d ' ')
n_skills=$(shipped_l 'skills/*/SKILL.md' | wc -l | tr -d ' ')
n_cmds=$(shipped_l 'commands/*.md' | wc -l | tr -d ' ')
countbad=$(printf '%s\n' "$CLIENT_DOCS" | grep -v '^$' | xargs perl -CSD -e '
  my %want = (agents => shift, skills => shift, commands => shift, checks => shift);
  my %num = (one=>1,two=>2,three=>3,four=>4,five=>5,six=>6,seven=>7,eight=>8,nine=>9,
             ten=>10,eleven=>11,twelve=>12,thirteen=>13,fourteen=>14,fifteen=>15,
             sixteen=>16,seventeen=>17,eighteen=>18,nineteen=>19,twenty=>20);
  # Anchored on the NUMBER, so a sentence with no count in it can never match,
  # with one optional word between ("12 invocable skills", "eleven other checks").
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
# this warns rather than letting a reader trust a stale number. Check 13 covers
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
