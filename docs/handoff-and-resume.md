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

Here is the failure this rule is drawn from. A resume file contained the pasted-prompt block at the
top, and below it, a long section holding everything the next session would need: state details,
file inventories, open questions. The block itself named four files to read first. It did not name
the file it was sitting in. Pasting that block exactly as designed would have orphaned the entire
lower half of the document, because nothing in the pasted text told the next session that more
detail existed just below it, in the same file.

The fix is that the block must name its own file in its own read list. This matters most exactly
when the prompt and the supporting detail live in the same file, because that co-location is
precisely what makes the omission easy to miss. When you are looking at one file with the prompt
at the top and the detail right below it, it feels redundant to tell the block to read the file it
is already inside. It is not redundant. The block is the only part that travels; if it does not
carry its own location, the location is lost.

## The three-step check before declaring a handoff done

Before treating a handoff as finished, run through three checks:

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

## SESSION_HANDOFF.md, and the /handoff and /checkpoint commands

This harness ships a template at `templates/project/.project-state/SESSION_HANDOFF.md`. It is a
short, fixed-shape file: a date and tool line, a one-paragraph summary, a list of files changed, key
commands worth keeping, a single-sentence next step, and a blockers section that defaults to
"None." Its comment says it is meant to be overwritten at the end of each session, with prior
handoffs preserved under a `handoffs/` directory.

The repository also ships two slash commands that write a related but differently-shaped
checkpoint file, `docs/checkpoint.md`:

- **`/checkpoint`** reads the current state from `phases/CLAUDE.md` (the phase status index),
  `docs/deployment-log.md` (completed work), and `docs/open-issues.md` (active issues), then writes
  `docs/checkpoint.md` with a timestamp, the active phase and step, the last completed step, what
  was done this session versus prior sessions, branch decisions, open issues, confirmed system
  paths, and a next-step and resumption instruction.
- **`/handoff`** does the same reads as `/checkpoint`, plus `docs/open-issues.md`, and overwrites
  `docs/checkpoint.md` with a fuller version: a full session summary, updated phase status, any new
  decisions or deviations, updated open issues, an exact next step with file path and command, and
  a resumption instruction. It also appends a dated entry to `docs/deployment-log.md` summarizing
  the session, and confirms the handoff is written before the operator clears context.

In short: `/checkpoint` is the lighter, structured status snapshot: `/handoff` is the fuller version
meant to run right before a `/clear`, and it also logs the session to the deployment log so the
history is not lost even after `docs/checkpoint.md` gets overwritten again next time.

Whichever mechanism a project uses, the self-sufficiency rule above still applies. A checkpoint or
handoff file is only useful if the block someone pastes out of it can find its own way back to the
rest of the file, and to whatever else it needs to read.

## A worked example

```
RESUME: agent-harness, Phase 5 documentation set

Working directory: /Users/adamlindsey/projects/agent-harness
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
