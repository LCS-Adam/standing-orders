---
description: Show completion matrix of all phases and tasks
---

Scan every CLAUDE.md and task file in phases/ to build a status matrix.

Output format, one line per phase and one indented line per task, using `[x]` complete,
`[ ]` pending, `[~]` in progress:

```
Phase A: Example                    [0/1] PENDING
  [ ] 01-first-task
...
```

Show total progress at the bottom: X/N tasks complete across all phases.
