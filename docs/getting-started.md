# Getting started

## What this is

`agent-harness` is a portable set of instructions, subagent definitions, skills, and safety hooks
for AI coding agents. It installs onto a machine in one command and works the same way across
Claude Code, Auggie, Intent, Codex, Cursor, and Gemini CLI. The problem it solves is that most agent
setups accumulate as machine-specific config that cannot be moved, shared, or handed to a
collaborator. This one is built to leave the laptop it grew on.

## Prerequisites

The install and verify scripts are plain shell. You need:

- `bash`
- `git`
- `jq` (used to merge `settings.json` without clobbering existing hooks)
- `perl` (used for the UTF-8-aware glyph scan and for resolving tier tokens)

All four are standard on macOS and most Linux distributions. If `jq` is missing, `harness install`
fails with a clear message naming it rather than doing a partial install.

## Installing at user scope

```bash
git clone <this-repo> ~/projects/agent-harness
cd ~/projects/agent-harness
./bin/harness install --user --dry-run   # see what would happen first
./bin/harness install --user             # the always-on core, into ~/.claude
```

Run `--dry-run` first. It prints every file the install would touch, with nothing written, so you
can see the shape of the change before it happens.

`harness install --user` copies, file by file:

| What | Goes to | Notes |
|---|---|---|
| `agents/*.md` | `~/.claude/agents/` | 11 subagent definitions, each with a `model:` tier pin resolved to a real model name |
| `skills/*` | `~/.claude/skills/` | Invocable skills: planning, autonomous execution, review, debugging, TDD, scoping |
| `commands/*` | `~/.claude/commands/` | Slash commands for planning, handoff, and phase status |
| `hooks/*.sh` | `~/.claude/hooks/` | The `PreToolUse` gate that denies a subagent spawn with no explicit model |
| `AGENTS.md` | `~/.claude/rules/00-harness-core.md` | The full instruction core |
| `CLAUDE.md` (minus its import line) | `~/.claude/rules/10-claude-specifics.md` | Claude Code mechanics: the hook, context discipline, the advisor gate |
| `rules/shell-portability.md` | `~/.claude/rules/shell-portability.md` | macOS BSD-tool portability notes |

The instruction core installs into `~/.claude/rules/`, not into `~/.claude/CLAUDE.md`. This is
deliberate. Files under `.claude/rules/` load in every session exactly like `CLAUDE.md` does, but
writing into `rules/` means the installer never has to touch a `CLAUDE.md` you already wrote by
hand. If you have personal instructions in `~/.claude/CLAUDE.md` today, they survive the install
untouched, and the harness core loads alongside them.

Everything the installer writes is additive. If a destination file already exists and is
identical, the install reports it as a no-op. If it exists and differs, the install skips it and
tells you so, rather than overwriting silently. Nothing is replaced unless you pass `--force`.

`install --user` also merges `config/settings.portable.json` into `~/.claude/settings.json`.
Objects merge normally; hook arrays are appended and deduplicated, so a hook you already had on the
same event is never dropped. A timestamped backup of your prior `settings.json` is written before
the merge.

## User scope versus project scope

**User scope** is what you just installed: agents, skills, commands, hooks, and the instruction
core in `~/.claude/`. It loads in every Claude Code session, in every repository you open, forever,
until you remove it.

**Project scope** is what `harness init` and `harness add` write into one specific repository:
`AGENTS.md`, `CLAUDE.md`, `.project-state/`, and whichever modules you add. It loads only when you
are working inside that repository.

The workspace-brain module (see below) is deliberately a project-scope module, not a user-scope
one, even though it is one of the most useful things this harness ships. The workspace brain
mandates writing artifacts into `active/contracts/`, `active/runs/`, and `active/verification/` for
every substantial task. That is exactly the right discipline inside a repo that has opted into it.
It is the wrong thing to have appear, uninvited, inside every repository you happen to open,
including one that belongs to an employer or a client who never agreed to a directory full of your
agent's scratch state showing up in their tree. Keeping it project-scoped means you choose, repo by
repo, where that discipline applies.

## Setting up a repo

Inside any git repository:

