# Standing up the Augment side

Everything in this repo that targets Augment was built from Augment's published documentation, on a
machine that has never had Auggie installed. That was deliberate, and it has a cost: a claim
verified in a vendor's docs is a claim, not a fact. This runbook is how the claims become facts.

You need a machine with Auggie installed and an Augment account. Work top to bottom. The steps are
ordered so that no step depends on an answer a later step produces.

Each step gives you the command to run, the shape of the output to expect, where to write the
answer down, and what to change in the repo when the answer comes back. Write every answer into the
table at the bottom of this file as you go. A probe you ran and did not record is a probe someone
runs again.

**Two things not to do.** Do not push to `main` and do not merge without being asked; that rule is
in `AGENTS.md` and it applies here. And do not work around a step that fails by typing a value the
tooling was supposed to discover. Step 5 in particular refuses a hand-typed model id on purpose.

**A note on step 10.** There is no step 10. It ran an external-LLM review script that was cut from
this project before it shipped. The steps are not renumbered, because 11, 12 and 13 are referenced
by number elsewhere in the repo.

---

## Step 1: prerequisites

```bash
node --version          # 20 or newer
npm install -g @augmentcode/auggie
auggie login
auggie --version
```

Expect a version string. Commit nothing yet; the first several steps only read.

If `auggie login` cannot complete, stop here and sort out account access before continuing. Nothing
below works without it.

Then pull the upstream sources down, so Auggie has them to read:

```bash
harness upstream
```

That clones every repository in `config/upstream.conf` into `.upstream/`, gitignored. It does not
install anything. Once Auggie is running (step 8), hand it the instruction block in
`docs/upstream-sources.md`: it reads each cloned repo as its author wrote it and installs what the
harness needs in Auggie's own format, rather than taking a conversion this repo guessed at. Record
what it installed, and anything it had to change to make it load, in the answers table.

## Step 2: does headless mode work on this account

```bash
auggie --print --quiet --max-turns 1 "reply PING"
```

Expect `PING` and nothing else. `--print` runs one instruction and exits, `--quiet` prints only the
final assistant message.

If it refuses, the reason is almost certainly licensing: Augment's own documentation says
non-interactive mode "may be disabled if it is not included in your agreement (enterprise)". Record
`headless: no` and carry on. Steps 6 and 7 then have to be done interactively instead of scripted,
which is slower but not blocked. Note the exact error text in the answers table; nobody has seen it
yet and it is worth having written down.

## Step 3: is `auggie cloud` available

```bash
auggie cloud --help
```

Expect a list of subcommands including `expert`. This decides whether a Cosmos Expert can be
exported to a YAML bundle and committed, which is the whole basis of the Cosmos integration being a
file-based one. Record go or no-go.

If the subcommand does not exist on this account, the Cosmos side stays Advisor-only: the prompt in
`adapters/cosmos/adversary-advisor-prompt.md` remains the durable artifact and there is nothing to
export. Record that and skip the export line in step 13.

## Step 4: which rules files does Auggie actually read

In a clone of this repo:

```bash
auggie rules list
```

Expect both `CLAUDE.md` and `AGENTS.md`. The documented precedence puts `CLAUDE.md` above
`AGENTS.md`, and this repo's `CLAUDE.md` is a one-line import of `AGENTS.md` plus a short
Claude-specific section, so both being read is the intended state rather than a duplication problem.

Record what the command actually lists. If `AGENTS.md` is absent, say so: the whole portability
claim in `adapters/README.md` rests on it.

## Step 5: discover the tier binding

This is the one file this repo deliberately does not ship.

```bash
scripts/resolve-tier.sh --write-conf
```

It asks the CLI which models this account has, ranks them, and writes
`config/models.auggie.conf` with the four tiers bound. Its stderr carries one audit line per tier
saying which predicate chose it.

- **Exit 0.** The conf is written. Go on.
- **Exit 3.** No eligible model for some tier. Read the stderr line; it names what was excluded.
- **Exit 4.** The shape of `auggie models list --full-info` does not match what the script expects.
  Do step 5a, then come back.

Then confirm each id is one the CLI will actually accept. A plausible id is not the same as a real
one, and the failure shows up at dispatch time rather than here:

```bash
for id in $(grep -oE '^TIER_[A-Z_]+=[^ #]+' config/models.auggie.conf | cut -d= -f2); do
  echo "== $id"
  auggie --print --quiet --max-turns 1 --model "$id" "reply PING"
done
```

Expect `PING` four times. Record the four accepted literals and the resolver's audit lines.

**Never fix a problem here by typing an id into the conf.** The point of discovering the binding is
that the company allowlist moves without telling anyone. A hand-typed id is how this ends up wrong
six months from now with nothing to catch it.

### Step 5a: capture the model-list schema (only if step 5 exits 4)

```bash
auggie models list --full-info | head -60
```

