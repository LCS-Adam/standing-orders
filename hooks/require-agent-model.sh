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
# .augment/agents holds the generated Auggie subagents, which carry a resolved
# model: too, so the same rule answers for either tool once step 6 lands.
for dir in ".claude/agents" "$HOME/.claude/agents" ".augment/agents" "$HOME/.augment/agents"; do
  f="$dir/$stype.md"
  if [[ -n "$stype" && -f "$f" ]] && grep -qE '^model:[[:space:]]*\S' "$f"; then
    exit 0
  fi
done

cat <<'EOF'
{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"Right-fit model rule (operator hard rule): this Agent/Task spawn passes no explicit model and its agent definition pins none, so it would silently inherit the parent session's model. Re-issue the call with an explicit model sized to the task (tier bindings live in the harness repo config/models.conf), and set effort where the surface supports it. Do not disable this hook; pick a model."}}
EOF
