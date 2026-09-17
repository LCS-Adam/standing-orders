# Third-party skills

**The policy: reference, do not vendor.** A skill, agent or command that comes from a GitHub
repository belongs in `config/upstream.conf`, gets cloned to `.upstream/` by `harness upstream`, and
is installed into whichever tool you are running by that tool, reading the author's own source.
`docs/upstream-sources.md` explains why, and carries the instruction to hand a coding agent.

Everything below predates that policy.

## Pinned snapshots still in `skills/`

These were copied from the [Superpowers](https://github.com/obra/superpowers) skill collection by
Jesse Vincent (obra) before the harness referenced upstreams:

| Skill | Upstream |
|---|---|
| `brainstorming` | obra/superpowers |
| `requesting-code-review` | obra/superpowers |
| `systematic-debugging` | obra/superpowers |
| `test-driven-development` | obra/superpowers |

The author's internal test fixtures (`test-pressure-*.md`, `test-academic.md`, `CREATION-LOG.md`)
were removed; the skill bodies are otherwise unmodified except for the tier-name rewrite applied
across this repo, and the dispatch line in `requesting-code-review/SKILL.md`, which now dispatches
this harness's own `agents/code-reviewer.md` instead of pasting an inline prompt. The checklist that
skill links at the end (`requesting-code-review/code-reviewer.md`) is still the vendored one;
`agents/code-reviewer.md` links it too, so the two stay one document rather than diverging.

**Treat `.upstream/superpowers/` as authoritative and these as a fallback.** They are what the
harness installs on a machine with no network, and they are frozen at the moment they were taken.
When the two disagree, upstream is right about the author's intent and these copies are right about
what this repo currently ships.

## Converted by hand, from a repository that cannot be installed from

`skills/grill-me/` comes from [Joanium/Skills](https://github.com/Joanium/Skills) (Apache-2.0),
recorded in `config/upstream.conf` as reference material with no `install=`.

It could not go through the normal upstream path. That repository is over six thousand flat `.md`
files in one directory: there is no `skills/<name>/SKILL.md` tree for the installer to find, and the
frontmatter carries a display name with a space in it, which the installer refuses as a directory
component. So one file was taken and reshaped.

The body is byte-identical to upstream and the file says so in a comment at the top. Only the
frontmatter changed: `name` became the directory name this repo requires, and the upstream
`trigger` list was folded into `description` so skill matching still fires on the same phrases.
Apache-2.0 requires that modifications be stated, which is what that comment and this paragraph do.

Refreshing it is manual. `harness upstream` updates the clone; nothing propagates from the clone
into `skills/grill-me/`, so diff the two if you want the author's later changes.

## Retiring them

Not done, and not a one-line change. Whoever does it should know what it touches:

- `agents/code-reviewer.md` links `skills/requesting-code-review/code-reviewer.md`. Removing the
  skill without redirecting that link leaves the agent pointing at nothing.
- The skill count is asserted in the client-facing docs and machine-checked by `verify.sh`, so
  every count claim moves in the same commit or the gate goes red. `verify.sh` names which files.
- The offline fallback goes away with them. That is the actual trade: upstream freshness against
  working without a network. Decide it deliberately.

## License

**Before distributing this repo publicly, confirm the upstream license permits redistribution and
add the required notice here.** This applies to the pinned snapshots above, which carry the
author's bytes. It does not apply to anything in `config/upstream.conf`, which carries only a URL.
Everything else in this repository is the maintainer's own work.
