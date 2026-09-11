---
description: Show completion matrix of all phases and tasks
---

Scan every CLAUDE.md and task file in phases/ to build a status matrix.

Output format:
```
Phase A: Account Hardening          [5/5] ✅ COMPLETE
  ├── 01-create-service-account     ✅
  ├── 02-secure-launchdaemons       ✅
  ├── 03-verify-os-security         ✅
  ├── 04-switch-to-service-account  ✅
  └── 05-install-nvm-node           ✅

Phase B: Container Infrastructure   [3/4] ⏳ IN PROGRESS
  ├── 01-install-orbstack           ✅
  ├── 02-verify-docker-context      ✅
  ├── 03-test-isolation             ✅
  └── 04-build-sandbox-image        ⏳
...
```

Show total progress at the bottom: X/N tasks complete across all phases.
