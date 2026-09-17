# Finishing a build: review, QA, red team, fix iterations, final review, deploy

Reader: the person closing out a build who needs to know what the harness gives them for each tail
stage, what it does not, and what to do by hand where it does not. This document assumes you have
read `docs/lifecycle.md` through the Execute stage; it picks up where that one hands over.

## Coverage, honestly

Each "does not have" entry below was checked by searching skills/, agents/, commands/, docs/,
AGENTS.md, and templates/ for rollback, smoke, release, post-deploy, canary, staging, QA, and red
team, and by reading every agent and skill in the repo. Absences are stated as absences, not
softened into "not yet."

| Stage | The harness has | The harness does not have |
|---|---|---|
| Review | the per-wave gate stack; `adversary`; `/ponytail-review`; optional `external-llm-review`; step 4.5 in the main checkout | nothing missing at the wave level |
| QA | machine-checkable done-when per phase (`templates/phase/a-example-phase/CLAUDE.md`); the test command the plan names; the vendored `test-driven-development` skill; `verify-unexecuted` for scripts whose preconditions do not exist at build time; `templates/project/context/verification.md`, with Standard and Critical levels and a verdict schema | a QA skill; guidance on writing acceptance or end-to-end tests; non-functional checks beyond "accessibility basics" in `AGENTS.md` |
| Red team | `adversary` on a diff, with its taxonomy sweep; the build loop's reproduce-the-attack rule | a system-level red team of the integrated, running build; a threat-model step; any test of an agent's own instruction surface |
| Fix iterations | class closure; stopping by class; guarantee-vs-claim; fixtures-must-fail; the hand-list warning (all in `skills/autorun-plan/SKILL.md`) | nothing missing; this is the harness's deepest material |
| Final review | `code-reviewer` via `requesting-code-review` (implementation against plan); `design-reviewer` (plan against code); `AUTORUN-REPORT-{date}.md`; `/handoff` | a whole-build release-readiness review that re-checks scope and premises against what actually shipped |
| Deploy | a hard-stop category in `AGENTS.md`; the live-data corollary; the task-file Rollback section | a deploy skill; a rollback template; a post-deploy smoke or monitoring step; staged rollout guidance |

The rest of this document expands each row and gives a checklist wherever the harness leaves a gap
a human has to fill by hand.

## Review: the gate stack, and the one rule that keeps it honest

`docs/autorun-hitl-heartbeat.md` covers the full per-wave gate stack. The one rule worth adding here
is the step that turns a green review into a real one rather than a green review of the wrong tree.
`skills/autorun-plan/SKILL.md`: "**Run 4.5 in the MAIN checkout, with the suite's REAL command
(binding).**" And: "**Never substitute a nearby command for the suite's own** -- read its invocation
and use it verbatim." A worktree can be missing gitignored fixtures the real environment has; only
the main checkout, on the suite's own command, tells you the wave actually works.

## QA: what counts as proof

Proof is a script that exits non-zero when the condition is unmet, never a self-report.
`templates/phase/a-example-phase/CLAUDE.md`: "A machine-checkable condition. A script asserts it and
exits non-zero if unmet. An autonomous loop is only worth wiring when the acceptance signal is
machine-checkable, never model-self-reported."

The build loop's three categories for being honest about what a check actually proves, from
`templates/project/knowledge/autonomous-build-loop.md`: "Categorize each check honestly: **REAL-now**
vs **MODELED** vs **DEFERRED-to-a-gate** ... A MODELED check must never masquerade as a boundary
proof." A check that only simulates the real condition is useful, but it is a different thing from a
check that ran against the real system, and reporting it under a false category is how a build ends
up green on paper and wrong in production.

For scripts that cannot run at build time -- one that needs a live VM, or a claw/robot that does not
exist in the build environment -- `verify-unexecuted` covers the gap it can cover: "Syntax-gate and
body-flow smoke for scripts that ship UNEXECUTED by construction." It cannot prove the script works;
it proves the script would not fail on a syntax error or an obviously broken control-flow path the
moment it finally runs.

`templates/project/context/verification.md` sets the depth by risk level. Its Critical tier:
"Default: 2 full loops. Explicit residual-risk section. Operator approval gate if not
self-executable."

The gap: there is no acceptance-test-authoring skill in this harness. Write acceptance checks as
phase done-when scripts, and state in the report which of the three categories above each one falls
into. Do not let a MODELED check stand in for a REAL-now one without saying so.

## Red team: what adversary is, and what it is not

`adversary` attacks a diff before it merges. Its own definition: "BREAK the change before it merges.
A clean review is only credible if you tried to falsify each claim. Rubber-stamping is failure." Its
fixed taxonomy: fail-OPEN, fail-STUCK, global-vs-local scope mismatch, vacuous assertion, fixture
pins both sides, fixture topology != production.

