# Operating boundaries

This document is for a security reviewer or an engineer's employer asking what actually happens
when this harness runs: what leaves the machine, where agent output lands, who approves a
permission-bypass flag, the hard stops that are already enforced, and what is left as an
organizational decision this repository does not make for you.

## What leaves the machine

**External LLM review.** Skill `skills/external-llm-review/SKILL.md` is used "when a
Claude-authored plan, wave diff, or design doc needs an independent non-Claude review" (line 3) by
invoking a separate CLI (codex, cursor-agent, or gemini) backed by a different model provider. The
artifact NAMED is scoped: the phase table names it precisely, a PLAN file during planning or the
"wave's final simplified DIFF file" during execution, and the contract reads "Pass the artifact by
path. You apply fixes; the reviewer stays read-only."

**The artifact named is not the limit of what is read.** The reviewer runs with the repository as
its workspace and the skill instructs it to "Verify against live code (`path:line`)". Verifying a
plan that references `src/auth.ts` means opening `src/auth.ts`. So the honest disclosure is that a
third-party CLI, and the cloud model behind it, may read and transmit any file in the repository it
judges relevant to the artifact. Treat this as giving an outside vendor read access to the
repository for the duration of the review, not as handing over one file.

If your organization needs a one-file guarantee, this step does not provide it. Run the reviewer
against a temporary directory containing only the approved artifact, or do not run it at all: the
gate stack works without it and the surrounding documentation treats it as optional throughout.

Each reviewer runs with a read-only sandbox flag: codex with `--sandbox read-only` (line 65),
cursor-agent with `--sandbox enabled` (line 81), gemini with a real read-only mode,
`--approval-mode plan` (line 44). The model itself is never a Claude model (line 94 states
"model | From the plan. Never `claude-*`."), so this is a deliberate hand-off of one artifact to
an external vendor's inference endpoint.

Read-only sandboxing constrains WRITES. It does not constrain reads, and it is reads that leave the
machine. A reviewer that cannot modify a file can still send its contents to the model.

