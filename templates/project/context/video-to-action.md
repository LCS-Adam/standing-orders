---
skill: video-to-action
version: 1.0
when_to_use: workflow exists only in video or UI demo, multimodal analysis required
when_not_to_use: workflow is documented in text, static screenshots sufficient
---

# Video-to-Action Mode

## Purpose
Convert observed video or UI demonstrations into executable, ordered instructions.
Use when the only available workflow documentation is a recording or live demo.

## When to Use
- a workflow exists only as a video recording or screen demo
- multimodal analysis is required to extract steps
- the system must convert observed actions into runnable instructions

## When NOT to Use
- the workflow is already documented in text or code
- static screenshots are sufficient
- the video is supplementary to written docs

## Process

### Step 1 — Ingest the video or demo
Use Gemini or equivalent multimodal tooling to analyze the recording.

### Step 2 — Extract ordered steps
Identify each distinct user action in sequence.
Note tool, UI element, or command for each step.

### Step 3 — Map to commands
For each step, produce:
- the tool or application involved
- the exact action (click, type, run, navigate)
- the expected output or state change
- any ambiguity that could not be resolved from the video

### Step 4 — Write report
Write to `active/video-to-action/extracted_steps.md`.

## Output Schema

```markdown
## Video-to-Action Report

Source: [video filename or URL]
Analyzed with: [Gemini | other]

Steps:
1. Tool: [tool]
   Action: [exact action]
   Expected output: [what should happen]
   Ambiguity: [none | describe]

2. ...

Required tools:
- [tool 1]
- [tool 2]

Open ambiguities:
- [step N]: [what could not be determined]
```

## Rules
- steps must be ordered exactly as observed
- ambiguities must be noted, not silently resolved
- do not infer steps that were not visible in the video
- if a step is unclear, mark it with an ambiguity note and ask the operator

## MCP Setup Reference
```bash
claude mcp add gemini -- gemini-mcp-server
```
Verify: `claude mcp list`

Status: Phase 5 (not yet configured in this workspace)
