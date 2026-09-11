---
skill: chrome-mcp
version: 1.0
when_to_use: deterministic browser access, JS-rendered pages, DOM extraction, browser automation
when_not_to_use: static content already in context, tasks solvable without rendering
---

# Chrome MCP Mode

## Purpose
Use Chrome DevTools MCP for tasks that require rendered browser state.
Never use this mode when static text already provides the needed information.

## When to Use
- data only available after JavaScript rendering
- DOM extraction or interaction
- browser workflow automation
- scraping across multiple pages

## When NOT to Use
- static text or API responses already provide the content
- the task is solvable without a real browser
- the page state must be inferred or guessed — never hallucinate unseen state

## Process

### Step 1 — Define target set
List all URLs or page targets before spawning workers.

### Step 2 — Assign workers
Each browser worker operates on its assigned target set only.
Workers write results to their section in `active/multi-agent/chat.md`. Section semantics differ by mode: flat-mode runs (Phase 5C) use one `## agent-<N>` section per worker; multi-role runs (Phase 6a, `schema: multi-role`) use `### <role>-<i>` sub-sections under a `## role: <name>` parent header.

### Step 3 — Execute
Navigate, interact, and extract only visible and deterministically retrievable data.

### Step 4 — Log blockers
Use explicit blocker tags for any blocked or inaccessible content.
Never fabricate unseen page state.

### Step 5 — Aggregate
Collect all worker outputs.
Produce structured output + blocker log.

## Chat Protocol Tags
- `[INIT]` — worker initialized
- `[WORKING]` — task in progress
- `[DONE]` — task complete
- `[ERROR]` — error encountered
- `[WAITING]` — blocked, waiting
- `[ABORT]` — task aborted

## Output Schema

```markdown
## Browser Extraction Report

Target: [URL or target set]
Worker count:
Mode: single | parallel

Results:
- [structured extracted data]

Blockers:
- [URL]: [reason blocked]

Notes:
- [any ambiguity or partial extraction]
```

Write to the relevant section of `active/multi-agent/chat.md` during execution.
Write final aggregated output to a named file in `active/runs/`.

## Rules
- only capture visible or deterministically retrievable data
- log every blocker explicitly
- never hallucinate unseen page state
- keep extracted outputs structured, not narrative
- per-agent sections must not overlap in `chat.md`

## MCP Setup Reference
```bash
claude mcp add chrome-devtools -- npx chrome-devtools-mcp
```
Verify: `claude mcp list`

Status: Phase 5 (not yet configured in this workspace)
