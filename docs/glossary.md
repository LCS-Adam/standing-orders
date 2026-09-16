# Glossary

Terms used across this harness, alphabetical, one paragraph each. Each entry names the repo file
where the term is actually defined or used, so this page is a map rather than a second source of
truth.

## `.project-state/`

A directory `harness init` writes into a repo to hold what a diff cannot show: intent, next steps,
blockers, and decisions. It is complementary to git, not a duplicate of it, and it is the read-first
location for any session picking up work that a previous session left in flight.
In depth: `docs/project-management.md:11`

## `advisor`

A tool that forwards the calling agent's entire transcript to a stronger reviewer model and returns
critique. It takes no arguments; everything it needs comes from the conversation it is called
into. This repo's own instructions call for using it before substantive work, when stuck, when
changing approach, and before declaring a task done, and for treating an unreachable advisor as a
gate to route around with a stand-in reviewer, never to skip.
Two paragraphs because this repo leans on it constantly: the mechanics above are what makes it
different from a normal subagent dispatch. A subagent starts cold, with only what its prompt gives
it; the advisor instead sees the calling agent's actual history, so it can catch a drift in
reasoning the agent itself cannot see because it is inside that reasoning. `commands/deep-plan.md`
calls it twice around a single `Plan` dispatch, once to shape the approach before planning and once
to critique the plan afterward, which is the pattern to imitate for any workflow that produces a
plan or a decision worth a second look.
In depth: `docs/writing-your-own.md`, `docs/orientation.md`

## AUTORUN

The full unattended-execution mechanism, run by the `autorun-plan` skill via the
`autorun-plan-orchestrator` agent, for an approved multi-wave plan meant to run overnight or
otherwise unattended for a long stretch. Every code-producing wave passes through an ordered review
gate stack (tests, `adversary`, `/simplify`, external-LLM fold-back, a regression re-run, then
merge) before it lands, and the run maintains a mission-scoped `AUTORUN-STATE-<mission-slug>.md`
file that gets reconciled against the real world on every wake rather than trusted blindly.
In depth: `docs/autorun-hitl-heartbeat.md:17`

## compaction

What happens when a session's transcript would exceed the context window: the harness summarizes
the full transcript down to a shorter form that preserves the gist, and that summary replaces the
original turns going forward. Work continues after compaction; the session does not have to stop
and restart. What survives is a summary, not a full record, so anything that must survive with full
fidelity, a commit SHA, an exact command, a specific decision and its reasoning, has to be written
to a durable file before compaction happens.
In depth: `docs/context-window-management.md:110`

## contract (prompt contract)

A written agreement about what a dispatched worker must actually do and produce, used where a
plain instruction is not enough to guarantee a persistence step happens (for example, requiring a
worker dispatched as `general-purpose` rather than `Explore` because the latter cannot call
`Write`, which would silently break the contract). The project-scope workspace-brain module
generalizes this into a required artifact per triggering task, written to
`active/contracts/<run-id>.md`.
In depth: `templates/project/context/multi-agent-inline.md:20`, `templates/project/CLAUDE.md:76`

## context window

A fixed amount of text a model can hold at once. Instructions, files read, commands run, and every
reply all live in that same space, and none of it carries over to a new session unless a file on
disk tells the next session where to look. Quality degrades as the window fills because everything
in it competes for the same fixed amount of the model's attention, not because anything mystical
happens at some threshold.
In depth: `docs/context-window-management.md:1`

## `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE`

An environment variable the harness's portable settings set to `85`, controlling the percentage of
the context window that triggers an automatic compaction. Setting it explicitly rather than relying
on a tool default keeps the compaction point consistent across machines that install this harness.
In depth: `config/settings.portable.json:4`

## denylist

A rule expressed as a list of forbidden items rather than a positive check for what is required.
This repo removed one such check from its own scrub gate on the grounds that a fixed list of banned
words or markers is easy to work around and expensive to keep current; prefer a positive,
structural check where one is available.
In depth: recent commit `b4612fc` on this repo's own history (`git log --oneline`); no denylist
remains in `verify.sh` as of this writing.

## effort

