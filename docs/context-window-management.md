# Managing the context window

Every AI coding agent session runs against a context window: a fixed amount of text the model can
hold at once. Your instructions, the files it has read, every command it has run, and every reply
it has given all live in that same space. When a new session starts, none of that carries over. The
agent has no memory of yesterday's session, last hour's session, or the session that ran right
before a `/clear`. It reads whatever loads at launch and nothing else, unless a file on disk tells
it where to look.

This matters immediately, because the first thing most new users do wrong is assume the agent
remembers something it was never told to write down. If a decision only exists as a sentence in a
chat transcript, it is gone the moment that session ends. This document covers what actually fills
the window, why the agent gets worse as it fills, and what to do about both.

## Why quality drops as the window fills

Nothing mystical happens as a context window fills up. What changes is competition. Every
instruction, file, and tool result in the window is competing for the same fixed amount of the
model's attention. Early instructions have to compete with everything added after them. A rule
stated in turn one is still there in turn eighty, but so is everything else, and the model's
adherence to any single instruction drops as the total volume of context grows.

This is gradual, not a cliff. Degradation starts well before the window is technically full: the
practical rule is to treat the middle of the window as the point where you should already be
managing context, not the point where you start worrying. Waiting until the window is nearly full
to do something about it means you have already been operating in degraded conditions for a while.

There is no need for specific numbers to act on this. The operating rule is: keep the window from
filling with things that do not need to be there, and notice the symptoms below when they show up.

## The counter-intuitive fact: imports do not save context

New users almost universally get this wrong, so it is worth stating plainly before anything else:
splitting one file into several files that import each other does not reduce how much context a
session uses.

An `@path` import loads the imported file at launch, in full, exactly as if its text had been
pasted inline. If a 400-line instruction file is split into five 80-line files that import each
other, the session still loads 400 lines. What changed is organization on disk, not cost in the
window.

Imports are still useful. They let you keep related material in separate files for readability, and
they let you point a short file at a big reference without cluttering the short file's prose. But
nobody should split a file into imports believing it will make sessions faster or leave more room
for other work. It will not. The only way to reduce what a session loads is to reduce what actually
loads at launch, which the next section covers.

## What actually loads, and when

Different mechanisms in this harness load at different times. Some load every single session no
matter what. Others load only when they become relevant. Knowing which is which is the entire
game:

| Mechanism | Loads when | Saves context |
|---|---|---|
| `CLAUDE.md` and its imports | every session, at launch | no |
| `.claude/rules/*.md` without `paths:` | every session | no |
| `.claude/rules/*.md` with `paths:` | Claude reads a matching file | yes |
| A nested `subdir/CLAUDE.md` | Claude reads a file in that subdir | yes |
| A skill | invoked, or judged relevant | yes |

The first two rows are your always-on tax. Everything in `CLAUDE.md`, everything it imports, and
every rule without a `paths:` filter loads into every session before the agent does anything at all.
That cost is paid whether the session ever touches the thing the rule is about or not.

The last three rows are how you avoid paying that tax for material that is only sometimes relevant.
A rule with `paths:` frontmatter stays out of the window entirely until the agent actually reads a
file matching that path. A `CLAUDE.md` inside a subdirectory does the same thing for an entire area
of a project: it stays dormant until work happens in that directory. A skill loads only when it is
invoked directly or when the harness judges it relevant to the current task.

## The practical levers, in order of payoff

**Keep the always-on core small.** Since `CLAUDE.md` and unscoped rules load every time regardless
of relevance, the biggest lever is simply keeping that always-on material short. Target under 200
lines for any single instruction file. This is not an arbitrary style preference: longer files
measurably reduce adherence, because they leave less room in the window for everything else that
session needs to hold, and they compete harder for attention against the specific task at hand.

**Push situational instructions into skills.** Anything that only matters for a particular kind of
task, rather than every task, belongs in a skill, not in the always-on core. A skill for debugging,
a skill for planning, a skill for a specific review workflow: each one sits outside the window until
the situation that calls for it actually shows up.

**Path-scope your rules.** A rule that only matters when someone touches a specific kind of file
(a migration script, a public API handler, a client-facing template) should carry `paths:`
frontmatter naming that pattern. Loaded-every-session is the default; scoping it out and making it
conditional is the exception you have to add on purpose.

**Give each phase of a large build its own short `CLAUDE.md`.** For anything bigger than a single
session's worth of work, split the build into phase directories, and give each one a `CLAUDE.md`
holding only that phase's status and task table. `templates/phase/` in this repository is the
worked example:

```
templates/phase/
  CLAUDE.md                  <- status index for the whole build
  a-example-phase/
    CLAUDE.md                <- this phase's status and task table only
    01-first-task.md         <- one task's goal, steps, verification, rollback
```

The top-level `templates/phase/CLAUDE.md` is a table with one row per phase and its status
(`PENDING`, `IN PROGRESS`, `COMPLETE`, `BLOCKED`). That is all it holds. The per-phase
`a-example-phase/CLAUDE.md` holds one paragraph on what that phase achieves, its own status, and a
task table. It stays out of context until the agent actually works inside that phase's directory,
at which point only that phase's short file loads, not the other nine phases sitting untouched
elsewhere in the build.

## What compaction does

When a session runs long enough that its transcript would exceed the window, the harness compacts
it: the full transcript is summarized down to a shorter form that preserves the gist of what
happened, and that summary replaces the original turns going forward. Work can continue after a
compaction; the agent is not required to stop and start a fresh session.

What survives is a summary, not a full record. Specific numbers, exact file paths mentioned once in
passing, and precise wording of an earlier instruction can all get lossy or disappear entirely in
that summary. Anything that must survive with full fidelity, a commit SHA, an exact command, a
specific decision and its reasoning, needs to be written to a durable file on disk before
compaction happens, not left to survive as a memory of the conversation. That durable-file discipline
is the subject of the companion document, `docs/handoff-and-resume.md`.

## Symptoms and fixes

| Symptom | Likely cause | Fix |
|---|---|---|
| Agent forgets an instruction it followed earlier | The window has filled enough that early instructions are competing with a lot of later material | Move the instruction into a path-scoped rule or a phase `CLAUDE.md` so it reloads fresh near the work, instead of relying on it surviving from turn one |
| Agent re-reads files it already read | The read happened long enough ago, or enough has been added since, that the content is effectively out of reach | Start a fresh session for the next major piece of work, or checkpoint and resume, rather than pushing one session further |
| Answers get vaguer or more generic | The window is in the degraded middle range described above | Trim what is loading by default: check for unscoped rules or an oversized `CLAUDE.md` that could be split |
| Agent contradicts a decision made earlier in the same session | The decision was stated once in prose and never written to a durable file, and it is now competing with everything said since | Write standing decisions to a file the agent will re-read (a rule, a phase `CLAUDE.md`, `.project-state/PROJECT_STATE.md`), not just into the conversation |

The common thread across all four: the fix is almost never "try harder in the same session." It is
either reducing what loads by default, or writing the thing that must persist to a file that will
still be there next time, instead of trusting it to survive inside a conversation that is already
competing for room.