Paste that output into the answers table. Then open `scripts/resolve-tier.sh` and set the five
knobs in the SCHEMA KNOBS block near the top to match the real field names: `MODELS_JQ`, `F_ID`,
`F_NAME`, `F_COST`, `F_EFFORT`. If the cost tiers are words rather than integers, also set
`COST_TIER_ORDER` to the labels, highest first.

Re-run step 5. Commit that edit on its own, with the captured shape in the commit message, so the
next person can see what the schema actually was.

### Step 5b: when to re-bind, and how

This is the only way a binding changes. Do it on a new machine, when the company allowlist changes,
or when the vendor adds a model:

```bash
scripts/resolve-tier.sh --write-conf --force
harness add --tool auggie
harness build-plugin --tool auggie
./verify.sh
```

An existing conf counts as a pin, which is why `--force` is required to re-discover. Everything
downstream of the conf is a generated file holding a static copy of the binding, so all of it has to
be rebuilt in the same pass. Commit the result.

## Step 6: find the subagent-dispatch tool, and arm the model gate

This is the one thing in the whole integration that could not be built from the documentation.
`hooks/require-agent-model.sh` denies a subagent dispatch that would silently inherit the parent's
model. The payload shape Auggie sends a hook is compatible, but the name of the tool that dispatches
a subagent, and the key inside `tool_input` that carries the agent name, are not documented
anywhere. Guessing fails two ways and one of them is silent: a matcher of `.*` denies every tool
call, and a wrong tool name matches nothing at all while the gate reads as green.

So: log one real dispatch and read the answer off it.

Add a temporary logging hook to `.augment/settings.json`, matching everything:

```json
{
  "hooks": {
    "PreToolUse": [
      { "matcher": ".*",
        "hooks": [ { "type": "command", "command": "cat >> /tmp/auggie-hook.log" } ] }
    ]
  }
}
```

Create a throwaway subagent at `.augment/agents/probe.md`, dispatch it once from an interactive
session ("use the probe agent to list the files in this directory"), then read the log:

```bash
jq -r '.tool_name' < /tmp/auggie-hook.log | sort -u
jq -c '.tool_input' < /tmp/auggie-hook.log | tail -5
```

Two values come out: the tool name, and the `tool_input` key holding the agent name. Then:

1. In `hooks/require-agent-model.sh`, at the insertion point marked with this step number, extend
   the `stype` line to fall back to that key.
2. In `templates/project/.augment/settings.json`, add a `hooks.PreToolUse` entry whose `matcher` is
   that tool name and whose command runs `hooks/require-agent-model.sh`.
3. Remove the temporary logging hook.
4. Re-run `harness add --tool auggie` so the repo picks up the new template.
5. Prove it works: delete the `model:` line from `.augment/agents/probe.md`, dispatch it again, and
   expect a denial. A gate that has never refused anything is not a gate.
6. Delete `probe.md` and commit the two edits.

## Step 7: does Auggie mind an undocumented frontmatter key (informational)

Add `effort: high` to `.augment/agents/probe.md` and dispatch it. Note whether Auggie errors,
warns, or ignores it.

Nothing depends on the answer. The generator strips `effort:` and `reasoning:` unconditionally
because they are not in the documented field list, and every agent body states its effort in words
anyway. This step only decides whether it would be safe to stop stripping them later.

## Step 8: generate the config and check it took

Work in a scratch clone, not in a repo anyone depends on:

```bash
harness add --tool auggie
```

That writes the subagents into `.augment/agents/`, merges the tool-permission rules into
`.augment/settings.json`, and drops `AGENTS.md` into `~/.augment/rules/`. Then start Auggie
interactively and check three things:

```
/agents     expect 11 subagent definitions
/skills     expect 13, with source .claude/skills
/plugins    expect nothing yet; step 9 changes that
```

and out of band:

```bash
auggie command list    # expect 4 slash commands
```

If the skills do not appear, the claim that Auggie reads `.claude/skills/` directly is wrong and
`adapters/README.md` needs correcting rather than the repo needing new files. Say which it was.

Then test the security rules by asking the agent, in an interactive session, to run each of these.
The first two must be refused and the third must go through:

```
git merge main
git push --force origin scratch
git merge-base HEAD HEAD
```

`verify.sh` check 14 already runs every deny pattern against a table of commands, but it runs them
under perl. Auggie's own regex engine is not documented, so this step is the one that proves the
rules bite. If a verdict is wrong, fix the pattern in
`templates/project/.augment/settings.json` and re-run check 14 before committing.

## Step 9: build and publish the plugin

```bash
harness build-plugin --tool auggie
./verify.sh
```

The build writes `plugins/agent-harness-auggie/` and `.augment-plugin/marketplace.json`. Check 13
now rebuilds both and compares them byte for byte with what is committed, so the gate tells you if
they ever drift.

