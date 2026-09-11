---
skill: prompt-contracts
version: 1.0
when_to_use: every substantial task
when_not_to_use: trivial one-line edits with no ambiguity
---

# Prompt Contracts

## Purpose
A contract makes task expectations explicit before execution begins.
It prevents scope drift, reduces rework, and gives verification a clear standard.

## When to Use
Use a contract for every substantial task.
For trivial edits, use an inline one-line statement of intent instead.

## Full Contract Schema

```markdown
## Contract

GOAL:
- measurable desired outcome

CONSTRAINTS:
- hard limits
- required or forbidden technologies
- scope boundaries

FORMAT:
- exact deliverables
- files, reports, artifacts, or output schema

FAILURE (any = not done):
- explicit failure conditions
- security or correctness failures
- missing tests or validations
- missing edge-case handling

ASSUMPTIONS:
- only include assumptions not confirmed by the operator

RISK LEVEL:
- low | medium | high | critical

APPROVAL MODE:
- self-executable | operator-confirmation-required

VERIFICATION LEVEL:
- standard | critical
```

## Minimal Contract Variant
For small but non-trivial tasks:

```markdown
GOAL:
CONSTRAINTS:
FORMAT:
FAILURE:
```

## Contract Status Format
Every delivery reports:

```markdown
## Contract Status
GOAL: pass | fail | partial
CONSTRAINTS: pass | fail | partial
FORMAT: pass | fail | partial
FAILURE: clear | triggered | unverifiable

Notes:
- what was verified
- what remains uncertain
```

## Rules
- define the contract before implementation begins
- do not ask questions the repo, memory, or contract already answer
- state assumptions explicitly rather than silently embedding them
- the contract is the verification standard — the reviewer checks against it
