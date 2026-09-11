---
name: scope-audit
description: Use BEFORE planning or improving an existing system - to establish from runtime evidence which parts are actually used, so no plan spends effort on dead surface. Also use when a plan feels too big, when a repo is a fork or inherited codebase, when work keeps expanding, or when asking "do we even need this?". Produces a normative IN SCOPE / OUT OF SCOPE document that later filters every proposed phase.
version: 1.0.0
user-invocable: true
argument-hint: "[the system or repo to scope]"
tools: Bash, Read, Grep, Glob, Write
---

# Scope audit (what is this system, really?)

**The failure this prevents.** A 2,695-line plan survived 32 review rounds and an approval, and
nobody asked whether the surface it improved was ever used. Execution then spent hours hardening a
control whose only purpose was pausing a component being retired by that same plan. Later audit found
roughly **half the plan aimed at inherited surface the operator had never run** — including a phase
to harden a batch runner whose log directory contained nothing but a `.gitkeep`.

**Why review did not catch it.** Every requirement was locally well-argued. Review checks whether a
requirement is *correct*, not whether its *subject matter is alive*. Those are different questions,
and only one of them is answered by reading the plan.

**Run this BEFORE planning.** It is cheap (under an hour), and it is the highest-leverage hour
available on any inherited, forked, or long-lived system.

## The governing rule it produces

> **A plan phase earns its place ONLY if it touches something on the IN SCOPE list.**
> Work aimed at OUT OF SCOPE surface is inherited maintenance, not improvement of the thing that
> matters — drop or defer it regardless of how well the plan argues for it.

## Method — evidence over documentation

**Never conclude from a README, a mode table, or the plan itself.** Those describe intent. You need
artifacts that only exist if code actually ran.

### 1. Find the real entry points

What can start work without a human typing it, and what does a human actually invoke?

```bash
launchctl list | grep -i <project>        # macOS scheduled jobs
crontab -l; systemctl list-timers         # other platforms
```
Then read each entry point and follow it to what it invokes. Note the trigger condition precisely —
"fires on a file landing in X" is very different from "fires daily."

### 2. Look for runtime residue (the decisive evidence)

For each subsystem, name an artifact that **exists only if it ran**, then check:

- a history/state file the feature writes (`*-history.tsv`, `*-log.md`, a cache)
- a log DIRECTORY with actual logs in it, not just a `.gitkeep`
- output the feature produces (reports, generated files) and their dates
- its own config file — **a feature with no config has never been configured, let alone run**

Absence is the strongest signal available, and the strongest form of it is a PAIR: when a feature's
run-history artifact is missing AND the config file it requires is missing, that feature is not idle,
it is **unconfigured and cannot run** — which is a far stronger claim than "nobody used it lately."
Look for that pair specifically; either half alone is weaker.

### 3. Map reachability

For each mode/module/doc, ask what live code references it:

```bash
for f in modes/*.md; do b=$(basename "$f" .md)
  hits=$(grep -rl "modes/$b.md" <live-entry-dirs> 2>/dev/null | wc -l)
  [ "$hits" = "0" ] && echo "ORPHAN: $b"
done
```
Follow references transitively — a file reached only via another orphan is also an orphan, and a file
reached from a live mode is in scope even if nothing references it directly.

### 4. Check whether guards are already enforced structurally

Before proposing a rule, check whether the deployment already enforces it. In the source case the
operator's "never auto-fetch a job description" rule was **already impossible** — the permission
files denied the fetch tools outright. The prose ladder survived in unreachable documentation.
**A structural denial beats a proposed rule; find it before specifying work.**

### 5. Size the blast radius

Measure what "the data" actually is. Recovery ceremony should be proportionate to it.

```bash
du -sh <data dirs>; find <dir> -type f | wc -l; git ls-files <path> | head
```
"58 markdown files, 328 KB, a sub-second `cp -R`" is a different engineering problem from a database,
and it invalidates journal/preimage/rollback contracts written as though it were one.

## The output document

Write a durable scope file (e.g. `.project-state/SCOPE-<system>.md`) with:

1. **IN SCOPE** — entry points and their triggers; the data that IS the system (with sizes); the code
   actually on the path, grouped by role.
2. **OUT OF SCOPE** — each item with **the evidence it has never run**, stated as a fact, not a
   judgement.
3. **Already-enforced guards** — rules the deployment satisfies structurally, so nobody specifies
   work to add them.
4. **What this means for the plan** — a phase-by-phase verdict for anything targeting dead surface.
5. **The rule** (quoted above), so later sessions apply it without re-deriving it.

## Dormant is not deleted

Say so explicitly. Unused surface may become relevant when circumstances change — in the source run, a
whole subsystem was dormant only because the current inbound workflow made it unnecessary, and a shift
back to the other workflow would have made it load-bearing again. **This audit removes planned
EFFORT, not code.** Name the condition that would revive each dormant area.

## Also audit PREMISES, not just usage

Requirements rest on premises, and premises rot. For each expensive requirement, trace it back:

- **What must be true for this to be needed?**
- **Is that still true today?**

Watch for premises falsified by *the plan's own other half* — the source case built a pause control
for a component that a merged sibling plan existed to retire. Also watch for a component being
disabled mid-flight: when the operator turns something off, immediately ask **what work that
justifies is now dead**, rather than noting the fact and continuing.

## Do NOT

- Conclude a thing is used because documentation describes it.
- Conclude a thing is unused because you cannot find a caller — check transitive reachability first.
- Propose deleting code. This audit governs EFFORT.
- Skip the counter-list: name what looks dead but is load-bearing. The drop list is only credible
  when the keep list is honest.
- Relax anything that can cause an irreversible external effect (a sent message), corrupt a record
  without an easy rebuild, or **fail silently** — regardless of how quiet the deployment is.
