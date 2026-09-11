---
skill: multi-agent-worktree
version: 3.1
when_to_use: subprocess-based parallel agents that require git worktree isolation, long-running child Claude Code processes, code changes across multiple worktrees, or staged pipelines with cross-stage I/O; needs --bypass
when_not_to_use: lightweight Agent-tool fan-out where workers run inline in orchestrator context (use multi-agent-inline); narrow single-agent tasks; tasks touching auth, billing, secrets, production, or deployment
---

# Multi-Agent Worktree Orchestration

## Three modes

This skill covers three modes of `active/multi-agent/launch_agents.sh`:

- **Flat mode (Phase 5C)** — N identical agents in parallel against a slot-based task spec (`## agent-1`, `## agent-2`, …). Same model, same effort, same prompt template per agent. Operator interview asks four questions for global configuration.
- **Multi-role mode, single stage (Phase 6a)** — operator-defined roles, each with its own count, model, effort, and prompt prose. All roles run in parallel in a single batch (no in-runtime fan-in). Task file declares top-level `roles:` under `schema: multi-role`.
- **Multi-role mode, staged (Phase 6b)** — pipelines of stages. Stages run sequentially; roles within a stage run in parallel. Stage N+1 agents can read the outputs of stage 1..N from inside the runtime via per-role `inputs_from:` declarations. Task file uses `stages:` containing nested `roles:`.

The operator chooses by which task file they hand the launch script. The runtime auto-detects shape via the task file's frontmatter and dispatches accordingly. Phase 5C task files (no `schema:` key) keep working unchanged.

## Purpose
Coordinate a real multi-agent run using `active/multi-agent/launch_agents.sh`. The orchestrator interviews the operator for run configuration, invokes the script with explicit flags, uses the script's `--wait` mode to block until completion, reads each agent's outputs, and aggregates into a consensus or chatroom report.

## When to Use
- Operator says "multi-agent", "fan out", "parallel agents"
- Task is separable and aggregatable across N independent worker perspectives
- Benefits from reasoning independence that serial execution cannot provide

## When NOT to Use
- Narrow single-agent tasks
- Tasks touching auth, billing, secrets, production, or deployment (handle single-orchestrator with Level C approval)
- When `consensus` or `chatroom` mode can be simulated serially without real parallel processes

## Pre-launch Operator Interview

Before invoking the launch script, ask the operator these four questions **one at a time**, in order. For each, present a recommended default with short rationale and accept either a direct answer or "default".

### Question 1 — Orchestrator effort
Ask: *"The orchestrator (this session) will aggregate results, write consensus, and verify. What effort should it use? Recommended: **high**. Options: low | medium | high | ultrathink."*

If the operator's current session effort is already set appropriately, note it and ask whether to change. Do not silently override.

### Question 2 — Number of agents
Ask: *"How many agents? Recommended defaults by task shape:*
- *2-way comparison → 2*
- *3-way comparison or research fan-out → 3*
- *High-variance ranking → 5*

*Max: 5. Only exceed 3 if variance reduction clearly justifies the quota draw."*

### Question 3 — Worker model
Ask: *"Which model per worker? Recommended:*
- ***SMALL** — default for fan-out research, small scoped outputs, high volume*
- ***MID** — tasks needing moderate reasoning depth*
- ***FRONTIER-DO** — tasks needing strongest reasoning (rarely needed for workers)*

*Options: FRONTIER-DO | MID | SMALL."*

### Question 4 — Worker effort
Ask: *"Reasoning depth per worker? Recommended:*
- ***low** — short factual outputs*
- ***medium** — default for research briefs*
- ***high** — careful multi-section analysis*
- ***ultrathink** — deep multi-pass reasoning, rarely needed for workers*

*Options: low | medium | high | ultrathink."*

Workers receive this as a prompt-injected directive, since `claude -p` does not have a native effort slider. Each worker interprets the directive.

## Launch Flow

After collecting all four answers:

1. **Write the contract** to `active/contracts/<run-id>.md` documenting:
   - The task
   - All four configuration choices
   - Autonomy level (C — multi-agent with `--bypass` is always Level C)
   - Approval provenance (the operator interview)

