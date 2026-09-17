# Choosing the right mechanism

`agent-harness` gives you six different ways to change how an agent behaves. New users
tend to reach for the same one or two every time, then get surprised when a rule they
wrote gets ignored under pressure, or when a "skill" they wrote never actually loads.
This document walks through all six, what each one is mechanically, when to reach for
it, and when not to.

If you already know what a subagent, a hook, or a context window is, skip to the
decision table near the end. If you do not, read straight through: the vocabulary is
small and this is the one place it is explained together.

## Two words you need first

**Context window.** Everything a model can see for a given turn: your prompt, the
conversation so far, and whatever files or instructions got loaded into it. It has a
fixed size. Every file you load into it competes with your actual conversation for that
space. A model that has to read 3,000 lines of standing instructions before it reads
your question is a model that has less room left for your question, and adherence
measurably drops as the always-on instruction set grows. This is why the harness
keeps its always-on core small and pushes everything else behind an on-demand mechanism.

**Enforcement versus context.** Some of the six mechanisms below are text the model
reads and is expected to follow. Some are code that runs regardless of what the model
decides. That difference gets its own section before the tour.

## The one distinction that matters most

**Instructions are context. Hooks are code.**

`AGENTS.md`, `CLAUDE.md`, rules, skills, and even a subagent's own system prompt are all
just text fed into the model at some point. The model reads them and, in the ordinary
case, follows them. But a model under a confusing prompt, a long conversation, or an
adversarial input can drift from what an instruction says. Nothing forces it back.

A hook is different. It is a real script that the harness runs at a fixed point (before
a tool call, after one, at session start) and its exit code and output can outright
block the action. The model does not get a vote. This repo ships one lifecycle hook,
`hooks/require-agent-model.sh`, and it is the only mechanism in the whole framework that
is guaranteed to fire no matter what the model is thinking. (`hooks/` also holds
`hooks/statusline.sh`, which draws the context-budget status line and gates nothing. See
[`docs/context-health.md`](context-health.md).)

**If something must happen every time, with no exceptions, it needs a hook.** Everything
else in this document shapes behavior. Only a hook enforces it.

## 1. `AGENTS.md` / `CLAUDE.md` - the always-on core

**What it is.** `AGENTS.md` is a plain Markdown file this harness installs at the root
of a project (`harness init`) and merges into `~/.claude/rules/00-harness-core.md` at
user scope (`harness install --user`). It is loaded into context at the start of every
session, every time, with no invocation step. `CLAUDE.md` is a one-line import
(`@AGENTS.md`) plus a short section of Claude Code-specific mechanics; other tools that
do not understand the `@import` syntax just read `AGENTS.md` directly.

**What it is not.** Enforcement. Nothing stops a model from ignoring a line in
`AGENTS.md` under enough pressure. It is a strong steering signal, not a guarantee.

**When to reach for it.** Anything that should apply to every task, in every session,
regardless of what the task is: how to size a model to a task, when to stop and ask a
human, how to write a commit message, whether AI attribution belongs in a commit.
`AGENTS.md` in this repo carries exactly that: model tiers, security stop-conditions,
version control conventions, and writing style for anything a third party will read.

**When not to.** Anything that only matters some of the time. If a rule only applies
when editing shell scripts, putting it in `AGENTS.md` means every session pays its
context cost even on sessions that never touch a shell script. That is what rule 2 is
for.

**Example from this repo.** The model-tiering table in `AGENTS.md` needs to be visible
on every single task, because every delegated unit of work has to be sized against it.
It is short (about a dozen lines including the table) precisely so that being always-on
does not cost much.

## 2. `.claude/rules/*.md` - path-scoped instructions

**What it is.** A directory of Markdown files. A rule with no frontmatter loads every
session, same as `AGENTS.md`. A rule with a `paths:` frontmatter block loads only when
the agent reads a file matching one of those globs. This is the harness's main lever for
"important, but not always relevant."

**Worked example: `rules/shell-portability.md`.**

```markdown
---
paths:
  - "**/*.sh"
  - "**/*.bash"
  - "**/hooks/**"
---

# Shell script portability
...
```

That file documents real gotchas: BSD `sed` needing an explicit backup suffix, `awk -v`
rejecting embedded newlines, `date -j -f` filling missing time fields from the current
clock instead of midnight. Every one of those is true and worth knowing, but only when
you are actually about to write or edit a shell script. The `paths:` block means a
session that never touches a `.sh` file never pays for loading it, and a session that
opens `hooks/require-agent-model.sh` gets it automatically, with no one having to
remember to ask for it.

**When to reach for it.** A standing fact that is true whenever a certain kind of file
is in play, but is dead weight otherwise: language-specific conventions, a subsystem's
quirks, a file format's gotchas.

**When not to.** Something that is not really tied to a file pattern (use a skill,
below), or something so universally relevant that scoping it would just mean it loads
almost every session anyway (put it in `AGENTS.md` and accept the cost, since scoping
adds no benefit).

