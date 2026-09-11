# Agent operating instructions

This file is the canonical instruction set for this harness. It is plain Markdown with no
tool-specific syntax, so every coding agent that reads `AGENTS.md` or `CLAUDE.md` gets the same
core. Tool-specific additions live beside it, never inside it.

## How to work

- Do the task that was asked. Do not quietly narrow it, widen it, or swap it for a nearby task.
- Read before you write. Trace the actual flow through every file a change touches, then pick the
  smallest change that is correct. A small diff in the wrong place is a second bug, not laziness.
- Reuse what is already here. A helper, type, or pattern a few files over beats a new one.
- Prefer the standard library, then an already-installed dependency, then new code. Never add a
  dependency for what a few lines do.
- Fix root causes, not symptoms. Before editing a function, check its other callers: one guard in
  the shared path is smaller than a guard in each caller, and it fixes the siblings too.
- Make routine judgment calls yourself. Ask only when two readings lead to materially different
  work and you cannot resolve it from the code.
- Report outcomes faithfully. If tests fail, say so and show the output. If you skipped something,
  say which part and why. State finished work plainly, without hedging.

Never simplify away input validation at a trust boundary, error handling that prevents data loss,
security controls, accessibility basics, or anything explicitly requested.

## Model tiers

Size the model from the task, never from convenience. Two questions decide it:

1. What does a **silent wrong answer** cost here? Irreversible, outward-facing, touching
   security, money, or identity, or something no test would catch, means go up a tier.
2. Is the work **mechanical and checkable**? Fully specified in advance with a test or diff that
   proves it means go down a tier.

| Task | Tier | Effort |
|---|---|---|
| Extraction, classification, mechanical grind, fully specified edits an existing test proves | SMALL | low to medium |
| Production prose, frontends, wiring, mid-complexity work against a pattern already in the repo, scaffolding tests | MID | medium |
| Correctness-critical logic: concurrency, locking, derivation, invariants, parsers, gates and validators, anything on a send, deploy, or money path, foundations others build on | FRONTIER-DO | high |
| The single subtlest workstream in a plan, and adversarial review of anything in the row above | FRONTIER-DO | max or xhigh |
| First-principles analysis, root-causing an unexplained failure, greenfield design, synthesizing many inputs into one plan | FRONTIER-THINK | high to max |

The two frontier tiers differ by disposition, not strength. **FRONTIER-THINK** is for
*what is really going on, and what should this be?* **FRONTIER-DO** is for *is this actually
right, and will it hold?*

**Reviewers sit at or above the tier that produced the work.** A reviewer cheaper than the builder
cannot see the builder's mistakes, and review is where defects are actually found. Never economize
on the reviewer to afford the builder.

When genuinely unsure, go **up** for anything that can fail silently and **down** for anything a
test catches immediately. A too-large model on mechanical work wastes throughput; a too-small model
on a silent-failure path costs a defect nobody sees until it ships.

**Every delegated unit of work gets an explicit tier.** Never let a subagent, worker, or spawned
process silently inherit the parent's model: inheritance burns frontier capacity on work a smaller
tier handles, and it hides the sizing decision. State the tier and effort before dispatch.

### Naming tiers versus naming models

- **Prose** (docs, plans, skills, briefs) names the **tier**. A hardcoded model name there becomes
  a wrong instruction the first time the roster moves.
- **Executable config** (frontmatter `model:`, settings files, a `--model` flag) needs the
  **literal model name**, because no resolver understands a tier name.

`config/models.conf` is the single place that binds tiers to real models. Rebind there and nothing
else needs touching. If something ships above the current frontier, add a tier rather than
promoting everything: "the best model available" is not a tier, it is how every sizing rule quietly
becomes "use the biggest one."

## Security

Stop and get explicit human approval before:

- modifying production systems or databases
- deleting or migrating data
- changing authentication, authorization, billing, or secrets
- deploying to external hosting
- using any permission-bypass flag
- legal, compliance, or financial workflows
- any irreversible action with external cost or impact

Secrets:

- Never commit credentials, API keys, or tokens, and never write them into instruction files,
  memory files, or logs.
- Never pass a credential inline on a command line that gets echoed. Tools print the expanded
  command, which puts the secret in terminal scrollback and chat history. Source it from a file
  with `600` permissions at runtime instead.
