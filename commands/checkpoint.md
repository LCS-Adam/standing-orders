---
description: Save a durable mark of where the work stands, mid-session, without writing a resume prompt
---

Write a checkpoint: a short, dated record of what is done and what is in flight, at a save point
inside a session. This is the small, repeatable sibling of `/handoff`. It does not write a resume
prompt and does not assume the session is ending.

**Reach for this** at the end of a wave, after a merge, once a test suite goes green, before
starting something that might not work, or any time losing the last hour would hurt. Several times
a session is normal.

**Reach for `/handoff` instead** when the session is actually ending, or before a `/clear` or a
compact. That one writes a self-sufficient resume prompt for a session that has no memory of this
one. A checkpoint assumes the reader is still you, with the conversation still in front of you.

## What to do

1. Gather, from sources that actually exist rather than files a project might not have:
   `git status --short`, `git log --oneline -5`, and the current branch.
2. Update the header of `.project-state/PROJECT_STATE.md`: `Last-Updated` to today, `Phase` if it
   moved, `Last-Tool` to the tool you are running in.
3. Rewrite its **Current Focus** to what is actually in flight right now, in one or two sentences.
   Replace it; this section is the present, not a log.
4. Update **Blockers**: add anything now blocking, and remove anything that has cleared. A blocker
   list nobody prunes stops being read.
5. Append one entry under a `## Checkpoints` heading, creating that heading if it is absent:

```markdown
### <YYYY-MM-DD HH:MM> <branch> @ <short-sha>

- Done since the last checkpoint: <what actually landed, with the commits>
- In flight: <what is half-finished, and where it is>
- Next: <the single next action>
- Verification: <the command that proves it, and whether it passed>
```

## Rules

**Write only what you verified this turn.** A checkpoint that records a test suite as green
without running it is worse than no checkpoint, because the next reader trusts it. Name the command
and its real result, or write that it was not run.

**Say what is half-finished, plainly.** The value of a mid-session save is the in-flight line. Work
that is committed is already recoverable from git; work that is half-applied in the working tree is
not, and that is what the next reader needs to know.

**Do not overwrite the previous entry.** Checkpoints accumulate. `/handoff` archives to
`.project-state/handoffs/`; this appends in place, so a session's saves read as a sequence.

**Do not read files this repo does not create.** An earlier version of this command read a
deployment log and an open-issues file that no project here ships, so it produced a confident
checkpoint from nothing. Every source named above exists, or is created by this command.