A model's reasoning budget for a given call, distinct from which model runs. This repo pins it two
ways depending on the surface: as a literal `reasoning:` frontmatter field in an agent definition
(values seen in this repo include `medium`, `high`, `max`, and `xhigh`), or as a real per-call
`effort` argument to the Workflow tool's `agent()` function, because the Agent tool itself has no
`effort` parameter and instead carries "high effort" as a directive inside the dispatched prompt.
Two paragraphs because the mapping between "tier" and "effort" is a live source of mistakes: they
are independent knobs. A FRONTIER-DO dispatch at low effort and a MID dispatch at max effort are
both valid combinations for different tasks; the model tiering table in `AGENTS.md` gives an effort
range per task archetype, but the actual number for a specific agent definition lives in that
agent's own frontmatter, not in the tier table.
In depth: `docs/writing-your-own.md`, `agents/exec-subtle.md:7`

## Environment

An Augment/COSMOS concept: the runtime configuration an Expert deploys into. Not documented in this
repo beyond the adapter notes; confirm exact scope and configuration surface against Augment's own
documentation before relying on details beyond what is cited here.
In depth: `adapters/README.md:38`

## Expert

An Augment/COSMOS concept: a reusable agent template that runs inside an Environment. COSMOS has
two configuration paths for these, and the file-based one (`auggie cloud`) is the one this repo can
target; the fully managed path's own documentation states you never see or edit the underlying
files.
In depth: `adapters/README.md:38`

## external-LLM review

A review step, covered by the `external-llm-review` skill, that dispatches the same diff to a
different model family entirely (`codex`, `cursor-agent`, or `gemini`, whichever the plan names)
rather than another Claude reviewer. The point is specifically to catch shared model-family blind
spots that a same-family reviewer, however strong, cannot structurally see; this repo's own
AUTORUN gate stack states outright that a Claude reviewer is never a substitute for this step.
In depth: `docs/autorun-hitl-heartbeat.md:44`, `skills/external-llm-review/SKILL.md`

## `fork`

An `Agent`/`Task` subagent type that always inherits the parent session's model by design, and is
therefore the one exemption from the right-fit-model hook: dispatching `fork` never requires an
explicit `model` parameter or a pinned agent definition, because there is nothing to check.
Two paragraphs because the exemption is easy to over-read: `fork` inheriting is a deliberate design
choice for that one subagent type, not evidence that inheritance is safe generally. Every other
subagent dispatch in this harness is required to state its model explicitly, precisely because
silent inheritance elsewhere burns frontier capacity on work a smaller tier would handle and hides
the sizing decision from review.
In depth: `docs/writing-your-own.md`, `hooks/require-agent-model.sh:6`

## gate (review gate, human gate, scrub gate)

Three distinct uses of "gate" in this repo. A **review gate** is one step in the AUTORUN per-wave
stack (tests, adversary, `/simplify`, external-LLM fold-back) that a wave must pass before merging.
A **human gate** is a point where auto-proceed-on-rule explicitly does not apply: live judgment
needed, a real person reached, an untested irreversible action, or a required physical action, and
these are the only stopping points AUTORUN respects while otherwise running unattended. A **scrub
gate** is this repo's own `verify.sh`, the check suite that must exit clean before a change to the
harness itself is considered done.
In depth: `docs/autorun-hitl-heartbeat.md:24`, `docs/autorun-hitl-heartbeat.md:88`,
`docs/getting-started.md:159`

## handoff and resume prompt

A handoff is the durable file written before a context clear, compaction, or new session, so the
next session can pick up work without re-deriving it. A resume prompt is the specific
copy-pasteable block pasted into that next session; it must be self-sufficient, including a pointer
to the handoff file itself, because the user pastes only the block, never the whole document
surrounding it. A summary of what happened is not a substitute: a resume prompt says what to do
next, not what already occurred.
In depth: `docs/handoff-and-resume.md:17`

## HEARTBEAT

The deliberately lighter counterpart to AUTORUN, for a plan that is already reviewed and approved
and where the full AUTORUN gate stack would cost more context than it protects. It runs the plan
unattended until it finishes or hits a real human gate, with no review gates, no adversarial pass,
no external-LLM loop, and no improvement rounds; its state file is named `HEARTBEAT-STATE-<mission-slug>.md`
specifically so a reader can tell, from the filename alone, that the full gate stack did not run.
In depth: `docs/autorun-hitl-heartbeat.md:96`, `skills/heartbeat/SKILL.md`

## HITL

Human-in-the-loop: a point in an otherwise autonomous run where a human is asked to decide or
approve before the run continues. AUTORUN's auto-proceed-on-rule mechanism is explicitly about
minimizing HITL interruptions to the four cases where a stated pass/fail rule genuinely cannot
substitute for one: live judgment, reaching a real person, an untested irreversible action, or a
required physical action.
In depth: `docs/autorun-hitl-heartbeat.md:88`, `skills/autorun-plan/SKILL.md:3`

