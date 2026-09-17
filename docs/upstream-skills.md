# Upstream skills: what actually lands on a new machine

[docs/upstream-sources.md](upstream-sources.md) is the policy: other people's skills are cloned
next to this repo, never copied in, and the ones `config/upstream.conf` marks with `install=` are
deployed into `~/.claude/` by `harness install --user`. That page never says what those skills are.
This one does. It is written for the engineer who has just run the install on a fresh machine and
now has thirteen additions to their everyday toolkit, from five projects, none of which this
repository wrote.

Everything below was gathered by reading the clones on disk and reconciling that against
`harness install --user --dry-run`. The two agree exactly. Run the dry run yourself before trusting
this page on a machine whose clones may be newer than the day it was written; the clones track
`main`, and nothing here is pinned.

## Contents

- [Read this before you run install](#read-this-before-you-run-install)
- [What lands, at a glance](#what-lands-at-a-glance)
- [superpowers](#superpowers)
- [ponytail](#ponytail)
- [humanizer](#humanizer)
- [notebooklm-py](#notebooklm-py)
- [graphify](#graphify)
- [graphify has no licence file](#graphify-has-no-licence-file)
- [joanium-skills installs nothing](#joanium-skills-installs-nothing)
- [What this page and the gate do not cover](#what-this-page-and-the-gate-do-not-cover)

## Read this before you run install

Two things separate this set from "some extra prompts landed in `~/.claude`".

**`ponytail` is a persistent mode, not a tool.** Once invoked, its own text says it is "ACTIVE
EVERY RESPONSE" until you say "stop ponytail" or "normal mode". Every piece of code the agent
writes after that goes through its seven-rung ladder, in every response, whether or not you asked
for it in that response. If you install it and do not know this, you will wonder why the agent
started writing terser code and refusing abstractions unprompted. Nothing else in the set behaves
this way: the other twelve do their work when invoked and do not change how the agent behaves in
later responses.

**Two of the thirteen reach outside the machine.** `notebooklm` and `graphify` pip-install
third-party packages on first use and make live network calls. `notebooklm` goes further: it holds
what its own documentation calls "a durable full-account credential that survives password changes"
for a Google account, written to `~/.notebooklm/` outside any repository. The other eleven are
self-contained prompting skills. They read files, dispatch subagents, and write text, and none of
them opens a socket or installs anything.

And the standing caveat from [docs/operating-boundaries.md](operating-boundaries.md): this
repository's gate does not scan any of this code. It scans nothing under `.upstream/`, and it says
so on every run. Installing an `install=` entry is a decision to run unscanned third-party
material. If your organization cannot accept that, remove the `install=` field from the entry and
the next install retires the skill.

## What lands, at a glance

| Skill | Project | Shape | Leaves the machine |
|---|---|---|---|
| `brainstorming` | superpowers | Procedure with a hard gate | No |
| `requesting-code-review` | superpowers | Dispatches a fresh subagent | No |
| `systematic-debugging` | superpowers | Four-phase procedure | No |
| `test-driven-development` | superpowers | Procedure with a hard rule | No |
| `ponytail` | ponytail | Persistent mode | No |
| `ponytail-review` | ponytail | One-shot report over a diff | No |
| `ponytail-audit` | ponytail | One-shot report over a repo | No |
| `ponytail-debt` | ponytail | One-shot ledger, may write a file if asked | No |
| `ponytail-gain` | ponytail | Static scoreboard | No |
| `ponytail-help` | ponytail | Static reference card | No |
| `humanizer` | humanizer | Four-step prose edit | No |
| `notebooklm` | notebooklm-py | CLI and Python API over a Google product | Yes: pip install, authenticated calls, stored credential |
| `graphify` | graphify | CLI plus subagents, writes a `graphify-out/` tree | Yes: pip install, URL fetch, optional Neo4j push and MCP server |

"Leaves the machine" means the skill itself makes network calls or installs packages. Every skill
runs inside a model session, so the prompt and whatever files the agent reads go to the model
provider regardless. That is the same exposure as any other session and is covered in
[docs/operating-boundaries.md](operating-boundaries.md) under "What leaves the machine".

## superpowers

Jesse Vincent's collection (github.com/obra/superpowers, MIT, copyright 2025 Jesse Vincent) packages
a software-development methodology as composable skills. This harness installs four of them, and
`config/upstream.conf` names them individually rather than taking the whole set.

Four pinned snapshots of the same skills already live in this repository's `skills/` directory as an
offline fallback. An upstream skill overrides a harness skill of the same name, and the install
prints that on the line where it happens. Where the snapshot and the clone disagree, the clone is
the author's current intent. `skills/THIRD_PARTY.md` records the snapshots and how they retire.

| Skill | What it does | Reach for it when |
|---|---|---|
| `brainstorming` | Classifies a creative request as a spike, a bounded change, or an architectural one, then runs a matching round of clarifying questions and proposed approaches. Hard gate: no implementation code until a human approves a design. | You are about to build something and the shape is not yet agreed. |
| `requesting-code-review` | Dispatches a fresh subagent with a minimal context package (a description, the requirements, and the base and head git SHAs) to review a diff, instead of reviewing inside the main session's already-loaded context. | You want a review that has not been reading your session for the last hour. Needs git. Costs one extra agent invocation per run. |
| `systematic-debugging` | Four phases: root-cause investigation, pattern analysis, single-hypothesis testing, test-first fix. Its Iron Law is that no fix is proposed before phase one completes. Three failed fixes means question the architecture, not the symptom. | Anything that looks like a bug, before anyone proposes a patch. |
| `test-driven-development` | Red, green, refactor. Its Iron Law is no production code without a failing test first, and code written before its test gets deleted rather than kept as reference. Names the exceptions to ask about: throwaway prototypes, generated code, config files. | Implementing a feature or a fix where a test can exist. |

**What will surprise you.** All four cross-reference sibling superpowers skills this harness does
not install: `writing-plans`, `verification-before-completion`, and `elements-of-style`.
`brainstorming` ends by telling the agent to invoke `writing-plans` and nothing else;
`systematic-debugging` tells it to run `verification-before-completion` before claiming success.
On a machine with only these four, those references dead-end, and the handoff the author designed
does not happen. What the host does with a reference to a skill it cannot find varies. If you want the
full chain, widen the `install=` list in `config/upstream.conf`; if you do not, know that the
procedure ends one step earlier than its text says.

## ponytail

DietrichGebert's ponytail (github.com/DietrichGebert/ponytail, MIT, copyright 2026 DietrichGebert)
is a "lazy senior developer" persona plus a set of one-shot review skills built on the same
judgement. This harness installs everything it ships, six in all, because `/ponytail-review`
is load-bearing: it is step 3 of the per-wave gate stack in this repository's `autorun-plan` skill,
and the `ponytail:` comment convention this repository uses to mark a deliberate shortcut comes
from the same project.

| Skill | What it does | Reach for it when |
|---|---|---|
| `ponytail` | Turns on the mode. Every subsequent piece of code goes through a seven-rung ladder (does this need to exist, is it already in the codebase, does the stdlib do it, does a native platform feature cover it, does an installed dependency solve it, can it be one line, and only then the minimum code that works) plus anti-abstraction rules. Three intensity levels, default "full". | You want the agent to fight over-building on every response for the rest of the session. |
| `ponytail-review` | Over-engineering review scoped to a diff. One line per finding: location, what to cut, what replaces it. By its own text it is out of scope for correctness bugs, security holes, and performance. | Before a merge, alongside a correctness review, never instead of one. |
| `ponytail-audit` | The same review over a whole repository. Ranked findings with fixed tags (delete, stdlib, native, yagni, shrink) and a net-lines-saveable summary. | Inheriting a codebase, or wondering what a repo could lose. |
| `ponytail-debt` | Harvests every `ponytail:` marker comment into a ledger: file, line, what was simplified, its ceiling, and the trigger that should upgrade it. Flags any marker with no named upgrade path as silent-rot risk. | Periodically, so deliberate shortcuts get tracked instead of forgotten. |
| `ponytail-gain` | Prints the project's published benchmark medians. It refuses to report a per-repo number because there is no unbuilt baseline to diff against. | Someone asks what the mode is worth. Do not expect a figure for your repo. |
| `ponytail-help` | Static reference card of modes and commands. | You forgot the switch syntax. |

**What will surprise you.** The mode is the whole point and the whole hazard. It stays on until you
say "stop ponytail" or "normal mode", and its own text says it stays on even when the agent is
unsure whether it applies. The intensity is changed by giving the skill an argument (`lite`,
`full`, or `ultra`), by the `PONYTAIL_DEFAULT_MODE` environment variable, or by
`~/.config/ponytail/config.json`. It is explicitly not for non-coding requests: prose, translation,
summaries, and the like are outside its remit, so if you invoke it and then ask for a document, the
document should be unaffected.

`ponytail-debt` is the only skill in the set that can write a new file into your repository, and
only when explicitly asked to produce a ledger file. Everything else in the project reports and
changes nothing.

## humanizer

Siqi Chen's humanizer (github.com/blader/humanizer, MIT, copyright 2025 Siqi Chen) installs one
skill, `humanizer`, which rewrites prose that reads as machine-written. It catalogues about
twenty-five tells across five categories, then runs a four-step edit: mark the tells, rewrite while
keeping every supported claim, check the draft against the source for facts dropped or added, and
finalise.

It is load-bearing for this repository's own rule. `AGENTS.md` requires that anything a third party
reads must not read as machine-written, and `verify.sh` check 8 can only catch the banned
characters that habit leaves behind. This skill catches the habit. A document that swapped every em
dash for a spaced hyphen and kept the same rhythm passes check 8 and fails a reader; this is what
finds it.

Reach for it on anything in the client-facing set: a README, a proposal, an email, a cover letter.
It runs entirely locally, with no network, so no document leaves the machine to be rewritten. It
carries its own prompt-injection guard: the text being edited is material, never instructions.

**What will surprise you.** Compression can silently drop a real claim. Step three, the fact-check
against the source, is the step that matters, and it is the one an agent in a hurry will skim.
Read the diff yourself when the document carries numbers, names, or dates.

## notebooklm-py

Teng Lin's notebooklm-py (github.com/teng-lin/notebooklm-py, MIT, copyright 2026 Teng Lin) operates
Google's Gemini Notebook through a CLI and a typed async Python API: notebook and source
management, grounded chat over the sources, and artifact generation and download. The skill's
frontmatter `name:` is `notebooklm`, not `notebooklm-py`. Searching your skill list for the
repository name finds nothing; search for the short one.

Reach for it when the work is explicitly in Gemini Notebook. The skill's own description rules out
the generic Gemini API and unrelated content creation.

**What will surprise you.** Its risk profile is unlike everything above it on this page.

- It pip-installs a third-party package on first use.
- It makes live, authenticated network calls to a Google product under your own account.
- It handles a master token that its own documentation calls "a durable full-account credential
  that survives password changes", stored under `~/.notebooklm/profiles/<profile>/` at mode 0600,
  outside any repository. The same documentation tells you to use a dedicated account, keep the
  token in a secret store, and revoke it if exposed. Take that advice.

The hard stops in `AGENTS.md` require explicit human approval before changing authentication or
secrets. Minting that token is exactly that. Do it yourself, deliberately, on an account you would
be comfortable losing, and never let an agent session paste it anywhere.

## graphify

Graphify-Labs' graphify (github.com/Graphify-Labs/graphify) turns a folder of files into a
queryable knowledge graph with community detection. It produces an interactive HTML view, a
GraphRAG-ready JSON export, and an audit report that tags every edge as EXTRACTED, INFERRED, or
AMBIGUOUS, so you can see which relationships were read from the files and which were guessed.

Reach for it when a corpus is too large to hold in one session and you want a persistent map of
how its pieces relate, one you can query weeks later without re-reading everything.
[docs/corpus-swarms.md](corpus-swarms.md) covers the alternative of reading it with a swarm.

**What will surprise you.** It is the heaviest thing in the set operationally.

- It pip-installs `graphifyy` on first use. The repository is the source to read; the package is
  what runs. [docs/upstream-sources.md](upstream-sources.md) explains that split.
- It dispatches subagents for semantic extraction, so every run makes metered model calls, not
  just the one session you are sitting in.
- It can fetch arbitrary URLs into a `raw/` folder, push to a Neo4j server, and start a local MCP
  server, each behind its own flag.
- It writes a `graphify-out/` tree into whatever folder it is pointed at, which may be outside
  this repository. Decide before running it whether that output should be committed or ignored.
- Its skill file is `skills/graphify/skill.md`, lowercase, not the `SKILL.md` this repository's
  own conventions describe. The installer matched it by frontmatter anyway, so it lands, but a
  search for `SKILL.md` in the clone will not find it.

## graphify has no licence file

There is no LICENSE file in the graphify clone. Its `pyproject.toml` declares MIT in the package
metadata, and nothing at the repository level confirms that declaration. Every other project on
this page ships a LICENSE file at its root.

This harness installs graphify anyway. Package metadata is a real statement of intent from the
author, and it is what a package index shows. It is also weaker than a licence file, because it
covers the package and says nothing explicit about the repository the skill file lives in. If your
organization's policy requires a repository-level licence before third-party code runs, this entry
does not meet it. Remove `install=*` from the graphify line in `config/upstream.conf` and the next
install retires it.

## joanium-skills installs nothing

`config/upstream.conf` also clones Joanium's collection (github.com/Joanium/Skills, Apache-2.0),
and that entry correctly has no `install=` field. It is over six thousand flat files in one
directory, with a frontmatter shape the installer refuses. It is there for a person or a coding tool
to read. One skill was hand-converted from it into this repository's own `skills/grill-me/`, and
`skills/THIRD_PARTY.md` records that.

## What this page and the gate do not cover

- **The gate does not scan any of this.** `verify.sh` holds the invariant that nothing it did not
  scan reaches `~/.claude`, with `install=` entries as the one declared exception. It prints the
  file and skill count of that exception on every run. Nothing in this repository checks these
  skills for absolute paths, banned glyphs, hardcoded model names, or anything else it checks its
  own material for.
- **This page is a snapshot of clones that track `main`.** A refresh can change any behaviour
  described here, and nothing announces it. The dry run shows what will land; it does not diff
  against what landed last time.
- **Nothing here reviews what the skills tell the agent to do.** A skill is a prompt. The
  procedures above are the authors' judgement, and where they conflict with `AGENTS.md` the
  instruction in [docs/upstream-sources.md](upstream-sources.md) is to report the conflict, not
  to resolve it silently. This page did not perform that audit. The dead-end cross-references in
  superpowers are the only gap the research behind it surfaced, and a gap is not a conflict.
- **The clone directory can hold more than the manifest names.** `.upstream/` is gitignored, so
  anything a person cloned there by hand sits beside the managed entries. Only entries in
  `config/upstream.conf` with `install=` are deployed; the rest is read material, whatever put
  it there.