**Cosmos (Augment's cloud platform).** `adapters/README.md`, under "Tools with no repo surface",
describes COSMOS as "Augment's cloud platform, where reusable agent templates called Experts run
inside Environments." Two paths exist, and the difference matters:

- **Cosmos Advisor** is conversational; per its own documentation you never see or edit a
  configuration file on that path.
- **`auggie cloud`** is file-based and is the path this repo can target: Experts, environments, MCP
  servers, and residents are represented as YAML bundles that "can live in a repository and be
  reviewed like any other change", with an explicit `init`, edit, `validate`, `diff`, `apply`
  workflow. Augment's own docs state "the repository becomes the source of truth for your Cosmos
  configuration" (citing docs.augmentcode.com/cli/cloud).

In both cases what is sent is a named artifact (a plan file, a diff, or a bundle path) to a specific
vendor's cloud, not an unscoped repository upload. Which artifacts are safe to send to which vendor
is a question the reviewer should confirm against their own organization's data-handling policy
before running either integration.

## Where agent output lands, and what to do with each

| Location | What it holds | Recommendation |
|---|---|---|
| `runtime/` | Every `exec-*` agent's verification report, defaulted there in each agent's own file (`.gitignore:8-9`). | Ignore, do not commit. `.gitignore:9-11` explains why: an unignored report lands in the shipped set and check 1 then scans the absolute worktree paths an agent naturally writes there, failing the packaging gate on output that was never meant to ship. |
| `.project-state/` | Planning and handoff state: `PROJECT_STATE.md`, `NEXT_STEPS.md`, `ERRORS.md`, `SESSION_HANDOFF.md` and its `handoffs/` archive, `DEPENDENCIES.md`, `CLEANUP.md`, `SKILL_CANDIDATES.md` (`docs/project-management.md` ("`.project-state/` as shipped in the template")). | Commit. This directory is designed to be the durable, cross-session record git history does not give you: "intent, next steps, blockers, and decisions" (`docs/project-management.md` ("How this differs from git history")). Treat it like any other tracked doc: review its content for anything sensitive before it ships, same as code. |
| `active/` | Artifact directories mandated by the optional workspace-brain module (`README.md`: the quickstart's `harness add workspace-brain` line, and the scope note that the brain "mandates writing `active/` artifact directories"). Not present unless that module was added. | Project-scope by design (`README.md`: "brain is project scope on purpose") so it does not appear in every repo you touch; if the module is added, decide per-project whether its contents are safe to commit or belong in `.gitignore`, the same review you would give any new tracked directory. |

## Who approves a permission-bypass flag

This section documents the approval boundary already written into the harness. It does not propose
using a permission-bypass flag.

`AGENTS.md` lists "using any permission-bypass flag" among the actions that require the operator
to "Stop and get explicit human approval before" acting (the "Security" section).

Where a bypass flag has a concrete, named use, `templates/project/rules/multi-agent-runtime.md` ("--dangerously-skip-permissions Usage")
narrows it further: `--dangerously-skip-permissions` is "Reserved for isolated, operator-approved
worker sessions only," specifically:

- "Enabled only via the `--bypass` flag on `active/multi-agent/launch_agents.sh`"
- "Never the default for interactive Claude Code sessions"
- "Never used outside a git worktree"
- "Never used for tasks touching auth, billing, secrets, production, or deployment"

The same file ties the approval level to the flag: launching any multi-agent run requires "The
parent operator has approved the launch (Level B gate minimum; Level C if `--bypass` is used)"
(`templates/project/rules/multi-agent-runtime.md` ("Launch Gate Requirements")). Level C is the harness's hard-stop tier;
`templates/project/rules/workflow.md` ("Level C - Hard Stop") defines it as requiring explicit operator approval
before proceeding, including for "using unsafe permission bypass flags."

## The hard stops, verbatim

`AGENTS.md`, under "Security," lists what always requires a stop and explicit human approval
before proceeding, reproduced here verbatim (punctuation normalized to straight ASCII where the
source used none needing normalization):

> Stop and get explicit human approval before:
>
> - modifying production systems or databases
> - deleting or migrating data
> - changing authentication, authorization, billing, or secrets
> - deploying to external hosting
> - using any permission-bypass flag
> - legal, compliance, or financial workflows
> - any irreversible action with external cost or impact

The `Secrets:` list that follows it in `AGENTS.md` adds secret handling enforced regardless of task
type: never commit credentials or write them into instruction files, memory files, or logs; never
pass a credential inline on a command line, because tools echo the expanded command into scrollback
and chat history, so source it from a file with `600` permissions at runtime instead; and confirm
`.env` and secret files are ignored before committing.

## The model-pin gate is not enforced on native Windows

`hooks/require-agent-model.sh` denies a subagent spawn carrying no model pin. On macOS, Linux and
WSL 2 it does that. On native Windows without Git for Windows installed and detected, it can fail to
launch at all, and a `PreToolUse` hook that does not exit 2 is treated as a non-blocking error, so
the spawn proceeds. Nothing in the session reports it.

This is a platform limitation, not a configuration mistake, and it is not one this repository can
close: the hook cannot report a refusal it was never started to make. It matches an open upstream
issue (anthropics/claude-code#90077).

If your organization relies on that gate, standardise Windows engineers on WSL 2, or require Git for
Windows and verify it is detected. `docs/windows.md` has the detail. Do not read a green
`harness verify` as evidence either way: the gate inspects this repository and cannot see whether a
hook fired in someone's session.

## Third-party code the gate does not scan

The scrub gate holds one invariant: nothing reaches `~/.claude` that it did not scan. The installer
and the gate share a single definition of what the repository contains, so a file that is ignored
by git reaches neither of them. That is the property, and it still holds for everything in this
repository.

There is exactly one declared exception, and a reviewer should understand its shape.

`config/upstream.conf` lists other people's repositories that this harness uses rather than copies.
An entry may carry an `install=` field naming skills that `harness install --user` should deploy
from the clone. Those files are another project's work. This gate does not scan them, and it should
not: holding someone else's repository to this one's style rules would fail on their first absolute
path and teach you to ignore the result.

So the claim is narrowed rather than quietly widened. The gate prints both halves on every run:

```text
PASS every file harness install would ship from this repo is in the scanned set
     plus 91 file(s) from 13 upstream skill(s), which this gate does not scan (config/upstream.conf)
```

What that means in practice:

- Adding an upstream entry with `install=` is a decision to run unscanned third-party code. It is a
  commit to this repository, so it is reviewable, and the count above changes when it lands.
- Remove the `install=` field and the clone becomes reference material again. The next install
  retires whatever it had deployed, because upstream skills go through the same manifest as
  everything else.
- The clones live in `.upstream/`, which is gitignored. A local edit there would be installed
  unscanned, so treat that directory as read-only. `harness upstream` refreshes with a hard reset
  and will discard anything you changed.
- Nothing is cloned or installed without someone running `harness upstream` first. An install on a
  machine that has never run it deploys only this repository's own content and says so, once per
  entry.

If your organization cannot accept unscanned third-party skills, remove the `install=` fields. The
harness works without them; you lose the upstream skills and keep everything else.

## Gate minimalism is a dial, not a default

This harness ships with few human gates on purpose, and says so explicitly at the point where an
autonomous run is assembled. `agents/plan-synthesizer.md` ("The output contract - a MULTI-STEP EXECUTION PLAN, not a design essay") states: "Review gates - MINIMAL BY
DEFAULT. This is a dial; an organization sets it deliberately." The rule that follows
(`agents/plan-synthesizer.md` ("The output contract - a MULTI-STEP EXECUTION PLAN, not a design essay")) is a four-part test for when a human gate exists at all: the
pass/fail rule cannot be stated in advance and needs live judgment, or the action reaches a person
outside the system, or the action is irreversible and lacks a tested rollback, or it requires
physical human action. Everything else is auto-proceed-on-rule (`agents/plan-synthesizer.md` ("The output contract - a MULTI-STEP EXECUTION PLAN, not a design essay")).

The same section states the dial is adjustable, not fixed: "this is a dial, and an organization sets
it deliberately" (`agents/plan-synthesizer.md` ("The output contract - a MULTI-STEP EXECUTION PLAN, not a design essay")). An organization that wants more gates than
this default sets its position by editing `agents/plan-synthesizer.md` directly, changing the
four-part test or adding categories that must gate regardless of how cleanly their rule can be
stated. `agents/plan-synthesizer.md` ("The output contract - a MULTI-STEP EXECUTION PLAN, not a design essay") shows the harness already carves out a few categories
that never weaken under this rule regardless of how statable they are: sends that reach a person
outside the system, deletion of tracked content, and writes to a source of truth the plan marks
read-only.

## What the agent may read

Whether customer data, production credentials, or regulated records may enter an agent's context
window is an organizational decision this repository cannot make for you. Nothing in this harness
inspects the content of what a session reads before reading it; the security controls documented
above govern what an agent may do (stop before production, billing, auth, secrets, deployment,
irreversible actions) and where its output is stored (`runtime/`, `.project-state/`, `active/`), not
what data sources it may be pointed at in the first place.

Before pointing an agent session at any data source, take these questions to your security team:

- Does this data fall under a regulatory regime (health records, payment data, other personal data
  subject to a privacy law) that restricts where it may be processed or by which vendor?
- Does the model provider retain prompts or context for training, and for how long, and does your
  data-processing agreement with that vendor cover this use?
- If the external-LLM-review skill or a Cosmos integration is in use, does the specific artifact
  being sent (a plan, a diff, a bundle) contain any of the above, and has it been reviewed before
  that hand-off?
- Are production credentials or secrets ever present in the working tree an agent reads, even
  transiently, and if so does the secret-handling section above cover the case?

None of these questions has a default answer in this repository. Set the position deliberately, the
same way `agents/plan-synthesizer.md` treats the gate dial, and record the decision somewhere a
future session will read it, such as `.project-state/PROJECT_STATE.md`.