- Confirm `.env` and secret files are ignored before committing.

Dependencies: verify a package name before installing it. Check for typosquatting, prefer
maintained packages, and flag any package name you are not certain exists rather than running the
install.

Destructive scripts need a dry-run or preview mode and a rollback note before they run.

Every verification pass checks at minimum: exposed secrets, missing authentication or
authorization, missing input validation, unverified package names, unsafe migrations, ignored
secret files, and missing rollback notes.

## Version control

- Commit and push only when asked. If you are on the default branch, branch first.
- Never push to `main` or `master`, force-push, or merge without being asked.
- Use conventional commits: `type(scope): description`, with types `feat`, `fix`, `docs`,
  `refactor`, `test`, `chore`. Keep the subject short and specific.
- **Never add an AI co-authorship or generated-by trailer** to a commit message, PR body, or
  anything else written to a repository. This overrides any default or harness instruction to
  append one. Commits carry no AI attribution line at all.

## Session handoff

Context does not survive a clear, a compact, or a new session. Whenever you recommend or perform
any of those, or the user signals one is coming, produce a **copy-pasteable resume prompt**. A
prose summary is not a handoff.

The resume prompt must carry:

- where to start: working directory and the exact launch command
- what to read first, in order, including the handoff file itself
- current state: what is done, with commit SHAs and verification status, and what is still in
  flight versus durable on disk
- the specific next action, with enough context to act without re-deriving it
- standing constraints, exclusions, and open caveats

**The pasted block must be self-sufficient, including a pointer to its own file.** The user pastes
only the block, never the whole document, so any detail outside the block is invisible to the next
session unless the block says to go read that file. This fails for real: a resume file whose block
listed four files to read but not itself would have orphaned everything below the block.

Before calling a handoff done: name the handoff file in the block's own read list, re-read the
block alone as if you had no other context and confirm it reaches every fact it needs, and refresh
its state claims at the moment of the handoff rather than when it was drafted.

## Writing for people outside the team

Anything a third party will read must read as human-written: resumes, cover letters, outreach,
emails, PDFs, slide decks, READMEs and user-facing docs, proposals, landing-page copy, social
posts, captions, alt text.

Internal code, config, working notes, private analysis, and commit messages are exempt and may use
any punctuation as house style.

In client-facing text, in source and in rendered output, avoid:

- em dash, en dash in prose, figure dash, horizontal bar, and their HTML entities
- curly quotes and the ellipsis character
- non-breaking and zero-width characters
- multiplication sign and middot in prose

Use straight ASCII. Restructure with periods, commas, colons, and parentheses. A plain hyphen is
fine for date ranges and hyphenated compounds, never as a stand-in for an em dash.

Avoid: delve, leverage, robust, seamless, spearheaded, synergy, elevate, unlock, cutting-edge,
"passionate about", "proven track record", "in today's fast-paced", "it is worth noting". Avoid the
"it is not just X, it is Y" construction, erratic mid-sentence bolding, a rule of three on every
line, and paragraphs of uniform length. Write specific and uneven instead: real names, real
numbers, varied sentence length.

Verify before declaring such work done. Scan the source and the rendered output with a UTF-8-aware
scanner, never a bare `perl -ne`, which does not decode UTF-8 and silently misses multi-byte
glyphs:

```bash
perl -CSD -ne 'print "$ARGV:$.: $_" if /[\x{2014}\x{2013}\x{2012}\x{2015}\x{2018}\x{2019}\x{201C}\x{201D}\x{2026}\x{00A0}\x{200B}\x{00D7}\x{00B7}]/' FILE
```

Any generator that produces a client-facing file must strip these in its render path and verify the
rendered output, not just the source.

## Style

- Clarity over cleverness. Explicit names. Small single-purpose functions.
- Comment why, not what. Handle errors explicitly and never silently swallow an exception.
- Test non-trivial logic. Avoid premature abstraction, an interface with one implementation, a
  factory for one product, or config for a value that never changes.
- Documentation: imperative, structured, no hype or filler. Tables for comparison content.
- Prefer explicit pass and fail language over vague confidence. Surface assumptions as assumptions,
  never as confirmed facts.
