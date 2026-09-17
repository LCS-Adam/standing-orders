#!/bin/bash
# Right-fit model gate.
# Denies Agent/Task spawns that would silently inherit the parent session's
# model: the call must either pass an explicit `model` parameter, or name a
# subagent_type whose definition file pins `model:` in its frontmatter.
# `fork` agents are exempt (they always inherit by design).
# Paired with the Model tiers section of AGENTS.md, which covers surfaces
# this hook cannot see.
input=$(cat)
model=$(jq -r '.tool_input.model // empty' <<<"$input")
# INSERTION POINT, docs/augment-runbook.md step 6.
# Auggie's hook payload is byte-compatible with this one (tool_name plus a
# tool_input object, aug_cli_hooks.md, verified in docs 2026-09-16), but the
# name of the tool that dispatches a subagent, and the tool_input key that
# carries the agent name, are NOT FOUND in the snapshot. Step 6 logs one real
# dispatch and reads both off it. The fallback then becomes:
#   stype=$(jq -r '.tool_input.subagent_type // .tool_input.<AUGGIE_FIELD> // empty' <<<"$input")
# It is not guessed here: a wrong key silently matches nothing, which is the
# same as having no gate, and this hook exists because a silent inherit is
# expensive.
stype=$(jq -r '.tool_input.subagent_type // empty' <<<"$input")

if [[ "$stype" == "fork" || -n "$model" ]]; then
  exit 0
fi

# Agent definition with a model pin satisfies the rule (project first, then user).
# The directory list is chosen by WHICH TOOL IS ASKING, never searched as one
# pool. Searching both let a pin in .augment/agents/ answer for a Claude Code
# dispatch: `harness add --tool auggie` generates a pinned file for all eleven
# agent names, so a .claude/agents/ definition that forgot its pin was waved
# through on the strength of a file Claude Code does not read. A guard reading
# state scoped to one tool while gating another is not a guard.
case "$(jq -r '.tool_name // empty' <<<"$input")" in
  Agent|Task|"") dirs=(".claude/agents" "$HOME/.claude/agents") ;;
  *)             dirs=(".augment/agents" "$HOME/.augment/agents") ;;
esac
# FIRST match wins, then stop. Two defects here, both found in review.
#
# The loop used to continue past an unpinned project definition and accept a
# same-named PINNED user definition instead. The tool loads the project one, so
# the hook was approving a spawn on the strength of a file that would not run.
#
# And `grep '^model:'` searched the WHOLE file, so a body example containing a
# line starting `model:` satisfied it. Only the opening frontmatter block
# counts, which is the only place the tool reads it from.
for dir in "${dirs[@]}"; do
  f="$dir/$stype.md"
  [[ -n "$stype" && -f "$f" ]] || continue
  if awk 'NR==1 && $0!="---" {exit 1}
          NR>1 && /^---[[:space:]]*$/ {exit 1}
          NR>1 && /^model:[[:space:]]*[^[:space:]]/ {found=1; exit 0}
          END {exit found?0:1}' "$f"; then
    exit 0
  fi
  break
done

cat <<'EOF'
{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"Right-fit model rule (operator hard rule): this Agent/Task spawn passes no explicit model and its agent definition pins none, so it would silently inherit the parent session's model. Re-issue the call with an explicit model sized to the task (tier bindings live in the harness repo config/models.conf), and set effort where the surface supports it. Do not disable this hook; pick a model."}}
EOF
