# Third-party skills

These skills are not original to this harness. They are vendored from the
[Superpowers](https://github.com/obra/superpowers) skill collection by Jesse Vincent (obra):

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

**Before distributing this repo publicly, confirm the upstream license permits redistribution and
add the required notice here.** Everything else in this repository is the maintainer's own work.
