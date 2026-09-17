# Context in Augment

`docs/context-health.md` covers watching a context window in Claude Code. Augment works differently
enough that the same advice does not transfer, and the difference is worth understanding before you
carry habits across.

## How to read the labels in this document

Nothing here was verified by running Auggie. This machine has never had it installed. Every claim
below is one of two things, and each is labelled:

- **Docs 2026-09-16**, followed by a page name and a line, means it was read in an offline capture
  of Augment's documentation taken on that date. That capture is a set of pages kept outside this
  repository, in the maintainer's own fork under
  `.project-state/research/2026-09-16_augment-docs-snapshot/`, which is why you will not find
  `aug_cli_reference.md` and its siblings here. The line numbers are stable because the capture is
  frozen. If you do not have it, read the same page live at `docs.augmentcode.com` and expect it to
  have moved on. `adapters/README.md` carries the same convention.
- **NOT FOUND** means the documentation does not answer the question. These are kept visible on
  purpose. A precise list of what is undocumented is worth as much as the list of what is.

A claim with neither label is a defect. Report it.

## Retrieval comes first

Augment is built around retrieval, not around filling a window.

Its Context Engine indexes the codebase and retrieves what a query needs, rather than reading whole
files into the model. Augment describes the design goal as retrieving "only what matters before the
model spends tokens" (`augmentcode.com/context-engine`, fetched 2026-09-16). The concrete surface
is a `codebase-retrieval` tool, which is what indexing gates and what a subagent's tool allowlist
can name (Docs 2026-09-16, `aug_cli_subagents.md:133,162`, `aug_cli_reference.md:101`).

So the failure mode shifts. In a plain long-context session the thing that goes wrong is the window
filling with material that dilutes attention. Here the thing that goes wrong is a retrieval miss or
a stale index: the model never sees the relevant code at all, and nothing in the window looks wrong.

NOT FOUND: the retrieval mechanism itself (ranking, chunking, embeddings), and how to detect a
retrieval miss. The docs name factors the ranking considers, not a formula, and describe no
recall failure handling. Treat "why did it not find that file" as an open question you will have to
answer empirically on the work machine.

## What you can see

Augment does have a context meter. It is in the interactive terminal UI only.

```text
/context   show context usage and token breakdown
/stats     session statistics, including messages, tools and credits
/skills    every loaded skill, its source, and its estimated token cost
```

Docs 2026-09-16, `aug_cli_interactive.md:96,110,121` and `aug_cli_skills.md:118,140,150`. The
skills view is explicitly framed as helping you understand the context cost of each skill, which is
the closest thing to a per-item breakdown in either tool.

**You cannot build a status line for Auggie today.** NOT FOUND: any way to read those numbers from
a script. Headless mode has a JSON output format, but no captured page shows a token-count or
context-usage field in it, and no flag or environment variable exposes one. The nearest proxy is a
credit usage summary in print mode, which is a billing metric and not a token count (Docs
2026-09-16, `aug_cli_reference.md:17,18`). If you want the number, you read it in the TUI.

One naming collision to know, because it is genuinely dangerous: `auggie token print` prints the
stored session authentication token. It has nothing to do with context tokens (Docs 2026-09-16,
`aug_cli_reference.md:244`).

## What you can control

### There is no compaction lever

NOT FOUND, and this one is load-bearing rather than an unread page. A targeted sweep of all
captured pages for compaction, summarization, pruning and truncation found only a display mode
named compact, which controls streaming output rather than context (Docs 2026-09-16,
`aug_cli_reference.md:16`). A web search aimed specifically at Augment found no page describing
compaction either.

So there is no documented equivalent of a manual compaction command and no documented automatic
threshold. If a session gets unwieldy, two levers are documented instead (Docs 2026-09-16,
`aug_cli_interactive.md:77,83,89`):

- **fork** branches the session into a new conversation, keeping history to that point. Use it
  before a token-heavy or risky step, so the parent stays lean and resumable.
- **new** starts a conversation with no history. A hard reset.

A third command, named clear, clears the visible scrollback while keeping the conversation history.
It sounds like a context reset and is not one. In Claude Code the similarly named command does
discard context. Do not carry the habit across.

### The biggest documented control is tool search

