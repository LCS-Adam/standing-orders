---
description: Find and present the next incomplete task from phases/
---

Scan all task files in phases/ directories in order. Find the first file with status "IN PROGRESS" or "PENDING" (prefer IN PROGRESS over PENDING).

Present:
1. **Phase:** which phase and its purpose (from the phase CLAUDE.md)
2. **Task:** the task file path and title
3. **Status:** current status
4. **Prerequisites:** what must be complete first
5. **Commands:** the specific commands to run (from the task file)
6. **Context:** any open rows from .project-state/ERRORS.md

If a task is IN PROGRESS, show what's been done and what remains.
