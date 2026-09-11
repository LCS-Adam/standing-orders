---
name: heartbeat
description: Keep an already-approved plan executing unattended until it finishes or hits a real human gate. Wakes itself, reconciles actual state, continues. NO review gates, no adversary pass, no external-LLM loop, no improvement rounds. Use when the plan is simple enough that the autorun-plan harness would cost more context than it protects.
---

# Heartbeat (keep a run alive, nothing else)

**One job: the plan keeps executing instead of stopping to ask.**

This is deliberately NOT `autorun-plan`. That skill carries a per-wave gate stack (tests ->
adversary -> ponytail-review -> external-LLM fold-back), HITL doctrine, and morning-report
ceremony. For a plan that has already been reviewed, all of that costs context it does not earn.
**If the plan needs those gates, use `autorun-plan` instead. Do not run both.**

## What this skill does NOT do

No adversary pass. No `/ponytail-review`. No external-LLM review or fold-back rounds. No
improvement passes. No plan-quality judgement. **The plan is already approved — execute it, do not
re-litigate it.**

## Loop

1. **Read the mission's STATE file:** `.project-state/HEARTBEAT-STATE-<mission-slug>.md`.
   **The filename names the harness AND the mission, on purpose.** A run driven by this skill must
   not write an `AUTORUN-STATE-*` file: that label would tell the next reader the `autorun-plan`
   gate stack ran when it did not.
   **Mission-scoped, always.** A STATE describing a different mission — or produced by a different
   harness — is foreign: never read it, never continue from it, never overwrite it. If none exists,
   create yours.
2. **Reconcile, do not assume.** `git status`, `git log -5`, whether the last step's output actually
   landed on disk. A wake that trusts STATE over the filesystem resumes into fiction.
3. **Do the next step of the plan.**
4. **Rewrite STATE** — phase, next action, last heartbeat, anything parked.
5. **Schedule the next wake** and repeat.

STATE stays small. It is a resume pointer, not a journal.

## Wake scheduling

Use `ScheduleWakeup` in dynamic mode (self-paced), or `Monitor` with an until-loop when waiting on a
specific condition.

- Waiting on work the harness tracks (a subagent, a background command): you are re-invoked when it
  finishes. Schedule a **long fallback (1200s+)** so the loop survives a hang, and do not poll.
- Waiting on something untracked (an external process): pick a delay matched to how fast that state
  actually changes.
- Idle with no specific signal: **1200-1800s.**

Never schedule short wakes to "check in". Polling burns context for nothing.

## When to stop, and when NOT to

**Stop only at a gate the plan explicitly marks as human**, or at a genuine blocker. Park it, say why,
and **continue every other independent stream** — a stopped stream is not a stopped run.

**Do not stop to ask** for anything the plan already answers. "Does this look right?" is not a gate.
If the plan states a rule, apply the rule and keep going. That is the entire point.

**Anti-grind:** the same step failing 3 times across wakes is not a step that needs a 4th try. Park
that stream, continue the rest, report it at the end.

## Never auto-proceed

These stop the stream regardless of how well the plan reads:

- Anything **candidate-facing** or otherwise sent outside the machine.
- **Writes to a source of truth** the plan marks sacred (a vault, live production data).
- **Deletion of tracked content**, or any irreversible act without a tested rollback.
- A **live-data mutation** without branch + precomputed patch + snapshot + tested rollback.

If the plan tries to auto-proceed one of these, that is a defect in the plan. Park and report.

## Finish

When the plan is done or everything left is parked, write a short summary: what shipped, what parked
and why, what needs the operator. Then stop the loop — do not keep waking on a finished run.
