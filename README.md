# agent-harness

A portable operating framework for AI coding agents: instructions, subagent definitions, skills,
slash commands, and safety hooks that install onto any machine in one command and work across
Claude Code, Auggie, Intent, Codex, Cursor, and Gemini CLI.

Most agent setups accumulate as a pile of machine-specific config that cannot leave the laptop it
grew on. This one is built to be moved, shared, and forked.

## Install

```bash
git clone <this-repo> ~/projects/agent-harness
cd ~/projects/agent-harness
./bin/harness install --user     # the always-on core, into ~/.claude
./bin/harness verify             # confirm nothing personal or machine-specific came along
```

Then, inside any repository you want the project layer in:

```bash
harness init                     # AGENTS.md, CLAUDE.md, .project-state/
harness add workspace-brain      # state machine, autonomy gates, artifact persistence
harness add --tool auggie        # another tool's pointer file
```

Everything is additive. Nothing is overwritten without `--force`, and every skip is reported. Run
anything with `--dry-run` first to see what it would touch.

Requires `bash`, `git`, `jq`, and `perl`.

## What is in it

| Directory | What it holds |
|---|---|
| `AGENTS.md` | The canonical instruction set. Self-contained, vendor-neutral, read by every tool. |
| `CLAUDE.md` | A one-line import of `AGENTS.md` plus Claude Code specifics. |
| `agents/` | 10 subagent definitions, named for the job they do rather than the model they run. |
| `skills/` | 12 invocable skills: planning, autonomous execution, review, debugging, TDD, scoping. |
| `commands/` | Slash commands for planning, checkpointing, handoff, and phase status. |
| `hooks/` | A `PreToolUse` gate that refuses any subagent spawn with no explicit model. |
| `rules/` | Path-scoped rules that load only when relevant. |
| `templates/` | Project scaffolding, the workspace brain, and the nested-phase pattern. |
| `config/models.conf` | The single place tiers bind to real models. |
| `verify.sh` | The scrub gate. Nine checks, fails the build rather than leaking. |

## Two ideas worth knowing before you use it

**Size the model from the task, not from convenience.** Work is sorted into four tiers by two
questions: what a silent wrong answer costs, and whether the result is mechanically checkable.
Tiers are described by capability rather than by model name, so a new release slots in by
description. `config/models.conf` binds them to real models, and it is the only file to edit when a
machine has different access. Reviewers always sit at or above the tier that produced the work.

**Context is the scarce resource, and imports do not save any of it.** An imported file loads at
launch exactly like inline text. What actually reduces per-session context is path-scoped rules,
skills that load only when invoked, and giving each phase of a large build its own short
`CLAUDE.md` in its own directory. The always-on core is deliberately small. `docs/` covers this in
depth.

## Portability

`AGENTS.md` is the canonical file because it is the format the ecosystem standardized on, and
`CLAUDE.md` imports it rather than symlinking it, since symlinks need Administrator rights on
Windows and check out as plain text when `core.symlinks` is false.

Auggie reads `CLAUDE.md` natively and at higher precedence than `AGENTS.md`. Intent reads both plus
a `skills/` directory. Codex, Cursor, Gemini CLI, Copilot, and Windsurf read `AGENTS.md`. COSMOS is
configured conversationally in Augment's cloud and has no repo-committed surface at all, so there is
nothing to generate for it. `adapters/README.md` has the details per tool.

## The scrub gate

`verify.sh` exists because this framework is meant to be carried onto machines that are not yours.
It fails on absolute home paths, vendor model names that escaped into prose, agent definitions
missing a tier pin, malformed skill frontmatter, permission-bypass defaults, shell scripts with a
fragile shebang, banned typographic glyphs in client-facing docs, and any term in a personal-marker
denylist.

That denylist deliberately lives outside the repository, at `~/.agent-harness-denylist` or wherever
`--denylist` points, because a committed list of the things you want to keep private is itself the
leak.

A scrub that has never been run against a known-bad input is unverified, so the gate is tested by
planting each defect class into a scratch copy and confirming a non-zero exit.

## Third-party content

Four skills are vendored from the Superpowers collection. See `skills/THIRD_PARTY.md` for
provenance and for the license check to complete before distributing this repository publicly.

## License

Not yet chosen. Treat as all rights reserved until a license file is added.
