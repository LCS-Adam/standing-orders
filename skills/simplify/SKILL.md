---
name: simplify
description: Quality-only review of a wave diff after the correctness review - reuse what exists, remove over-engineering, fix wrong altitude. Applies fixes. Never a bug hunt and never a substitute for the adversary step.
when_to_use: after the adversary correctness review has passed on a wave diff, before the external-LLM fold-back loop
version: 1.0.0
---

# Simplify (quality-only pass)

Runs after `adversary` has cleared a diff for correctness. This step never hunts bugs and never
substitutes for that review - it assumes the diff is correct and asks only whether it is the
smallest correct diff.

## The reuse ladder

Applied top-down; stop at the first rung that holds. Rungs 2 to 5 restate `AGENTS.md:10-14`;
rung 1 is this skill's own.

1. Does this need to exist at all? Speculative code with no current caller - cut it.
2. Is there already a helper, type, or pattern a few files over? Reuse it instead of a parallel one.
3. Does the standard library already do this?
4. Does an already-installed dependency already do this?
5. Only then: the minimum new code that is correct.

Within that ladder, look for: duplicated logic that should call one shared path, an abstraction
built for one caller, boilerplate carried "for later," and code operating at the wrong altitude
for its job (business logic in a config file, a one-line check wrapped in a class).

## What this does NOT do

- Find bugs. That is the `adversary` step; if something looks wrong, flag it back to that step
  rather than patching around it here.
- Add features, tests, or abstractions the wave did not already need.
- Re-review correctness, security, or behavior. Structure and size only.
- Replace or skip the adversary pass. This step runs after it, never instead of it.

## Output format

- **Applied simplifications**: each as a one-line diff summary (file, what shrank, why).
- **Left alone and why**: anything that looked simplifiable but has a reason it is not (a
  documented ceiling, an exemption, a caller this pass did not check).

## Re-entry rule

Any change this step makes is a code change: it re-enters the wave's gate stack at the
correctness step (`adversary`), never skips straight to merge.