2. **Confirm the task spec file exists** at the path the operator provided. If the operator described the task in prose only, generate a task spec file at `active/multi-agent/task-<slug>.md` with per-slot subtasks, confirm it with the operator, then proceed.

3. **Invoke the launch script** non-interactively:
   ```bash
   ./active/multi-agent/launch_agents.sh \
     --task-file <task-spec> \
     --agents <N> \
     --model <model> \
     --worker-effort <level> \
     --bypass \
     --wait
   ```

4. **Always use `--wait`.** Blocks until all agents exit. Avoids scheduled wakeup loops per `rules/learned.md` rule 4.

5. **Always use `--bypass`** for multi-agent runs in this workspace. Policy is in `rules/security.md` Multi-Agent Runtime Policy. The upstream operator interview IS the approval gate when run from Claude Code.

6. **Do not use the Monitor tool for this workflow.** `--wait` replaces it.

## Aggregation Flow

After the launch script returns:

1. Read each `active/multi-agent/agent-<N>/result.md`.
2. Write an aggregation report — typically `active/consensus/<run-id>.md` for ranking tasks, `active/chatroom/<run-id>.md` for tradeoff tasks.
3. Write a run output to `active/runs/<run-id>.md` summarizing launch + aggregation steps.
4. Write a verification report to `active/verification/<run-id>.md` confirming:
   - Launch script actually spawned N processes (check agent logs for evidence)
   - Each `result.md` was authored by its assigned agent (check each agent's branch commit history)
   - Aggregation cites all N inputs
   - Worker effort directive appears in the agent prompts (verifiable in agent logs)
5. Tear down worktrees:
   ```bash
   for dir in active/multi-agent/agent-*; do
     git worktree remove --force "$dir"
   done
   ```

## Output Schema

Close delivery with:

```markdown
## Contract Status
GOAL: pass | fail | partial
CONSTRAINTS: pass | fail | partial
FORMAT: pass | fail | partial
FAILURE: clear | triggered | unverifiable

## Artifacts Written
- active/contracts/<run-id>.md
- active/runs/<run-id>.md
- active/consensus/<run-id>.md (or chatroom)
- active/verification/<run-id>.md

## Memory Updated
yes | no — reason
```

## Autonomy Policy
Multi-agent runs with `--bypass` are always **Level C** per `rules/security.md`. The four-question operator interview IS the operator-approval gate. Do not proceed without explicit operator answers.

## Edge Cases
- **Operator answers "default" for all four** → proceed with recommended defaults for the task shape
- **Operator omits a required answer** → ask again; do not guess
- **One or more agents exit non-zero** → launch script exits non-zero in `--wait` mode; capture exit status in verification report, decide whether partial results are usable
- **Agents fail to write a schema-matching `result.md`** → flag in verification; do not silently patch the missing fields
- **Task spec file missing** → generate one with operator confirmation, then proceed (this is explicitly allowed)

## Multi-Role Mode (Phase 6a)

### When to use multi-role over flat
- Roles need **different models** (e.g., SMALL researchers + FRONTIER-DO synthesizer in the parent session).
- Roles need **different reasoning efforts** in one run.
- Roles need **different prompt prose** that the slot-based "## agent-N" pattern handles awkwardly.
- The operator's task is naturally framed as "X advocates and Y critics" rather than "N peers".

### When to keep using flat mode
- Symmetric fan-out (all agents do the same thing).
- Quick smoke tests against one task type.
- Phase 5C task files in active/multi-agent/ that already work — leave them alone.

### Multi-role task file schema
YAML frontmatter declares roles. Markdown body has per-role subtask sections.

```yaml
---
schema: multi-role
roles:
  - name: advocates
    count: 2
    model: {{TIER_FRONTIER_DO}}
    effort: high
    outputs: [result.md]
    on_failure: continue_with_partial
  - name: critics
    count: 3
    model: {{TIER_SMALL}}
    effort: high
    outputs: [result.md]
    on_failure: continue_with_partial
defaults:
  timeout_seconds: 600
  bypass: true
---
# Task: <prose>

## role: advocates
<operator-authored subtask prose for advocates>

## role: critics
<operator-authored subtask prose for critics>
```

Canonical example: `active/multi-agent/task-multi-role-heterogeneous.md`.

### Multi-role validation rules
- `schema: multi-role` is the only trigger. Typo'd values (`multi-rolez`) are rejected at parse time.
- Role-name pattern: `^[a-z][a-z0-9-]{0,30}$`. Lower-case kebab-case.
- Role names unique within the run.
- Sum of role counts ≤ `MAX_AGENTS_PER_RUN = 5`.
- `model` ∈ {FRONTIER-DO, MID, SMALL}; `effort` ∈ {low, medium, high, ultrathink}; `on_failure` ∈ {abort, continue_with_partial, retry_once}.
- Output filenames are root-relative within the worktree (no `/` allowed).
- `--wait` is mandatory. Detached multi-role runs are rejected.

### Multi-role pre-launch interview (three-tier)
The launch script runs these directly when the task file is multi-role. The orchestrator session does **not** ask the four flat-mode questions in this case. Instead:

- **Tier 1 (always):** "Accept all per-role defaults from the task file? (Y/n)" — Y is the Level C approval gate.
- **Tier 1.5 (only if Tier 1 = N):** Per role: "Override role `<name>` defaults? (y/N)".
- **Tier 2 (only on Tier 1.5 Y per role):** Per-role overrides for count, model, effort. Accept "default" to keep the file's value.

All Q/A are timestamped and captured verbatim in `active/multi-agent/run-<run-id>/operator-interview.md`.

### Override precedence
1. CLI flags (`--model`, `--worker-effort`) — apply uniformly to every role
2. Operator interview Tier 2 — per-role
3. Task-file frontmatter

### Multi-role launch
```bash
./active/multi-agent/launch_agents.sh \
  --task-file active/multi-agent/task-multi-role-heterogeneous.md \
  --bypass \
  --wait
```

`--agents` / `--model` / `--worker-effort` are optional under multi-role (they become uniform overrides if supplied).

### Multi-role aggregation
After the launch script returns:

1. Read each per-role aggregation at `active/multi-agent/run-<run-id>/role-<name>.md`. The launch script writes these uniformly across `count=1` (passthrough wrapper) and `count>1` (structured aggregation with per-agent excerpts).
2. The orchestrator session synthesizes across roles and writes `active/consensus/<run-id>.md` or `active/chatroom/<run-id>.md` if cross-role synthesis is appropriate. The runtime never writes there directly.
3. Write a run output to `active/runs/<run-id>.md` summarizing the launch and the aggregations.
4. Write a verification report to `active/verification/<run-id>.md` confirming:
   - Schema validation succeeded (no errors in stderr from `validate_multi_role.sh`)
   - Per-role agent counts match declared values
   - Branch namespace matches `multi-agent/run-<run-id>/stage-1/<role>-<i>` (the `stage-1/` segment is preserved for Phase 6b additive compatibility)
   - Each declared output is present in each agent's worktree
   - Per-role aggregation files exist for every role
   - Operator-interview answers captured at `active/multi-agent/run-<run-id>/operator-interview.md`
   - chat.md uses the multi-role section format
5. Tear down worktrees:
   ```bash
   for dir in active/multi-agent/agent-*; do
     git worktree remove --force "$dir"
   done
   ```

### chat.md format under multi-role
Under `schema: multi-role`, `chat.md` uses `## role: <name>` headers and `### <role>-<i>` per agent (instead of the flat `## agent-N` format). The format change is scoped to multi-role runs only; Phase 5C task files retain the flat format. Tools that read chat.md by section (e.g., `kill_agents.sh` abort markers) work unchanged.

## Phase 6b — Staged pipelines

### When to use stages
- True fan-in (a synthesizer agent reads parallel-role outputs from inside the runtime).
- Linear pipelines with handoff (researchers → writer → reviewer).
- Specialization at each stage (different models / efforts per stage, including `ultrathink` synthesizer reading `medium`-effort researcher briefs).

### Stages task-file schema
Replace top-level `roles:` with `stages:` containing nested `roles:`. Each stage has a `name`, optional `timeout_seconds` (defaults to `defaults.timeout_seconds`), and a `roles:` list with the same per-role schema as 6a. Roles can declare `inputs_from: [role-name, ...]` to restrict which prior-stage role outputs are surfaced in their prompt.

```yaml
---
schema: multi-role
stages:
  - name: deliberation
    timeout_seconds: 600
    roles:
      - name: advocates
        count: 2
        model: {{TIER_FRONTIER_DO}}
        effort: high
        outputs: [result.md]
        on_failure: continue_with_partial
      - name: critics
        count: 2
        model: {{TIER_SMALL}}
        effort: high
        outputs: [result.md]
        on_failure: continue_with_partial
  - name: synthesis
    timeout_seconds: 900
    roles:
      - name: synthesizer
        count: 1
        model: {{TIER_FRONTIER_DO}}
        effort: ultrathink
        inputs_from: [advocates, critics]
        outputs: [synthesis.md]
        on_failure: abort
defaults:
  timeout_seconds: 600
  bypass: true
---
```

Canonical examples:
- `active/multi-agent/task-pattern-a-fanin.md` — advocates + critics → synthesizer
- `active/multi-agent/task-pattern-b-pipeline.md` — researchers → writer → reviewer

### inputs_from filtering
- `inputs_from:` absent → role's prompt mentions every prior-stage role's output dir (default behavior).
- `inputs_from: [role-name, …]` → only the listed roles' output dirs are mentioned. Useful when a downstream role should not see the outputs of unrelated upstream roles (e.g., a writer that only reads researchers, not critics).
- Validation: each name must reference a role declared in an **earlier** stage. Same-stage and forward references are rejected at parse time.

### Cross-stage I/O
- After a stage completes, the runtime copies each agent's declared `outputs:` (default `[result.md]`) from the agent's worktree to `active/multi-agent/run-<run-id>/stage-<N>-outputs/<role>/<agent-i>/`. A `manifest.md` in that dir records role / agent / exit code / output presence.
- Stage N+1 agent prompts include the absolute path to each prior-stage output dir the role's `inputs_from:` admits. Agents read those paths from inside their own worktree (read-only — they have no write access to other worktrees).
- Stage N+1 agents do **not** see stage N+1's worktrees from siblings.

### Per-stage parallelism cap
`MAX_AGENTS_PER_RUN = 5` is enforced **per stage**, not pipeline-wide. A 3-stage pipeline with 5 agents per stage is fine (15 total agents over time, max 5 parallel at any moment).

### Per-stage failure semantics
Per-role policies (`abort | continue_with_partial | retry_once`) apply within each stage exactly as in 6a. The pipeline-level effect:
- A role with `abort` and any failed agent halts the entire pipeline before stage_collect; downstream stages do not launch; per-role aggregations are skipped; chat.md gets a `[HALTED]` marker citing the stage and role.
- `continue_with_partial` lets the stage finish; downstream stages see whichever outputs were produced (the manifest records absences).
- `retry_once` respawns failed agents in fresh `agent-<role>-<i>-retry/` worktrees once. On retry success, AGENT_DIRS is updated for aggregation. On second failure the pipeline aborts.

### Per-stage timeouts
Each stage has a `timeout_seconds` (or inherits from `defaults.timeout_seconds`). A self-polling watchdog runs alongside the stage's agents; if elapsed time exceeds the timeout, surviving agents are killed and the pipeline halts with a `[TIMEOUT]` marker.

### Branch namespace
- 6a (single implicit stage): `multi-agent/run-<run-id>/stage-1/<role>-<i>`
- 6b (staged): `multi-agent/run-<run-id>/stage-<N>/<role>-<i>` (N matching the 1-indexed stage number)
- 6a `roles:` task files are auto-wrapped into an implicit `stage-1`, so the namespace is identical for both shapes.

## Future Work
- **Restartability** (`--resume <run-id> --from-stage <n>`). Requires run-state persistence so a failed pipeline can resume from the last completed stage. Not yet implemented.
- **Arbitrary DAG.** Stages list covers Pattern A and Pattern B. If a future pattern needs a real DAG (multiple stages feeding the same downstream stage with different fan-out shapes), revisit then.
