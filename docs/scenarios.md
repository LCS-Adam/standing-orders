# Five projects, start to finish

## Contents

- [How to read these](#how-to-read-these)
- [The five shapes at a glance](#the-five-shapes-at-a-glance)
- [Scenario 1: a one-line fix, and why the harness stays in its box](#scenario-1-a-one-line-fix-and-why-the-harness-stays-in-its-box)
- [Scenario 2: a bounded feature across four files](#scenario-2-a-bounded-feature-across-four-files)
- [Scenario 3: a three-wave build with parallel agents, run overnight](#scenario-3-a-three-wave-build-with-parallel-agents-run-overnight)
- [Scenario 4: an investigation with no endpoint on day one](#scenario-4-an-investigation-with-no-endpoint-on-day-one)
- [Scenario 5: a production incident at 21:40](#scenario-5-a-production-incident-at-2140)
- [Habits the five scenarios share](#habits-the-five-scenarios-share)

## How to read these

Each scenario follows the same seven sub-headings: Situation, What the person decides at each
step, Commands and dispatches, What each gate returns, Where it goes wrong and how it is caught,
What lands, Time and numbers. Read the whole set once to see the range, or jump to the one that
matches the shape of what you are about to do.

Every repo, file, person, and number below is invented for the scenario, not drawn from any real
project. Where a scenario shows a dispatch, model tier names appear in prose (SMALL, MID,
FRONTIER-DO, FRONTIER-THINK); the literal model string is whatever `config/models.conf` currently
binds to that tier.

## The five shapes at a glance

| | S1 one-line fix | S2 bounded feature | S3 three-wave build | S4 investigation | S5 incident |
|---|---|---|---|---|---|
| Size (step 0) | small | bounded | large | large, then bounded | bounded, correctness-critical |
| Scope audit | skip | skip | yes, cuts one phase | yes, is the deliverable | skip |
| Plan | none | `/deep-plan` | `/deep-plan-swarm` | swarm without synthesis | five lines, inline |
| Worktrees | none | one | four | none | one |
| Tier of the builder | SMALL, headless | MID | FRONTIER-DO then MID | SMALL recon, FRONTIER-THINK verdict | FRONTIER-DO |
| Adversary | no | yes, one IMPORTANT finding | yes per wave, one BLOCKER finding | no, nothing built | yes at xhigh, one IMPORTANT finding |
| `/ponytail-review` | no | yes, one cut | yes per wave | no | deferred to morning, recorded |
| Unattended | no | no | `/autorun-plan`, overnight | no | no |
| Human gates hit | none | none | one, billing code | none | two, pausing the sender and deploying |
| Handoff | no | no | close-out report | yes, between two sessions | yes, at 00:30 |
| What lands | one commit | two commits, one PR | one integration branch, one parked branch | a scope file and a plan, no code | three commits, one deploy, one ERRORS row |

## Scenario 1: a one-line fix, and why the harness stays in its box

**Situation.** Repo `inventory-cli`, a small Python tool. A colleague reports that the `pages`
column in the report is one too low when the item count is an exact multiple of the page size. The
engineer opens `inventory/paginate.py` and finds `page_count = total // page_size`, though the
docstring says "rounded up." `tests/test_paginate.py` has a handful of cases; none uses an exact
multiple.

**What the person decides.** Step 0: a silent wrong answer here costs a wrong number in an internal
report; a test catches it immediately; the fix is fully specified. Small. They skip the scope step
and the plan step, open no worktree, and dispatch no adversary. They say the size out loud: small,
because a test proves it.

Then the detour this scenario exists for: what `/deep-plan` would cost here. The person has seen
the plan's shape in docs/planning-large-builds.md. For a one-line change it would return the same
four required parts (how to execute, a Workflow-versus-plain verdict, a model matrix, a phase list)
at something like eighty lines for a one-line diff, and its advisor pre-flight would ask about
constraints that do not exist on this ticket. That is the harness being overkill, and the operating
process says so at step 0. They do not run it.

**Commands and dispatches.**

```
$ git switch -c fix/page-count
$ claude -p --model <TIER_SMALL literal from config/models.conf> \
    "In inventory/paginate.py, page_count must round up (see the docstring). Add one case to
     tests/test_paginate.py where total is an exact multiple of page_size, then fix page_count.
     Change nothing else."
```

`-p` runs one prompt headlessly and exits. SMALL is the right tier for a fully specified edit that
an existing test proves.

**What each gate returns.** The only gate is the test command, and the person runs it, not the
model:

```
$ python3 -m pytest tests/ -q
....                                                                     [100%]
4 passed in 0.04s
```

**Where it goes wrong and how it is caught.** `git diff` shows two hunks in `paginate.py`: the fix,
and a rewrite of the module docstring the model "tidied" along the way. The person reverts the
second hunk with `git checkout -p`, because the instruction was "change nothing else," and a diff a
reviewer cannot predict from the task is a diff with a second change hiding inside it. That is the
whole lesson of the scenario: at small size, the human is the reviewer, and the review is reading
the diff against the sentence you typed.

**What lands.**

```
$ git add -A && git commit -m "fix(paginate): round page_count up on exact multiples"
$ git log --oneline -1
4c1e2a9 fix(paginate): round page_count up on exact multiples
```

One file changed under `inventory/`, one test added. A pull request from `fix/page-count`.

**Time and numbers.** About four minutes. One file, one line, one test. No dispatches beyond the
single headless call, no worktrees. The harness contributed the sizing question, the tier, and the
commit convention, and nothing else, which is correct.

## Scenario 2: a bounded feature across four files

**Situation.** Repo `usage-report`, a Python CLI that prints a usage report from a JSON export. The
request: a `--since <date>` filter so the report covers only records after a given date. The files
that will change: `report/filters.py` for the new function, `report/cli.py` for flag wiring,
`tests/test_filters.py` for new tests, and `docs/cli.md` for one paragraph. The person has already
run `harness install --user` and `harness init` in this repo.

**What the person decides.** Step 0: a wrong filter silently drops or includes records, and a test
only catches that if the fixture data is right; the change touches the CLI's shared argument
parsing. Bounded. Step 1 is skipped, since this is a single new code path with no dead surface to
audit. Step 2 runs `/deep-plan`. Step 3 opens one worktree and one `exec-standard` dispatch at MID.
Step 4 is tests, then the adversary, then `/ponytail-review`, then tests again. Step 5 needs no
handoff; it is one sitting. Step 6 ends in a pull request.

**Commands and dispatches.**

Step 2: they type `/deep-plan` with the request. Their installed session has no advisor tool (the
company plan does not expose one), so the command's two advisor calls cannot run. The CLAUDE.md
fallback applies: they tell the session there is no advisor here, and to dispatch `design-reviewer`
for the pre-flight and the critique instead, with an explicit model. The plan comes back in the
same four-part shape. The part the person reads first is the phase list:

```
### Phase 1: filter function and tests [agent: exec-standard, model: MID, effort: medium]
Files: report/filters.py, tests/test_filters.py
Done when: python3 -m pytest tests/ -q is green with two new cases (before/after boundary, empty result)

### Phase 2: CLI flag and doc [agent: exec-standard, model: MID, effort: medium; after Phase 1]
Files: report/cli.py, docs/cli.md
Done when: the same test command is green with one new end-to-end case

Workflow-vs-plain: plain is enough here; one Agent subagent, sequential, one worktree.
```

Step 3: one worktree, then the dispatch brief, filled in:

```
$ git worktree add .worktrees/since-filter -b feat/since-filter
```

```
Dispatch exec-standard (tier MID, effort medium) for the --since filter, phases 1 and 2 of the plan
above, in order.
Worktree: .worktrees/since-filter, branch feat/since-filter, already created.
You own exactly these files: report/filters.py, report/cli.py, tests/test_filters.py, docs/cli.md.
Touch nothing else.
Task: as the plan states, phase 1 then phase 2.
Test command: python3 -m pytest tests/ -q; green in the worktree before each commit.
Commit on your branch, one commit per phase, conventional messages, no attribution trailer.
Write your report to runtime/verify/since-filter-report.md before you finish, and return it.
```

The session makes the Agent tool call. `exec-standard` is installed under `~/.claude/agents/` with
a model pin, so the hook allows it. Earlier in the same session, the person had asked for a quick
read-only look at `report/cli.py` with a bare general-purpose agent, and the hook denied it, with
the same JSON shape docs/first-day.md shows, because that agent has no pin and no model was passed;
they re-issued it with the small tier's literal model instead. The hook working as designed.

**What each gate returns.**

Tests, run by the person in the worktree after the agent reports:

```
$ cd .worktrees/since-filter && python3 -m pytest tests/ -q
.......                                                                  [100%]
7 passed in 0.09s
```

Adversary: the person dispatches it against the diff between main and the feature branch, and it
returns one finding above MINOR:

```
### I1. --since compares a naive datetime against timezone-aware record timestamps
**Invariant claimed.** Records with timestamp >= since are included, per docs/cli.md.
**What is broken.** report/filters.py:14 parses --since with datetime.fromisoformat, which yields a
naive datetime for "2026-09-01". The JSON export's timestamps carry "+00:00". Python raises
TypeError on the comparison. Every fixture in tests/test_filters.py is naive, so the suite is green.
**Reproduction.**
  $ python3 -m report.cli --since 2026-09-01 samples/export-with-tz.json
  TypeError: can't compare offset-naive and offset-aware datetimes
**Fix.** Normalize both sides to UTC at the parse boundary in filters.py; add one fixture with an
offset; prove the test red by removing the normalization.
```

Plus one MINOR: a help string says "date" but the flag accepts a full datetime. The person sends I1
back to the same `exec-standard` dispatch with instructions to apply the fix and prove the red
check, and files the MINOR in `.project-state/NEXT_STEPS.md` under a "since-filter adversary"
label.

Then `/ponytail-review` on the diff. It removes a one-method `DateFilter` class in favor of the
function that already did the same job, and shortens the CLI branch by four lines. No behavior
changes.

Tests once more, since two review passes both landed fixes:

```
$ python3 -m pytest tests/ -q
........                                                                 [100%]
8 passed in 0.10s
```

**Where it goes wrong and how it is caught.** The green suite after phase 2 was a false clean: the
fixtures could never go red on the shape of data the code would actually see in production. The
adversary caught it because it read the real export format, not the test's fixtures. The lesson the
scenario is built to show: a MID builder plus a FRONTIER-DO reviewer found what the MID builder
alone had reported as done. Reviewers sit at or above the builder.

**What lands.**

```
$ git log --oneline main..feat/since-filter
b71d0c3 refactor(filters): drop the one-method DateFilter class
9e44f17 fix(filters): compare --since in UTC against aware timestamps
2a0c8de feat(cli): add --since date filter and document it
d3f5b90 feat(filters): add since() with boundary and empty-result tests
```

A pull request from `feat/since-filter`. The worktree is removed with `git worktree remove
.worktrees/since-filter`. The two report files stay under `runtime/verify/`, which is gitignored.

**Time and numbers.** About fifty minutes. Four files touched, three tests added, one adversary
finding fixed and one filed, one ponytail cut, four commits, one pull request.

## Scenario 3: a three-wave build with parallel agents, run overnight

**Situation.** Repo `orders-platform`. The request: an audit log. Every order create, order cancel,
and billing refund writes an audit row, and a CLI reads them back. The ticket also proposes
instrumenting a legacy import job. The person owns the build across two days and wants the second
night to run unattended.

**What the person decides.** Step 0: large, since it spans many files and three subsystems and a
silent design error would compound. Step 1 runs `/scope-audit` first, because one of the four
proposed call sites is inherited code nobody has confirmed still runs. Step 2 runs
`/deep-plan-swarm`. Step 3 sets up waves and worktrees, then `/autorun-plan` for the unattended
night. Step 4 bakes a per-wave gate stack into the plan itself. Step 5's close-out report is the
handoff. Step 6 lands on an integration branch, never on main.

**Commands and dispatches.**

Step 1: `/scope-audit` on the four call sites looks for runtime residue and writes
`.project-state/SCOPE-audit-log.md`:

```
| Surface | Evidence | Verdict |
|---|---|---|
| orders/create.py | orders/logs/create-2026-09-*.log, forty-one files | IN SCOPE |
| orders/cancel.py | same directory, forty-one files | IN SCOPE |
| billing/refund.py | billing/logs/refund-*.log, a dozen files; touches billing | IN SCOPE, hard-stop category |
| legacy/import.py | legacy/logs/ holds only .gitkeep; no legacy/import.yml | OUT OF SCOPE. Revive when: an import.yml exists and a log appears |
```

The legacy phase is cut before anyone plans it.

Step 2: `/deep-plan-swarm`. An investigation swarm runs three read-only groups, one each for
orders, billing, and tests and CI, dispatched at SMALL with an explicit model and the same output
contract: for each in-scope module, load-bearing, unexecuted, or risky-if-moved, with absolute
paths. The synthesis goes to `plan-synthesizer` at FRONTIER-THINK and max effort. The external-LLM
review step is skipped because no third-party CLI is installed on this machine, and the plan
records that fact in its own gate section instead of pretending the step ran. The execution section:

```
Wave 1 (alone, first): the writer and schema.
### Phase 1A: audit/log.py, audit/schema.sql, tests/test_audit_log.py [agent: exec-critical, model: FRONTIER-DO, effort: high]
Done when: python3 -m pytest tests/test_audit_log.py -q green; a write failure raises, never passes silently.

Wave 2 (parallel, after Wave 1 merges): three integrations.
### Phase 2A: orders/create.py [agent: exec-standard, model: MID, effort: medium]
### Phase 2B: orders/cancel.py [agent: exec-standard, model: MID, effort: medium]
### Phase 2C: billing/refund.py [agent: exec-critical, model: FRONTIER-DO, effort: high; HUMAN GATE: billing code, AGENTS.md hard stop]

Wave 3 (after Wave 2): the reader.
### Phase 3A: tools/audit_query.py, tests/test_audit_query.py [agent: exec-standard, model: MID, effort: medium]
### Phase 3B: docs/audit.md [agent: exec-standard, model: MID, effort: medium]

File ownership (exclusive):
| Branch | Owns |
|---|---|
| feat/audit-writer | audit/, tests/test_audit_log.py |
| feat/audit-create | orders/create.py, tests/test_create.py |
| feat/audit-cancel | orders/cancel.py, tests/test_cancel.py |
| feat/audit-refund | billing/refund.py, tests/test_refund.py |
| feat/audit-reader | tools/audit_query.py, tests/test_audit_query.py, docs/audit.md |

Per-wave gate: python3 -m pytest -q (main checkout after merge) then adversary, then
/ponytail-review, then re-run tests, then merge to integration/audit-log. External review: not
available on this machine.
Workflow-vs-plain: plain is not enough; Agent subagents with worktree isolation.
```

The person also lays out a `phases/` directory per wave with `harness add phase`, so
`/phase-status` can answer "where are we" straight from disk.

Step 3, day one, attended. Wave 1 runs alone: one worktree, one `exec-critical` brief from the
template. Gate: tests green, the adversary returns nothing above MINOR, `/ponytail-review` returns
nothing, and the branch merges to `integration/audit-log`.

Step 3, night two, unattended. The person creates the three Wave 2 worktrees and types:

```
Execute the plan at .project-state/plans/2026-09-17_audit-log.md under /autorun-plan.
State file: .project-state/AUTORUN-STATE-audit-log.md. Wave 1 is merged at 7d21e0c; reconcile
against integration/audit-log first. Heartbeat with the heartbeat skill. Park the branch, continue
the rest.
Phase 2C is a human gate: build it, do not merge it, and stop there for that branch.
```

Before the fan-out the orchestrator prints the auditable line:

```
SWARM CONFIG: count=3 model=<MID literal>,<MID literal>,<FRONTIER-DO literal> effort=medium,medium,high definitions=exec-standard,exec-standard,exec-critical branches=feat/audit-create,feat/audit-cancel,feat/audit-refund
```

The state file after the first wake, kept small on purpose:

```
# AUTORUN-STATE: audit-log
mission: .project-state/plans/2026-09-17_audit-log.md   slug: audit-log
last wake: 2026-09-17 23:12   next: on worktree ref change or 900s
integration/audit-log = 7d21e0c (Wave 1 merged)
Wave 2: 2A building | 2B building | 2C building (HUMAN GATE at merge)
Parked: none
Last gate result: Wave 1 tests all passed, adversary clean, ponytail clean
```

**What each gate returns, night two.** Wave 2 merge candidate is 2A plus 2B; 2C is parked by rule.

Tests in the main checkout of the integration branch: green, sixty-one passed.

The adversary on the merged Wave 2 diff returns one BLOCKER:

```
### B1. The audit writer swallows a database error and the order path continues as if logged
**Invariant claimed.** Plan phase 1A: "a write failure raises, never passes silently."
**What is broken.** orders/create.py:88 wraps audit.log.write() in `except Exception: pass` (added by
2A "so a logging failure cannot block an order"). The Wave 1 writer raises correctly; the caller
discards it. The suite is green because no test injects a write failure at the call site.
**Reproduction.** Monkeypatch audit.log.write to raise in tests/test_create.py; the order succeeds
and no audit row exists.
**Fix.** Remove the bare except; if orders must survive an audit outage, that is a plan decision,
not a call-site default. Add the injected-failure test; prove it red by restoring the except.
```

The orchestrator dispatches the fix to `exec-standard` on `feat/audit-create`, re-runs tests, and
re-enters the gate at the adversary step, since a fix is a code change. Second adversary round:
clean. `/ponytail-review` finds one cut, a duplicated row-builder in cancel.py replaced by the
writer's own helper. Tests again: green. Waves 2A and 2B merge.

**Where it goes wrong and how it is caught.** Two places.

First, the parked branch. `feat/audit-refund` builds and its tests are green in the worktree, but
the plan marks it a human gate because `billing/` sits on the AGENTS.md hard-stop list. The
orchestrator does not merge it. It records "PARKED: feat/audit-refund at 3ab9c11, reason: billing
code, human approval required, diff at runtime/verify/audit-refund-report.md," and continues with
Wave 3. A single parked branch does not stall the run. In the morning the person reads the diff,
approves it, and merges it themselves.

Second, the post-merge suite. Wave 3 merges at 05:40. The first full run in the main checkout of
`integration/audit-log` fails one test that was green in every worktree:
`tests/test_repo_hygiene.py::test_no_stray_scripts` walks the tree and finds a one-off script under
`runtime/`, a gitignored directory that does not exist inside a worktree. The orchestrator dispatches
a fix to the walk's skip list at SMALL, re-runs, and it goes green. The state file records the rule
this exposed: run the real suite command in the main checkout before calling any gate closed.

**What lands.** The morning close-out, `.project-state/AUTORUN-REPORT-audit-log.md`, in the shape
the person reads first:

```
## OPERATOR ITEMS, in order
1. feat/audit-refund is PARKED at 3ab9c11: billing code. Diff summary and adversary notes at
   runtime/verify/audit-refund-report.md. Approve and merge, or send it back.
2. Nothing else needs a decision.

## SHIPPED (integration/audit-log = 9f0e2d4)
| What | Commit |
|---|---|
| Wave 1 writer and schema | 7d21e0c |
| 2A create integration, with the B1 fix | 5c77a01 |
| 2B cancel integration | 5c77a01 |
| 3A reader CLI, 3B docs | 9f0e2d4 |
| repo-hygiene walk skips runtime/ | 9f0e2d4 |

## GATE LEDGER
Wave 2: tests pass (61) -> adversary B1 -> fix -> adversary clean -> ponytail one cut -> tests pass (63) -> merge
Wave 3: tests pass (70) -> adversary clean -> ponytail clean -> tests pass (70) -> merge -> main checkout catches one failure -> fix -> tests pass (70)

## PARKED
feat/audit-refund, human gate, see item 1.
```

`/phase-status` the next morning shows Waves 1 through 3 COMPLETE and phase 2C IN PROGRESS.

**Time and numbers.** Two days. Three waves, six phases, four worktrees, one integration branch.
One BLOCKER finding closed on Wave 2 across two adversary rounds. One parked branch. One
post-merge failure that no worktree could have caught on its own. The unattended run lasted about
ten hours. Nothing reached main.

## Scenario 4: an investigation with no endpoint on day one

**Situation.** Repo `data-pipeline`, inherited from a team that has since moved on. A vendor has
deprecated the HTTP client library the pipeline uses, `legacyhttp`. Fourteen modules import it. The
ticket says "migrate off legacyhttp." Nobody currently on the team knows which of the fourteen
modules still run.

**What the person decides.** Step 0 reads large in shape, but the honest read is that the endpoint
here is a decision, not a diff. They run the harness for its investigation half and stop before
building anything. Step 1 runs `/scope-audit`, which in this scenario is the deliverable. Step 2
runs the investigation half of `/deep-plan-swarm`, the swarm and the registry, then asks
`design-reviewer` for a verdict instead of a full synthesis, because there is not yet a thing to
plan. Steps 3 and 4 have nothing to build and nothing to review. Step 5 produces a handoff, because
the work spans two sessions. Step 6 lands a scope file and a plan; no code changes.

**Commands and dispatches.**

Session one: `/scope-audit` runs on the fourteen importers, looking for runtime residue: a log
under `logs/` per module, a row in `config/schedule.yml`, a history file under `data/`. It writes
`.project-state/SCOPE-legacyhttp.md`:

```
IN SCOPE (8): ingest/fetch_orders.py, ingest/fetch_inventory.py, ingest/fetch_prices.py,
  sync/push_status.py, sync/push_labels.py, alerts/webhook.py, export/upload_daily.py,
  export/upload_weekly.py
  Evidence: each has a logs/<name>-2026-09-*.log and a schedule.yml row.
OUT OF SCOPE (6): ingest/fetch_reviews.py, ingest/fetch_returns.py, sync/push_notes.py,
  legacy/portal_scan.py, legacy/batch_reprice.py, tools/probe_vendor.py
  Evidence: no log ever; no schedule row; legacy/batch_reprice.py's log dir holds only .gitkeep;
  tools/probe_vendor.py has no config file it requires.
  Revive when: a schedule row is added and a first log appears.
Premises: "the vendor drops security fixes at end of year" (from the ticket, unverified).
```

Then the swarm: three read-only groups by directory (`ingest/`; `sync/` and `alerts/`; `export/`
and `tools/`), each a `repo-recon` dispatch at SMALL with an explicit model and the same output
contract: for each in-scope module, which `legacyhttp` calls it makes, whether each call has a
direct standard-library replacement, and a confidence mark. The person merges the three reports
into one twenty-row registry by hand, because the reports disagree on two modules and both
disagreements can only be settled by opening the file.

`design-reviewer`, at FRONTIER-THINK, reads the registry and the scope file and returns a verdict:
five of the eight live modules use only calls with a drop-in replacement; three use a streaming API
with no equivalent and need real work; the six dead modules should be deleted rather than migrated,
with their revive conditions carried into the deletion commit's message.

Session two, the next day, starts from the handoff block session one wrote, which is the resume
side of a handoff that docs/first-day.md does not show:

```
Where to start: ~/projects/data-pipeline, then run: claude

Read first, in this order:
1. .project-state/SESSION_HANDOFF.md (this file, read everything below this block)
2. .project-state/SCOPE-legacyhttp.md
3. runtime/verify/legacyhttp-registry.md
4. runtime/verify/legacyhttp-verdict.md

Current state:
- Scope audit done and committed (a41f77e): eight live, six dead importers of legacyhttp.
- Registry (twenty rows) and design-reviewer verdict on disk under runtime/ (gitignored, not committed).
- Nothing built. No production file changed.

Next action:
Verify the ticket's premise ("security fixes stop at year end") against the vendor's notice before
planning anything; then, if it holds, run /deep-plan for the three streaming modules only.

Standing constraints:
- Do not migrate the six OUT OF SCOPE modules; delete them in a separate PR with revive conditions.
- Do not touch sync/push_status.py without a plan: it is on the outbound path.
```

The resumed session reads the four files in order without being told to, and states the next action
back. That confirms the block was self-sufficient.

**Where it goes wrong and how it is caught.** The premise dies. Checking the vendor's actual notice,
the person finds that `legacyhttp` keeps receiving security fixes; only the streaming API is being
removed. The rule from docs/anti-patterns.md, the premise that died mid-run, applies before the
next dispatch: what work does this make unnecessary? The five drop-in migrations no longer earn
their place; they were justified only by the end-of-support claim. The three streaming modules are
still real work. The person rewrites the scope file's premise line, records the decision in
`.project-state/PROJECT_STATE.md`, and runs `/deep-plan` for three modules instead of eight.

**What each gate returns.** None ran; nothing was built. The plan's own critique, from
`design-reviewer` filling in for an advisor, returns one note: the three streaming modules share a
helper, so the plan should be a single phase with a single owner, not three.

**What lands.** `.project-state/SCOPE-legacyhttp.md`, committed; a decision note in
`PROJECT_STATE.md`; a `/deep-plan` output saved to
`.project-state/plans/2026-09-18_streaming-migration.md`, sized as a bounded change in scenario 2's
shape, ready to execute later; and a separate pull request that deletes the six dead modules with
their revive conditions in the commit message. Zero lines of production code changed by the
investigation itself.

**Time and numbers.** Two sessions, about three hours total. Fourteen importers: eight live, six
dead, three headed for migration, and five that are not migrated because the premise that justified
them fell apart. One handoff, one resumed session.

## Scenario 5: a production incident at 21:40

**Situation.** Repo `notify-service`, which sends replies to customers by email out of a support
queue. At 21:40 a support lead reports that two replies today went to the wrong address: each reply
was addressed to the newest message in its thread, and in both threads the newest message was the
company's own earlier outbound. The service is live and sends hourly.

**What the person decides.** Step 0: this sits on a send path, reaching people outside the system,
and a silent wrong answer is exactly what just happened. The fix itself is bounded in size, one
selection function, but it is correctness-critical, so the builder runs at FRONTIER-DO and the
reviewer runs the adversary at xhigh effort even at this hour. Step 1 is skipped. Step 2 is five
lines, typed inline after root cause is found; no `/deep-plan`. Step 3 opens one worktree with one
`exec-critical` dispatch. Step 4 runs the full gate stack minus one step, which is written down.
Step 5 produces a handoff before sleep. Step 6, the deploy, is a human action.

The two hard stops, in order. Pausing the live sender counts as modifying a production system: the
person does it themselves at 21:44 and tells the session it is done; the agent never touches the
production host. Deploying the fix at the end falls in the same category and is also done by a
person. No permission-bypass flag is used or even considered; the pressure of the hour is exactly
when that habit would form, which is the point of naming it here.

**Commands and dispatches.**

Root cause first, with `/systematic-debugging`. The person exports one affected thread's headers,
with addresses replaced by placeholders before the data ever enters the session; the customer's
real address is not something the agent needs to see. The reproduction:

```
Thread T1 (headers, redacted)
  Sep 13 17:06Z  INBOUND   customer@<redacted>
  Sep 15 09:12Z  OUTBOUND  support@<company>          <- newest message
notify/pick_recipient.py:31  target = thread.messages[-1].sender
```

The bug: newest message, not newest inbound message. Then the class question: what surface does
this invariant range over? `grep -rn pick_recipient notify/` shows four outbound paths, ordinary
reply, follow-up nudge, recovery resend, and queue drain, all calling `pick_recipient()`. The fix
belongs in that one function, not in the path the ticket named.

The five-line plan, typed straight into the session:

```
Fix in notify/pick_recipient.py only: select the newest INBOUND message, skipping drafts and
automated senders; assert the chosen recipient is never a company address and never a no-reply.
Tests in tests/test_pick_recipient.py: one per outbound path plus drafts and automated cases.
Tier FRONTIER-DO, exec-critical, worktree .worktrees/hotfix-pick-recipient, branch hotfix/pick-recipient.
Test command: python3 -m pytest tests/ -q. Report to runtime/verify/pick-recipient-report.md.
```

Then the brief, filled from the template, and the dispatch. The agent's report names the mutation
checks it ran: reverting the selection to the newest message turns six tests red; removing the
recipient assertion turns one red; allowing drafts as reply parents turns one red.

**What each gate returns.**

Tests, run by the person in the worktree:

```
$ python3 -m pytest tests/ -q
...........................                                              [100%]
27 passed in 0.31s
```

The adversary, at xhigh effort, at 22:50, returns one IMPORTANT finding:

```
### I1. A draft with no From header reads as inbound and is selected with an empty recipient
**Invariant claimed.** The target is the newest inbound human message; drafts are skipped.
**What is broken.** pick_recipient.py:38 skips drafts by checking `msg.is_draft`; an unsaved draft
in this mail store has no From header and is_draft unset, so it passes the inbound test (no
company sender) and is selected. The recipient assertion then sees an empty string, which is
neither a company address nor a no-reply, and passes.
**Reproduction.** Add a From-less message last in the fixture; target.recipient == "".
**Fix.** Treat a missing From as not selectable; assert the recipient is non-empty and parseable.
Prove red by removing the non-empty assertion.
```

Fixed in the same worktree; tests then all pass at twenty-eight; the second adversary round comes
back clean.

`/ponytail-review` is deliberately not run tonight. The person writes in the report: "quality pass
deferred to morning; adversary ran twice; the diff is forty-one lines." Skipping a step is allowed
when it is written down; skipping the adversary would not have been, since this is a send path.

**Where it goes wrong and how it is caught.** The first fix attempt, before the class question, was
a two-line patch to the ordinary reply path that the person nearly typed themselves at 21:50. The
grep showed three other callers with the same defect, and one of them, the recovery resend, had
already sent one of the two wrong replies. Closing only that one instance would have left the class
open. The adversary then found a second instance of the same class, the From-less draft, that the
builder's own mutation checks had not covered. Two layers, two catches.

**What lands.**

```
$ git log --oneline main..hotfix/pick-recipient
e8a1c47 fix(pick-recipient): reject From-less messages and empty recipients
71b3f0e test(pick-recipient): one case per outbound path, drafts, automated senders
c92ad55 fix(pick-recipient): select the newest inbound message, assert the recipient
```

The person merges to the release branch and deploys at 23:20, their own action rather than the
agent's, then un-pauses the sender. An `ERRORS.md` row:

```
| 2026-09-16 | critical | replies addressed to newest message, not newest inbound; two wrong sends; fixed c92ad55..e8a1c47 | mitigated |
```

And `/handoff` at 00:30, whose block names the deferred ponytail pass and "confirm with support
whether the two wrong replies need a correction sent" as the morning's first action, since that is
a send to a person outside the system and is never auto-proceeded.

**Time and numbers.** About two and a half hours from report to deploy. One function, four callers
closed at once, one worktree, three commits, twenty-eight tests, one adversary finding fixed, two
human gates, one ERRORS row, one deferred step written down.

## Habits the five scenarios share

Written from the person's side, since the rest of this document is not.

1. Say the size out loud before typing anything, and name the question that drove it (S1, S5). The
   size decides which of the six steps run; the harness cannot decide it for you.
2. The prompt you type is the spec. "Change nothing else" and "you own exactly these files" are not
   politeness; they are what you check the diff against (S1, S2).
3. You are the reviewer at small size; the adversary is the reviewer above that, and it sits at or
   above the builder's tier (S2, S5). Do not skip it to save the evening; skip the quality pass
   instead, and write that down (S5).
4. Read an adversary report by rank: fix BLOCKER and IMPORTANT before merge; file MINOR and NIT in
   NEXT_STEPS.md with the finding id (S2, S3).
5. A fix is a code change and re-enters the gate at the adversary step; re-run the suite yourself,
   with its real command, in the main checkout, before you call any gate closed (S3).
6. When a premise changes, stop before the next dispatch and list what just became unnecessary
   (S4). Sunk cost on a branch is not a reason to finish it.
7. Hard stops are done by a person: pausing production, deploying, anything that reaches someone
   outside the system (S3, S5). A parked branch is a success outcome, not a failure.
8. End every session that changed a file or made a decision with `/handoff`, and test the block by
   resuming from it alone (S4).
