# Writing your own agents, skills, rules, commands, and hooks

This is a reference for authoring the five extension shapes this harness ships: agent
definitions, skills, rules, commands, and hooks. Each section names the frontmatter fields a
real shipped file uses, cites the file, and says what the field does. Nothing here is
documented because it seems plausible; every field named below exists in a file in this repo.

## Agent definitions

An agent definition is a Markdown file with YAML frontmatter under `agents/`. Two examples,
`agents/adversary.md` and `agents/exec-mechanical.md`, show the fields in use:

```yaml
---
name: adversary
description: FRONTIER-DO tier at xhigh effort. Adversarial correctness reviewer for
  high-stakes or correctness-critical diffs. Read-only. Tries to BREAK the change...
tools: Read, Grep, Glob, Bash
model: {{TIER_FRONTIER_DO}}
effort: xhigh
reasoning: xhigh
---
```

```yaml
---
name: exec-mechanical
description: SMALL tier at medium effort. Execution agent for mechanical, well-specified
  edits in an isolated git worktree...
tools: Read, Edit, Write, Bash, Grep, Glob
model: {{TIER_SMALL}}
effort: medium
reasoning: medium
---
```

Field by field:

- `name` - the identifier the Agent tool's `subagent_type` argument matches against, and the
  filename stem (`agents/<name>.md`).
- `description` - states the tier and effort up front, then what the agent is for and when to
  use it. This is what a dispatcher reads to pick the right agent.
- `tools` - the exact tool allowlist. `adversary` gets no `Edit` or `Write`: it is read-only by
  design, not by convention.
- `model` - a `{{TIER_*}}` token, never a literal model name. `config/models.conf` holds the
  binding, and `harness install` resolves the token at install time. See "Naming tiers versus
  naming models" in `AGENTS.md`.
- `effort` and `reasoning` - the values observed across shipped agents are `medium`
  (`exec-mechanical.md`, `exec-standard.md`), `high` (`exec-critical.md`, `code-reviewer.md`,
  `autorun-plan-orchestrator.md`), `xhigh` (`adversary.md`, `design-reviewer.md`), and `max`
  (`exec-subtle.md`, `plan-synthesizer.md`). This is this repo's convention for ordering
  low, medium, high, xhigh, max, not a guarantee any given model vendor exposes all five levels
  or interprets them identically.

### What an `exec-*` agent expects from its dispatcher

`agents/exec-standard.md` states the report requirement:

> Write your report to the path the orchestrator names (or `runtime/verify/<yourname>-report.md`)
> via Bash BEFORE you finish, AND return it as your final message.

Every `exec-*` agent body (`exec-standard.md`, `exec-mechanical.md`, `exec-critical.md`,
`exec-subtle.md`) repeats this same requirement, plus two more: a file-ownership list (the exact
files it may touch, nothing else) and a worktree to work in in isolation. Whoever dispatches an
`exec-*` agent must supply all three in the brief: which files, which worktree, and where to
write the report.

The report goes to a file, not just the final chat message, because of a failure mode
`agents/adversary.md` names directly:

> Backgrounded agents go idle and their final message is sometimes lost with no way to retrieve
> it - one full review had to be re-run from scratch.

The report path lives under `runtime/`, and `.gitignore` explains why that directory is
ignored:

```
# agent run reports. agents/exec-*.md default every report to runtime/verify/,
# and an unignored report lands in the shipped set: check 1 then scans the
# absolute worktree paths an agent naturally writes there and fails the gate on
# output that was never meant to ship.
runtime/
```

An agent's own scratch output must never join the set of files a repo-scrubbing gate scans, so
the report path is gitignored on purpose, not by oversight.

### `fork` agents are exempt from the model-pinning hook

`CLAUDE.md` states the exemption:

> `fork` agents are exempt because they always inherit by design.

`hooks/require-agent-model.sh` implements it:

```bash
# `fork` agents are exempt (they always inherit by design).
...
if [[ "$stype" == "fork" || -n "$model" ]]; then
  exit 0
fi
```

A `fork` continues the parent conversation as a subagent rather than starting a fresh one, so
there is no "parent model" to silently diverge from - inheriting is the correct behavior, not
the failure the hook exists to catch. Every other `subagent_type` must either pass an explicit
`model` argument or name an agent definition file that pins `model:` in its frontmatter.

## Worktrees

Give each concurrent execution stream its own worktree and branch:

```bash
git worktree add .worktrees/<name> -b <branch>
```

Remove it when the stream is done:

```bash
git worktree remove .worktrees/<name>
```

`.gitignore` ignores `.worktrees/` with the comment "agent worktrees are transient and local" -
they are local execution scratch, not something a clone should carry.

### The worktree-green-main-red trap

`skills/autorun-plan/SKILL.md` documents a case where a gate passed on every branch in isolation
and then failed after the merge:

> Wrong tree. Where a repo keeps gitignored local data, a worktree does not have it, so the
> suite there silently runs FEWER checks than the same command on the main checkout, and any
> test that walks directories sees a different tree. Five consecutive rounds were green in the
> worktree; the first full run on the main checkout after the merge failed two.

A worktree is not a faithful copy of the branch it will become part of: gitignored local state
(caches, generated files, anything outside version control) does not follow it. Green in every
worktree is not proof of green after the merge. Re-run the full verification suite on the
integration branch itself before calling a multi-stream build done.

## Skills

A skill is a directory, `skills/<name>/`, containing a `SKILL.md` with frontmatter. `name` must
match the directory name; a skill invoked as `/<name>` or via the Skill tool resolves by
directory, not by the frontmatter `name` alone matching some other string.

