---
description: Generate a structured session checkpoint to docs/checkpoint.md
---

Read the current state from:
- `phases/CLAUDE.md` (phase status index)
- `docs/deployment-log.md` (completed work)
- `docs/open-issues.md` (active issues)

Generate a checkpoint at `docs/checkpoint.md` with:
1. Timestamp (today's date)
2. Active phase and step
3. Last completed step
4. Steps completed this session (from conversation context)
5. Steps completed in prior sessions (from deployment-log)
6. Branch decisions made
7. Open issues / flags
8. Confirmed system paths
9. Next step instruction
10. Resumption instruction for new sessions

Use the same format as the existing checkpoint.md.
