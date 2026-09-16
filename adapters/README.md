# Using this harness with other tools

The instruction layer is portable because the tools converged on two filenames. `AGENTS.md` is the
canonical file here and `CLAUDE.md` is a one-line import of it, so a single edit reaches every tool
below. What does not port is per-agent model pins, MCP server config, and anything a vendor keeps
in its own cloud settings.

## What each tool reads

| Tool | Project scope | User scope | Needs an adapter |
|---|---|---|---|
| Claude Code | `CLAUDE.md`, `.claude/rules/`, `.claude/{agents,skills,commands}` | `~/.claude/CLAUDE.md`, `~/.claude/rules/` | no |
| Auggie (Augment) | `CLAUDE.md` first, then `AGENTS.md`, `.augment-guidelines`, `.augment/rules/` | `~/.augment/rules/` | user scope only |
| Intent | `AGENTS.md`, `CLAUDE.md`, a `skills/` directory | app settings | no |
| OpenAI Codex | `AGENTS.md` | `~/.codex/AGENTS.md` | user scope only |
| Cursor | `.cursor/rules/*.mdc`, also reads `AGENTS.md` | `~/.cursor/` | optional |
| Gemini CLI | `GEMINI.md` | `~/.gemini/` | one-line pointer |
| Copilot, Windsurf, Cline | `AGENTS.md` | varies | no |

`harness add --tool <name>` writes whichever pointer file a tool needs.

The "reads `CLAUDE.md` natively, no adapter required" shortcut only holds at **project** scope. At
user scope every tool reads its own home directory, which is why `harness add --tool` writes one
file per tool there.

## Tools with no repo surface

**COSMOS** is Augment's cloud platform, where reusable agent templates called Experts run inside
Environments. It has two configuration paths, and the difference matters:

- **Cosmos Advisor** is the conversational one. You describe the workflow you want in plain language
  and it deploys or designs the Expert end to end. Its documentation says you never see or edit a
  configuration file, which is true of that path.
- **`auggie cloud`** is the file-based one, and it is the one this repo can target. Experts,
  environments, MCP servers and residents are represented as YAML **bundles**:
  "A bundle is a complete, portable description of the resource, so it can live in a repository and
  be reviewed like any other change." The workflow is `init`, edit, `validate`, `diff`, `apply`,
  every `apply` creates an immutable version, and the docs state plainly that
  "the repository becomes the source of truth for your Cosmos configuration"
  ([docs](https://docs.augmentcode.com/cli/cloud)).

So COSMOS is a real integration target, not an exception. Reading only the Advisor page and
concluding there is no committable surface is a mistake this project made once already.

**Intent** reads `AGENTS.md` and a `skills/` directory straight out of the repo, so the instruction
and skill layers work with no adapter. Its Specialists and MCP servers are configured inside
Intent's own settings and cannot be driven from a repo.

## Why `CLAUDE.md` imports rather than symlinks

A symlink needs Administrator privileges or Developer Mode on Windows, and a repository symlink
checks out as a plain text file containing the target path when `core.symlinks` is false, which is
common on managed corporate machines. The `@AGENTS.md` import has neither failure mode. It is also
the pattern Anthropic documents for repositories that already use `AGENTS.md`.

Note that `@path` is Claude-only syntax. Every other tool reading `AGENTS.md` sees literal text and
follows nothing, which is exactly why `AGENTS.md` is self-contained rather than a set of imports.

## Agent names

Agent definitions are named for the job they do, not the model they run, so a roster change does
not turn every filename into a lie. If you are porting plans or dispatch sites written against the
older model-named agents, this is the mapping:

| Old name | Now |
|---|---|
| `exec-haiku-medium` | `exec-mechanical` |
| `exec-sonnet-medium` | `exec-standard` |
| `exec-opus-high` | `exec-critical` |
| `exec-opus-max` | `exec-subtle` |
| `opus-adversary` | `adversary` |
| `fable-master-planner` | `plan-synthesizer` |
| `fable-reviewer` | `design-reviewer` |

Agent names are load-bearing identifiers: skills, plans, and state documents dispatch by name. Treat
a name as an opaque identifier and change the `model:` pin instead. `config/models.conf` is the one
file that binds a tier to a real model.

## MCP

MCP is the one genuinely cross-tool capability surface, but every tool reads it from a different
path. `config/mcp.example.json` documents where each looks. Never commit credentials into any of
them; reference an environment variable instead.
