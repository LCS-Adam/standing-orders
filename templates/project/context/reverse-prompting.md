---
skill: reverse-prompting
version: 1.0
when_to_use: greenfield builds, ambiguous architecture, broad strategic tasks
when_not_to_use: small scoped edits, low-risk refactors, tasks the repo already resolves
---

# Reverse Prompting

## Purpose
Reverse prompting surfaces unresolved assumptions before implementation.
Use it when incorrect assumptions would be expensive to undo.

## When to Use
- greenfield builds with no prior architecture
- ambiguous architecture decisions
- broad strategic tasks with multiple valid paths
- tasks where the operator's intent is unclear from context

## When NOT to Use
- small scoped edits
- low-risk reversible refactors
- tasks where the repository and memory already resolve the ambiguity
- trivial formatting or style changes

## Process

### Step 1 — Read the request
Identify what is explicitly stated vs what must be assumed.

### Step 2 — Draft the contract
Write a draft contract with GOAL, CONSTRAINTS, FORMAT, and FAILURE.
Mark any assumption that is not operator-confirmed.

### Step 3 — Generate clarifying questions
Produce only the questions that:
- materially change the implementation if answered differently
- cannot be resolved from repo context, memory, or prior decisions

Maximum: 5 questions. Ask fewer if fewer are needed.

### Step 4 — Present and wait
Present the draft contract and questions.
Wait for operator input before executing.

### Step 5 — Finalize and proceed
Update the contract with operator answers.
Proceed under Level A autonomy for remaining low-risk assumptions.

## Output Schema

```markdown
## Draft Contract
[GOAL, CONSTRAINTS, FORMAT, FAILURE, ASSUMPTIONS]

## Clarifying Questions
1. [high-impact question]
2. [high-impact question]
...
```

## Edge Cases
- if the operator declines to answer, document the default assumption and proceed
- if answers reveal a scope change, revise the contract before executing
- never force five questions when fewer resolve the ambiguity
