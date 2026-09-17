---
skill: consensus
version: 1.0
when_to_use: strategy, ranking, option comparison, hallucination-sensitive research
when_not_to_use: narrow implementation, architecture debate, tasks needing one coherent answer
---

# Consensus Mode

## Purpose
Generate multiple independent views on a question, then synthesize agreement and divergence.
Use when the quality of a decision benefits from independent perspectives rather than one direct answer.

## When to Use
- strategic decisions
- comparative rankings
- research where hallucination risk is high
- option selection where multiple valid answers exist

## When NOT to Use
- narrow well-defined implementation tasks
- architecture tradeoffs (use chatroom instead)
- tasks where one coherent perspective is more valuable than many

## Default Configuration
- 5 workers for normal tasks
- up to 10 for high-variance strategy work

## Process

### Step 1 — Define the question
State the question clearly. Include the decision criteria.

### Step 2 — Assign independent workers
Each worker reasons independently. Workers must not see each other's outputs during generation.

### Step 3 — Collect outputs
Collect all worker outputs before synthesis.

### Step 4 — Synthesize
Identify:
- consensus findings (majority agreement)
- divergences (meaningful disagreement)
- outliers (minority positions with signal)
- recommendation
- confidence notes

### Step 5 — Write report
Write to `active/consensus/<run-id>.md`, where the run id is dated and slugged, for example
`2026-06-24_cache-strategy.md`. A fixed filename cannot hold two runs, and the second one silently
overwrites the first.

## Output Schema

```markdown
## Consensus Report

Problem:
Agent count:
Schema used:

Consensus:
- [finding 1]
- [finding 2]

Divergences:
- [point of disagreement]

Outliers:
- [minority position worth noting]

Recommendation:
- [synthesized recommendation]

Confidence:
- [high | medium | low] — [reason]
```

## Edge Cases
- if all workers agree, note it and verify it is not groupthink
- if divergence is very high, escalate to chatroom mode for deliberate debate
- always include divergences even when there is a clear majority
