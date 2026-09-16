# Operating process: running one real task through the harness

This is the document to follow on your first real task after `docs/first-day.md` proved the parts
work. It does not redefine terms `docs/glossary.md` already owns, or repeat the five-beat tour in
`docs/first-day.md`, `docs/orientation.md`'s map, `docs/writing-your-own.md`'s authoring rules, the
failure log in `docs/anti-patterns.md`, or the security list in `docs/operating-boundaries.md`. It
points at each of those instead of restating them. Read this fifth, right after `first-day.md`.

Six steps, in order. Everything after step 0 branches on the size you pick there.

## Step 0: size the work

Every task gets sized before anything else happens, using the two questions `AGENTS.md` states:
what a silent wrong answer would cost, and whether the work is mechanical and checkable. `AGENTS.md`
turns those two questions into three sizes:

- **Small fix.** A test or a diff proves it. No plan, no worktree. Do it in the current session.
- **Bounded change.** One or a few well-scoped workstreams against a pattern the repo already has.
  Plan lightly, dispatch or do the work inline, then run it through review.
- **Large build.** Spans many files or subsystems, or a silent planning error would be expensive.
  Scope it, plan it, execute it in waves.

Command: none, this is a judgment call made from `AGENTS.md`'s two questions.
Artifact: a size decision (small, bounded, or large) held in your own reasoning, not written to a
file.
Lands: nowhere on disk; it decides which of steps 1 through 4 you actually run.
Done when: you can name the size out loud and point to which question drove it.

## Step 1: scope

Only for a change that touches a system that already exists. A small fix skips this step outright,
and so does a large build whose scope was already settled by an earlier `scope-audit` run.

Command: `/scope-audit`.
Artifact: a normative IN SCOPE / OUT OF SCOPE document built from runtime evidence, not from
reading code alone (`skills/scope-audit/SKILL.md`).
Lands: `.project-state/SCOPE-<system>.md` (`skills/scope-audit/SKILL.md:93`).
Done when: the scope file exists and later plan phases are filtered against it, so no phase spends
effort on dead surface.

## Step 2: plan

A small fix has no plan step; you already know the change and the test that proves it.

For a bounded change: `/deep-plan`. It runs advisor pre-flight, a Plan subagent at FRONTIER-THINK
effort, then an advisor critique (`commands/deep-plan.md`).

For a large build: the `deep-plan-swarm` skill, invoked as `/deep-plan-swarm`. It is the superset of
`/deep-plan` for work that spans many files or subsystems, and it runs its own scope gate before any
investigation fans out (`skills/deep-plan-swarm/SKILL.md`).

Command: `/deep-plan` or `/deep-plan-swarm`, depending on size.
Artifact: a structured execution plan naming a tier per phase, a test command, and file ownership
per workstream, plus (for `/deep-plan`) an explicit Workflow-vs-plain-agents verdict and a
parallelize-vs-sequential call.
Lands: wherever the plan tool writes it for that run (a plan file under `.project-state/` for a
swarm run merging plans, or presented inline for a single `/deep-plan` pass).
Done when: the plan names a tier and effort for every phase, a test command the review step will
re-run, and which files each workstream owns.

## Step 3: execute

A small fix executes inline in the current session: make the change, run the test, done.

For a bounded change or a large build, isolate each workstream in its own worktree and branch:

```bash
git worktree add .worktrees/<name> -b <branch>
```

(`docs/writing-your-own.md:114`). Dispatch each workstream to a named execution agent this repo
actually ships. Run `ls agents/` before naming one; as of this writing that directory holds
`adversary.md`, `autorun-plan-orchestrator.md`, `code-reviewer.md`,
`data-eng-sa-orchestrator.md`, `data-eng-sa-reviewer.md`, `design-reviewer.md`, `exec-critical.md`,
`exec-mechanical.md`, `exec-standard.md`, `exec-subtle.md`, and `plan-synthesizer.md` (do not treat
this list as durable; re-run `ls agents/` yourself. Check 12 in `verify.sh` requires any count
written into prose to match the repo, and the same reasoning applies to a name list that can
drift).