## 3. Skills - procedures you invoke

**What it is.** A directory at `skills/<name>/` containing a `SKILL.md` file whose
frontmatter declares `name:` and `description:`. That shape is what makes it a real
skill: something the Skill tool can list, something invocable by typing `/<name>`, and
something the harness's skill-matching can surface unprompted when a task looks like a
match. Thirteen skills currently ship in `skills/`:

| Skill | For |
|---|---|
| `autorun-plan` | Executing an approved multi-wave plan unattended, with review gates and heartbeat |
| `brainstorming` | Socratic refinement of a feature idea before any code gets written |
| `deep-plan-swarm` | Heavy multi-agent planning for large or high-stakes work |
| `external-llm-review` | Getting an independent, non-Claude review of a plan or diff |
| `heartbeat` | Keeping a simple approved plan running unattended, no review gates |
| `grill-me` | Interrogating a plan or design until every open decision is resolved |
| `readme-coauthoring` | Writing or rewriting a project README |
| `repo-recon` | Read-only inventory of a repo or binary with file:line citations |
| `requesting-code-review` | Dispatching a review subagent before proceeding |
| `scope-audit` | Establishing what a system actually uses before planning changes to it |
| `systematic-debugging` | Four-phase root-cause debugging before attempting a fix |
| `test-driven-development` | Writing the failing test before the implementation |
| `verify-unexecuted` | Syntax and body-flow smoke checks for scripts that cannot run in the build environment |

One more command belongs in that list and is not in the table, because it is not a harness
skill: `/ponytail-review` cuts a diff back to the smallest thing that holds, and it comes from
the ponytail plugin rather than from `skills/`. `config/upstream.conf` records it as a
dependency and [`docs/upstream-sources.md`](upstream-sources.md) explains how it gets installed.

**When to reach for it.** A multi-step procedure that only applies some of the time and
is complex enough to be worth writing down once rather than re-deriving every time. If
you find yourself wanting to say "when the user asks for X, do these five things in
this order," that is a skill, not a rule.

**When not to.** A one-line fact (that is a rule, or just a line in `AGENTS.md`). Also
not the place for something that must happen unconditionally, since a skill still has
to be judged relevant and loaded before it does anything, and that judgment can miss.

## 4. Slash commands - one-shot invocations

**What it is.** A Markdown file in `commands/`, invoked by typing `/<filename-without-extension>`.
Where a skill is often a standing procedure the model can also decide to load on its
own, a slash command is something the user types deliberately, once, to kick off a
specific flow right now. Four exist in this repo:

| Command | What it runs |
|---|---|
| `/deep-plan` | Local deep-planning flow: advisor pre-flight, a Plan subagent at max effort, advisor critique |
| `/handoff` | Writes a self-sufficient resume prompt to `.project-state/SESSION_HANDOFF.md` |
| `/next-step` | Notes the next action to take |
| `/phase-status` | Reports where a multi-phase build currently stands |

**When to reach for it.** The user wants to trigger a specific, named flow right now,
and that flow has enough steps (calling a subagent, running a script, following a
template) that typing it out each time would be tedious or error-prone.

**When not to.** Anything that should happen automatically without the user asking. A
slash command only runs when someone types it.

## 5. Hooks - the enforcement layer

**What it is.** A shell script the harness runs at a fixed lifecycle point, wired
through Claude Code's own hook configuration (`config/settings.portable.json`, merged
into `~/.claude/settings.json` on install). This repo ships one:
`hooks/require-agent-model.sh`, a `PreToolUse` hook that runs before every `Agent` tool
call.

