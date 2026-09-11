# Autonomous Build-Loop — orchestrator-led, advisor-gated, decisions-bubble-up

**Purpose.** Keep the build plan moving every session with maximum end-result quality, by having ONE
orchestrator decompose the next plan increment, fan out parallel sub-agents to build + test as much as
possible, and **decide the next step from structured results** — gating the operator only at true
Level-C boundaries and genuine decision forks, never for routine progress. This codifies the method that
built the v1 enforcer spine on 2026-06-29 (`active/{contracts,runs,verification,swarms}/2026-06-29_omni-enforcer-spine-v1*`).

**Standing instruction.** At the start of each session working a phased build plan, apply this loop by
default. It is the operating mode, not a one-off.

---

## Core principles (each ties to a learned rule)

1. **One orchestrator; decisions bubble UP.** Sub-agents and phases return *structured verdicts +
   artifacts*; the orchestrator decides the next move from them. Do NOT prompt the operator for anything
   the orchestrator can resolve from the plan + repo + results. The operator is gated only at (a) Level-C
   hard stops (`rules/security.md`), (b) genuine Level-B forks that materially change the outcome and
   aren't resolvable from context. Everything else: decide, act, report the decision.

2. **Contract-first — kill the seam before fanning out (rule #30).** The orchestrator builds the FROZEN
   integration contract INLINE first: file/dir layout, message/data schemas (closed enums), the *pinned
   internal interfaces* between work units, shared libs, conventions, and the acceptance categorization.
   Parallelizing before this exists guarantees integration backtracking (agents invent incompatible
   schemas/paths/log-formats). Run a dependency-ordering pass: which unit NEEDS what another BUILDS.

3. **Right-size + isolate the fan-out (rules #19/#29).** Emit a `SWARM CONFIG: count=N model=<m> effort=<e>
   est_cost_tier=<…>` line before any dispatch, per-unit (read/mechanical → SMALL; research/analysis →
   MID; reasoning/critique/security → FRONTIER-DO). Each agent owns a DISJOINT work unit (no two touch the same
   file). Persist each worker's verbatim to `active/swarms/<run-id>/` and write code to disk; the
   orchestrator synthesizes FROM DISK, not re-held context (headroom). Give concurrent test runs isolated
   state (e.g. an overridable `RUN_DIR`) so they don't race.

4. **Machine-checkable acceptance only (rule #27).** Every acceptance is a script that asserts and exits
   non-zero on failure — never a model-self-reported "green." Categorize each check honestly: **REAL-now**
   vs **MODELED** vs **DEFERRED-to-a-gate** (needs a privilege/resource the build env lacks). A MODELED
   check must never masquerade as a boundary proof. Verification scripts that ship UNEXECUTED by
   construction (operator-runs-later) must still be syntax-gated + body-flow-smoked in the build (rule #31).

5. **Adversarial gate before done.** An independent reviewer tries to REFUTE the result against the design's
   invariants — not rubber-stamp it. Fix every blocking finding and PROVE the fix by reproducing the attack
   as a regression test. Then the advisor (or a stand-in sub-agent per the advisor-fallback rule).

6. **Stay inside the authorized blast radius.** Build and validate everything reversible (`/tmp`, throwaway
   repos, `--dry-run`, modeled targets) autonomously, as far as the plan allows. At the Level-C execution
   boundary, STOP and hand the operator a tight decision: contract + residual risks + the machine-checkable
   evidence + a recommendation — ONE decision, not a prompt-per-step.

7. **Persist + update rules.** Write the contract/run/verification triple + swarm verbatim every time files
   change. Append a learned rule when a generalizable lesson emerged. Write/refresh the session handoff +
   resume prompt before any clear.

---

## The session loop (state machine)

```
ORIENT  → ADVISOR(shape) → DECOMPOSE(contract) → FAN-OUT(build) → INTEGRATE+VERIFY → REVIEW(adversarial) → DECIDE → PERSIST
   │                                                                                                          │
   └──────────────────────────────── operator gated ONLY at Level-C forks ◄───────────────────────────────────┘
```

- **ORIENT** — read the plan + `.project-state` + the named read-first docs. Identify the next increment
  and its gate level. Reconcile what's already done (don't rebuild).
- **ADVISOR (shape)** — before substantive work, sanity-check the decomposition/approach + the gate read.
- **DECOMPOSE** — write the frozen contract (principle 2) inline. This is the orchestrator's own work.
- **FAN-OUT** — parallel builders on disjoint units (principle 3), each producing artifacts + a verbatim report.
- **INTEGRATE + VERIFY** — assemble from disk; run machine-checkable acceptance; categorize honestly; write
  the real cross-unit integration test the per-unit tests stubbed.
- **REVIEW** — adversarial refute → fix-and-prove → advisor gate (principle 5).
- **DECIDE** — from the structured results, the orchestrator picks the next step. Within the authorized
  radius → continue the loop on the next increment. Level-C / genuine fork → surface ONE decision to the
  operator with evidence + recommendation.
- **PERSIST** — triple + rule update + handoff/resume.

## When to gate the operator (the ONLY times)
- **Level-C** (`rules/security.md`): production, auth, billing, secrets, deploy, irreversible, external cost.
- **Genuine Level-B fork**: a choice that materially changes the outcome and isn't resolvable from context.
- Otherwise: **decide and proceed; report the decision, do not ask.** Prefer `AskUserQuestion` only for a
  real fork; never to confirm routine progress. (Honor any per-task operator preference to the contrary.)

---

## Copy-pasteable session-start prompt

Paste this (or have the resume prompt embed it) to put a fresh session into the loop:

> You are the single orchestrator for this build. Apply the Autonomous Build-Loop
> (`knowledge/autonomous-build-loop.md`). Steps: (1) ORIENT — read the active plan + `.project-state` +
> its read-first docs; state the next increment and its gate level; reconcile what's already done.
> (2) Call the advisor to pressure-test your decomposition BEFORE building. (3) DECOMPOSE — write the
> frozen integration contract inline (layout, schemas/closed-enums, pinned interfaces between units,
> conventions, machine-checkable acceptance categorized REAL/MODELED/DEFERRED). (4) FAN-OUT — emit a
> SWARM CONFIG line, then dispatch parallel sub-agents on DISJOINT units, each writing code to disk +
> a verbatim report to `active/swarms/<run-id>/`; right-size model/effort per unit. (5) INTEGRATE +
> VERIFY — assemble from disk, run the machine-checkable suite (assert + non-zero on fail), write the
> real cross-unit integration test. (6) REVIEW — dispatch an adversarial reviewer to REFUTE the result;
> fix every blocking finding and prove the fix by reproducing the attack; then call the advisor as the
> final gate. (7) DECIDE — from the structured results, choose the next step yourself; only surface a
> decision to the operator at a Level-C boundary (`rules/security.md`) or a genuine fork that materially
> changes the outcome. Build and execute AS MUCH AS POSSIBLE within the authorized (reversible / `/tmp` /
> dry-run) radius before stopping. (8) PERSIST the contract/run/verification triple + a learned rule if
> one emerged + refresh the handoff. Do not prompt for routine progress; pass decisions back to yourself.

---

## Worked reference (what "good" looked like)
The 2026-06-29 enforcer-spine build: Phase A frozen contract (`CONTRACT.md` with pinned B4→B1→B2 / B1→B3
interfaces) → 5 disjoint parallel builders (FRONTIER-DO for the 2 security-critical units, MID for the rest) →
orchestrator integration (caught a real security property: the brain can't choose the deploy repo) + 21
machine-checkable tests → adversarial red-team that found 2 v1-blocking defects (fixed + proven by
reproducing the attack) → advisor (caught the unexecuted boundary-verifier, closed with `bash -n` + body-flow
smoke). Operator gated ZERO times mid-build; the single decision handed up was the Level-C live-wiring gate.
Artifacts: `active/swarms/2026-06-29_omni-enforcer-spine-v1/`.
