---
skill: multi-agent-inline
version: 1.1
when_to_use: parallel Agent-tool sub-agent dispatch where workers run in the orchestrator's context (no subprocess, no worktree), return inline, and persist verbatim outputs to disk; research / audit / multi-slice review / read-only fan-out at N≥3
when_not_to_use: code changes that need isolation (use multi-agent-worktree); single-slice questions (just call Agent once); 2-way comparisons (one synthesis pass is cheaper); tasks touching auth, billing, secrets, production, or deployment
---

# Multi-Agent Inline Orchestration

## Purpose

Parallel sub-agent dispatch via the `Agent` tool, where workers run inline in the orchestrator's context (no subprocess, no worktree), return structured responses, and persist their complete outputs to disk before returning. Use for research, audits, multi-slice reviews, or other read-only fan-out at N≥3.

This is the lightweight sibling of `multi-agent-worktree`. The two skills divide labor by execution model: inline = in-context Agent-tool dispatch; worktree = subprocess + git worktree isolation.

## Sub-agent type

**Always dispatch as `general-purpose`.** Mandatory.

- `general-purpose` has `tools: *` and can call `Write`, satisfying the persistence contract.
- `Explore` is read-only and CANNOT call `Write`. Dispatching this skill via `Explore` will fail the persistence contract for every worker.

If a future Claude Code release narrows the `general-purpose` tool roster, the one-shot pre-flight sanity test (below) catches it on the first dispatch after the upgrade. Fall back to orchestrator-side post-hoc `Write` if the worker contract starts failing.

## Trigger model

### Exact triggers (auto-apply, N≥3 floor)

Apply this skill without asking when any of these match:

- Literal tokens in the prompt: `swarm`, `fan out`, `fanout`.
- `spawn N agents` / `N research workers` / `N parallel agents` where N≥3.
- **3+ explicitly enumerable independent slices in the task body** (e.g., "for each of these 10 files…", "across these 5 dimensions…"). This is the load-bearing trigger most natural to operator language.

### False-positive defenses

- The phrase `in parallel` by itself does **not** auto-trigger. It must co-occur with both (a) a plural worker noun (agents/workers/researchers/sub-agents) **and** (b) a numeric ≥3 or an enumerable list of ≥3 items.
- `spawn N agents` with N≤2 falls through to the soft-trigger path (recommend + ask).

### Soft triggers (recommend + ask with concrete config)

Propose this skill when, but verify with the operator first:

- A single broad research question would naturally split into ≥3 slices to answer.
- Audit/review tasks where cardinality is ambiguous.
- A task has 3+ axes that fit the count window but no lexical signal.

### Catch-all (concrete-question recommendation)

When uncertain, **enumerate the inferred slices and proposed config** (count, model, effort, est_cost_tier) and ask the operator to confirm or adjust. Never open-ended "should we parallelize?" — always a concrete proposal.

## Dynamic config inference

| Axis | Inference rule |
|---|---|
| **count** | Explicit number in prompt → use it. Else count of enumerable independent slices. Else recommend by task shape (3 for narrow research; 5-10 for broad audit; 10-20 for survey-everything). |
| **model** | Read-and-report / file summarization → SMALL. Research with analysis → MID. Reasoning-heavy synthesis → FRONTIER-DO (rare for workers). |
| **effort** | Read/report → low. Multi-section analysis → medium. Reasoning-heavy → high. ultrathink only on operator request. |

**When to ask:** ask only when **count** is non-derivable. Otherwise apply inferred config silently — but always surface count + model + effort in the contract before dispatch.

## Cost surface (load-bearing)

The contract must state count × model × effort BEFORE dispatch lands. 20 MID agents at high effort is real money; the operator must see what they're approving. The contract block must include this line:

```
SWARM CONFIG: count=N model=<m> effort=<e> est_cost_tier=<low|medium|high>
```

`est_cost_tier` is a coarse heuristic: SMALL/low = low; MID/medium = medium; MID/high or FRONTIER-DO/anything = high. Operator can object before dispatch.

## Run-id and paths

**Run-id:** `YYYY-MM-DD_<short-slug>` — matches the canonical convention documented at `CLAUDE.md:71`. Same-day reruns disambiguate via slug suffix (`readme-review`, `readme-review-2`, `readme-review-3`).