```bash
harness init
```

This writes:

- `AGENTS.md`: the canonical instruction set, copied in full
- `CLAUDE.md`: a single line, `@AGENTS.md`, plus a short "Project notes" section for anything
  specific to this repo (only written if `CLAUDE.md` does not already exist)

  The `@` prefix is Claude Code's import syntax. `@AGENTS.md` means "load that file here", so the
  instructions live in exactly one place and Claude reads them through this file. A symlink would
  also work, but it needs Administrator rights on Windows and checks out as a plain text file when
  `core.symlinks` is off, so the import is the safer default. Note that `@` is Claude-only: every
  other tool reads `AGENTS.md` directly, which is why that file is self-contained rather than a set
  of imports itself.
- `.project-state/`: the tracking files covered in `docs/project-management.md`

Then add modules as you need them:

```bash
harness add workspace-brain
harness add context
harness add multi-agent
harness add phase
harness add project-state
```

| Module | What it brings |
|---|---|
| `workspace-brain` | `.claude/CLAUDE.md` (the state-machine orchestrator role, autonomy levels, artifact-persistence rules) and `.claude/rules/workflow.md` (the full routing matrix), plus a `knowledge/` directory |
| `context` | `.claude/context/`: reference docs for consensus mode, chatroom mode, multi-agent inline and worktree modes, reverse prompting, prompt contracts, verification, Chrome MCP, and video-to-action |
| `multi-agent` | `.claude/rules/multi-agent-runtime.md`: the runtime policy for running agents in parallel git worktrees, including when `--dangerously-skip-permissions` is and is not acceptable |
| `phase` | `templates/phase/` copied to `phases/`: a nested per-phase `CLAUDE.md` pattern for multi-phase builds, so each phase's status and task table stays out of context until you are actually working in that phase |
| `project-state` | Re-copies `.project-state/` on its own, for a repo that already ran `harness init` but skipped or lost that directory |

Every `add` is additive in the same way `install` is: an existing file is skipped and reported, not
overwritten, unless you pass `--force`.

## Using it with another tool

```bash
harness add --tool auggie
harness add --tool codex
harness add --tool cursor
harness add --tool gemini
harness add --tool intent
harness add --tool cosmos
```

`auggie`, `codex`, `cursor`, and `gemini` each write one pointer file for that tool: a rules file
for Auggie's user scope, `~/.codex/AGENTS.md` for Codex, a `.mdc` rule for Cursor, or a one-line
`GEMINI.md` import for Gemini CLI. `intent` prints guidance rather than writing anything, because
Intent already reads `AGENTS.md` and a `skills/` directory straight from the repo with no adapter
needed.

`cosmos` is the one that needs explaining. COSMOS has two paths: a conversational Advisor that
edits no files, and `auggie cloud`, which manages Experts as committable YAML bundles. This harness
does not yet generate those bundles, so `harness add --tool cosmos` prints guidance rather than
writing a file: either describe the Expert you want to Cosmos Advisor in plain language, or run
`auggie cloud expert init` to scaffold a bundle yourself and paste the relevant parts of
`AGENTS.md` into it.

Generating Cosmos bundles from the harness's own agent definitions is planned work, not a shipped
feature. Do not assume it exists because this section describes the shape it would take.

See `adapters/README.md` for the full table of what each tool reads at project and user scope.

## Running verify

```bash
harness verify
```

This runs `verify.sh`, the scrub gate. It exists because this framework is meant to be carried onto
machines that are not yours, and a fail-open scrub looks exactly like a passing one. The gate runs
eleven checks and asserts, at the end, that it ran all eleven, so a broken check fails loudly
instead of silently passing nothing:

1. No absolute home paths in tracked files.
2. No vendor model names in prose outside `config/models.conf`.
3. Every agent definition pins a `{{TIER_*}}` model token.
4. Every skill's `SKILL.md` has `name:` and `description:` frontmatter.
5. `CLAUDE.md` starts with `@AGENTS.md` on line one.
6. No permission-bypass defaults in the shipped `settings.portable.json`.
7. Every shell script uses an absolute-path shebang (`#!/bin/bash`, not `#!/usr/bin/env bash`).
8. No banned typographic glyphs (curly quotes, em dashes, and the rest) in client-facing docs.
9. No matches against a personal-marker denylist.
10. No instruction points at a `~/.claude/rules/` file that the installer never creates. An
    instruction naming a file that is not there is worse than no instruction: the agent is told to
    go read something and finds nothing.
