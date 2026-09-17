---
skill: chatroom
version: 1.0
when_to_use: architecture decisions, contested tradeoffs, principle-driven design
when_not_to_use: simple tasks, option ranking without tradeoffs, narrow implementation
---

# Chatroom Mode

## Purpose
Simulate structured deliberation between distinct perspectives.
Use when tradeoffs matter and competing principles need synthesis before implementation.

## When to Use
- architecture is contested
- multiple valid design principles conflict
- tradeoffs need explicit surface area before committing
- a decision requires deliberate disagreement to reach a robust recommendation

## When NOT to Use
- simple tasks
- ranking without principle conflicts (use consensus instead)
- narrow implementation where the approach is clear

## Default Configuration
- 3 roles: Architect, Pragmatist, Critic
- 2 rounds (optionally 3 for complex systems)

## Roles

### Architect
Focuses on: long-term scalability, clean design, structural integrity.
Asks: will this hold under growth and change?

### Pragmatist
Focuses on: delivery speed, operational simplicity, team capability.
Asks: can we build and run this with what we have?

### Critic
Focuses on: failure modes, edge cases, hidden assumptions, risks.
Asks: what breaks, what was missed, what is being oversimplified?

## Process

### Round 1
Each role states their position independently.

### Round 2
Each role responds to the others, defends or concedes, and refines their position.

### Round 3 (optional)
Synthesis round — resolve remaining disagreements and produce a unified recommendation.

### Synthesis
Orchestrator synthesizes all rounds into a final report.

## Output Schema

```markdown
## Chatroom Report

Participants: Architect, Pragmatist, Critic
Rounds: [2 | 3]

Round 1:
- Architect: [position]
- Pragmatist: [position]
- Critic: [position]

Round 2:
- Architect: [response]
- Pragmatist: [response]
- Critic: [response]

Agreements:
- [point]

Disagreements:
- [point]

Recommended Architecture:
- [recommendation]

Unresolved Risks:
- [risk]
```

Write to `active/chatroom/<run-id>.md`, where the run id is dated and slugged, for example
`2026-06-18_queue-vs-cron.md`. A fixed filename cannot hold two runs, and the second one silently
overwrites the first.

## Edge Cases
- if all roles immediately agree, the problem may be underdefined — revisit the question
- if no agreement is reachable after 3 rounds, escalate to the operator with explicit options
- the Critic must surface at least one risk even on strong proposals
