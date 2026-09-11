#!/bin/bash
# Right-fit model gate (operator hard rule, 2026-07-22).
# Denies Agent/Task spawns that would silently inherit the parent session's
# model: the call must either pass an explicit `model` parameter, or name a
# subagent_type whose definition file pins `model:` in its frontmatter.
# `fork` agents are exempt (they always inherit by design).
# Paired with the "Right-fit models for all sub-execution" section in
# ~/.claude/CLAUDE.md, which covers surfaces this hook cannot see
# (Workflow agent() calls, headless `claude -p` spawns).
input=$(cat)
model=$(jq -r '.tool_input.model // empty' <<<"$input")
stype=$(jq -r '.tool_input.subagent_type // empty' <<<"$input")

if [[ "$stype" == "fork" || -n "$model" ]]; then
  exit 0
fi

# Agent definition with a model pin satisfies the rule (project first, then user).
for dir in ".claude/agents" "$HOME/.claude/agents"; do
  f="$dir/$stype.md"
  if [[ -n "$stype" && -f "$f" ]] && grep -qE '^model:[[:space:]]*\S' "$f"; then
    exit 0
  fi
done

cat <<'EOF'
{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"Right-fit model rule (operator hard rule): this Agent/Task spawn passes no explicit model and its agent definition pins none, so it would silently inherit the parent session's model. Re-issue the call with an explicit model sized to the task (tier bindings live in config/models.conf), and set effort where the surface supports it. Do not disable this hook; pick a model."}}
EOF