Read what it actually does: it reads the tool call's JSON payload from stdin, pulls out
`tool_input.model` and `tool_input.subagent_type`. If `subagent_type` is `"fork"` (a
fork always inherits the parent's model by design, so there is nothing to check) or if a
`model` was passed explicitly, it exits 0 and the call proceeds. Otherwise it checks
whether the named subagent's definition file, in the project's `.claude/agents/` or the
user's `~/.claude/agents/`, has a `model:` line in its frontmatter. If none of that
holds, it prints a `permissionDecision: "deny"` response and the call never happens.

**Why this is different from everything above.** `AGENTS.md` also says every delegated
unit of work must get an explicit tier. That is the same rule. The difference is that
`AGENTS.md` is a request the model can, in principle, forget under pressure, while this
hook is code that runs unconditionally on every single `Agent` call and physically
blocks the ones that violate the rule. That is what "hooks are the only hard enforcement
layer" means in practice: same policy, expressed twice, but only one copy of it cannot
be talked out of applying.

**When to reach for it.** Anything that must never happen, no exceptions, regardless of
what the model believes at the time: model-tier omission, a destructive command,
committing a secret. If the honest answer to "what happens if the model just does not
follow this" is "something bad, silently," write a hook.

**When not to.** Anything where being usually-right is good enough, or where the check
is subjective and needs judgment rather than a fixed rule. Hooks are good at binary,
checkable conditions; they are the wrong place for "does this code look reasonable."

## 6. Subagents - a separate context window with a return value

**What it is.** A definition file in `agents/`, each with `name:`, `description:`,
`tools:`, and a `model:` pin in frontmatter. Dispatching one (via the `Agent` tool) spins
up a fresh conversation with its own context window, gives it a scoped prompt and a
scoped toolset, lets it run to completion, and returns its final message back to
whoever dispatched it. The subagent's internal back-and-forth, every file it read, every
command it ran, none of that lands in your context. Only its answer does.

This is the mechanism to reach for when a piece of work would otherwise burn a large
amount of context on work you do not need to keep: a broad read-only investigation, a
mechanical edit you want isolated in its own worktree and branch, an adversarial review
that should not see (and be biased by) the reasoning that produced the thing it is
reviewing. Eleven subagent definitions exist here, named for the job rather than the model:

| Agent | Tier | Job |
|---|---|---|
| `exec-mechanical` | SMALL | Fully-specified, test-provable edits (config entries, plist keys, verified deletions) |
| `exec-standard` | MID | Well-bounded implementation against a proven local pattern |
| `exec-critical` | FRONTIER-DO | Correctness-critical implementation: concurrency, derivation, foundations other work builds on |
| `exec-subtle` | FRONTIER-DO, max effort | The single subtlest workstream in a plan |
| `adversary` | FRONTIER-DO, xhigh effort | Adversarial pre-merge correctness review, tries to break the change |
| `design-reviewer` | FRONTIER-THINK, xhigh effort | Reviews a plan or design against real code, read-only, never edits |
| `plan-synthesizer` | FRONTIER-THINK, max effort | Synthesizes investigation and prior plans into one execution plan |
| `autorun-plan-orchestrator` | FRONTIER-DO | Executes an approved multi-wave plan unattended |
| `data-eng-sa-orchestrator` | MID | Implements data-engineering / analytics-engineering deliverables |
| `data-eng-sa-reviewer` | FRONTIER-DO | Reviews data-engineering deliverables for grain, correctness, honesty |
| `code-reviewer` | FRONTIER-DO | Reviews a diff against its plan for production readiness, read-only |

**When to reach for it.** The work is separable, would pollute your context if done
inline, and benefits from a fresh, unbiased, or narrowly-scoped view. Also whenever a
piece of work needs an isolated git worktree so it cannot collide with other concurrent
work.

**When not to.** Small tasks where the overhead of spinning up a new context and
writing a self-contained brief costs more than just doing the work inline. A subagent
that starts fresh has no memory of your conversation; every subagent prompt has to be
self-sufficient, and writing that briefing is itself a cost.

## The trap: a skill directory and a flat file look alike and are not

`skills/repo-recon/SKILL.md` with `name: repo-recon` and a `description:` field in its
frontmatter is a real, invocable skill. `/repo-recon` finds it; the Skill tool can list
it and load it when relevant.

A file like `notes/repo-recon.md`, sitting flat with no such directory shape, is not
invocable by anything. It is a document. If some other instruction tells the model to
go read it, fine, that works, but nothing makes that happen on its own. There is no
`/notes-repo-recon` command waiting for that file, and no matching logic will surface
it.

This harness keeps the two apart on purpose: `skills/` holds only the real, invocable
shape, and project-specific reference documents that are meant to be read rather than
invoked live under `templates/project/context/`. Before you write either one, decide
which you need. If you want `/something` to work, or you want the harness's own skill
matching to find it, you need the `skills/<name>/SKILL.md` shape with real frontmatter.
If you just want a document that gets read when something else points at it, a flat
file is fine, and dressing it up with skill frontmatter buys you nothing.

## Decision table

| I want to... | Mechanism |
|---|---|
| Set a standing rule that applies to literally every task | `AGENTS.md` / `CLAUDE.md` |
| Document a gotcha that only matters when editing a certain kind of file | A rule with `paths:` frontmatter |
| Write down a multi-step procedure the model should follow when a task matches it | A skill (`skills/<name>/SKILL.md`) |
| Let the user kick off a specific named flow by typing something | A slash command (`commands/<name>.md`) |
| Guarantee something happens (or is blocked) every time, with no exceptions | A hook |
| Delegate a piece of work to run in its own context and hand back only the result | A subagent (`agents/<name>.md`) |
| Isolate concurrent edits so two workstreams cannot collide | A subagent with its own git worktree |
| Make sure a rule cannot be quietly ignored under pressure | Move it from prose into a hook |

## One more thing worth remembering

None of the first five mechanisms are mutually exclusive with the sixth. A subagent's
own `agents/<name>.md` file is itself instructions, the same as `AGENTS.md`, just
scoped to that one agent's run. The `require-agent-model.sh` hook exists specifically
because dispatching a subagent is the one place where "the model just forgot the rule"
has a real cost (silently burning a frontier-tier model on work a small one could have
done), which is exactly why it is the mechanism that got backed by code instead of left
as prose.
