# Workflow Rules

## Canonical State Machine

```
RECEIVE
  ↓
CONTEXT LOAD
  ↓
TASK CLASSIFICATION
  ↓
AUTONOMY CHECK
  ├─ blocked → ASK / APPROVAL
  └─ safe → continue
  ↓
CONTRACT
  ↓
MODE SELECTION
  ↓
PREPARE INPUTS / AGENTS / TOOLS
  ↓
EXECUTE
  ↓
AGGREGATE
  ↓
VERIFY
  ├─ PASS → MEMORY WRITE
  ├─ ISSUES_FOUND → RESOLVE → RE-VERIFY
  └─ CRITICAL → ESCALATE + RESOLVE
  ↓
RULE UPDATE
  ↓
DELIVER
```

## Mandatory Gates
Never skip: contract creation, mode selection, verification, memory write for substantial tasks.
May skip: full reverse prompting for low-risk scoped work; consensus/chatroom when not needed; browser/video when not needed.

## Autonomy Levels

### Level A — Self-Resolvable
Proceed without asking when:
- task is reversible
- requirements are clear from repo + memory + prior decisions
- risk is low
- no credentials or destructive actions involved

Action: self-disambiguate, state assumptions in the contract, execute.

### Level B — Limited Clarification
Ask when:
- unresolved choices materially change implementation
- choice is not recoverable from context
- work is not destructive

Action: ask 1–5 high-impact questions only. Proceed after answers or documented defaults.

### Level C — Hard Stop
Require explicit operator approval when:
- modifying production systems
- deleting or migrating data
- using unsafe permission bypass flags
- changing auth, billing, secrets, deployment, or security posture
- making high-cost external actions
- legal, compliance, or financial workflows

Action: stop. Present contract + risks + approval request. Wait.

## Reverse Prompting Rule
Use full reverse prompting for: greenfield builds, ambiguous architecture work, broad strategic tasks.
Do not use for: small scoped edits, low-risk reversible refactors, tasks the repo/memory already resolve.

## Routing Matrix

| Task shape | Primary mode | Secondary mode | Main output |
|---|---|---|---|
| ambiguous build | reverse prompting + contract | chatroom or direct | approved contract |
| strategy / ranking | consensus | direct synthesis | consensus_report.md |
| architecture / tradeoff | chatroom | direct synthesis | chatroom_report.md |
| narrow implementation | direct execution | verification | code + tests + summary |
| wide separable build / code-change | `multi-agent-worktree` (git worktrees) | direct + verification | merged artifact set |
| parallel research / audit / multi-slice review | `multi-agent-inline` (Agent tool) | direct synthesis | per-agent verbatim files + synthesis report |
| browser / DOM | Chrome MCP | parallel browser workers | structured data + blocker log |
| video / tutorial | video-to-action | direct execution | extracted_steps.md |
| mixed research + build | chatroom or consensus first | direct execution + verification | architecture + implementation |
| auth / billing / data / deploy | direct or worktree | critical verification | implementation + verification report |

## Coding Mode Split
- Direct execution: single-surface or low-merge tasks
- Worktree / parallel: multi-surface or collision-prone tasks
- Chatroom before code: architecture unsettled
- Consensus before code: option selection matters more than implementation detail

## Memory Write Requirement
Every substantial task writes memory after verification passes.
