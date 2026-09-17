# Anti-patterns

Every entry here is drawn from a failure this repository already records, not a hypothetical.
Each has the same four parts: what happened, what it cost, the rule it produced, and where that
rule lives in the code today, so you can go read the primary source rather than trust the summary.

## Contents

- [The orphaned resume block](#the-orphaned-resume-block)
- [Worktree green, main red](#worktree-green-main-red)
- [The premise that died mid-run](#the-premise-that-died-mid-run)
- [The long plan spent on dead surface](#the-long-plan-spent-on-dead-surface)
- [The timeout wrapper that faked a clean review](#the-timeout-wrapper-that-faked-a-clean-review)
- [Fixtures that pin both sides of an assertion](#fixtures-that-pin-both-sides-of-an-assertion)
- [Closing the instance instead of the class](#closing-the-instance-instead-of-the-class)
- [The report lost when a backgrounded agent goes idle](#the-report-lost-when-a-backgrounded-agent-goes-idle)
- [The fail-open scrub](#the-fail-open-scrub)
- [The rebind that did nothing](#the-rebind-that-did-nothing)
- [The shared exemption list](#the-shared-exemption-list)
- [The report that joined the set it was supposed to be scanned by](#the-report-that-joined-the-set-it-was-supposed-to-be-scanned-by)
- [The check that cannot fail is worse than no check](#the-check-that-cannot-fail-is-worse-than-no-check)

## The orphaned resume block

**What happened.** A resume file held a pasted-prompt block at the top and, below it, a long
section with everything the next session would need: state details, file inventories, open
questions. The block named four files to read first. It did not name the file it was sitting in.

**What it cost.** Pasting that block exactly as designed would have orphaned the entire lower half
of the document, because the pasted text is all the next session ever sees. Nothing in it said more
detail existed just below.

**The rule it produced.** A resume prompt's own block must name its own file in its own read list.
The user pastes only the block, never the document around it, so anything outside the block is
invisible unless the block says to go read that file.

**Where the rule lives.** [`docs/handoff-and-resume.md`](handoff-and-resume.md), the before/after where "the block names
four files but not the file it is sitting in", and `AGENTS.md`: "The pasted block must be
self-sufficient, including a pointer to its own file."

## Worktree green, main red

**What happened.** A gate ran clean for five consecutive rounds inside a worktree. The first full
run on the main checkout after merging came back with new failures. One was a repo-walking test
whose skip-list omitted a gitignored scratch directory that does not exist in a worktree at all.

**What it cost.** No amount of worktree-green could ever have caught it, because the worktree
literally does not have the tree the test walks. Local data that lives only in a gitignored
directory on the main checkout is invisible to every pre-merge run.

**The rule it produced.** Run the full suite, with the suite's real command, in the main checkout,
not just in the worktree. Expect the first post-merge run to differ from every pre-merge run and
treat that as part of the gate, not a formality.

**Where the rule lives.** `skills/autorun-plan/SKILL.md` ("2. Right-fit dispatch (custom agents/skills)").

## The premise that died mid-run

**What happened.** Mid-run, an operator disabled a component. The orchestrator noted it in state
("this makes that sender inert") and kept hardening a control whose only purpose was pausing that
exact component, for hours. A plan already in flight existed to retire that component, and a spike
earlier the same run had proven the replacement worked.

**What it cost.** Hours spent hardening something a parallel plan was about to delete. Noting a
premise change in state is not the same as acting on it.

**The rule it produced.** When any premise changes, stop before the next dispatch and ask what work
this makes unnecessary, what downstream requirements just lost their justification, and whether the
current in-flight work still earns its place. Sunk cost on a branch is not a reason to finish it.

**Where the rule lives.** `skills/autorun-plan/SKILL.md` ("5. Close-out").

## The long plan spent on dead surface

**What happened.** A large plan survived many review rounds and an approval. Nobody asked whether
the surface it improved was ever used. Execution spent hours hardening a control whose only purpose
was pausing a component the same plan was retiring. A later audit found roughly half the plan aimed
at inherited surface the operator had never run, including a phase to harden a batch runner whose
log directory held nothing but a `.gitkeep`.

**What it cost.** Review checks whether a requirement is correct, not whether its subject matter is
alive. Every requirement in that plan was locally well-argued, and the plan was still aimed at dead
surface for roughly half its length.

**The rule it produced.** Run a scope audit from runtime evidence before planning, not from a
README or the plan itself. A plan phase earns its place only if it touches something on the IN
SCOPE list; work aimed at OUT OF SCOPE surface is inherited maintenance, not improvement, no matter
how well-argued.

**Where the rule lives.** `skills/scope-audit/SKILL.md` ("Scope audit (what is this system, really?)").

## The timeout wrapper that faked a clean review

**What happened.** A reviewer CLI was wrapped in `timeout` to bound a review round. `timeout` does
not exist on macOS by that name, so the wrapper silently failed to run the reviewer at all,
producing a roughly 38-byte output file and exit 0, indistinguishable from a terse clean review if
you check file size instead of file content.

**What it cost.** A full review round, burned on output that never ran.

**The rule it produced.** Use `gtimeout` if present, or no timeout wrapper at all. Verify a
reviewer's output by its content and its verdict line, never by its size or its exit code alone. A
reconnect loop that keeps a file growing is a failed round too, not a slow one.

**Where the rule lives.** `skills/external-llm-review/SKILL.md` ("Harness traps that fake a verdict").

## Fixtures that pin both sides of an assertion

**What happened.** A test forced the same override onto both halves of a contract it was meant to
check, so the two sides could never disagree regardless of what the code under test actually did.

**What it cost.** A structurally blind test: it stays green even if the behavior it names is
deleted, because nothing in the fixture can produce a red result.

**The rule it produced.** A test that cannot go red is not a test. Prove each new assertion red by
a named mutation. Watch for a fixture that pins the same override on both sides of a contract, and
for a fixture that gives each sandbox its own copy of something that is global in production.

**Where the rule lives.** `agents/adversary.md` ("Sweep this taxonomy FIRST, then hunt freely") and `agents/exec-mechanical.md` ("Tests must be able to FAIL").

## Closing the instance instead of the class

**What happened.** Three separate review rounds found the same underlying defect by three
different routes. Each fix closed the one caller the round's ticket named and left the next caller
open, because nobody asked what surface the violated invariant actually ranged over.

**What it cost.** Three rounds of review time spent re-discovering one defect class instead of one
round closing it.

**The rule it produced.** Before writing a fix, name the invariant in one sentence, then enumerate
the full surface it ranges over (callers, subcommands, scope states, config states) as a
table-driven test, with every cell an expected verdict and every claimed exemption backed by its
own negative test.

**Where the rule lives.** `agents/exec-mechanical.md` ("When you fix a defect, close the CLASS, not the instance").

## The report lost when a backgrounded agent goes idle

**What happened.** A backgrounded review agent finished its work, but its final message never
reached the caller. The review had to be re-run from scratch.

**What it cost.** A full review, redone, for a result that already existed and was simply
unreachable.

**The rule it produced.** Write the report to a file before finishing, in addition to returning it
as the final message. Write an early stub and overwrite it as the review proceeds, so a review that
gets cut short still leaves findings on disk.

**Where the rule lives.** `agents/adversary.md` ("Write the report to a FILE before you finish").

## The fail-open scrub

**What happened.** A scan-based check can read an empty file list as "nothing to flag" instead of
"scanned nothing," which means running the gate from the wrong directory, or against a resolver
that silently returns zero paths, produces a clean result for a check that never actually ran.

**What it cost.** A fail-open scrub looks exactly like a passing one from the outside. The comment
above the gate's own file-list definition calls this out directly: an empty file list means
"scanned nothing," not "clean," and without a guard against it, running the gate outside a checkout
would turn most of its checks into permanent passes.

**The rule it produced.** Every check counts itself as run, and the run asserts at the end that the
expected number of checks actually executed. The set of files a check scans must assert a floor on
its own size, not just trust whatever the resolver handed back.

**Where the rule lives.** `verify.sh`: the header note that "A fail-open scrub looks exactly like a
passing one", and the guard that fails with "scanning nothing, not clean".

## The rebind that did nothing

**What happened.** The documented procedure for changing a model binding was to edit the config
file and re-run install. Editing the file and re-running install silently changed nothing, because
the installer skipped every file that was already present at the destination, and the config
binding only takes effect through files that get re-copied.

**What it cost.** A rebind procedure that looked correct in the docs and did not work in practice,
discoverable only by noticing the old model was still in effect.

**The rule it produced.** Files the installer owns (agents, skills, commands, hooks, the core
rules) are marked as managed and always replaced on reinstall, with any local difference backed up
first, specifically so that a one-line edit to the binding file takes effect on the next install.

**Where the rule lives.** `bin/harness`, the comment above `put()` that begins "MANAGED=1 marks
files this installer OWNS at user scope".

## The shared exemption list

**What happened.** Twice, a leak reached the gate green by way of an exemption written for one
check being reused by a second check that had no reason to share it: once when a documentation
exemption meant to let docs name models also silently exempted an absolute-path check, and again
when a second leak check reused an unrelated check's exemption and stopped looking at the one file
that check had a real reason to skip.

**What it cost.** Two separate leaks reaching a green gate. A comment saying "never widen this" did
not hold either time it happened.

**The rule it produced.** No exemption may be shared between checks. This is no longer a comment;
it is machine-checked: the gate scans its own source for every variable name containing `EXEMPT`
and fails if any of them is referenced from more than one numbered check.

**Where the rule lives.** `verify.sh`, the "gate integrity" block: every `EXEMPT` variable "may be
REFERENCED from at most one numbered check".

## The report that joined the set it was supposed to be scanned by

**What happened.** Agent report files default to a path under `runtime/verify/`, and that
directory was not gitignored. A report written there, naming the absolute worktree path it was
written from, joined the same file set the gate scans for leaked absolute home paths, and failed
the gate on output that was never meant to ship in the first place.

**What it cost.** A gate failure caused by the gate's own working files, not by the change under
review.

**The rule it produced.** Agent-authored output that only exists to report on a run, and is never
meant to ship, belongs in a gitignored directory. A verification pass has to distinguish "this is
part of the shipped set" from "this exists because an agent ran here."

**Where the rule lives.** `.gitignore:8-12` (see `git show aefe6d4`).

## The check that cannot fail is worse than no check

Several entries above are the same defect in different clothes: a fixture that pins both sides of
its own assertion, an exemption quietly widened until it covers the thing it was meant to catch, a
file-size proxy for a review that never ran. Each one passes for a reason that has nothing to do
with whether the thing it claims to verify is true, and each one is trusted exactly because it is
green.

Its inverse happened here too: a check that failed on the wrong input, when agent report output
that was never meant to ship landed in a directory the gate scanned by default (see "The report
that joined the set it was supposed to be scanned by," above). A check that fires on noise erodes
trust in the same direction as one that never fires at all: either way, the next person stops
reading what it says and starts routing around it.

The shared discipline underneath every entry above: prove a check can go red before trusting that
it stays green. A named mutation that should flip the result, a fixture where the two sides can
actually disagree, an assertion that counts what actually ran instead of assuming it did.