## the host's built-in subagent types (`Plan`, `Explore`, `general-purpose`)

Three subagent types the Agent tool exposes that are not defined by this repo's own agent
definitions in `agents/*.md`. `Plan` is dispatched by `/deep-plan` and `deep-plan-swarm` for
first-principles plan synthesis, typically at the FRONTIER-THINK tier and high effort. `Explore` is
read-only and cannot call `Write`, which matters directly for any skill with a persistence
contract: dispatching such a skill via `Explore` fails that contract for every worker. General
mechanical work that needs full tool access but has no dedicated agent definition uses
`general-purpose`.
In depth: `docs/planning-large-builds.md:60`, `templates/project/context/multi-agent-inline.md:21`,
`skills/readme-coauthoring/SKILL.md:287`

## Level A / B / C autonomy

Three autonomy levels a project-scope workflow can assign to a decision. Level A proceeds without
asking: low risk, reversible, context resolves the ambiguity. Level B asks one to five high-impact
questions when ambiguity would materially change the solution. Level C is a hard stop: destructive
actions, production systems, auth, billing, secrets, anything irreversible. A multi-agent run
launched with a permission-bypass flag is always treated as Level C regardless of what the
individual task would otherwise warrant.
In depth: `templates/project/rules/workflow.md:42`, `templates/project/CLAUDE.md:31`

## `/loop`