**Commit `config/models.auggie.conf` in the same commit as `plugins/`.** The plugin tree cannot be
re-derived without the binding, and check 13 fails when it finds one without the other. That is
intentional: a generated tree nobody can regenerate is the thing this check exists to prevent.

Decide where the marketplace lives. It has to be a GitHub repository, and everyone who installs the
plugin clones it. The default is this repo's own remote; the company organization is the
alternative and changes one string. Then, from a scratch repo:

```bash
auggie plugin marketplace add <owner>/<repo>
auggie plugin install agent-harness-auggie@agent-harness --project
```

Check the agents command and the skills command again: both should now show the plugin as the
source. Record which repository you chose.

## Step 11: capture the first-day outputs

`docs/first-day.md` ends with an Auggie section carrying five fenced placeholders, each reading
exactly `<captured on the work machine: runbook step 11>`. Run the five commands that section
names, one at a time, and paste the real output over each placeholder. Shorten your home directory
to `~` and change nothing else. Truncated or tidied output is worse than none, because a reader
compares what they see against it.

```bash
grep -c '^<captured on the work machine' docs/first-day.md   # 5 before, 0 after
```

The anchor matters: the section's opening paragraph names the placeholder string in prose and that
mention stays.

## Step 12: flip the status cells and commit

`adapters/README.md` has a mapping table whose last column reads "verified in docs 2026-09-16" for
every row. For each row a step above actually exercised, change it to
`verified in practice, runbook step N, <date>`. Leave the rest alone: a cell nobody tested stays
labelled as a documentation claim, and that honesty is the point of the column.

Fill in the answers table at the bottom of this file. Then:

```bash
./verify.sh                 # must pass every check
git switch -c feat/augment-probes
git add -A && git commit
```

Open a pull request. Do not push `main`.

## Step 13: the Cosmos session

This is a separate piece of work in the Augment tenant rather than on the command line, and it
starts from `adapters/cosmos/adversary-advisor-prompt.md`. In short: settle the Option A versus
Option B question with the Advisor, build the Expert with its trigger disarmed, run it once by hand
against one real pull request, and only then arm it.

Four questions get answered along the way, all of them about what a Cosmos session can see:

1. Does a Cosmos session on a synced repo read `AGENTS.md`? Put a canary line in it and ask the
   session to recite it.
2. Does a `SessionStart` hook fire for a Cosmos agent? Have it write a marker file and look for it.
3. With both `probe/SKILL.md` and `probe2/probe2.md` present, which does Cosmos list?
4. Do the `toolPermissions` deny rules reach a Cosmos agent? Ask one to run `git merge main`.

If step 3 was a go, export the Expert once it has proved itself:

```bash
auggie cloud expert export <expert-id> -o cosmos/experts/adversary.yaml
```

Check `auggie cloud expert export --help` first; that command shape came from documentation, not
from a run. The exported bundle is tenant-bound, so commit it to the personal fork rather than here.

---

## Answers

Fill this in as you go. One row per step, and a real answer rather than "done".

| Step | Question | Command | Answer | Date |
|---|---|---|---|---|
| 1 | Auggie installed and logged in | `auggie --version` | | |
| 1 | Upstream repos cloned | `harness upstream` | | |
| 8 | What Auggie installed from `.upstream/`, and what it changed | the instruction in `docs/upstream-sources.md` | | |
| 2 | Is headless mode licensed | `auggie --print --quiet --max-turns 1 "reply PING"` | | |
| 3 | Is `auggie cloud` available | `auggie cloud --help` | | |
| 4 | Which rules files are read | `auggie rules list` | | |
| 5 | The four bound model ids | `scripts/resolve-tier.sh --write-conf` | | |
| 5a | The model-list schema, if it differed | `auggie models list --full-info` | | |
| 6 | Subagent dispatch tool name and `tool_input` key | the logging hook | | |
| 6 | Does the model gate deny an unpinned agent | dispatch `probe` with no `model:` | | |
| 7 | Does an undocumented frontmatter key error | `effort: high` on `probe.md` | | |
| 8 | Counts: subagents, skills, commands | the agents, skills and command lists | | |
| 8 | Are the deny rules enforced | `git merge main`, `git push --force`, `git merge-base` | | |
| 9 | Which repository hosts the marketplace | `auggie plugin marketplace add` | | |
| 9 | Does the gate pass with `plugins/` committed | `./verify.sh` | | |
| 11 | First-day outputs captured | `grep -c 'captured on the work machine'` | | |
| 13 | Does a Cosmos session read `AGENTS.md` | the canary line | | |
| 13 | Does `SessionStart` fire in Cosmos | the marker file | | |
| 13 | Which skill layout does Cosmos list | both probes present | | |
| 13 | Do the deny rules reach Cosmos | `git merge main` in a Cosmos session | | |
