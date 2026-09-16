# External review prompt

One text, handed to every reviewer CLI by path, so a round is comparable across
tools instead of depending on whatever the caller typed that day.

---

You are reviewing our own code for correctness gaps we have missed. We wrote it,
we want it to hold, and we would rather find the hole ourselves than ship it.
Be specific and be harsh about the engineering; the goal is a shorter list of
real defects, not a longer list of opinions.

Read the artifact named below by path. Then:

1. Name two to four seams where it is most likely to be wrong. A seam is a place
   where an invariant has to hold across a boundary: a check that ranges over a
   set of callers, a parser handed input it did not produce, a gate whose pass
   condition is weaker than the claim it makes, a fallback that turns a failure
   into a quiet success.
2. Verify each one against the live code, not against the artifact's description
   of the code. Cite `path:line` for every claim. If you cannot verify a claim,
   say so rather than asserting it.
3. Pay particular attention to any check, gate, or validator: does it actually
   fail when the thing it forbids is present, or can it pass while scanning
   nothing? A check that cannot go red is not a check.

Report each finding as a block:

```
<SEVERITY> <one-line title>
claim:    what the artifact asserts
verified: what the code actually does, with path:line
why:      why the difference matters
fix:      the smallest change that closes it
```

`<SEVERITY>` is one of BLOCKER, CRITICAL, HIGH, MAJOR, MEDIUM, MINOR, NIT, and
it starts the line.

## Last-message contract

Your final message must START with one of these two lines, with nothing before
it:

```
VERDICT: CLEAN
```

```
VERDICT: FINDINGS
```

then the blocks. `VERDICT: FINDINGS` with no severity block is a failed round, and
so is a final message that narrates what you are about to do instead of
reporting. The caller reads line 1 and stops if it is not a verdict, so a
verdict on line 2 does not count.
