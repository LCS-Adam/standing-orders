# Handing off between sessions

An agent session does not survive a `/clear`, a compaction, or the start of a new session. Whatever
the agent knew a moment ago, which files it read, which decisions it made, which command it tried
and reverted, is gone unless it was written to a file before that moment. This document covers how
to write that file so the next session can actually pick up where the last one left off.

## Why a handoff is needed at all

The instinct is to type a paragraph summarizing what happened and trust that this is enough. It is
not. A prose summary in a chat window disappears with the chat window. The only thing that survives
a clear, a compact, or a fresh session is a file on disk, and only if the next session is told to
read it.

`AGENTS.md` states this directly: context does not survive a clear, a compact, or a new session.
Whenever any of those is about to happen, and it always eventually happens, the deliverable is a
copy-pasteable resume prompt, not a summary. The distinction matters because a summary describes
what happened; a resume prompt tells the next session what to do about it.

## What a resume prompt must contain

Per the session handoff section of `AGENTS.md`, a resume prompt carries five things:

1. **Where to start.** The working directory and the exact launch command. Not "the project
   directory," the actual path, and not "start the agent," the actual command with any flags it
   needs.
2. **What to read first, in order.** The specific files the next session should open before doing
   anything else, in the order that makes them make sense. If file B references something defined
   in file A, list A first.
3. **Current state.** What is done, with commit SHAs and verification status, not "mostly working"
   or "should be fine." State what is durable on disk versus what is still in flight and could be
   lost if the session ends now.
4. **The specific next action.** Not "continue the work," the actual next step, with enough context
   attached that the next session can act on it without re-deriving how you got there.
5. **Standing constraints.** Decisions already made, exclusions already agreed, and open caveats
   the next session needs to honor rather than re-litigate.

Skipping any of these five turns the resume prompt back into a summary. A summary that lists what
was done but not where to start, or what to read, leaves the next session to reconstruct the launch
conditions from scratch, which is the exact cost a handoff exists to avoid.

## The self-sufficiency rule

This is the rule that is easiest to get wrong, and it comes from a real failure, not a
hypothetical one.

The user pastes only the resume prompt block into the next session, never the whole document it
came from. That means anything written outside the block is invisible to the next session unless
the block itself explicitly says to go read that file. A resume prompt that assumes the reader has
also seen the rest of the document it was written in is making an assumption that will not hold,
because the rest of the document is not what gets pasted.

Here is the failure this rule is drawn from, and the fix for it, as a before-and-after pair.

Before, the block names four files but not the file it is sitting in:

```
Read first, in this order:
1. AGENTS.md, section "Session handoff"
2. docs/context-window-management.md
3. templates/phase/CLAUDE.md
4. .project-state/NEXT_STEPS.md
```

Pasting this exactly as designed orphans the long section of state details, file inventories, and
open questions sitting below it in the same file, because nothing in the pasted text says that
detail exists.

After, the block names itself first, with an instruction to keep reading past it:

```
Read first, in this order:
1. .project-state/SESSION_HANDOFF.md (this file, read everything below this block)
2. AGENTS.md, section "Session handoff"
3. docs/context-window-management.md
4. templates/phase/CLAUDE.md
5. .project-state/NEXT_STEPS.md
```

This matters most exactly when the prompt and the supporting detail live in the same file: the
block is the only part that travels, so if it does not carry its own location, the location is
lost, no matter how thoroughly the detail is written below it.

## The three-step check before declaring a handoff done

Before treating a handoff as finished, run through three steps:

1. **Name the handoff file in the block's own read list.** If the block lives inside
   `SESSION_HANDOFF.md`, or any other file with more detail below it, the block's read-first list
   must include that filename, with an instruction to read everything below the block.
2. **Re-read the block alone**, as if you were the next session with no other context and nothing
   pasted but that block. Ask whether it reaches every fact it needs. Anything it cannot reach by
   following its own instructions is not written down, no matter how thoroughly it is documented
   somewhere else in the file.
3. **Refresh the block's state claims at the moment of the handoff**, not when it was first
   drafted. A resume prompt written a few hours earlier will confidently assert next-actions and
   completed work as still accurate, even after the state has moved on. Update it right before the
   clear or compaction happens, not before.

## SESSION_HANDOFF.md and the /handoff command

This harness ships one handoff mechanism, and one file for it: `.project-state/SESSION_HANDOFF.md`,
scaffolded from `templates/project/.project-state/SESSION_HANDOFF.md`.

**`/handoff`** archives the existing `SESSION_HANDOFF.md` (if any) to
`.project-state/handoffs/<YYYY-MM-DD-HHMM>.md`, then writes a new one. The first thing in the new
file is a fenced, copy-pasteable resume block carrying the five things named above, with the file
itself named first in its own read list. Below the block, the file carries a date and tool line, a
one-paragraph summary, the files changed, key commands worth keeping, a single-sentence next step,
and a blockers section that defaults to "None."

The self-sufficiency rule above applies directly to that block: it is only useful if the text
someone pastes out of it can find its own way back to the rest of the file, and to whatever else it
needs to read.

## A worked example

```
RESUME: standing-orders, Phase 5 documentation set

Working directory: ~/projects/your-repo
Launch: claude (no special flags)

Read first, in this order:
1. .project-state/SESSION_HANDOFF.md (this file, read everything below this block)
2. AGENTS.md, section "Session handoff"
3. docs/context-window-management.md
4. templates/phase/CLAUDE.md

Current state:
- Phases 0-4 complete and committed (SHAs bcf1a02, d918e33, 7ff4b40, 22a9c15).
- Phase 5 (documentation) in progress: docs/context-window-management.md
  and docs/handoff-and-resume.md are written and committed at SHA e401b7c.
  Not yet verified against the glyph scanner.
- Nothing else is in flight; everything above is durable on disk.

Next action:
Run the UTF-8-aware glyph scan against both new docs files
(perl -CSD per AGENTS.md "Writing for people outside the team"), fix any hits,
then move to the third documentation file, docs/model-tiers.md, using
config/models.conf and AGENTS.md's "Model tiers" section as sources.

Standing constraints:
- ASCII punctuation only in docs/ content; no em dash, no curly quotes.
- Document only what exists in the repo; do not invent commands or paths.
- Do not touch skills/THIRD_PARTY.md or the vendored Superpowers skills;
  out of scope for this phase.
```

Notice what this example does: it names its own file first in the read list, it gives exact SHAs
rather than "recent commits," it separates what is durable from what still needs a checking step,
and it hands over a next action specific enough to start immediately, no re-deriving required.