A host built-in slash command, not a harness command shipped by this repo; there is no
`commands/loop.md` or `skills/loop/SKILL.md` here. It is listed in this repo's own host-built-in
allowlist alongside `clear`, `compact`, `agents`, `help`, `model`, and `resume`, all of which the
scrub gate treats as resolved without requiring a matching file in `commands/` or `skills/`.
In depth: `verify.sh` (check 10's allowlist)

## MCP (Model Context Protocol)

The one genuinely cross-tool configuration surface in this space, letting an agent reach an
external tool or data source through a standard server interface. Each coding tool reads MCP
server configuration from its own path (Claude Code from `.mcp.json` in a project or via `claude
mcp add`, Codex from `~/.codex/config.toml`, Cursor from `.cursor/mcp.json`, Augment from
`~/.augment/settings.json`), and this repo's example file is explicit that credentials belong in an
environment variable, never committed inline.
In depth: `config/mcp.example.json:2`

## parking

The harness's answer to a workstream that hits a real blocker or a genuine human gate during an
unattended run: that one branch stops and holds unmerged, with the reason recorded, while every
other independent stream keeps running. The skill treats this as a first-class success outcome,
not a failure, stated as "parking is success; guessing is failure," and the close-out report lists
every parked branch with its reason so a human can pick each one up without re-deriving what
stopped it.
In depth: `docs/autorun-hitl-heartbeat.md:77`

## `paths:` frontmatter

A field on a `.claude/rules/*.md` file that restricts when it loads. Without `paths:`, a rule loads
into every session at launch, same as `AGENTS.md`. With `paths:`, the rule stays out of the context
window entirely until the agent actually reads a file matching one of the listed paths, which is
the one mechanism in this repo that genuinely keeps an always-relevant instruction out of every
session that does not need it.
In depth: `docs/context-window-management.md:58`, `rules/shell-portability.md:2`

## phase and nested `CLAUDE.md`

For a multi-phase build, each phase gets its own directory with a short `CLAUDE.md` holding only
that phase's stated goal, current status, and task table. It stays out of context until the agent
works inside that phase's directory, so a build with many phases does not load all of their status
files at once. `templates/phase/` in this repo is the shipped pattern to copy.
In depth: `CLAUDE.md:64`, `docs/context-window-management.md:92`

## plan mode

Not a term this repo defines or names as a discrete artifact; confirm what "plan mode" means in
your specific tool's own documentation before relying on a definition. What this repo does define
and use heavily is a dispatched `Plan` subagent (see the host's built-in subagent types, above) and
the `/deep-plan` and `deep-plan-swarm` flows built on top of it.
In depth: `docs/planning-large-builds.md`, `commands/deep-plan.md`

## prompt

The instructions given to a model for a specific call, distinct from the context window that holds
it. A subagent's prompt is everything it starts with, because a fresh subagent dispatch has no
memory of the calling session's conversation; anything the calling session knows that the subagent
needs has to be written into that prompt explicitly.
In depth: `docs/choosing-your-tools.md:234`

## rule versus skill versus command versus hook versus context document

Five distinct mechanisms this repo keeps deliberately separate. A **rule** is a file under
`.claude/rules/*.md` that loads automatically, either every session or, with `paths:` frontmatter,
only when a matching file is read. A **skill** is a directory `skills/<name>/SKILL.md` with real
`name:` and `description:` frontmatter, invocable by the Skill tool or by typing `/<name>`. A
**command** is a file at `commands/<name>.md`, a named flow the user triggers by typing it; unlike a
skill it never fires because the model judged it relevant, only because someone typed it. A
**hook** is a shell script Claude Code itself runs at a fixed lifecycle point, wired through
`settings.json`; this repo ships exactly one, the `PreToolUse` right-fit-model gate. A **context
document** is a flat `<name>.md` file with no invocable frontmatter: not a skill, not a rule unless
placed under `.claude/rules/`, just a document some other instruction has to load deliberately by
naming it.
In depth: `CLAUDE.md:26`, `docs/choosing-your-tools.md:114`, `docs/choosing-your-tools.md:166`

## run-id

An identifier substituted into a required-artifact path when the project-scope workspace-brain
module is in use, for example `active/contracts/<run-id>.md`. The exact format of a run-id is not
specified in this repo; treat it as whatever stable, unique label the session picks for the task at
hand, consistent across every artifact path for that same task.
In depth: `templates/project/CLAUDE.md:76`

## scope (user versus project)

User scope is what `harness install --user` writes into `~/.claude/`: agents, skills, commands,
hooks, and the instruction core, loaded in every session, in every repository, until removed.
Project scope is what `harness init` and `harness add` write into one specific repository:
`AGENTS.md`, `CLAUDE.md`, `.project-state/`, and whichever optional modules are added, loaded only
when working inside that repository. The workspace-brain module is deliberately project-scope
rather than user-scope, so its artifact-persistence discipline never appears uninvited in a
repository that has not opted in.
In depth: `docs/getting-started.md:62`

## session

One continuous run of an agent against a context window, ending at a `/clear`, a new session start,
or the process exiting. A session has no memory of a prior session's conversation; only what was
written to a durable file survives the boundary.
In depth: `docs/context-window-management.md:5`

## subagent

A separate agent dispatch, started fresh with no memory of the calling session's conversation,
given a written prompt and (per this repo's own hard rule) an explicit model rather than a silent
inheritance from whatever dispatched it. This repo defines its own subagent roles as files under
`agents/*.md`, each carrying a `model:` tier pin in its frontmatter that `harness install` resolves
from `config/models.conf`.
In depth: `AGENTS.md:54`, `hooks/require-agent-model.sh:1`

## tier

One of four capability bands this repo sizes delegated work against, defined by what a task
requires rather than by which model currently fills the band: **SMALL** for extraction,
classification, and mechanical grind a test can check; **MID** for production prose, frontends, and
mid-complexity implementation against an existing pattern; **FRONTIER-DO** for correctness-critical
logic, anything on a send/deploy/money path, and adversarial review of the row below it;
**FRONTIER-THINK** for first-principles analysis, root-causing an unexplained failure, and
greenfield design. The two frontier tiers differ by disposition, not raw strength: FRONTIER-THINK
asks "what is really going on, and what should this be?", FRONTIER-DO asks "is this actually right,
and will it hold?" `config/models.conf` is the single place that binds each tier to a literal model
name.
In depth: `AGENTS.md:36`, `config/models.conf`

## worktree

An isolated working copy of a git repository, checked out on its own branch, letting concurrent
workstreams edit without colliding on the same files. This repo dispatches a subagent into its own
worktree whenever a piece of work needs isolation from other concurrent edits, and cautions that the
git stash stack is shared across all worktrees of the same repository, so a bare `git stash` inside
one worktree can pop another session's changes.
Two paragraphs because the shared-stash trap above is a real, repeated failure mode worth
restating: prefer a temporary WIP commit over stashing when setting work aside inside a worktree,
and if a stash is unavoidable, tag it uniquely, capture its SHA immediately, and restore with
`git stash apply <sha>` rather than a bare `pop`.
In depth: `docs/writing-your-own.md`, `docs/choosing-your-tools.md:230`

## the Workflow tool

Not defined with its own section in this repo's current docs under that exact heading; used
throughout as the mechanism for a per-call `agent({model, effort})` dispatch, distinct from a plain
Agent-tool subagent call which takes `model` but has no `effort` parameter. Confirm the tool's full
capability surface against your own tool's documentation before relying on details beyond this
usage.
In depth: `commands/deep-plan.md:53`, `docs/planning-large-builds.md:62`
