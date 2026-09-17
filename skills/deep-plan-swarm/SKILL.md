---
name: deep-plan-swarm
description: The heavy-duty local planning harness for large, multi-area, or high-stakes work — a superset of /deep-plan. Runs advisor pre-flight → a right-fit read-only investigation swarm → FRONTIER-THINK master synthesis into one structured plan → an independent external-LLM review fold-back loop → present for approval. Also merges multiple existing plans into one. Use when the scope spans many files/subsystems, when unexecuted work is scattered, or when a silent planning error is expensive. For a small, single-area plan, use /deep-plan instead. Execution after approval is skill autorun-plan, not this skill.
version: 0.1.0
user-invocable: true
argument-hint: "[what to plan, or the plans to merge]"
tools: Agent, Bash, Read, Grep, Glob, Edit, Write, WebFetch
---

# Deep-Plan-Swarm (local ultraplan harness)

This is the pipeline crystallized from repeated large planning runs. It produces ONE
structured execution plan from a large or contested problem space, with two independent review
layers. It is the superset of `/deep-plan` (which is advisor → Plan → advisor only); reach for
`/deep-plan` when the scope is small and for this when it is not.

Run the whole thing INSIDE plan mode when a plan file is the deliverable, following the plan-mode
5-phase workflow (only the plan file is writable until approval).

## The pipeline

### 0. Orient
Read the request and the on-disk artifacts it names. If merging existing plans, read each in full
plus any investigation reports they cite. Do NOT start substantive synthesis before you know the
current state.

### 0.5 SCOPE GATE — REQUIRED before any investigation (skill `scope-audit`)

**Do not fan out a swarm until you know which surface is alive.** Run skill `scope-audit` and produce
its IN SCOPE / OUT OF SCOPE document first.

**Why this is a hard gate.** A 2,695-line plan from this very harness survived 32 review rounds and
an approval, and roughly **half of it targeted inherited surface the operator had never run** — a
phase to harden a batch runner whose log dir held only a `.gitkeep`, a scanner with no config file,
18 modes nothing referenced. Worse, execution then spent hours hardening a control whose sole purpose
was pausing a component **the plan's own merged sibling existed to retire.**

**Review cannot catch this.** Every requirement was locally well-argued; review asks whether a
requirement is CORRECT, not whether its subject matter is ALIVE. An investigation swarm dispatched
before the scope gate will faithfully map dead surface and produce excellent findings about code
nobody runs.

Carry the scope document into every later stage:
- **the swarm** — do not dispatch a group whose whole subject is out of scope;
- **synthesis** — the planner receives the scope doc and must justify any phase touching dead surface;
- **both review layers** — reviewers are told to test each phase against it.

Also state, in one line each, the **premises** the plan rests on (what must be true for this work to
be needed). Premises rot; naming them makes later falsification detectable instead of invisible.

### 1. Advisor pre-flight (shape the framing)
Call `advisor` with no arguments (it sees the transcript). Use it to surface load-bearing
constraints, missing context the swarm should gather, and the strongest 1-2 alternative framings.
Print its response under `## Advisor pre-flight (framing)`. This is `/deep-plan` Step 1 — reuse it.

### 2. Right-fit investigation swarm (skip or shrink if the material already exists)
Fan out read-only agents to map the problem space. This is the layer `/deep-plan` lacks.

- **Group** the swarm by subject, file-type, or role (e.g. "plans/handoffs", "scripts", "tests/CI",
  "config/assets", "external artifacts"). 10-20 groups for a full audit; 3-5 for a targeted merge
  where investigation already exists.
- **Right-fit each agent's model** — never inherit. Extraction / mechanical mapping → `SMALL`;
  pattern-spotting and most investigation → `MID`; subtle judgment (security, derivation,
  reconciliation) → `FRONTIER-DO`. Dispatch `Explore` (read-only) or an `exec-*` def with an explicit
  `model` per call. The `require-agent-model` hook denies unpinned spawns.
- **Give every swarm member the same output contract** (this is the reusable prompt template):
  > READ-ONLY. Do NOT write/edit any file. Scope: <this group only>. Classify findings:
  > (A) SUPERSEDED/STALE, (B) UNEXECUTED/PLANNED-BUT-UNBUILT (the headline — cite the ask, and grep
  > + git-log to mark SHIPPED / NOT-SHIPPED / UNKNOWN), (C) PLACEHOLDER, (D) KEEP (load-bearing),
  > (E) RISK-if-moved. Every claim carries an absolute path (and line where relevant). Mark
  > CONFIDENCE: low where unsure and say what would resolve it. Hard cap ~180 lines. Your final
  > text IS the report; no preamble, no offer to continue.
- **Synthesize** the reports into a single deduped registry yourself (the swarm's raw reports are
  too big to hand the planner whole). Verify anything load-bearing first-hand — swarm reports
  contain errors; a wrong "safe to delete" has bitten this before.
