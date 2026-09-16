#!/bin/bash
# Status line: model, context window usage, and git location.
#
# Claude Code runs this once per render and passes a JSON blob on stdin. The
# fields this script reads are documented in docs/context-window-management.md,
# along with the settings.json snippet that wires it up.
#
# Requires jq. If jq is missing the script prints a reduced line rather than
# failing: a status line that exits non-zero renders as empty, which looks like
# a broken terminal rather than a missing dependency.
#
# DELIBERATELY NOT SHOWN: a percentage when the host does not report a window
# size. An earlier version of this script assumed a 1M window and divided by it.
# That is one plan's number, and on any other plan the bar reads comfortable
# while the session is nearly full. A missing denominator prints the raw token
# count instead, which is honest.

PATH="/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

input=$(cat)

if ! command -v jq >/dev/null 2>&1; then
  printf 'statusline: jq not found on PATH\n'
  exit 0
fi

# ---------------------------------------------------------------- parse, once
# One jq call, not one per field. This runs on every redraw, and six forks per
# render is six times the cost for the same answer. Parsing once also means a
# malformed payload produces one quiet fallback line instead of a screenful of
# jq parse errors where the status line should be.
#
# Every token the host is holding counts against the window, whether it was sent
# fresh or served from cache. Summing only input_tokens undercounts a long
# session badly, because most of it is cache reads by then.
fields=$(printf '%s' "$input" | jq -r '
  [ (.model.display_name // "unknown model"),
    ( (.context_window.current_usage.input_tokens // 0)
    + (.context_window.current_usage.cache_read_input_tokens // 0)
    + (.context_window.current_usage.cache_creation_input_tokens // 0) ),
    (.context_window.max_tokens // 0),
    (.workspace.current_dir // .cwd // "")
  ] | @tsv' 2>/dev/null)

if [ -z "$fields" ]; then
  printf 'statusline: unreadable input\n'
  exit 0
fi

IFS=$'\t' read -r model total_ctx max_tokens cwd <<EOF
$fields
EOF

if [ "$total_ctx" -ge 1000000 ]; then
  tok_label=$(awk "BEGIN { printf \"%.1fM\", $total_ctx/1000000 }")
elif [ "$total_ctx" -ge 1000 ]; then
  tok_label=$(awk "BEGIN { printf \"%.0fk\", $total_ctx/1000 }")
else
  tok_label="$total_ctx"
fi

BAR_WIDTH=10
if [ "$max_tokens" -gt 0 ] 2>/dev/null; then
  pct_int=$(awk "BEGIN { printf \"%.0f\", $total_ctx * 100 / $max_tokens }")

  # Colour is a reading aid, not a measurement. The thresholds below are a
  # convention this repo picked so the bar changes before you are in trouble,
  # not a number taken from any published result. See the research section of
  # docs/context-window-management.md for what is actually measured.
  if   [ "$pct_int" -lt 50 ]; then BAR_COLOR="\033[32m"
  elif [ "$pct_int" -le 80 ]; then BAR_COLOR="\033[33m"
  else                             BAR_COLOR="\033[31m"
  fi
  RESET="\033[0m"

  filled=$(( pct_int * BAR_WIDTH / 100 ))
  [ "$filled" -gt "$BAR_WIDTH" ] && filled="$BAR_WIDTH"
  [ "$filled" -lt 0 ] && filled=0
  empty=$(( BAR_WIDTH - filled ))

  bar=""
  i=0; while [ "$i" -lt "$filled" ]; do bar="${bar}#"; i=$((i+1)); done
  i=0; while [ "$i" -lt "$empty"  ]; do bar="${bar}-"; i=$((i+1)); done

  ctx_part=$(printf "${BAR_COLOR}[%s]${RESET} %d%% (%s)" "$bar" "$pct_int" "$tok_label")
else
  # No window size reported. Show what is known and claim nothing else.
  ctx_part=$(printf "[context %s]" "$tok_label")
fi

# ---------------------------------------------------------------- git location
git_part=""

if [ -n "$cwd" ]; then
  git_root=$(git --no-optional-locks -C "$cwd" rev-parse --show-toplevel 2>/dev/null)
  if [ -n "$git_root" ]; then
    branch=$(git --no-optional-locks -C "$cwd" symbolic-ref --short HEAD 2>/dev/null \
             || git --no-optional-locks -C "$cwd" rev-parse --short HEAD 2>/dev/null \
             || echo detached)

    staged=$(git --no-optional-locks -C "$cwd" diff --cached --name-only 2>/dev/null | wc -l | tr -d ' ')
    unstaged=$(git --no-optional-locks -C "$cwd" diff --name-only 2>/dev/null | wc -l | tr -d ' ')

    change_label=""
    [ "$staged"   -gt 0 ] && change_label="+${staged}"
    [ "$unstaged" -gt 0 ] && change_label="${change_label:+$change_label }~${unstaged}"
    [ -n "$change_label" ] && change_label=" ${change_label}"

    # Pure shell prefix strip. GNU realpath --relative-to is not on macOS, and
    # shelling out to python for one path was the kind of dependency that makes
    # a status line fail silently on someone else's machine.
    repo_name=$(basename "$git_root")
    rel_path="${cwd#"$git_root"}"
    rel_path="${rel_path#/}"
    if [ -n "$rel_path" ]; then
      location="${repo_name}/${rel_path}"
    else
      location="$repo_name"
    fi

    git_part="${location}  ${branch}${change_label}"
  fi
fi

# ---------------------------------------------------------------- assemble
SEP="  |  "
line="${model}${SEP}${ctx_part}"
[ -n "$git_part" ] && line="${line}${SEP}${git_part}"

printf '%b\n' "$line"
