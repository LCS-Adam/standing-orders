# Tracking work across sessions

## The problem

An agent session ends and takes its context with it. The next session starts cold: no memory of
what was tried, what broke, or what the plan was. If that state only lives in your head or in a
chat transcript you have to scroll back through, every session pays a re-discovery tax. The fix is
to put the state that matters on disk, in a fixed set of files, so any session (yours, a
teammate's, a different tool entirely) can read where things stand in under a minute.

That is what `.project-state/` is for.

## `.project-state/` as shipped in the template

`harness init` writes this directory into any repo. Here is every file, what belongs in it, and who
writes it.

| File | What belongs in it | Who writes it |
|---|---|---|
| `PROJECT_STATE.md` | Repo name, phase, last-updated date, last tool used, a production-readiness flag, a one-paragraph purpose, current focus, blockers, and stakeholders. The single-page orientation for "what is this repo and where does it stand." | Edited by hand on the first session; phase and date fields are meant to be kept current every session after |
| `NEXT_STEPS.md` | Immediate, short-term, medium-term, and backlog bullets. The "Immediate" section is what a resuming session reads first. | Operators and agents append bullets as they identify next actions |
| `ERRORS.md` | An append-only table of errors, blockers, broken tests, and deployment issues, each with a date, severity, summary, and status | Appended whenever something breaks, never edited retroactively |
| `SESSION_HANDOFF.md` | What the just-ended session accomplished, which files changed, notable commands, the single next step, and any blockers. Overwritten each session; prior versions move to `handoffs/`. | Written at the end of a session, by the agent or the operator |
| `handoffs/` | Archived copies of past `SESSION_HANDOFF.md` snapshots | Populated automatically when a new handoff overwrites the current one |
| `DEPENDENCIES.md` | What this repo depends on and what depends on it, hand-curated, plus auto-detected sections for manifest packages and plan-derived dependencies | Hand-curated tables edited by the operator; auto-detected sections are machine-refreshed |
| `CLEANUP.md` | Stale files, duplicates, stale docs, dead code, and token-heavy files worth trimming out of frequent `Read` reach | Hand-curated, no automatic scanning in this version |
| `SKILL_CANDIDATES.md` | Workflows you have run more than twice by hand, as candidates for a real skill, slash command, or agent | Noted when a repeated pattern is spotted; promoted once a third repo would benefit |

## How this differs from git history

Git records what changed. It does not record why you stopped, what you were about to try next, or
what you decided against and why. A diff shows you a function got rewritten; it does not show you
that the rewrite was blocked on a flaky test you have not yet diagnosed, or that you chose the
simpler of two designs because the second one needed a dependency you were not ready to add.
`.project-state/` exists to hold exactly the information a diff cannot show: intent, next steps,
blockers, and decisions. Git and `.project-state/` are complementary records of the same work, not
competing ones.

## Automating the files above

A fork of this template can add automation that writes these files for you. This template gives
you the files and the discipline of writing to them by hand.

## Practical habits

- Write a next step the moment you notice one, not at the end of the session when you might forget
  it. A bullet in `NEXT_STEPS.md` costs one sentence; a lost next step costs the next session time
  re-deriving it.
- Log an error as soon as it is confirmed, with enough detail that a different session (or a
  different tool) can act on the row without re-reproducing the failure first. `ERRORS.md` is
  append-only for a reason: it is a timeline, not a scratchpad you tidy up.
- Set the phase when it actually changes, not on a schedule. `PROJECT_STATE.md`'s phase field
  (Idea, Scaffolding, In-progress, Testing, Production-ready, Active production, Maintenance,
  Archived) is what a resuming session or a `global-status` summary trusts first.
- Treat `SESSION_HANDOFF.md` as the load-bearing document at the end of any session that changed
  files or made a decision. Read `docs/handoff-and-resume.md` for what makes a handoff actually
  sufficient: the short version is that it must be self-contained, including a pointer to itself,
  because the next session pastes only the handoff, never the whole repository.