11. Every backticked slash command in the docs resolves to a file in `commands/`, a
    `skills/<name>/SKILL.md`, or one of two short, reasoned allowlists in `verify.sh`. A doc that
    tells you to type a command that does not exist costs you more than saying nothing would.

Read the output top to bottom. Each line is `PASS`, `FAIL`, or, for check 9 specifically, `WARN` if
no denylist is configured. A `FAIL` line is followed by up to ten example matches so you can find
and fix the problem without re-running with more verbosity.

The denylist for check 9 deliberately does not live in this repository: a committed list of the
personal terms you want to keep private would itself be the leak. Point it at a file outside the
repo with `--denylist PATH`, or set `HARNESS_DENYLIST`; the default is
`~/.agent-harness-denylist`. One term or regex per line, case-insensitive, blank lines and `#`
comments ignored. If that file does not exist, `verify` still runs the other ten checks and warns
that the personal-marker check did not run, rather than silently skipping it.

## A first real task

Here is a full pass through the framework on a small, real change.

1. `cd` into a repo you have run `harness init` in.
2. Ask your agent to fix a specific bug, naming the file and the symptom.
3. The agent reads `AGENTS.md` (loaded automatically as project instructions) and applies "read
   before you write": it traces the actual code path the bug touches before proposing anything.
4. If the fix requires the agent to dispatch a subagent, for example to run an isolated verification
   pass, the `PreToolUse` hook checks that call. If it has no `model` parameter and no agent
   definition with a pinned model, the hook denies it with a message telling the agent to re-issue
   the call with a model. This is not a bug: it is the sizing rule from `AGENTS.md` being enforced
   in the harness that everything else assumes.
5. The agent fixes the bug, writes or updates a test, and reports what changed plainly: what was
   fixed, what was tested, and whether the fix touched anything unexpected.
6. Before committing, run `harness verify` if the repo carries harness scaffolding you want to keep
   clean, particularly if any file you touched could plausibly contain an absolute path or a stray
   personal term.
7. Commit with a conventional-commit message. The agent never appends an AI co-authorship trailer;
   `AGENTS.md` says so explicitly, and it overrides any tool default that would add one.

## Troubleshooting

| Problem | What is happening | Fix |
|---|---|---|
| `error: required tool not found: jq` | `harness install` checks for `jq` before merging settings and refuses to do a partial install | Install `jq` (`brew install jq` or your package manager's equivalent), then re-run |
| A subagent spawn gets denied by a hook | A `PreToolUse` hook is a script Claude Code runs before it executes a tool call, and it can veto that call. This one vetoes any subagent dispatch that does not name a model, because the alternative is inheriting the parent's model silently and burning a frontier model on mechanical work. It will interrupt you, and that is the cost of the guarantee | Re-issue the dispatch with an explicit `model` parameter, or point it at an agent definition that pins one in its frontmatter. If it fires often, pin the model in the agent definition once instead of passing it per call |
| A file you expected to be written says `(exists, differs - use --force to replace)` | The installer found a file already at that path with different content and chose not to overwrite it | Diff the two versions by hand; re-run the same command with `--force` only once you are sure the existing file should be replaced |
| `harness verify` fails on a denylist term | Check 9 matched a term from your personal denylist against tracked content | Remove or rephrase the flagged line; if the match is a false positive, tighten the term in your denylist file |
| `harness verify` reports `WARN no denylist at ...` | No denylist file exists at the default or `--denylist` path | Create one outside the repository, one term per line, if you want that check to actually run |

## Where to go next

`docs/choosing-your-tools.md` covers when to reach for a rule, a skill, a subagent, or a slash
command. `docs/project-management.md` covers `.project-state/` and how session state survives a
context clear.