- Launch groups concurrently (one message, multiple Agent calls). Run the parts you delegated —
  don't also do them inline.

### 3. FRONTIER-THINK master synthesis
Dispatch the `plan-synthesizer` agent (`model: {{TIER_FRONTIER_THINK}}`, max effort) with: the request, the
advisor framing, the synthesized registry (and, when merging, the prior plans + a stated
reconciliation decision). It returns ONE plan in the four-part shape (how-to-execute waves →
workflow-vs-overkill verdict → per-phase model/effort matrix injected inline → the phases) plus an
AUTORUN mission and a verification section. It also bakes the **per-wave execution review stack**
into every code-producing phase's gate per skill `autorun-plan` (tests → `adversary` →
`/ponytail-review` → external-LLM fold-back → re-test → merge). Name `planning_reviewer` and
`execution_reviewer` in the plan (CLI + model); if silent, planning review defaults to **codex**
via skill `external-llm-review`. Print the plan verbatim under `## Plan (FRONTIER-THINK, ULTRATHINK)`;
write it to the plan file.

### 4. Advisor critique (Claude review layer)
Call `advisor` again (it forwards the whole transcript incl. the plan). It critiques: load-bearing
risks missed, unsafe parallelism (are the "parallel" files actually disjoint?), whether the
Workflow-vs-Agent verdict and the model/effort right-fitting are sound. Fold confirmed points in.

### 5. External-LLM review fold-back loop (independent layer)
Invoke the `external-llm-review` skill on the finished plan. **Default CLI: codex.** If the
operator or the draft plan names cursor-agent or gemini for this planning pass, use that
instead; the skill holds all three. Point it at the 2-4 seams most likely to hide a flaw
(for a merge: the merge seams, wave ordering, and any duplicate dropped from the wrong plan).
**Re-verify every finding first-hand**, record a corrections table, apply fixes, and
**re-review until a round returns no new CRITICAL/HIGH findings. There is NO round cap.**
Empty/narration output is a failed round. If rounds stop converging, escalate — the artifact
needs restructuring, not less review.

### 6. Present
ExitPlanMode for approval. Do not execute. The plan's own phases carry the execution-time review
stack (below), so approval-then-execution inherits both review layers again at build time.

## The two review layers (why there are two)

| Layer | When | Who | Catches |
|---|---|---|---|
| Claude adversarial | planning (advisor) + execution (`adversary`) | same family | logic, drift, hidden coupling |
| `/ponytail-review` | execution only (acts on a code diff) | Claude, quality-only | duplication, over-complexity, wrong altitude — NOT bugs |
| External LLM fold-back | planning (the plan) + execution (the diff) | plan-named CLI (default **codex** at planning time) | shared-blind-spot defects the above miss |

`/ponytail-review` is execution-only because it operates on changed code; a plan has none to simplify. The
harness's job is to make the produced plan BAKE `/ponytail-review` into every wave gate (the
`plan-synthesizer` agent does this), so it runs at build time in the right place: after
correctness review, before the external review sees the final diff.

## When to use the Workflow tool instead of Agent subagents
The synthesis names the verdict, but for the SWARM itself: a large homogeneous audit with
deterministic fan-out can run under the Workflow tool; a handful of heterogeneous scoped
investigations run better as parallel Agent calls with synthesis in the main session (what the source
run did). Default to Agent subagents unless the fan-out is large and uniform.

## Calibrate the plan against how execution actually goes

A plan that reads as ~20 tidy workstreams is not a week. Observed on the source run: **one
10-file shell phase the plan called "a cheap gate" took ~3 hours and three adversarial rounds without
closing** — and every round found real blockers, so the cost was legitimate, not waste. Estimates
written at planning time were off by an order of magnitude, and that miscalibration silently sets the
wave order, the nightly scope, and the operator's expectations.

Therefore, in the produced plan:
- **Do not label a gate "cheap."** If it merits a full review stack, budget it like one.
- **Risk-tier the gates explicitly** (full stack for anything that can send, mutate live data, or
  guard those; a lighter gate for prose/docs/read-only surface). An untiered stack spends the same
  hours on a mode-text diff as on a live sender.
- **Size the plan against the operator's real horizon.** Ask what happens to this work if the goal it
  serves ends — a search that succeeds, a migration that ships, a contract that closes. When the
  horizon is weeks, a correct six-month plan is the wrong plan. Order phases so the most value lands
  soonest and the plan degrades gracefully if abandoned halfway.

## Do NOT
- **Do not plan before the scope gate (0.5).** An investigation swarm run first will map dead surface
  beautifully and you will not notice for 32 review rounds.
- Do not skip the external-LLM layer or substitute a Claude reviewer for it (see `external-llm-review`).
- Do not hand the planner 16 raw 180-line reports — synthesize to a registry first.
- Do not let any spawned agent inherit a model; pin every one by name or explicit `model`.
- Do not execute the plan from this skill — it ends at approval. Execution is
  `autorun-plan` / `autorun-plan-orchestrator`.