`skills/readme-coauthoring/SKILL.md` is the worked example:

```yaml
---
name: readme-coauthoring
description: Co-author a comprehensive, polished README for a software project. Use when
  the user wants to write, rewrite, or seriously improve a README...
version: 0.1.0
tools: Read, Glob, Grep, Bash, Edit, Write, WebFetch
---
```

- `name` - matches the directory (`skills/readme-coauthoring/`).
- `description` - states what the skill does and when to reach for it, including when NOT to
  (it defers one-off doc edits to a sibling skill).
- `version` - a semantic version for the skill file itself.
- `tools` - the allowlist the skill body is permitted to use.

A flat `<name>.md` file sitting outside a `skills/` directory is NOT an invocable skill. It is a
context document that something else has to load deliberately - `@`-imported by a `CLAUDE.md`,
or read as part of a phase. This harness keeps the two apart on purpose: `skills/` holds only
the invocable shape, and per-project context documents live in
`templates/project/context/`.

## Rules

`.claude/rules/*.md` load into context automatically. `CLAUDE.md` describes the two behaviors:

> `.claude/rules/*.md` load every session unless they carry `paths:` frontmatter, in which case
> they load only when Claude reads a matching file.

A rule with no `paths:` frontmatter is always-on cost: it loads at the start of every session,
whether or not that session ever touches the thing it governs. A rule with `paths:` is one of
the few mechanisms that genuinely reduces per-session context, per `CLAUDE.md`'s own table: it
loads lazily, only when an agent reads a file matching the glob. Put an instruction in a
`paths:`-scoped rule when it is only relevant to a subset of files (SQL migrations, a specific
config format), and reserve unconditional rules for things that must be in force before the
moment you would have thought to invoke them.

## Commands

A command is a Markdown file under `commands/`, invoked as `/<filename-stem>`.
`commands/deep-plan.md` shows the frontmatter shape:

```yaml
---
description: Local deep planning - advisor (shape) -> Plan subagent (FRONTIER-THINK,
  ULTRATHINK MAX EFFORT) -> advisor (critique). Always emits a multi-step EXECUTION plan...
allowed-tools: Agent, advisor, Read, Bash, Grep, Glob, WebFetch, WebSearch
---
```

- `description` - shown wherever the command is listed; states what it does and, for this one,
  what it always produces.
- `allowed-tools` - the tool allowlist for the command's body.

This repo's shipped commands (`deep-plan.md`, `handoff.md`, `next-step.md`,
`phase-status.md`) do not use an `argument-hint` field, so it is not documented here even
though other Claude Code projects may use one - only fields observed in this repo's shipped
files are listed above.

## Hooks

`config/settings.portable.json` wires a `PreToolUse` hook:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Agent|Task",
        "hooks": [
          {
            "type": "command",
            "command": "bash ~/.claude/hooks/require-agent-model.sh",
            "timeout": 10,
            "statusMessage": "Right-fit model gate"
          }
        ]
      }
    ]
  }
}
```

- `matcher: "Agent|Task"` - the hook fires before any tool call named `Agent` or `Task`, and no
  other tool.
- `timeout: 10` - the hook script has 10 seconds to run. What the host does if it does not
  respond in time is not documented in this repo; confirm against your own tool's behavior
  before relying on it.
- `command` - runs the hook script with the tool-call event piped to it on stdin.

`hooks/require-agent-model.sh` reads that stdin JSON and extracts two fields with `jq`:

```bash
input=$(cat)
model=$(jq -r '.tool_input.model // empty' <<<"$input")
stype=$(jq -r '.tool_input.subagent_type // empty' <<<"$input")
```

So the event delivers (at minimum) a `tool_input` object carrying whatever arguments the
blocked tool call was about to receive - here, `model` and `subagent_type`.

To deny the call, the hook writes a JSON object to stdout and exits:

```bash
cat <<'EOF'
{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"..."}}
EOF
```

`permissionDecision: "deny"` blocks the tool call; `permissionDecisionReason` is the message
shown back to whoever tried to make it. Exiting 0 with no such output - the early-return path
for a `fork` agent or an explicit `model` argument, shown above - lets the call proceed.

## Exercises

1. **Path-scoped rule.** Create `.claude/rules/sql-style.md` with `paths: ["**/*.sql"]`
   frontmatter and a one-line body. Open any `.sql` file in the session (create a throwaway one
   if none exists) and ask which rules are currently in force. Checkable answer: the SQL rule
   appears in the answer only after a `.sql` file has been read in that session, never before.

2. **Trigger the model-pinning hook.** Dispatch an agent with the Agent tool, naming a
   `subagent_type` that has no `model:` pin in its frontmatter, and pass no `model` argument.
   Checkable answer: the call is denied, and the JSON reason names "Right-fit model rule" and
   instructs you to re-issue the call with an explicit model. This reproduces from any session
   with a plain call like `Agent(subagent_type="general-purpose", prompt="...")` when no
   `model` is supplied and `general-purpose` has no pinned model in its definition.

3. **Two-line skill.** Create `skills/hello-there/SKILL.md`:

   ```yaml
   ---
   name: hello-there
   description: Say hello. Use when asked to demonstrate a minimal skill.
   ---
   Say "hello there" and nothing else.
   ```

   Invoke it by its directory name: type a slash followed by your-skill-name (this is not a
   real command shipped in this repo, so it is written here without backticks on purpose).
   Checkable answer: the agent responds with exactly "hello there".