By default every tool from every configured MCP server loads its full schema into context before
your prompt is processed. Turning on tool search replaces that with two meta-tools that load a
schema only when a tool is actually used (Docs 2026-09-16, `aug_cli_reference.md:131-160`,
`aug_cli_integrations.md:286-300`). It is off by default.

If you configure more than a couple of MCP servers, turn it on. This is the single most direct
context control in the documentation.

### Rules have a load-on-demand mode

A rule can be marked as requested by the agent rather than always applied, and the docs frame this
explicitly as a context-usage choice (Docs 2026-09-16, `aug_cli_rules.md:95`). It is the same idea
as the `paths:` frontmatter this harness already uses for Claude Code rules, described at
`CLAUDE.md` ("Context discipline"), for the same reason: keep the always-on set small.

### Narrowing what gets indexed

A session can be pointed at a narrower workspace root, and more than one root can be added (Docs
2026-09-16, `aug_cli_setup-auggie_workspace-context.md:15-19`, `aug_cli_reference.md:93,209`).

NOT FOUND: file-level exclusion mechanics. The workspace page defers them to a separate indexing
document that was not part of the capture, so whether there is an ignore-file equivalent, and how
large or binary files are treated, is unanswered.

### Turn bounds are not context bounds

Headless mode can cap the number of agentic turns (Docs 2026-09-16, `aug_cli_reference.md:99`).
That bounds how many tool-call cycles happen, which indirectly limits how much gets pulled in. It
is not a token budget. NOT FOUND: any numeric context budget setting distinct from the model's own
window.

## Keeping a parent session small

Subagents each get their own context window, run in parallel, and return only a summary of progress
to the main thread rather than their full transcript (Docs 2026-09-16, `aug_cli_subagents.md:34-37`).
That is the documented way to keep a manager's window small, and it is the same pattern this harness
uses when it gives each workstream its own agent and its own report file.

NOT FOUND: the exact return contract. The docs say a summary comes back, without specifying a
schema. If you need structure, specify it in the prompt and have the subagent write a file, which
is what `agents/exec-standard.md` ("Report to a FILE, not just as your final message") already tells agents in this repo to do.

In Cosmos the heavier equivalent is a worker, which is a full separate Expert with its own
environment. Augment's own guidance there is worth repeating verbatim in spirit: prefer a single
Expert while the whole workflow still fits in one context window, and if you must delegate, prefer
one or two workers with clean handoff boundaries, because orchestration brings the same coordination
and ownership problems as multi-threading (Docs 2026-09-16, `aug_cosmos_workers-subagents.md:69-71`).

## Across sessions

Plain Auggie sessions are saved locally and can be resumed or listed, and saving can be turned off
(Docs 2026-09-16, `aug_cli_reference.md:74-86`). That is a stored transcript, not memory.

Memory proper is a Cosmos Expert feature. An Expert can retain knowledge across sessions, scoped to
a repo, channel, project or user, written into a durable file layer. The read path is described as
loading matching-scope memory at the start of relevant work and flagging conflicts against current
evidence rather than trusting stale memory (Docs 2026-09-16, `aug_cosmos_experts-memory.md:9-40`,
`aug_cosmos_understanding-files.md:9-67`).

INFERRED, from the absence of any memory feature in the CLI-scoped pages: a bare Auggie user
without Cosmos gets no semantic carryover between sessions, only the resumable transcript. The docs
do not state this outright.

NOT FOUND: whether Expert memory is gated by plan or tier. Confirm that against the account before
designing a workflow that depends on it.

## What to actually do

1. Stop thinking in window percentages and start thinking about retrieval. The engine's job is to
   avoid needing the repo resident in context. Watch for the model not knowing about code that
   exists, rather than for a full window.
2. Turn on tool search before adding MCP servers.
3. Mark rules as agent-requested unless they are needed every turn.
4. Fork before an expensive or risky step. There is no compaction to fall back on.
5. Delegate to a subagent when a task would bloat the parent, since only a summary returns.
6. Do not design around a scripted context meter. It does not exist yet.
7. Do not assume memory carries over without Cosmos, and confirm the plan covers it.

## Open questions for the work machine

These cannot be answered here and are the first things to check with Auggie actually installed.

- What does the headless JSON output contain, and is there any usage field in it.
- Is there an ignore-file equivalent, and what is excluded from indexing by default.
- What does a retrieval miss look like from the operator's side, and how do you notice one.
- Is Cosmos Expert memory available on this organization's plan.
