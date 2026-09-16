---
name: autorun-plan
description: Use when executing an approved multi-wave AUTORUN or overnight unattended plan; when running per-wave review gates with tests, adversary, `/simplify`, and external-LLM fold-back; when heartbeating, writing AUTORUN-STATE, parking a branch and continuing; or when minimizing HITL via auto-proceed-on-rule.
version: 0.1.0
user-invocable: true
argument-hint: "[path-to-mission-or-plan]"
tools: Agent, Bash, Read, Grep, Glob, Edit, Write
---

# Autorun plan orchestration (unattended execution)

Goal: **autonomous execution**. HITL only where the rule cannot be stated in advance, the
action reaches a person outside the system, irreversible without tested rollback, or physically human.
Parking is success. Guessing is failure.

**REQUIRED SUB-SKILLS:** `external-llm-review` (step 4 of every code-producing wave).
**Heartbeat:** Claude Code's built-in `/loop` (self-paced).
**Right-fit:** named agent definitions, never inherit. Hook
`~/.claude/hooks/require-agent-model.sh` denies unpinned spawns; name a def and re-issue.

This skill is the **executor**. `deep-plan-swarm` / `plan-synthesizer` produce the plan
and bake this stack into gates. Do not plan from here; do not skip a baked gate.

## 0. Kickoff (every session, every wake)