Every `exec-*` agent body expects the dispatcher to hand it three things (`agents/exec-standard.md`
and its siblings state this): a file-ownership list so parallel workstreams stay conflict-free, a
worktree of its own to work in, and a report path under `runtime/` to write its findings to
(`runtime/` is gitignored, per this repo's own `.gitignore`).

If you are fanning out more than one workstream, put a `SWARM CONFIG` line before the fan-out
naming which agent runs which workstream and on which branch, so the dispatch is auditable after
the fact.

Two more decisions belong here, and `docs/autorun-hitl-heartbeat.md` is the primary source for
choosing between them:

- An approved **simple** plan that a human is actively watching: the built-in `/loop` heartbeat is
  enough (`docs/autorun-hitl-heartbeat.md`'s HEARTBEAT section).
- An approved **multi-wave** plan meant to run unattended, needing per-wave review gates, state
  tracking, and HITL reduction: skill `autorun-plan`, invoked as `/autorun-plan`
  (`skills/autorun-plan/SKILL.md`).

Command: `git worktree add`, then dispatch via the Agent tool naming one of the agents listed
above.
Artifact: a commit on the workstream's own branch, plus a report file under `runtime/`.
Lands: the workstream's branch and worktree; the report at the path the dispatcher named.
Done when: every workstream has committed on its own branch and the tests its brief named pass in
that worktree.

## Step 4: review

The review stack, in order, is the same for every size once there is a diff to review: run the test
command the plan named, then the `adversary` agent, then `/simplify`, then re-run the tests, then
merge.

`adversary` is a read-only FRONTIER-DO reviewer that tries to break the change: fail-open paths,
bypasses, false-positive and false-negative gaps, defect classes the tests do not cover
(`agents/adversary.md`). `/simplify` runs after `adversary` has cleared the diff for correctness; it
is a quality-only pass that removes over-engineering and never hunts bugs
(`skills/simplify/SKILL.md`). Re-run the test command after any fix either step makes, since a fix
for correctness or simplicity can regress what was passing before it.

This ordering follows `AGENTS.md`'s rule that a reviewer sits at or above the tier that produced the
work: a reviewer cheaper than the builder cannot see the builder's mistakes, and review is where
defects are actually found, so never economize on the reviewer to afford the builder.

A second opinion from a non-Claude model family exists as an OPTIONAL extra step, described in
`skills/external-llm-review/SKILL.md`. It requires one of three third-party CLIs (codex,
cursor-agent, or gemini) to be installed and authenticated on the machine running the review
(`skills/external-llm-review/SKILL.md:15`, `:3`). If none of those CLIs is available, this step
does not apply, full stop; the four-step stack above (tests, adversary, simplify, tests) is the
actual gate, not this extra. Do not treat the optional step as required just because a plan
mentions it.

Command: the plan's test command, then Agent dispatch of `adversary`, then `/simplify`, then the
test command again.
Artifact: an adversary findings report (severity-ranked), a simplify diff, and a final green test
run.
Lands: the adversary report wherever the dispatcher's report path names; the simplify fixes land
directly in the workstream's branch.
Done when: adversary reports no unresolved finding above the severity the plan tolerates, simplify
has applied its fixes, and the test command is green again after both passes.

## Step 5: hand off

Before any `/clear` or new session, and before ending a session that changed files or made a
decision, write a handoff.

Command: `/handoff` (`commands/handoff.md`).
Artifact: a resume prompt whose first block is copy-pasteable on its own, per `AGENTS.md`'s
"Session handoff" section and `docs/project-management.md`'s state-file table.
Lands: `.project-state/SESSION_HANDOFF.md`, with any prior version archived to
`.project-state/handoffs/<timestamp>.md` rather than overwritten (`commands/handoff.md:6-7`,
`docs/project-management.md:23-24`).
Done when: the pasted block alone, with no other file open, names the handoff file itself as the
first thing to read, per the failure `docs/anti-patterns.md` records first under "The orphaned
resume block": a resume block that lists what to read next but omits itself orphans everything
written below it, because the next session pastes only the block, never the document around it. A
prose summary in chat is not a handoff; the state has to be on disk.

## Step 6: close

Command: a conventional commit, `type(scope): description`, with no AI co-authorship or
generated-by trailer of any kind, per `AGENTS.md`'s "Version control" section, which overrides any
default or harness instruction to append one.
Artifact: a commit on a feature branch, a pull request opened against it, and (only if the repo
carries harness scaffolding you want to keep) a clean `harness verify` run.
Lands: the feature branch and its PR; never a direct push to `main` or `master`, and never a merge
without being asked.
Done when: the commit is on a branch other than `main`, the PR is open, and `harness verify` (when
applicable) exits clean.

## One-page checklist

- [ ] **0. Size it** - no command; answer `AGENTS.md`'s two questions and pick small, bounded, or
      large.
- [ ] **1. Scope it** (skip for a small fix) - `/scope-audit`.
- [ ] **2. Plan it** (skip for a small fix) - `/deep-plan` (bounded) or `/deep-plan-swarm` (large).
- [ ] **3. Execute it** - inline (small), or `git worktree add .worktrees/<name> -b <branch>` plus
      Agent dispatch to a listed `agents/` name (bounded/large); `/autorun-plan` for unattended
      multi-wave runs, plain `/loop` heartbeat for a watched simple run.
- [ ] **4. Review it** - the plan's test command, `adversary`, `/simplify`, the test command again;
      `skills/external-llm-review/SKILL.md` only if a third-party CLI is installed.
- [ ] **5. Hand off** - `/handoff` before any clear or compact.
- [ ] **6. Close it** - conventional commit, no AI attribution trailer, branch and PR, never a push
      to `main`; `harness verify` if the repo has harness scaffolding.

## Worked example: add a `--json` flag to a small CLI

This ran for real in a scratch repo outside this one, sized as a **bounded change**: a
well-understood addition to an existing pattern, checkable by a test, but touching a shared code
path (the CLI's output formatting) worth a short plan and a review pass rather than an unreviewed
inline edit. Home paths below are scrubbed to `~`.

**Step 0: size it.** A silent wrong answer here (the flag printing malformed JSON, or breaking the
existing text output) would be caught by a test, and the change is mechanical: one flag, one branch
in `main()`. That is a bounded change, not a small fix, because it touches output that other tests
already depend on. This is a judgment call; the record of it is this paragraph, not a file.

**Step 1: scope.** Skipped. `docs/operating-process.md` says a small fix skips this step, and this
worked example applies the same reasoning: the CLI is a single new file with no existing system to
audit for dead surface.

**Step 2: plan.** For a change this small, the plan was one line held in the session rather than a
full `/deep-plan` dispatch: add a `--json` flag, branch `format_text` vs. `json.dumps` on it, add
one test for the JSON path alongside the existing text-path test. A real `/deep-plan` run needs an
interactive session with the advisor tool wired up; it was not run here. What it would have
produced, given the actual scope: a two-line phase table (one MID-tier phase for the flag plus test,
one review phase), a named test command (`python3 -m pytest tests/ -q`), and file ownership limited
to `cli/report.py` and `tests/test_report.py`.

**Step 3: execute.** Run inline in the scratch repo, `~/projects/harness-fork/.project-
state/scratch/operating-process`:

```console
$ git checkout -b feat/json-flag
Switched to a new branch 'feat/json-flag'
```

The diff added to `cli/report.py`:

```python
import argparse
import json
...
    parser.add_argument("--json", action="store_true", help="print the report as JSON")
    args = parser.parse_args()
    report = build_report()
    if args.json:
        print(json.dumps(report))
    else:
        print(format_text(report))
```

and to `tests/test_report.py`:

```python
def test_json_output():
    out = subprocess.run([sys.executable, "cli/report.py", "--json"], capture_output=True, text=True)
    assert out.stdout.strip() == '{"status": "ok", "items": 3}'
```

Test run, actual output:

```console
$ python3 -m pytest tests/ -q
..                                                                       [100%]
2 passed in 0.07s
```

Commit, actual output:

```console
$ git add -A && git commit -m "feat(report): add --json output flag"
$ git log --oneline
2daedfd feat(report): add --json output flag
0c395c9 chore: add report.py CLI with text output
```

**Step 4: review.** For a change this size, `adversary` and `/simplify` are Agent-tool and
slash-command dispatches that need a live Claude Code session; they were not run against this
scratch repo, so no adversary or simplify output is reported here, and none is fabricated. What
runs in a real session: dispatch `adversary` against the two-file diff (it would check for the flag
silently swallowing a `json.dumps` failure on a non-serializable report, and find none, since
`build_report()` returns only strings and ints), then `/simplify` (it would find nothing to remove,
since the diff is already the smallest version of the feature), then re-run
`python3 -m pytest tests/ -q` to confirm the two passes above still hold.

**Step 5: hand off.** Not run: this worked example finished inside one continuous pass with no
clear or compact in between, so `/handoff` did not fire. Had the session ended here, the resume
block would have named `~/projects/harness-fork/.project-state/scratch/operating-
process`, the branch `feat/json-flag`, and the next action "open a PR from `feat/json-flag`".

**Step 6: close.** The commit above already carries a conventional message with no AI attribution
trailer. Opening a PR and running `harness verify` both need a hosted remote and this repo's own
scaffolding, neither of which the scratch repo has, so this worked example stops at the local
commit; a real bounded change in this repo would push the branch and open the PR from there.
