# Session Handoff

Overwritten by `/handoff` at the end of each session. Previous handoffs preserved under `handoffs/`.

## Resume block

Copy-pasteable. Must be self-sufficient: name this file first in its own read list, with an
instruction to read everything below it. See `AGENTS.md`, "Session handoff".

```
Where to start: <working directory>, <launch command>

Read first, in this order:
1. .project-state/SESSION_HANDOFF.md (this file, read everything below this block)
2. <other files, in the order they need to be understood>

Current state:
- <what is done, with commit SHAs and verification status>
- <what is still in flight vs. durable on disk>

Next action:
<the specific next step, with enough context to act without re-deriving it>

Standing constraints:
- <decisions already made, exclusions already agreed, open caveats>
```

## Date

<YYYY-MM-DD HH:MM>
Tool: <tool>

## Summary

One paragraph: what this session accomplished.

## Files Changed

(from `git diff --name-only` against the session-start commit)

## Key Commands

Notable commands or workflows the model used. Trim to essentials — this is signal, not transcript.

## Next Step

Single sentence. The very first thing the next session should do.

## Blockers

- None
