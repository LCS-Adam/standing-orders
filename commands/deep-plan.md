---
description: Local deep planning — advisor (shape) → Plan subagent (FRONTIER-THINK, ULTRATHINK MAX EFFORT) → advisor (critique). Always emits a multi-step EXECUTION plan carrying operator directives (HOW to execute: parallelize + worktree isolation + review gates), an explicit Workflow-vs-overkill judgment, and a per-phase model/effort matrix injected inline into every phase heading. Local substitute for cloud /ultraplan.
allowed-tools: Agent, advisor, Read, Bash, Grep, Glob, WebFetch, WebSearch
---

**Step 1 — Pre-flight advisor (shape the approach).** Before dispatching Plan, call the `advisor` tool with no arguments. The advisor sees the full transcript including the user's `$ARGUMENTS`. Its job here is to shape the framing: surface load-bearing constraints, flag missing context the Plan subagent should be told to gather, and name the strongest 1–2 alternative framings worth Plan considering. When it returns, print a header `## Advisor pre-flight (framing)` and emit its response verbatim.

The advisor tool itself notes that it adds most value on the first call, before the approach crystallizes — that is exactly the role of this pre-flight pass.

**Step 2 — Dispatch the Plan subagent.** Call the Agent tool with:

- `subagent_type: "Plan"`
- `model: {{TIER_FRONTIER_THINK}}` — the FRONTIER tier's *thinking* occupant, which is the right half of that tier for planning and synthesis (see the "Model tiers" section of `~/.claude/rules/00-harness-core.md`; rebind in the harness repo's `config/models.conf`, not here, when a release moves the tier). Do NOT omit it — without it the subagent inherits the parent model and the frontier guarantee is lost.
- `description: "Deep plan: $ARGUMENTS"` (truncate to ~5 words)
- `prompt:` the directive below, prepended verbatim, followed by the user's request, followed by the advisor's pre-flight framing.

Directive (prepend verbatim):

> ULTRATHINK MAX EFFORT — apply maximum reasoning depth. Read deeply, consider edge cases, challenge assumptions, surface load-bearing tradeoffs, and propose at least two viable alternatives before settling on a recommendation. Produce a plan as thorough as a cloud-based ultraplan would, but fully local using only this session's context and on-disk artifacts. Cite absolute file paths for every reference. End with concrete next-step commands the operator can execute. A pre-flight advisor pass is included below — weigh its framing, but do not treat it as binding; if your analysis diverges, say so explicitly and justify.
>
> The output must be a MULTI-STEP EXECUTION PLAN, not a design essay. It MUST contain the following four parts, in this order:
>
> **1. How to execute (operator directives).** A dedicated top section that decides HOW the work runs, not just what it is:
>
> - **Parallelize vs. sequential.** Determine whether the work should run as multiple workstreams in parallel or as an ordered sequence. If parallel, give dependency-ordered WAVES: which workstreams run together, what each waits on, and what merges first to freeze any shared contract/interface. Land the shared contract FIRST, then fan out.
> - **Isolation.** When workstreams mutate files concurrently, isolate each in its own git worktree (a feature branch per workstream). State it explicitly, and note which files each workstream owns so parallel work is verifiably conflict-free.
> - **Review gates.** Feature branch → PR → CI → merge. Gate minimalism is a dial, not a default: state the plan's chosen position on that dial explicitly rather than assuming a hard stop between every phase or wave. A gate belongs wherever the pass/fail rule cannot be stated in advance and needs live judgment, the action reaches a person outside the system, the action is irreversible and lacks a tested rollback, or it requires physical human action; everything else can auto-proceed on a stated rule. Call out where the operator must confirm before any irreversible or outward-facing action regardless of the dial's position.
>
> **2. Workflows-vs-overkill judgment (REQUIRED, explicit).** Decide whether to orchestrate the build with the multi-agent **Workflow** tool or with plain parallel **Agent** subagents, and STATE the verdict with a one-line reason, using these criteria:
>
> - Fan-out over MANY homogeneous items + deterministic control flow (loops, conditionals, dedup, verify passes, loop-until-dry) → **Workflow tool**; sketch the script shape (phases, what fans out, what verifies).
> - A HANDFUL of heterogeneous, bespoke tasks (each a deep one-off implementation) → **parallel Agent subagents with worktree isolation**; the orchestration gates (tests, code-review, PR, merge order) stay in the main session, and subagents implement + commit only.
> - Trivial or inherently single-threaded → **inline, no orchestration**.
>   Name the verdict plainly ("Workflow tool warranted" / "Workflow overkill — use N parallel Agent subagents" / "inline"). This judgment is mandatory even when the answer is "overkill."
>
> **3. Phase model/effort matrix (REQUIRED ALWAYS — even when Workflow orchestration is skipped).** Right-fit each phase/workstream to its cognitive load:
>
> Name the TIER, not a model — the "Model tiers" section of `~/.claude/rules/00-harness-core.md` defines the tiers and the harness repo's `config/models.conf` binds them to current models, so a plan written this way survives a release. Resolve tier to model at dispatch time by reading that binding.
>
> - **FRONTIER** + high–max effort for correctness-critical foundations, subtle logic, and high-stakes or irreversible/outward-facing actions. Within the tier, prefer its *thinking* occupant for analysis and design and its *doing/breaking* occupant for implementation and adversarial review.
> - **MID** + medium effort for well-bounded or mostly-mechanical work.
> - **SMALL** + low–medium effort for high-volume, low-reasoning work a test can prove.
> - **FRONTIER**, high effort, for adversarial verify passes — a reviewer sits at or above the tier that produced the work.
>   Present it as a table (phase → model → effort → rationale) AND — this is load-bearing — inject the model+effort INLINE into every phase's own heading/description so the setting travels with the phase if it is lifted out of context. Mirror the Workflow `meta.phases: [{title, detail}]` shape: a heading like `Phase 1 — Data contract [model: FRONTIER-DO, effort: high]` plus a one-line detail. Do this in BOTH branches — as `meta.phases` + per-`agent()` `model`/`effort` when the Workflow tool is used, and as annotated Agent-dispatch headings when it is skipped.
>
> **4. The phases themselves.** Ordered and numbered, each with concrete absolute file paths, the specific edits/creations, the traps to avoid, per-phase tests/verification, and next-step commands. Each phase heading carries its `[model: …, effort: …]` annotation from the matrix.