1. Read the mission file the operator named (or the plan's AUTORUN section if none exists yet).
2. Read **your mission's** STATE file: `.project-state/AUTORUN-STATE-<mission-slug>.md`.
   **Reconcile, do not assume:** `git status`, `git log -5`, the plan's test command, any
   locks/launchd/sentinels the mission names.
3. Continue from STATE's "next action", not from memory.

**STATE IS MISSION-SCOPED. NEVER READ OR OVERWRITE ANOTHER MISSION'S STATE.**
`.project-state/` is tracked and shared, so every worktree inherits whatever STATE the branch last
committed — from a DIFFERENT run. Combined with "overwrite, do not append", an unslugged singleton
means a fresh run silently destroys another workstream's durable record. Rules:
- Your STATE file is `AUTORUN-STATE-<mission-slug>.md`, slugged from the mission the operator named.
- **Legacy fallback:** if no slugged file exists but a bare `AUTORUN-STATE.md` does, use it ONLY if
  its mission matches yours; then rename it to the slugged form on your first write.
- If a STATE file describes a mission that is not yours, it is **foreign**: do not reconcile against
  it, do not continue from its "next action", and **never overwrite it**. Create your own.
- Concurrent missions in sibling worktrees are normal. One STATE file per mission, not per repo.

If this is a fresh run, create STATE (overwrite YOUR OWN file, do not append forever):

```
# AUTORUN-STATE — <mission name>
mission:
phase / wave:
branch/SHA map:
open subagents:
locks/sentinels:
next action:
last heartbeat:
parked (branch + reason):
```

Rewrite STATE after every meaningful step.

## 1. Minimize HITL (binding)

A human stop exists ONLY if: (a) pass/fail cannot be stated in advance, (b) it reaches a person
outside the system, (c) irreversible without tested rollback, or (d) physical human action.

Everything else: **auto-proceed-on-rule**. State the rule in the plan, proceed while it
holds, **PARK THE BRANCH, CONTINUE THE REST** when it does not. Morning report lists parked
items. A rubber-stamp "does this look right?" gate is a defect: replace it with the rule.

Never auto-proceed a live-data mutation without branch + precomputed patch + snapshot +
**tested** rollback.

Never weaken, even when the rule is expressible: sends that reach a person outside the system,
deletion of tracked content, writes to a source of truth the plan marks read-only.

## 2. Right-fit dispatch (custom agents/skills)

Resolve agent definition in order: **the plan's per-phase matrix** → project
`.claude/agents/<name>.md` → `~/.claude/agents/<name>.md`. Prefer the project copy when both
exist (repo-specific reviewers win). If a named def is missing in both places, STOP that
stream and report; do not inherit a parent model as a workaround.

Standard catalog (copy lives in `~/.claude/agents/` so any repo can dispatch):

| Kind of work | Definition | Model / effort |
|---|---|---|
| Mechanical, fully specified, empirically checkable | `exec-mechanical` | SMALL / medium |
| Bounded impl against a local pattern | `exec-standard` | MID / medium |
| Correctness-critical, silent-wrong is expensive | `exec-critical` | FRONTIER-DO / high |
| Subtlest workstream in the plan (derivation, self-heal, crying-wolf) | `exec-subtle` | FRONTIER-DO / max |
| Adversarial correctness of a diff | `adversary` | FRONTIER-DO / xhigh |
| Plan/design vs live code | `design-reviewer` | FRONTIER-THINK / xhigh |

A repo's OWN agent definitions win when the **plan names them** — a project that ships a specialized
reviewer for its risky path knows something the catalog does not. Do not substitute a catalog agent
for a named project agent.

**Never inherit.** Every Agent/Task/`claude -p` spawn pins `model` (and effort in the def).
If the hook denies, re-issue with a named def. Never disable the hook.

**Silence is unknown.** A subagent that commits and goes idle without a report has not
passed. Re-run its tests yourself from a tree that can resolve deps before merge.

**EVERY child writes its report to a FILE before finishing (binding).** Observed repeatedly: a
backgrounded agent completes, emits an idle notification, and **its final report never reaches the
orchestrator and cannot be retrieved.** Survivable for a builder (the work is in git and you re-run
its tests anyway); **fatal for a REVIEW, where the report IS the deliverable** — one full adversary
round had to be re-run from scratch. Require in every dispatch: *write your report to
`runtime/verify/<name>.md` via Bash BEFORE finishing, AND return it as your final message.* Tell
reviewers to write an early stub and overwrite as they go, so a cut-short review still leaves
evidence. This also keeps large reports out of orchestrator context.

**A report is done when the AGENT reports done — NEVER when the file looks big enough (binding).**
The stub-and-overwrite rule above creates this trap, so it is stated here next to it. Observed, and it
cost a full round: the orchestrator armed a waiter on `wc -c report.md > 1000`, read the file at
21 KB, and wrote the fix brief from it. The agent kept writing; the FINAL report was 29 KB and had
**two BLOCKERs, not one**. The brief silently dropped the first one (the real BLOCKER 1), the fix
round executed the brief faithfully, and the defect walked into the next round to be rediscovered at
full cost. **Never gate a read on file size or on grepping for a marker mid-write.** Wait for the
agent's completion notification, then read. If you must poll, poll for the agent's process exiting,
never for bytes.

**Scope the interim re-runs; run the full suite once, at 4.5.** "Silence is unknown" stays, but
re-running the entire suite after every child was measured as the **worst cost-per-defect line in the
run** — three runs, ~10 min each, **zero** discrepancies, ~95% of each run on suites unrelated to the
wave. Cheaper attestation with the same trust: the child writes raw test output + exit code +
`git rev-parse HEAD` to a file; you verify the SHA matches the commit under review, parse the counts,
and re-run **only the phase's own fixture** as a spot-check. The full suite runs at step 4.5 on the
final bits — the only run that gates the merge anyway.

**Run 4.5 in the MAIN checkout, with the suite's REAL command (binding).** Two ways this gets faked,
both producing a false clean, both observed in one run:

1. **Wrong tree.** Where a repo keeps gitignored local data, a worktree does not have it, so the
   suite there silently runs FEWER checks than the same command on the main checkout, and any test
   that walks directories sees a different tree. Five consecutive rounds were green in the worktree;
   the first full run on the main checkout after the merge **failed two**. One was a repo-walking test
   whose skip-list omitted a gitignored scratch directory **that does not exist in a worktree at
   all** — no amount of worktree green could ever have caught it.
2. **Wrong command.** A near-equivalent command can enforce less than the one the suite runs. In that
   run a type-check was "verified" with a flag that omits unused-symbol checking while the suite used
   the project build, which enforces it — so the weaker command passed code the real one rejects.
   **Never substitute a nearby command for the suite's own** — read its invocation and use it verbatim.

Corollary: expect the first post-merge run to differ from every pre-merge run, and treat it as part of
the gate rather than a formality. If the repo has a known tree-dependent gap, record the specifics in
that project's memory or docs — this skill only carries the rule.

**File ownership.** One worktree + branch per concurrent stream. Exclusive file list. If a
child needs a file it does not own, it reports a handoff line; it does not edit it.

Workflow vs Agent: follow the plan's verdict. Default: heterogeneous waves → parallel
named Agents, gates in this session.

## 3. Per-wave review stack (code-producing waves)

Bake into EVERY code-producing wave's gate, in order: **(1) `<the test command the plan names>` green -> (2)
`adversary` correctness review of the merged wave diff -> (3) **`/simplify`** on the wave
diff (quality: reuse/simplification/altitude; it applies fixes; it does NOT hunt bugs and never
replaces step 2) -> (4) external-LLM fold-back loop on the FINAL simplified diff (review -> apply
fixes -> re-review; **loop until a round returns no new CRITICAL/HIGH — NO ROUND CAP,
per M3**) -> **(4.5) re-run `<the test command the plan names>` + the wave's phase-specific tests AFTER the last
step-3/4 modification (steps 3 and 4 both apply fixes after step 1's only test run, waves land by
fast-forward, and CI fires on pull_request only — without this, modified safety code could deploy
untested; any fix that changes code re-enters at step 2)** -> (5) merge.** Order
matters: never simplify code step 2 is about to rewrite; the external reviewer sees the final diff.

Generalize the **test binary**: if the plan names a different command than `node test-all.mjs`,
use that command in steps 1 and 4.5. The stack order does not change.

Step 4 CLI/model: **REQUIRED SUB-SKILL** `external-llm-review`. The **plan** names the
execution reviewer. Empty/narration output is a failed round.

Any fix in steps 3 or 4 that changes code **re-enters at step 2**.

### Fix rounds ship CLASS CLOSURE, not patches (binding)

**The failure this prevents, measured:** three rounds on one 10-file phase found the SAME defect
class by three different routes — a failed close-out, then the same end state via a different command
with no failure at all, then again via the one command the previous fix had explicitly EXEMPTED.
**Each fix closed one command and blessed the next**, at ~60-85 min per recurrence.

So a fix round's deliverable is not "the reported findings are fixed". It is:

1. **the violated invariant, in ONE sentence;**
2. **the finite surface that invariant ranges over, enumerated as a table-driven test** (e.g.
   subcommand x scope x config-state x precondition — usually under a hundred mostly-degenerate cells,
   executable in seconds);
3. **a mutation manifest** — the named mutation that turns each new protection red, re-runnable.

**Every exemption needs a NEGATIVE TEST proving it cannot reach the class's forbidden end state.**
An exemption without one is precisely what produced recurrences two and three.

The next review round then **audits completeness of the enumeration** (bounded) instead of hunting
the next route from scratch (open-ended, expensive, novel harness each time). Evidence it works: the
first class-closure round **found a fourth route for free while building the table** — a finding that
would otherwise have been another full round.

### The recurring test defect: fixtures that cannot see the bug

Four separate instances in one run. **A test constructed so the two halves of a contract cannot
disagree is structurally blind.** Concretely observed: the fixture pinned the same env override on
BOTH the writer and the reader (so they could never diverge — 111 green assertions while a fail-open
existed); every sandbox got its OWN copy of a directory that is GLOBAL in production (so no test
could express "action in checkout A damages checkout B"); an assertion passed for an incidental
reason (a cleanup trap removed the artifact regardless of the guard); a pinned ordering was only
half-pinned. Same shape as a historical defect where the fixture carried a byte-identical copy of the
bug it was meant to catch.

**Rules:** a fixture must let the two sides of a contract DIVERGE; it must mirror production's
sharing topology (what is global stays global); and **every new assertion is proven to go RED by a
named mutation** — a test that cannot fail is not a test.

**The hand list, and why it comes back.** A test that greps the SOURCE TEXT of a HAND-LISTED set of
files is the most common shape of "cannot fail" — and it is worse than no test, because it reads like
a guarantee. Measured in one gate: a suite grew to ~1600 lines carrying **14 assertions that read
source text**. The worst asserted a single canonical mechanism by checking that its identifier
appeared in each of four listed files — so it passed on a **comment**, and structurally could not see
the one file that used a different mechanism, because that file was not on the list. Two more matched
a single *spelling* of a call (the one hand-built variant was green by construction) and matched
against a whole file rather than a reachable line, so `if (false) doTheThing()` still passed.

**Prefer discovery over enumeration**: walk the tree, filter by content, assert the required symbol by
name on a non-comment line, and guard the walk itself (`assert(files.length > 50)`) so a broken walker
cannot pass by finding nothing.

**And expect the lesson to be re-lost inside the same gate.** In the source run, round 1 *deleted* a
14-file hand list and replaced it with a discovery walk for exactly this reason — and round 2 then
shipped **five new hand lists**, which is why several round-3 findings shipped green under tests that
claimed to guard them. When a later round deletes such a test, some previously-red mutations will turn
green: that is the grep never having caught anything, not a behavior regression. **Say so explicitly
and list what is now untested**, rather than leaving a green certificate. Where no runnable seam
exists (browser text, HTTP wiring), leaving it untested and named beats grepping it.

### When the loop will not converge: separate a broken GUARANTEE from a broken CLAIM

**The shape, seen across a five-round gate.** A fix round introduces shared machinery and asserts a
UNIVERSAL property of it in a docstring or a test name: *the one place X happens*, *the helper every
caller of Y goes through*, *the single canonical Z*. The next round correctly falsifies that assertion
by finding the one caller it did not reach. Widening the code to make the claim true generates the
next claim, which the round after falsifies. **That loop has no fixed point**, and from the inside it
is indistinguishable from productive review, because every finding is genuinely true.

**The discriminator that terminates it:**

> **Does the finding break the thing the PHASE PROTECTS, or does it break a CLAIM a previous fix round
> invented?** The first is a must-fix. The second gets the **CLAIM NARROWED** — never the code widened.

Route the second kind to a one-sentence docstring edit (scope the claim to the paths the phase
actually owns, instead of "the one place"), plus at most a cheap one-line call swap where a caller
genuinely matters. Then **fix the boundary in the NEXT brief in advance** — name what is explicitly
out of scope — so the fix round cannot mint a fresh universal claim for the round after to falsify.

**Diagnose before assuming the fixes were sloppy.** The intuitive reading — *"the guard keeps missing
a caller"* — was wrong in the source run: the shared helpers did reach every caller. What recurred was
one level up, *the machinery was correct and the ENUMERATION around it was not*: a vocabulary list one
member short of the canonical one it should have derived from, and an authority check airtight against
the bypass it was designed for while open to a second one nobody had enumerated.

**Measure before widening.** In that run the three "over-built" abstractions totalled **~7 lines of
code** serving 15+ callers, while the scaffolding around them had grown to a **1600-line test file**.
Widening the code was never the right move; the scaffolding was the problem. Run the over-engineering
pass (step 3) at exactly this moment — it answers the scope question with numbers instead of
intuition, and it is the step most likely to have been deferred while the correctness rounds ran.

### Stopping rule — count findings BY CLASS

Replaces bare "no new CRITICAL/HIGH". Stop when ALL THREE hold:

1. the round returned no new CRITICAL/HIGH, **counted by class** — a new *instance* of an
   already-known class does not merely count, it **resets the loop** and triggers the class-closure
   obligation for that class;
2. every class found in any round has a machine-checked closure artifact the reviewer has explicitly
   attested covers its surface;
3. the mutation manifest and the full suite are green on the FINAL bits.

Principled because it terminates exactly when further rounds would re-check machine-checked ground.
A numeric cap remains forbidden — this is stricter, not looser.

### Steps 2 and 4 may run in PARALLEL (round 1 of each)

The "external reviewer must see the final diff" argument does **not** justify serializing them: step
4 is already a fold-back LOOP, so that property is guaranteed by the loop, not by the start order.
Both are read-only attacks on the same bits. Run them concurrently and fold both into ONE fix brief;
de-dup costs minutes, serialization costs 20-40+ min per gate. **Still binding:** the TERMINAL
external round and step 4.5 happen on the final bits. **Exception:** do not open step 4 while a
BLOCKER class is still open — you pay twice to rediscover what class-closure is already fixing.
The 2-before-3 ordering ("never simplify code step 2 is about to rewrite") remains sound.

### Reviewer briefs carry a defect-class taxonomy, never an exemption list

Hand the adversary the taxonomy (fail-open, fail-stuck, global-vs-local scope mismatch, vacuous
assertion, fixture-pins-both-sides, fixture-topology-differs-from-production): **taxonomy sweep
first, free hunt second.** Do NOT hand it the previous round's exemptions as settled — a written
"never guard X" ANCHORED the next round and produced the third recurrence. A prior round's
"seams I could not break" section is a report, not an axiom, and the next round must re-attack every
exemption the last fix introduced.

## 4. Heartbeat (keep the run alive without a human)

**REQUIRED:** Claude Code built-in `/loop`. Kickoff shape:

```
/loop Read <mission> and execute the mission it describes.
Self-pace with the heartbeat rules in its Mechanics section.
```

Cadence (unless the mission overrides):

- **600-900s** while waiting on external state (tests, a runner, a lock, CI).
- **1200-1800s** idle fallback.
- Prefer an **event watcher** (log line, file, git ref) as the primary wake; time is backup.

Every wake: read STATE → reconcile git/fs/locks → do the next action → rewrite STATE → re-arm.

**Anti-grind:** same step fails 3x across wakes → park that stream, continue the rest, report.

**Reap your own waiters.** A `until <cond>; do sleep N; done` watcher whose condition never becomes
true SURVIVES a context clear and polls forever — orphaned, invisible, and attributable to nobody.
Two were found still running 18 hours after the session that spawned them had been cleared, waiting on
grep markers in files that never got them. Prefer a condition that is guaranteed to fire (a process
exiting) over one that may not (text appearing in a file), and sweep for strays at close-out.

**Context degradation:** write STATE fully → spawn
`claude -p --model <explicit, never inherit> "Read <mission> and <state>; continue the mission"`
in the background → verify that worker's **first** STATE write landed → end this loop.
Do not leave two orchestrators mutating the same STATE.

**Wall clock: THERE IS NO DEFAULT WALL. Do not invent one; this is a dial, an organization sets it deliberately.**
A run continues until the work is done, the operator stops it, or a real blocker parks every
remaining stream. **"The operator will be up soon", "it is getting late", a round number of
hours elapsed, and "this is a good place to stop" are NOT stopping conditions** — none of them
is a property of the work, and stopping on them abandons a run mid-plan for no reason.

A wall exists ONLY when the operator states one for this run, or when an external event
genuinely forces it (a scheduled job that must not collide, a credential expiring). If one
exists, it is a fact about the environment you can name and point at. If you cannot name it,
it does not exist.

**Safe stopping points still apply, always** — whenever you DO stop, for any reason: no
half-landed security patch, no unloaded launchd job or watchdog the mission requires, no open
live mutation, STATE flushed, report written.

**Long runs: keep going, but keep it durable.** Rewrite STATE after every meaningful step so a
crash or a clear costs one step, not the run. Use the context-degradation handoff above rather
than stopping early to "leave things tidy".

## 5. Close-out

Write `.project-state/AUTORUN-REPORT-{date}.md`: shipped, parked (branch + reason + diff
pointer), failed rounds, delegated decisions taken, hard aborts. Update handoff/resume
prompt. Morning report **opens with operator items, urgent first**.

**The resume prompt's pasted block must reach everything it needs (binding).** The operator pastes
ONLY the copy-pasteable block, never the whole file. Any detail outside that block is invisible to
the next session unless the block says to go read it. Observed for real: a `RESUME_PROMPT.md` held
the block plus a long "everything the next session needs" section below it, and the block's read-list
named four other files but **not `RESUME_PROMPT.md` itself** — so using it as designed would have
orphaned the whole lower half.

Before declaring close-out done:
1. **The block's read-list names the handoff file itself**, instructing the next session to read
   everything below the pasted block. Required even when prompt and detail share one file —
   *especially* then, since co-location hides the omission.
2. **Re-read the block in isolation**, as the next session with no other context: can it reach every
   fact it needs? What it cannot reach is not written down.
3. **Refresh state claims AT the clear, not at draft time.** A prompt written hours earlier asserts
   stale next-actions and calls finished work pending.
4. **Say which lines to paste.** Fence the block and state its boundaries, so there is no guessing
   between "the prompt" and "the file".

## A premise died mid-run: STOP AND RE-DERIVE (binding)

**The most expensive mistake of the source run, and it was an execution mistake, not a planning one.**
Mid-evening the operator disabled a component. The orchestrator NOTED it in STATE ("this makes that
sender inert") **and kept hardening a control whose only unique purpose was pausing that exact
component** — for hours. Sharper still: a plan merged into the document existed to RETIRE that
component, and a spike earlier the same night had proven the replacement worked.

**When any premise changes — an operator disables something, a spike returns a verdict, a dependency
is dropped, a phase is cut — STOP and ask, before the next dispatch:**

1. **What work does this make unnecessary?** Not "note it and continue." Enumerate.
2. **What downstream requirements just lost their justification?** Cut phases orphan things far from
   themselves — sequencing chains, expected-delta tables, model-matrix rows, gate contents, and
   scope bullets all reference phases by name and are not swept automatically.
3. **Does the current in-flight work still earn its place?** If the answer is no, PARK IT. Sunk cost
   on a branch is not a reason to finish. Verbatim from the review that caught this: *"class-closure
   is the cost of USING the control, not a reason to invent a need for it."*

Record the answer in STATE. A noted-but-unfollowed premise change is how a run spends its best hours
on the one thing it was about to delete.

**Corollary — respect the scope document.** If the plan was produced with a `scope-audit` (it should
have been), execution keeps applying its rule: a phase earns its place only if it touches live
surface. If no scope doc exists and the work smells inherited, run `scope-audit` mid-run rather than
continuing on faith.

## Improvements that are now rules (do not regress)

- Subagent "tests pass" is a claim. Orchestrator re-runs.
- Index/derivation gates use the plan's capture instrument, not a guessed CLI.
- Empty set is SUCCESS when the plan says so; do not treat zero rows as failure.
- Do not cat huge artifacts into argv; name paths.
- Privacy: nothing the mission marks local-only leaves the machine.

## Do NOT

- Wait on the operator for a rule you can evaluate.
- Close a wave gate on a silent external review.
- Inherit models. Skip `/simplify`. Skip 4.5 after a late fix.
- Execute a reaches-a-person send or a read-only-source write because "autonomy is the goal."
- Start a second Grok/codex plan review unless the mission says this session owns it.
