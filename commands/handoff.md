---
description: Write a self-sufficient resume prompt to .project-state/SESSION_HANDOFF.md before /clear
---

Before clearing context, write a resume prompt that stands on its own per `AGENTS.md`'s
"Session handoff" section.

1. If `.project-state/SESSION_HANDOFF.md` already exists, move it to
   `.project-state/handoffs/<YYYY-MM-DD-HHMM>.md` (archive, do not overwrite in place).
2. Gather: `git status --short`, `git log --oneline -5`, and the files changed this session.
3. Write `.project-state/SESSION_HANDOFF.md`. The FIRST thing in the file is a fenced,
   copy-pasteable resume block. That block must carry, in order:
   - **Where to start**: the working directory and the exact launch command.
   - **What to read first, in order**, and this list must name
     `.project-state/SESSION_HANDOFF.md` itself, first, with the instruction "read everything
     below this block."
   - **Current state**: what is done, with commit SHAs and verification status, and what is
     still in flight versus durable on disk.
   - **The next action**: specific enough to start without re-deriving how you got there.
   - **Standing constraints**: decisions already made, exclusions already agreed, open caveats.
4. Below the block, fill in the template's sections (date and tool, summary, files changed,
   key commands, next step, blockers).
5. Re-read the block alone, as if you were the next session with nothing else pasted in.
   Confirm it reaches every fact above before calling the handoff done.