**Output path:** `active/swarms/<run-id>/<NN>_<descriptor>.md`
- `NN` is a 2-digit zero-padded sequence number (`01_…`, `02_…`).
- `<descriptor>` is a short kebab-case label assigned by the orchestrator per slice (e.g. `01_audit-measures-dimensions.md`).
- Top-level `active/swarms/` namespace is distinct from `active/multi-agent/` (worktree runs).

**Pre-dispatch directory creation:** the orchestrator runs `mkdir -p active/swarms/<run-id>` immediately before dispatching workers. Workers are not in the business of directory creation.

Skill name (`multi-agent-inline.md`) describes mechanics; directory name (`active/swarms/`) describes deliverable shape. Asymmetry is intentional.

## Pre-flight sanity check (one-shot per harness upgrade)

Before the first dispatch under this skill (or after a Claude Code harness upgrade), dispatch 1 SMALL `general-purpose` Agent to `Write` a short string to `/tmp/write-reach.md`. Confirm the file exists. If this fails, the persistence contract is unreachable for this harness version — halt and fall back to orchestrator-side post-hoc `Write`.

This is a sanity test, not a halt-and-reassess gate for every run. Run it once per harness upgrade.

## Mandatory worker prompt tail

Every sub-agent dispatched under this skill receives this appended tail clause (with `<ORCHESTRATOR-COMPUTED ABSOLUTE PATH>` replaced by the literal absolute path the orchestrator assigned for this worker):

```
PERSISTENCE REQUIREMENT (mandatory before returning):
1. Use the Write tool to save your COMPLETE response as markdown to this absolute path:
   <ORCHESTRATOR-COMPUTED ABSOLUTE PATH>
2. The file must be everything you would have returned inline — no paraphrase, no truncation.
   If you found nothing notable for your assigned slice, write a file with the
   heading "## Finding: none" followed by 2-3 sentences of reasoning about WHY
   the slice was empty. An empty/near-empty file is a contract violation; a
   non-finding written as prose is not.
3. AFTER the Write call returns, obtain the file's actual on-disk byte size for
   the BYTES field. Use ONE of these methods — do NOT estimate from your
   intended content length, and do NOT hand-count characters:
   - Run `stat -f %z <PATH>` (macOS) or `stat -c %s <PATH>` (Linux) via the
     Bash tool, and use the integer it returns, OR
   - Read the file back with the Read tool and use the byte length of the
     returned content.
   The orchestrator cross-checks your BYTES value against the file on disk
   and flags any discrepancy >10%.
4. Return EXACTLY ONE of these structured responses (no other commentary):

   Success case:
   RESULT: written
   PATH: <ABSOLUTE PATH YOU JUST WROTE>
   BYTES: <integer byte size from step 3>
   SUMMARY: <≤2 sentences naming your top finding, or "no findings" with one-clause reason>

   Partial / truncation case (you wrote SOMETHING but had to truncate):
   RESULT: partial
   PATH: <ABSOLUTE PATH YOU JUST WROTE>
   BYTES: <integer byte size from step 3>
   TRUNCATED_REASON: <one-line reason: length cap, missing input, etc.>
   SUMMARY: <≤2 sentences>

   Failure case (Write call failed for any reason):
   RESULT: error
   ERROR: <one-line description>
   INLINE_OUTPUT: <your complete intended response here, as a fallback>
```

**Design notes:**

- The orchestrator passes the **literal absolute path** to each worker. Workers never compute run-id or paths themselves.
- `BYTES` is the file's actual on-disk size, obtained via `stat` or `Read` AFTER the `Write` call returns. v1.0 of this skill left `BYTES` as a self-reported placeholder; observed worker behavior was to estimate from intended content, producing discrepancies up to ~20% against the file on disk. The explicit step 3 closes that gap.
- Three explicit `RESULT` states (`written` / `partial` / `error`) distinguish clean success from truncated success from failure.
- The structured return is mechanically parseable (regex over `RESULT:`, `PATH:`, `BYTES:`).

## Orchestrator post-dispatch verification (mandatory)

Between worker returns and synthesis, the orchestrator must:

1. `ls active/swarms/<run-id>/` — file count == dispatched count?
2. For each expected `NN_<descriptor>.md`: exists, size ≥ 200 bytes, content non-empty.
3. Cross-check each worker's structured return against the file on disk: `BYTES` value within 10% of `stat -f %z` (macOS) / `stat -c %s` (Linux). Mismatch >10% → flag.
4. **On `RESULT: error`** — write the worker's `INLINE_OUTPUT` to `<NN>_<descriptor>_RECONSTRUCTED.md`. Synthesis tags this content with `[reconstructed]` and the verification report flags the failure.
5. **On `RESULT: partial`** — include the worker's output but tag it `[partial: <TRUNCATED_REASON>]` in synthesis.
6. **On missing file with `RESULT: written`** — treat as a worker compliance violation. Same fallback path as `RESULT: error` but flag separately in the verification report.

This converts a discipline-based prompt instruction into a checked artifact contract.

## Synthesis (read-only orchestrator role)

- **Default synthesis path:** `active/research/<run-id>.md`.
- Redirect only when the downstream task shape explicitly requires `active/consensus/` (ranking) or `active/chatroom/` (tradeoff debate).
- Synthesis primarily reads the structured `SUMMARY:` returns from worker responses + selectively reads full files on demand for citations. Most of the context savings land here — not just from worker write-out, but from selective synthesis reads.

## Fallbacks

- **Operator asked for raw results only, no synthesis** → skip synthesis. Confirm in delivery.
- **Operator asked for synthesis but inline persistence wasn't wired** → ask whether to retroactively `Write` worker outputs (from orchestrator context) before synthesizing, or treat outputs as ephemeral and synthesize from inline returns only.
- **Verification step fails for some workers** → proceed with synthesis using `[reconstructed]` / `[partial]` tags; flag in verification report; do NOT silently drop the worker's contribution.

## Teardown / orphan policy

- Successful runs leave their `<run-id>/` directory in place for audit. The synthesis file at `active/research/<run-id>.md` references it.
- **Cancelled or aborted runs:** orchestrator marks the run-id directory with an `_ABORTED` suffix at the moment of cancellation. Quarantine pattern: `active/swarms/_ABORTED/<run-id>/`. Periodic operator cleanup; no auto-deletion.
- **Agent-tool timeout:** if a worker doesn't return, treat as `RESULT: error` with `ERROR: timeout` and proceed via the fallback path (no inline output to reconstruct from — flag prominently in the verification report).

## End-to-end test scenario

Use this scenario to verify the skill's behavior end-to-end after edits land:

1. **Pre-flight sanity check (one-shot):** see above.
2. **Trigger test:** issue *"Spawn 3 agents to summarize each of `.claude/rules/workflow.md`, `.claude/rules/security.md`, `.claude/skills/multi-agent-worktree.md` — 2-paragraph plain summary each."*
3. **Verify expected outcomes:**
   - Skill `multi-agent-inline` is selected (not `multi-agent-worktree`).
   - Trigger detected via "3 agents" numeric + 3 enumerable slices.
   - Dynamic config: N=3, model=SMALL, effort=low. `SWARM CONFIG:` line in contract.
   - Run-id: `YYYY-MM-DD_<slug>`.
   - 3 Agent dispatches in a single tool-use message; sub-agent type `general-purpose`; each prompt contains literal absolute output path.
   - 3 verbatim files at `active/swarms/<run-id>/01_<slug>.md`, `02_<slug>.md`, `03_<slug>.md`.
   - Post-dispatch verification: file count == 3; byte floor ≥ 200B; `BYTES` cross-check within 10%.
   - Workers return structured response.
   - Synthesis at `active/research/<run-id>.md`.
   - Contract / run / verification artifacts at canonical paths.
4. **Negative test:** *"compare workflow.md vs security.md side-by-side"* — must NOT auto-trigger (2-way, below N≥3 floor).
5. **False-positive defense:** *"let's review these 2 files in parallel"* — must NOT auto-trigger (numeric=2 fails the ≥3 guard).
6. **Compliance-failure test:** dispatch one worker WITHOUT the persistence-tail clause; verify the orchestrator flags the missing file, writes inline output to `_RECONSTRUCTED.md`, and synthesis tags it `[reconstructed]`.