User request: $ARGUMENTS

Pre-flight advisor framing (from Step 1, verbatim):
<paste the advisor's Step 1 response here>

Note on effort: the Agent tool has no `effort` parameter. For the Plan subagent itself, MAX EFFORT is carried entirely by the directive above. The `model`/`effort` values the plan assigns to each phase are directives for the EXECUTION agents that implement each phase later, not for the Plan subagent — and they are honored differently per path: via a prompt directive plus the `model` choice when a phase runs as an **Agent** subagent (the Agent tool takes `model` but no `effort`, so "high/max effort" rides in the agent's prompt), or via a real per-call `agent({model, effort})` when a phase runs under the **Workflow** tool. The `model` parameter itself takes the literal alias that `config/models.conf` binds a tier to, never a tier name; the tier-token placeholders in shipped agent definitions resolve to that literal alias at install time. Tier names (`FRONTIER-DO`, `FRONTIER-THINK`, `MID`, `SMALL`) are for prose only, including this plan.

**Step 3 — Surface the plan verbatim.** When the Plan subagent returns, print a header naming the model you actually dispatched — `## Plan (FRONTIER-THINK, ULTRATHINK)` for the default above — and emit the plan exactly as returned. Do not paraphrase, summarize, or reorder. Confirm it carries all four required parts (How-to-execute, Workflow-vs-overkill judgment, model/effort matrix with inline per-phase annotations, the phases); if any is missing, send the Plan subagent one follow-up to add it rather than patching it yourself.

**Step 4 — Post-Plan advisor (critique).** Call the `advisor` tool a second time with no arguments. It automatically forwards the entire transcript (including the pre-flight pass, the plan, and any divergence the Plan subagent flagged). Its job here is critique: load-bearing risks the plan missed, unstated assumptions, cheaper alternatives, whether the parallelization is actually safe (disjoint files? real dependencies masked as parallel?), whether the Workflow-vs-Agent verdict and the model/effort right-fitting are sound, and explicit reconciliation against the pre-flight framing. When it returns, print a header `## Advisor critique (post-Plan)` and emit its response verbatim.

**Step 5 — Present next steps.** Append exactly:

---

**Next steps:**

1. Proceed with the plan as written.
2. Apply the advisor's recommended changes, then proceed.
3. Edit a specific section — tell me which.
4. Refine with `/deep-plan` — e.g., `/deep-plan refine option 2 with more depth` or `/deep-plan rescope to focus on phase 1 only`.
5. Discard and start over.

If either the plan or either advisor pass suggests writes, ask the user for explicit confirmation before any tool use beyond reading.
