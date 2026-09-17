---
name: version-drift-check
description: Check whether an installed dependency has a newer release, classify the size of the bump, and stop. Resolves installed versus latest, records a snapshot a later upgrade can roll back to, and exits with a code a scheduler can gate on. Never installs, upgrades, restarts, or edits config; applying an upgrade is a separate attended decision.
---

# Version drift check

The valuable half of an upgrade is knowing an upgrade exists. That half is fully mechanical, safe
to schedule, and safe to run unattended. The other half, deciding to apply it, is a judgment call
with a blast radius, and keeping the two apart is the entire point of this skill.

## Hard guard: check mode only

This skill resolves, classifies, records and reports. It does not install, upgrade, restart a
service, or write configuration. If asked to apply what it found, refuse and hand the decision back
with the evidence. `AGENTS.md` puts deploying and modifying production on the hard-stop list, and an
unattended runner is exactly the wrong place to quietly cross one.

## Procedure

**Resolve as the owner.** Read the installed version as the account that actually runs the
software. Another account's PATH can resolve a different or stale copy of the same tool, which
produces a drift alarm about a binary nobody is running.

**Resolve the latest release read-only.** Query the registry or index with a command that only
reads. Record which source you asked, because "latest" differs between a registry, a distribution
channel, and a project's own release page.

**Classify the bump.** Equal, patch, minor, or major, from comparing the two versions. The class is
what decides how much review the apply deserves, so report it rather than reporting only that a
newer version exists. Flag a major bump as needing a breaking-change review.

**Snapshot before you report.** Write down, read-only, what the current state is: version, the
resolved binary path, config path and modification time, service labels. A later upgrade needs a
rollback reference, and the moment to capture it is while the system is still known-good.

**Exit with a code, not a sentence.** Zero when up to date, a distinct non-zero when a bump is
available. A scheduler detects "action pending" without parsing prose.

## Output contract

One machine-readable verdict line (`DRIFT: UP_TO_DATE`, `PATCH`, `MINOR`, or `MAJOR`), then a
structured record carrying installed, latest, class, and the snapshot path.

## What can still go wrong

The check trusts the registry to report a truthful latest release. A yanked or compromised release
would be reported as available. That is survivable only because this skill proposes and never
applies, and the attended review before an upgrade is the backstop. Say so in the report rather
than implying the proposal is vetted.

A notification that failed to send must never read as "up to date". The durable signals are the
exit code and the snapshot file, not the message.

## Where this fits

Pair it with `readonly-healthcheck`: drift tells you a change is available, the health check tells
you the system is in the state you think it is, both before and after you decide to apply one.
