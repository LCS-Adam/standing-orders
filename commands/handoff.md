---
description: Write full session summary before /clear for context preservation
---

Before clearing context, generate a comprehensive handoff document:

1. Read current `docs/checkpoint.md`
2. Read `phases/CLAUDE.md` for phase status
3. Read `docs/open-issues.md` for active issues

Write to `docs/checkpoint.md` (overwrite) with:
- Full session summary (what was accomplished)
- Updated phase status
- Any new decisions or deviations
- Updated open issues
- Exact next step with file path and command
- Resumption instruction

Also append a dated entry to `docs/deployment-log.md` summarizing the session.

Confirm the handoff is written before the operator clears context.
