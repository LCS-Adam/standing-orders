@AGENTS.md

# Claude Code specifics

Everything above applies. This section covers mechanics that only exist in Claude Code.

## Dispatching subagents

The tier rules in `AGENTS.md` are enforced here by a `PreToolUse` hook
(`hooks/require-agent-model.sh`), which denies any `Agent` spawn that neither passes a `model`
parameter nor names an agent definition with a `model:` pin. `fork` agents are exempt because they
always inherit by design. If the hook denies a call, pick a model and re-issue. Never disable it.

The `model` parameter takes a literal alias, not a tier name. The harness repo's `config/models.conf`
holds the binding, and `harness install` resolves the `{{TIER_*}}` tokens in the shipped agent
definitions.

Surfaces the hook cannot see, which you must size by hand:

- `Workflow` scripts: pass `model` and `effort` in every `agent()` call's options.
- Headless `claude -p` invocations: pass an explicit `--model`.
- Agent definitions you create: pin `model:` in the frontmatter.

## Skills, rules, and commands are three different mechanisms

A directory `skills/<name>/SKILL.md` with `name:` and `description:` frontmatter is a real skill,
invocable by the Skill tool and as `/<name>`. A flat `<name>.md` file is **not** invocable: it is a
context document that something has to load deliberately. The two look alike and are not
interchangeable, so decide which you need before authoring. This harness keeps them apart on
purpose: `skills/` holds only the invocable shape, and per-project context documents live in
`templates/project/context/`.

`.claude/rules/*.md` load every session unless they carry `paths:` frontmatter, in which case they
load only when Claude reads a matching file. Put an instruction in a rule when it must always be
available, and in a skill when it is a procedure that only sometimes applies.

## Context discipline

`@path` imports do **not** save context. An imported file loads at launch exactly like inline text,
so splitting a file into imports is organization only. The mechanisms that genuinely reduce
per-session context are:

| Mechanism | Loads when | Saves context |
|---|---|---|
| `CLAUDE.md` and its imports | every session, at launch | no |
| `.claude/rules/*.md` without `paths:` | every session | no |
| `.claude/rules/*.md` with `paths:` | Claude reads a matching file | yes |
| A nested `subdir/CLAUDE.md` | Claude reads a file in that subdir | yes |
| A skill | invoked, or judged relevant | yes |

Keep the always-on core small. Target under 200 lines for any single instruction file: longer files
consume more context and measurably reduce adherence. Push everything situational into a skill or a
path-scoped rule.

This harness holds itself to that per-file rule and states the cost openly. At user scope it
installs two unconditional files: `00-harness-core.md` (179 lines) and `10-claude-specifics.md`
(69), so roughly 250 lines load in every session before your project adds anything. Each file is
under the limit, the combined total is not. That is a deliberate trade. The sections that could be
made lazy are the ones you least want an agent to forget: the security hard stops, the handoff
discipline, and the client-facing writing rules all have to be in force before the moment you would
have thought to invoke them. Everything genuinely situational is already a skill or a path-scoped
rule. If you do not need the writing rules, delete that section from your own copy.

For a multi-phase build, give each phase its own directory with a short `CLAUDE.md` holding just
that phase's status and task table. It stays out of context until Claude works in that phase.
`templates/phase/` has the pattern.

## Review before you commit to an approach

Use the `advisor` tool before substantive work, when stuck, when changing approach, and before
declaring a task done. Make the deliverable durable before the call, not after.

If the advisor is unavailable, do not silently skip the review. Retry once, and if it stays
unavailable dispatch a reviewer subagent at or above the tier doing the work, giving it the same
context the advisor would have had and asking it to find what is wrong rather than to approve.
"The reviewer was unreachable" is not a reason to skip the gate.

Avoid calling the advisor immediately after an auto-compaction. Do a turn or two of ordinary tool
work first, or start a fresh session.