How to brief it. `skills/autorun-plan/SKILL.md`: "Hand the adversary the taxonomy ... **taxonomy
sweep first, free hunt second.** Do NOT hand it the previous round's exemptions as settled." Handing
it a list of things already decided to be fine is how a real defect gets pre-excused before the
review even starts.

A found attack becomes a regression test, not just a note in a report.
`templates/project/knowledge/autonomous-build-loop.md`: "Fix every blocking finding and PROVE the
fix by reproducing the attack as a regression test."

What is not in the harness: nothing exercises the running, integrated system as a whole, and nothing
tests an agent's own instruction surface against injection. A recommended step to close the first
gap with what already exists: after the last wave merges, dispatch `adversary` once more against the
full integration diff (base is the commit before wave 1, head is the merged result), with the scope
file and the premises list in its brief, and ask it to attack the seams between waves rather than any
single wave's internals. No skill wires this up automatically; it is a manual dispatch.

## Fix iterations: close the class, and know when to stop

See `docs/anti-patterns.md`, entry "Closing the instance instead of the class," for the failure this
guards against. A fix round's deliverable, from `skills/autorun-plan/SKILL.md`: "1. **the violated
invariant, in ONE sentence;** 2. **the finite surface that invariant ranges over, enumerated as a
table-driven test** ... 3. **a mutation manifest**." The stopping rule: "Stop when ALL THREE hold: 1.
the round returned no new CRITICAL/HIGH, **counted by class** ... 2. every class found in any round
has a machine-checked closure artifact ... 3. the mutation manifest and the full suite are green on
the FINAL bits."

The escape hatch for a loop that never seems to converge: "Does the finding break the thing the
PHASE PROTECTS, or does it break a CLAIM a previous fix round invented?" A finding against the
protected invariant is a must-fix. A finding against a claim someone made up along the way gets the
claim narrowed, never the code widened to satisfy it.

Any fix that changes code re-enters the loop rather than skipping ahead: "Any fix in steps 3 or 4
that changes code **re-enters at step 2**."

## Final review: what closes a build

What exists today: `code-reviewer`, dispatched through `requesting-code-review`, whose brief carries
BASE_SHA, HEAD_SHA, and the plan. `skills/requesting-code-review/SKILL.md` lists this as mandatory
after each task in subagent-driven development, after completing a major feature, and before merge
to main. `design-reviewer` covers the other direction, plan against live code, for drift a
code-only review would miss. The close-out report: `skills/autorun-plan/SKILL.md`: "Write
`.project-state/AUTORUN-REPORT-{date}.md`: shipped, parked (branch + reason + diff pointer), failed
rounds, delegated decisions taken, hard aborts." And the resume prompt rule: "**The resume prompt's
pasted block must reach everything it needs (binding).**"

A recommended checklist for the final pass, since no single skill states it end to end:

1. Run the full suite, its real command, in the main checkout, on the final merged SHA.
2. Dispatch `code-reviewer` with BASE_SHA set to the commit before the first wave and HEAD_SHA set
   to the final merge, and the approved plan as the requirements input.
3. Re-apply the scope rule to what actually shipped: every merged phase should touch something on
   the IN SCOPE list, not just what it targeted at planning time.
4. Re-read the premises list written at finalize. Any premise that died mid-build means the phases
   it justified get reported as such, not silently kept.
5. Write `AUTORUN-REPORT-{date}.md`, opening with the items that need operator attention.
6. Run `/handoff`, and check it against the three-step rule in `docs/handoff-and-resume.md`.

## Deploy: a human gate by category

`AGENTS.md` puts "deploying to external hosting" on the hard-stop list, so no plan rule can
auto-proceed past it, however cleanly the rule reads. What the harness gives the person standing at
that gate: the tested-rollback precondition from `agents/plan-synthesizer.md` ("if a phase
auto-proceeds AND mutates live data, it MUST run on a branch with a precomputed patch, a snapshot,
and a TESTED rollback"), the task-file Rollback section (`templates/phase/a-example-phase/01-first-task.md`:
"## Rollback" followed by "How to undo it if it goes wrong."), and the build loop's shape for the
handoff itself (`templates/project/knowledge/autonomous-build-loop.md`: "hand the operator a tight
decision: contract + residual risks + the machine-checkable evidence + a recommendation -- ONE
decision, not a prompt-per-step").

What is not in the harness: a deploy skill, a rollback template, a post-deploy smoke or monitoring
step, staged rollout guidance. None of these were left out by oversight -- deploy tooling is
specific to a host, a CI system, and a company's own rollback mechanics in a way a generalized
harness cannot verify. A recommended checklist to hand the operator at the deploy gate, built from
what already exists rather than a new skill:

- The final SHA and the path to the close-out report.
- The rollback command, and evidence that it was actually tested, not just written down.
- Where the pre-deploy snapshot lives.
- The residual-risk list from the verification report.
- The smoke check to run right after deploy, and its expected output.
- Who is reachable if the smoke check fails.

Nothing in the harness runs after deploy. That check, and the decision to roll back if it fails,
stay with the person at the gate.
