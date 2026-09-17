---
name: readonly-healthcheck
description: Write or run a read-only health check that inspects a system and never changes it, emitting one PASS/FAIL verdict over per-probe evidence so a person and a scheduler can both read it. Use before a change as a preflight, after one as confirmation, or on a timer. Not for anything that fixes what it finds; a check that can also repair cannot be trusted to report honestly.
---

# Read-only health check

A health check earns its place by being safe to run at any moment, which means it inspects and
never mutates. That single property is what lets you run it before a change and after one and
compare the two outputs, and it is what makes it safe to put on a timer.

## The shape

**Refuse to run as the wrong identity.** Resolve what you are checking as the account that owns it.
A check run from a different account can pick up a different binary on a different PATH, or a
different config file, and report drift that does not exist. Make this the first probe and exit
non-zero when it fails, rather than producing a confident wrong answer.

**One verdict, then the evidence.** Print a single machine-readable line first (`HEALTH: PASS` or
`HEALTH: FAIL`), then a structured record of every probe including the ones that passed. The
verdict is what a scheduler or an autonomous loop reads. The per-probe evidence is what a person
reads at 2am when the verdict is FAIL and the only question is which part.

**Exit non-zero when any probe fails.** A scheduler cannot parse prose. If the check is worth
running unattended, its exit status has to carry the answer. Use distinct non-zero codes when the
caller needs to tell failure classes apart.

**Every probe states its expected value.** `PASS gateway-bind bind=loopback` is a probe. `PASS
gateway-bind ok` is a claim. The first lets a reader disagree with you; the second does not.

## The three ways a health check lies

These are the reason to write one carefully rather than quickly.

**A skipped probe reported as a pass.** The probe could not reach the thing it was checking, and
said nothing. Every probe must distinguish "checked, and it is as expected" from "could not
check", and the second is a FAIL. A check that cannot fail tells you nothing on the day it matters.
`docs/anti-patterns.md` records this as the fail-open scrub.

**Stderr discarded when stderr was the evidence.** Appending `2>/dev/null` to a probe whose failure
mode is a permission error deletes the only signal that the probe was denied. Never silence a probe
whose error output is what you are actually testing for.

**A command that exits zero having done nothing.** Some tools report success on a match while every
underlying operation was refused. Pair any probe like that with a separate confirming observation,
and treat the confirmation as the real oracle.

## Writing one

Start from the commands you already retype by hand every time you touch the system. Those are the
probe battery. For each, write down the expected value before you write the check, because a probe
whose expectation you derive from the current output can only ever pass.

Keep the deterministic part out of the model. A check made of fixed commands and fixed expectations
should ship as a script the scheduler runs directly. Reserve the model for interpreting a failure,
not for performing the check, so the scheduled path stays reproducible and cheap.

State what the check does not cover. A posture check confirms configuration; it does not prove the
system is uncompromised, and a report that does not say so invites a reader to over-trust it.

## Where this fits

`docs/finishing-a-build.md` lists a smoke check on the operator's deploy checklist and describes
this shape in its Deploy section. The harness ships no deploy tooling, because that is specific to
a host and a CI system in a way a portable framework cannot verify. This skill is the shape, not
the tooling.
