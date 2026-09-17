# Your first day with this harness

Five things, done for real, with the actual output pasted below each one: install and verify the
harness, scaffold a new project with `harness init`, run one real prompt through it, watch the
model-tier hook do its job, and hand off a session to your future self.

## Contents

- [Beat 1: install and verify](#beat-1-install-and-verify)
- [Beat 2: `harness init` in a fresh repo](#beat-2-harness-init-in-a-fresh-repo)
- [Beat 3: one real prompt](#beat-3-one-real-prompt)
- [Beat 4: the hook, on purpose](#beat-4-the-hook-on-purpose)
- [Beat 5: the handoff round trip](#beat-5-the-handoff-round-trip)
- [Doing the same in Auggie](#doing-the-same-in-auggie)
- [Your first week](#your-first-week)

## Beat 1: install and verify

`bin/harness install --user --dry-run` (see `cmd_init` and the sibling `cmd_install` in
`bin/harness`) shows what a real install would touch without writing anything. Every `dry run` or
`identical` line below is real output from this repo's checkout, with the account's home directory
scrubbed to `~`.

```
$ bin/harness install --user --dry-run
  + agents/exec-mechanical.md (dry run)
  + agents/design-reviewer.md (dry run)
  = agents/data-eng-sa-orchestrator.md (identical)
  + agents/exec-critical.md (dry run)
  ...
  + hooks/require-agent-model.sh (would replace, dry run)
  + rules/00-harness-core.md (dry run)
  + settings.json merge (dry run)

Done. Run 'harness verify' to check the result.
```

`+` means the file would be written (either it does not exist yet at `~/.claude`, or it differs from
what this repo ships); `=` means the file already matches, so a real install would skip it. Nothing
was written because of `--dry-run`.

`./verify.sh` runs the gate this repo holds itself to. This is the real output, unabridged, with
only the home path shortened to `~`:

```text
$ ./verify.sh
Scrubbing ~/projects/agent-harness

  PASS no absolute home paths
  PASS no vendor model names outside config/models.conf
  PASS all 11 agent definitions pin a tier
  PASS all 13 skills have name and description
  PASS CLAUDE.md imports AGENTS.md on line 1
  PASS no permission-bypass defaults in shipped settings
  PASS all 7 shell scripts use an absolute-path shebang
  PASS no banned glyphs in client-facing docs (39 files)
  PASS no dangling ~/.claude/rules references
  PASS every backticked slash command resolves to commands/, skills/, or the built-in allowlist
  PASS every file harness install would ship from this repo is in the scanned set
         plus 91 file(s) from 13 upstream skill(s), which this gate does not scan (config/upstream.conf)
  PASS documented counts match (11 agents, 13 skills, 4 commands, 14 checks)
  PASS docs/reference.md matches what scripts/gen-reference.sh generates; plugins/ not compared: config/models.auggie.conf is unbound (docs/augment-runbook.md step 5)
  PASS all 7 Augment deny rules give the expected verdict on 41 commands

OK all 14 checks passed
```

Be precise about which numbers in that output the gate actually defends.
The counts check compares exactly four things against the repo: the agent definitions, the skills,
the slash commands, and the number of checks the gate runs. Assert one of those four in any
client-facing document and the build fails when it stops matching. Add a skill while this page
still claims the old number and the gate goes red and tells you so.

Every other number in the block above is a snapshot of one run, dated to the commit that pasted it.
The file count and the command-table count are not compared by anything, so they can drift quietly,
and they have done exactly that more than once. Re-paste the block rather than editing a number in
place.

Exit code was 0. If a check fails, the script prints which one and why; it does not print a partial
pass.

## Beat 2: `harness init` in a fresh repo

`cmd_init` in `bin/harness` requires a git repository, then copies `AGENTS.md`
into the repo root, writes a `CLAUDE.md` that only imports it (see `adapters/README.md` for why an
import rather than a symlink), and copies the `.project-state/` template
(`templates/project/.project-state`) in.

```
$ git init -q
$ ~/projects/agent-harness/.worktrees/t-first-day/bin/harness init
Scaffolding project scope into ~/projects/first-day-scratch
  + AGENTS.md
  + CLAUDE.md (imports AGENTS.md)
  + .project-state/NEXT_STEPS.md
  + .project-state/DEPENDENCIES.md
  + .project-state/SESSION_HANDOFF.md
  + .project-state/ERRORS.md
  + .project-state/PROJECT_STATE.md
  + .project-state/CLEANUP.md
  + .project-state/SKILL_CANDIDATES.md
  + .project-state/handoffs/.gitkeep

Add more with: harness add <module>
  workspace-brain   state machine, autonomy levels, artifact persistence
  context           orchestration context docs (consensus, chatroom, multi-agent)
  multi-agent       runtime policy for parallel agents in worktrees
  phase             nested per-phase CLAUDE.md scaffold for a multi-phase build

$ ls -la
drwxr-xr-x  10 you  staff   320 Sep 16 17:17 .project-state
-rw-r--r--   1 you  staff  9891 Sep 16 17:17 AGENTS.md
-rw-r--r--   1 you  staff    71 Sep 16 17:17 CLAUDE.md
```

What each piece is for:

- `AGENTS.md` is the tool-agnostic instruction set copied straight from this repo (model tiers,
  security stops, version control, session handoff, writing rules).
- `CLAUDE.md` is one line, `@AGENTS.md`, plus a placeholder section for anything specific to this
  one project. Claude Code loads the import automatically; every other tool that reads
  `AGENTS.md` directly ignores `CLAUDE.md` entirely.
- `.project-state/` (`templates/project/.project-state`) holds the working-notes files a session
  reads and writes across a long build: `PROJECT_STATE.md`, `NEXT_STEPS.md`, `DEPENDENCIES.md`,
  `ERRORS.md`, `CLEANUP.md`, `SKILL_CANDIDATES.md`, and `SESSION_HANDOFF.md` plus a
  `handoffs/` archive directory. These start as templates with `<placeholder>` text; a session
  fills them in as it works.

`harness add <module>` layers on optional pieces (a workspace-brain state machine, orchestration
context docs, multi-agent worktree policy, or a per-phase scaffold) that most single-session repos
do not need on day one.

## Beat 3: one real prompt

Planted a ten-line off-by-one bug in `count.py` and a test that catches it, in a scratch repo
outside this one:

```python
def count_up_to(n):
    """Return a list of integers from 0 up to n, inclusive."""
    return list(range(n))
```

```python
from count import count_up_to

def test_count():
    assert count_up_to(5) == [0, 1, 2, 3, 4, 5]
```

Before the fix:

```
$ pytest -q
F
_________________________ test_count _________________________
    def test_count():
>       assert count_up_to(5) == [0, 1, 2, 3, 4, 5]
E       assert [0, 1, 2, 3, 4] == [0, 1, 2, 3, 4, 5]
E         Right contains one more item: 5
1 failed in 0.03s
```

Then ran the fix through the SMALL tier (the literal that `config/models.conf` currently binds
`TIER_SMALL` to at the time of writing; read that file for the current binding rather than trusting
a name printed here, per the tier-versus-literal rule in `AGENTS.md`):

```
$ claude -p --model <TIER_SMALL literal> "fix the off-by-one in count.py so test_count.py passes; do not touch the test"
The off-by-one error is fixed. The issue was `range(n)` which excludes `n`, but the docstring says
the function should return integers "up to n, inclusive". Changed it to `range(n + 1)` so
`count_up_to(5)` now returns `[0, 1, 2, 3, 4, 5]` as expected by the test.
```

Resulting file:

```python
def count_up_to(n):
    """Return a list of integers from 0 up to n, inclusive."""
    return list(range(n + 1))
```

After the fix:

```
$ pytest -q
.
1 passed in 0.00s
```

The test file was untouched; only `count.py` changed.

## Beat 4: the hook, on purpose

Every `Agent`/`Task` spawn passes through `hooks/require-agent-model.sh`, which denies a call that
would silently inherit the parent session's model. Ran it from a directory with no resolved agent
definition, simulating a call for `exec-mechanical` with no `model` set:

```
$ echo '{"tool_input":{"subagent_type":"exec-mechanical"}}' | bash hooks/require-agent-model.sh
{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"Right-fit model rule (operator hard rule): this Agent/Task spawn passes no explicit model and its agent definition pins none, so it would silently inherit the parent session's model. Re-issue the call with an explicit model sized to the task (tier bindings live in the harness repo config/models.conf), and set effort where the surface supports it. Do not disable this hook; pick a model."}}
```

The emitting line is `hooks/require-agent-model.sh` ("expensive."), a `cat <<'EOF'` heredoc. The JSON has
three fields:

- `hookEventName`: which hook event fired (`PreToolUse`, the same event every gate in this harness
  hooks).
- `permissionDecision`: `deny`. The hook has only two outcomes: `exit 0` (allow, silently) or this
  JSON (deny, with a reason).
- `permissionDecisionReason`: the message shown to the caller, telling it exactly what to fix.

The call was denied because it ran from a directory with no `.claude/agents/exec-mechanical.md` (or
`$HOME/.claude/agents/exec-mechanical.md`) carrying a `model:` frontmatter pin, and passed no
`model` parameter of its own. Either one satisfies the hook. A corrected dispatch that the hook
allows:

```
Agent(subagent_type: "exec-mechanical", model: "<TIER_SMALL literal>", ...)
```

or, from a directory where `agents/exec-mechanical.md` exists and its frontmatter pins a `model:`,
the same call with no `model` parameter also passes, because `require-agent-model.sh` checks the
agent definition file when the call itself is silent about it.

## Beat 5: the handoff round trip

`commands/handoff.md` describes a six-step procedure: archive the previous
`SESSION_HANDOFF.md` under `handoffs/<timestamp>.md`, gather `git status --short` and
`git log --oneline -5`, write the resume block first, fill in the sections below it, re-read
the block alone, then refresh its state claims at the moment of the handoff rather than when it
was drafted. Followed it by hand in the scratch repo used for beat 3.

Archived the template `harness init` had scaffolded, gathered state, then wrote the resume block
into the real `.project-state/SESSION_HANDOFF.md` (the file also has Date, Summary, Files Changed,
Key Commands, Next Step, and Blockers sections below this block, per the template):

~~~
Where to start: ~/projects/first-day-scratch, then run: claude

Read first, in this order:
1. .project-state/SESSION_HANDOFF.md (this file, read everything below this block)
2. count.py and test_count.py (the fix this session made)
3. .project-state/PROJECT_STATE.md

Current state:
- harness init scaffolded AGENTS.md, CLAUDE.md, and .project-state/ (commit bbe564d).
- count.py had an off-by-one (range(n) instead of range(n + 1)); fixed and committed
  in 3a85dca. pytest -q passes (1 passed).
- Nothing is in flight; both commits are on disk.

Next action:
None queued. This was a training walkthrough, not a real task.

Standing constraints:
- Demo repo only, not for production use.
~~~

**Placeholder, captured by the operator, not the agent:** the second half of this beat, clearing
the session and resuming from only the pasted block, cannot be produced inside a single agent turn.
To see it for yourself: run `/clear` (or start a fresh `claude` session in the same directory),
paste only the fenced resume block above (the part between the two ```` ``` ```` fences), and
nothing else. The resumed session should, without being told anything more, read
`.project-state/SESSION_HANDOFF.md` first (because the block names it), then `count.py` and
`test_count.py`, then `.project-state/PROJECT_STATE.md`, and should be able to state back to you
that this was a training walkthrough with no next action queued, citing commit `3a85dca`. If it
asks you what file to read first instead of already knowing, the block was not self-sufficient.

## Doing the same in Auggie

The five beats above were run on this machine. The five below were not: Auggie has never been
installed here, so each output block is a placeholder reading
`<captured on the work machine: runbook step 11>`, and [`docs/augment-runbook.md`](augment-runbook.md) step 11 is the
instruction to replace them with real output. Treat an unreplaced placeholder as a claim nobody has
checked. Everything outside the output blocks comes from Augment's documentation as of 2026-09-16.

Run [`docs/augment-runbook.md`](augment-runbook.md) steps 1 to 9 before this section: step 5 discovers the model binding,
and `harness add --tool auggie` refuses to run without it.

### Install and log in

```
$ npm install -g @augmentcode/auggie
$ auggie login
<captured on the work machine: runbook step 11>
```

### Set the repo up

`harness init` is the same command for both tools; it writes `AGENTS.md`, a `CLAUDE.md` that imports
it, and the `.project-state/` scaffold. `harness add --tool auggie` is the Augment-specific half.

```
$ harness init
$ harness add --tool auggie
<captured on the work machine: runbook step 11>
```

Expect the second command to print the four bound model ids, then one line per generated subagent,
then the settings merge. What it wrote:

- `.augment/agents/`, the subagent set, generated because Auggie's frontmatter is a different schema
- `.augment/settings.json`, the security hard stops as tool-permission deny rules
- `~/.augment/rules/harness-core.md`, a copy of `AGENTS.md` for other workspaces

Skills and slash commands need nothing at all. Auggie reads `.claude/skills/` and
`.claude/commands/` directly.

### The same prompt as beat 3

Same scratch repo, same off-by-one, same instruction. `--print` runs one instruction and exits,
which is the closest equivalent to `claude -p`:

```
$ auggie --print --model <TIER_SMALL literal from config/models.auggie.conf> "fix the off-by-one in count.py so test_count.py passes; do not touch the test"
<captured on the work machine: runbook step 11>
```

Read the literal out of `config/models.auggie.conf` rather than copying one from anywhere. The
Augment binding is discovered per account, so the id here is not the id in `config/models.conf`.

### The handoff command

Auggie reads `.claude/commands/`, so the handoff command works with no porting:

```
$ auggie
> /handoff
<captured on the work machine: runbook step 11>
```

### What the agent can see

```
$ auggie
> what rules files are you reading, and which subagents and skills do you have
<captured on the work machine: runbook step 11>
```

Expect both `CLAUDE.md` and `AGENTS.md`, 11 subagent definitions, and 13 skills sourced from
`.claude/skills`.

### Three differences worth knowing before you start

1. **The `@AGENTS.md` import does nothing here.** It is Claude-only syntax. Auggie reads `AGENTS.md`
   itself, as a separate rules file below `CLAUDE.md` in precedence, so nothing is lost; but if you
   ever move content out of `AGENTS.md` and behind an import, Auggie stops seeing it.
2. **Path-scoped rules have no equivalent.** A `.claude/rules/*.md` with a `paths:` header loads
   only when Claude reads a matching file. The nearest Auggie mechanism is a workspace rule with
   `type: agent_requested`, which the agent attaches when your `description` looks relevant. Close
   in spirit, different trigger.
3. **The model gate is not armed yet.** Under Claude Code, a hook refuses any subagent dispatch that
   would silently inherit the parent model. Under Auggie the generator refuses to write an agent
   with no resolved model, which covers everything this repo generates, but a hand-written
   `.augment/agents/*.md` is not caught. Runbook step 6 is what arms it.

## Your first week

The five beats above are one sitting. The five days below spread the same material across real
work, so each idea gets used before the next one lands.

| Day | Do | Read | Self-check |
|---|---|---|---|
| 1 | Run beats 1 through 5 above, on your own machine, in a scratch repo | This document | `./verify.sh` exits clean in the harness checkout, and your scratch repo's `.project-state/SESSION_HANDOFF.md` exists with a resume block that names itself |
| 2 | Pick a real one-line fix in a repo you actually work in and run it the way scenario 1 does: no plan, no worktree, no adversary | docs/scenarios.md, "Scenario 1: a one-line fix, and why the harness stays in its box" | The resulting diff touches exactly one file, and you can say out loud why that size did not call for `/deep-plan` or a worktree |
| 3 | Pick a real bounded change (a few files, one clear boundary) and run it the way scenario 2 does: `/deep-plan`, one worktree, one `adversary` pass | docs/scenarios.md, "Scenario 2: a bounded feature across four files" | The adversary report exists on disk at the path you named in the dispatch brief, and every finding in it is either fixed or filed with a reason |
| 4 | Work through writing-your-own exercises 1 through 3 yourself, in order | docs/writing-your-own.md, "Exercises" | Each exercise's own stated checkable answer holds for you: the path-scoped rule only shows up after a matching file is read, the unpinned dispatch is denied by name, and the two-line skill answers with exactly "hello there" |
| 5 | End the day by running `/handoff`, then clear or start a fresh session and resume from nothing but the pasted block | commands/handoff.md; the resume block itself | The new session reads `.project-state/SESSION_HANDOFF.md` first, without you telling it to, because the block named its own file |
