# Building a private knowledge vault

This document is for an engineer who has run `harness init` on a repository and wants agents to
maintain a corpus over time (runbooks, decision records, vendor notes, postmortems) without letting
them corrupt it or leak it. A second reader is the security reviewer who has already read
[`docs/operating-boundaries.md`](operating-boundaries.md) and wants the vault-specific addendum: what a corpus adds to the
leakage surface, and which controls close it.

## Contents

- [1. What a vault is](#1-what-a-vault-is)
- [2. The layout](#2-the-layout)
- [3. How to tell generated from authored](#3-how-to-tell-generated-from-authored)
- [4. The edit surface](#4-the-edit-surface)
- [5. Isolation: enforced, discipline, and absent](#5-isolation-enforced-discipline-and-absent)
- [6. The improvement process](#6-the-improvement-process)
- [7. Worked example: an SRE knowledge vault](#7-worked-example-an-sre-knowledge-vault)
- [8. Replication recipe](#8-replication-recipe)
- [9. Failure modes](#9-failure-modes)
- [10. What the harness already provides](#10-what-the-harness-already-provides)

## 1. What a vault is

A vault is a private corpus with one authorized writer, a deterministic projection into read-only
artifacts everything else consumes, and an append-only proposal queue that carries findings back to
the writer without letting any consumer edit the corpus directly. That shape exists to prevent three
concrete failure modes:

- a consumer edits the corpus to make its own output pass, instead of reporting what is missing;
- a correct finding gets logged as non-blocking somewhere and is never acted on;
- a bulk import drowns the corpus in unsourced or unverified claims.

Two repositories play two different roles. One is the corpus itself: an editable knowledge base
with an input zone, a compiled body of articles, and a deterministic pipeline that checks them. The
other is a consumer: it reads the corpus and produces generated artifacts other tools use, and it
never writes back except through a proposal queue.

## 2. The layout

The corpus repository:

| Directory | Role |
|---|---|
| `raw/` | Input zone. Source material lands here: exports, notes, documents, anything not yet reviewed. Consumers never read `raw/` directly; only the authorized writer promotes material from `raw/` into the corpus. |
| `wiki/` | The compiled corpus. Folder-per-article: `wiki/<topic>/<slug>/<slug>.md`. Each topic carries an exhaustive `_index.md` and, where useful, a curated tour document. A `_master-index.md` at the root lists every topic; a `_tags.md` holds the controlled vocabulary. |
| `scripts/` | The deterministic pipeline: one JSON schema per record type, validators, compilers that derive draft inputs (never final prose), idempotent migrators, and generated reports. |
| `output/` | Query results and generated reports. Typically near-empty; it exists for ad hoc runs, not routine ones. |
| `.project-state/` | Session handoffs and plans, in the same shape as `templates/project/.project-state/` in this harness. |

Two rules from that layout are worth stating exactly as design constraints, not style preferences.
First: **folder shape is a contract, not a style preference.** If a downstream consumer's path
logic assumes every article lives at `wiki/<topic>/<slug>/<slug>.md`, a third, deeper shape breaks
that consumer silently. Never invent a new shape without updating every reader of it first. Second,
on naming: **boring names.** If an agent has to infer where something belongs, the structure is too
clever. When two plausible homes exist for a new article, pick the boring one and cross-link from
the other rather than adding a third category.

The consumer repository projects the corpus into generated artifacts and keeps its own state
separate from the corpus's:

- A data contract document splits the consumer repo into a layer a human edits and a layer that is
  safe to regenerate, and states plainly that the corpus itself lives outside both layers and is
  read-only from the consumer's side.
- A sync step produces the generated artifacts: deterministic, keyed on the corpus's source commit,
  so an unchanged corpus reproduces byte-identical output.
- Runtime working directories (in-flight items, an archive of closed items, a batch queue) are
  tracked as empty directories with a `.gitkeep` sentinel while their contents are ignored: the same
  pattern this harness uses for `runtime/`.
- Program state (plans, handoffs, pass reports) is tracked by explicit decision, recorded as a
  comment in `.gitignore` next to the rule, because it is the project's memory across sessions and
  nothing else backs it up.

## 3. How to tell generated from authored

A reader who opens a file in the consumer repo needs to know in seconds whether it is safe to edit.
Four signals answer that, and a company vault should ship all four, not just one:

- A `.gitignore` comment next to each generated file names the command that rebuilds it.
- The generated file itself carries a provenance stamp: which corpus commit it was built from.
- A data contract document lists every file with a one-line purpose, distinguishing "generated by"
  from "yours."
- Generated reports are dated and pattern-ignored, so they never accumulate as tracked clutter.

## 4. The edit surface

Only one actor writes the corpus: a session whose working directory is the corpus root, so the
corpus's own instructions load and the session becomes the authorized writer. Call that actor the
librarian. Everything else may only drop source material into the input zone, append a proposal to
the queue, or stage a candidate record under a gitignored staging directory on a branch.

```
flowchart LR
  subgraph consumers [Consumers, read-only]
    A[Report or answer generation]
    B[Reviewer agent]
    C[Headless workers]
  end
  Q[(Proposal queue, append-only JSONL)]
  L[Librarian session, cwd = corpus root]
  W[wiki/ corpus]
  K[recompile --check, deterministic]
  G[Generated artifacts, stamped with source commit]
  A -- finding --> Q
  B -- finding via orchestrator --> Q
  C -- finding --> Q
  Q -- open items --> L
  K -- report --> L
  L -- one commit per session --> W
  W -- sync, keyed on HEAD --> G
  G --> A
  G --> B
  G --> C
  C -. denied: write or edit wiki, network fetch, git push .-> W
```

The queue is the channel that exists specifically because "log it and move on" loses findings. It
carries a small closed set of kinds (a broken link, a missing outcome, a dangling reference, a
naming leak, and similar), a status of open, applied, or rejected, and a rule that producers may
only append: a new item always starts open, and re-observing the same finding bumps a counter on
the existing row instead of adding a duplicate, so the queue stays a to-do list rather than a run
log. Only the librarian applies an item or changes its status. A rejection requires a note and
suppresses future re-observation of the same finding; an applied item that gets re-observed means
the fix did not actually take, and it reopens automatically.

The librarian arbitrates every change, and its decision input is a deterministic report, not
memory: a check script runs before any edit and again at the end of the session, and the session's
plan is built from what that report surfaces, not from what the librarian remembers about the
corpus's state.

A rejected or deferred item has three durable outcomes, never silent deletion: a queue item marked
rejected with a resolution note; a staged record marked parked in its manifest with the findings
that stopped it attached; or source material that stays in the input zone marked out of scope, never
promoted and never listed in the corpus index.

## 5. Isolation: enforced, discipline, and absent

Keep these three tiers separate when you evaluate any vault, including one you build from this
recipe. A rule in the middle tier is not a control; it is a hope.

**Enforced by a check** (a wrong action fails or is denied):

| Mechanism | How |
|---|---|
| Headless workers cannot write the corpus, the generated artifacts, or reach the network | A permissions deny list in each worker's settings file blocking writes and edits under the corpus path, outbound fetch and search, and `git push` |
| Malformed or under-specified records block the pipeline | The check script exits non-zero on any blocker-level finding: malformed frontmatter, a record missing its required fields |
| A restricted name cannot reach a generated artifact | A dedicated leak check treats any occurrence as a blocking failure |
| Generated artifacts are schema-valid and reproducible | Schema validation on the generated output, plus output keyed on the corpus's commit and golden and idempotency tests |
| An anonymized entity renders only its display name, never its real one | Enforced in the sync step's own render logic |
| Excluded source directories are never mined | A sentinel file plus an exclusion list, both read by code, not just documented |
| A malformed proposal cannot enter the queue | The append function throws on a missing required field or an invalid status or kind |

**Discipline only** (written down, relied on, not checked by anything):

| Rule | Why it is not enforced |
|---|---|
| Corpus edits happen only from librarian sessions | No deny rule exists for interactive sessions, only for headless workers; anyone with an interactive session and the wrong working directory can still write the corpus |
| Run the check script before any write and again at session end | Nothing runs it automatically if the session skips it |
| Commit at the librarian session boundary; never automate commits | Convention only; no hook backs it |
| Never run the sync from a worktree | The sync has no lock, so nothing prevents a second concurrent run |
| Swarm agents that read the corpus are read-only | Backed by an agent-type setting and prompt text, not a permissions deny |

**Designed and never built** (do not let a doc, or your own memory, claim these exist until they
do): a scheduled or scripted librarian runner; a fail-closed queue append that refuses to write if
the queue file is not gitignored; a lock file that serializes the sync step; an atomic publish step
that validates before swapping in new generated artifacts.

A single mechanism converts the biggest discipline-only row into an enforced one: a `PreToolUse`
hook, the same shape as `hooks/require-agent-model.sh` in this harness, that denies any write or
edit under the corpus's compiled-article directory unless the session's working directory is the
corpus root. Pair it with the deny block the headless workers already carry, and interactive
sessions get the same protection headless ones already have.

One more decision belongs here, and it should not be left implicit: whether the corpus repository
pushes anywhere at all. A private remote plus normal CI and a cloud code reviewer means the corpus's
tracked content is processed on vendor infrastructure, which may be fine for many corpora and wrong
for a genuinely sensitive one. If a corpus must never leave the machine, enforce that as three
layers, not one policy line: a file at the repo root stating the policy, a pre-push hook that blocks
every push, and a gitignore that excludes every category of sensitive content. If the policy is ever
relaxed, the remote must be a private repository on infrastructure the company controls. Whichever
you choose, record the decision in `.project-state/PROJECT_STATE.md`, the way
[`docs/operating-boundaries.md`](operating-boundaries.md) already asks you to record every leaves-the-machine decision.

## 6. The improvement process

```
flowchart TD
  R[raw drop or queue item] --> C1[check: deterministic validation]
  C1 --> AP[apply: safe mechanical fixes only]
  AP --> S[stage records under staging, gitignored]
  S --> LNT[record lint, fail-closed]
  LNT --> ADV[adversary review of the staged diff]
  ADV --> H{human gate?}
  H -- attestation or corpus-truth write --> HG[Operator approves one digest]
  H -- rule-statable --> M[manifest state: approved]
  HG --> M
  M --> FC[one fold-in commit, run-scoped tag before it]
  FC --> FZ[sync from a frozen checkout of that commit]
  FZ --> PUB[validate, then publish generated artifacts]
  ADV -- unresolved blocker --> P[parked, findings attached]
```

**The routine loop**, run at the start and end of every librarian session:

1. Run the check script; write its report to a dated file.
2. Address every blocker it surfaces.
3. Run the apply step for changes that are mechanical and safe: frontmatter fields, normalized
   tags, missing standard sections.
4. Handle remaining suggestions by hand: cross-links, prose.
5. Run the check step again to confirm the corpus is clean.
6. Commit once, at the session boundary.
7. On the consumer side, rerun the sync. It regenerates the artifacts and is byte-identical if the
   corpus did not change.

**The bulk loop**, for a large import or a sweeping enrichment pass, runs as an isolated multi-wave
effort rather than one long session: an early wave lands the lint, the staging scaffold, and the
librarian protocol alone, before anything else touches the corpus. A later wave fans work out over
disjoint staging directories so two workstreams never write the same file. Mining itself is tiered:
a cheap deterministic pass removes exact duplicates first, a small-tier swarm proposes candidates,
a mid-tier pass writes a report per group, and a single frontier-tier synthesis pass turns those
reports into records. A human attestation session follows for anything the corpus itself cannot
verify. Only after that does the librarian fold every staged record into the corpus as one commit,
and only after that does one coordinated sync run.

What is safe to apply without a person in the loop, and what needs one:

| Change class | Auto or human | Why |
|---|---|---|
| Frontmatter field insertion, tag normalization, a missing standard section | Automatic | The fix is idempotent and its diff proves it correct on its own |
| Cross-link suggestions, prose edits, new records built from sourced material | Librarian session, no separate human gate | The lint passes, review finds nothing blocking, and every source resolves to a real path |
| A claim only a person can attest to (a fact the corpus has no source for) | Human | Absence of a fact in the corpus is never proof the fact is false; route it to attestation, never to silent rejection |
| Any batch write to the corpus itself | Human | Writing to a source of truth a plan has marked read-only is never auto-approved |
| The sync step that publishes to consumers | Human | It needs a quiescent set of consumers and, until a lock exists, nothing else guarantees that |
| Honesty and framing corrections | Human, always | The librarian reports these; it does not silently edit tone or framing on its own judgment |

For the one mutation that actually changes the corpus, rollback is a single revert of the one
fold-in commit, made safe by a run-scoped tag placed before that commit and rehearsed ahead of time
in a throwaway worktree. Reverting the corpus does not by itself restore generated artifacts already
published from the bad state; a rollback always requires a follow-up sync.

Seven rules worth carrying into any librarian session, in the order they matter:

1. Verify against current state; never trust a stale status header.
2. Report distinct counts, never raw file counts, and claim no count at all when distinctness cannot
   be established.
3. A row in a task tracker is not a unit of volume.
4. Absence of a fact from the corpus is never evidence the fact is false.
5. A restricted term or personal detail is caught by running the leak check, not by remembering the
   rule.
6. Preserve the verb a source actually used: evaluated is not recommended is not observed is not
   deployed.
7. Every write is staged, approved as one digest, and applied as one commit, with a run-scoped tag
   placed before it.

## 7. Worked example: an SRE knowledge vault

- `raw/postmortems/`, `raw/vendor-docs/`, `raw/chat-exports/` hold input material. Chat exports
  carry a routing-status field, and anything marked out of scope stays in `raw/` and never reaches
  the corpus.
- `wiki/runbooks/<service>/<slug>/<slug>.md` follows a runbook schema requiring `service`,
  `owner-team`, `source`, a `source-type` of primary, third-party-witness, or
  secondary-synthesis, and `last-verified`. Body sections: Symptoms, Diagnosis, Remediation,
  Rollback, Key Takeaways, Related.
- `wiki/decisions/<slug>/<slug>.md` follows a decision schema with `status`, `date`, and
  `supersedes`, so a superseded decision stays discoverable rather than disappearing.
- `wiki/vendors/<slug>/<slug>.md` carries a naming policy and a display name, so a
  contract-restricted vendor name never surfaces in anything generated for a wider audience.
- The consumer is an on-call assistant reading a generated runbook index, stamped with the corpus
  commit it was built from. When it answers a page and the matching runbook has no rollback step,
  it appends a queue item naming the missing section and recommending either a Rollback section, if
  a tested rollback exists, or an explicit statement in Remediation that the action is irreversible.
- The librarian runs a weekly session with its working directory at the corpus root: check, drain
  open queue items, promote new postmortems into runbook updates, commit once, run the sync.
- A legacy wiki import runs as a bulk loop: an isolated worktree, a tiered mining swarm, staging,
  the lint, an adversary review, one attestation session with the service owners, one fold-in
  commit, one sync.

## 8. Replication recipe

1. Create the corpus repository. Run `harness init` for its `.project-state/`. Copy the corpus
   instructions shape from section 2: the directory layout, folder-per-article, boring names, a
   standard set of frontmatter properties, the librarian session protocol, and the check-then-apply
   workflow.
2. Write one JSON schema per record type and a check-and-apply script with blocker, warning, and
   suggestion severities, marking only mechanical fixes as safe to auto-apply.
3. Decide local-only versus a private company remote (section 5) and implement the choice fully:
   either a policy file plus a pre-push hook, or a private remote with CI disabled on the corpus
   repository.
4. Write the gitignore: editor state, generated reports by pattern, the staging directory, and a
   runtime directory. In the consumer repository, ignore every generated artifact by name with a
   comment naming its rebuild command, ignore every runtime directory as contents-only with a
   `.gitkeep` exemption, and ignore `.env`. Add a gate check that fails if a new data subdirectory
   is tracked without being listed in the data contract.
5. Create the consumer repository with a data contract document, a sync script that is
   deterministic and stamps the source commit into its output, and a queue-style intake validated
   against a schema.
6. Write the deny rules into every non-librarian settings file: no write or edit under the corpus
   path, no write to the generated artifacts, no outbound fetch or search, no `git push`.
7. Add the `PreToolUse` hook from section 5 so interactive sessions are denied the same way headless
   workers already are.
8. Port a fail-closed record lint (structural personal-data patterns, banned claim classes,
   disallowed glyphs) and wire it into the per-wave gate stack described in
   `skills/autorun-plan/SKILL.md`.
9. Only after all of the above let a swarm read the corpus. Only the librarian ever writes it.

## 9. Failure modes

| Incident, generalized | Fix |
|---|---|
| A write-enabled validator auto-wrote into the corpus during an automated run | Read-only agent type plus a permissions deny, not just a prompt instruction |
| A correct reviewer finding was logged as non-blocking and lost | The proposal queue: a finding always lands somewhere durable, never only in a log line |
| A plural frontmatter key was silently ignored by the sync step, producing empty provenance | Schema-required singular keys, caught by the lint before it reaches the sync |
| A stale status header nearly triggered a full redo of finished work | Verify against current state on disk, never trust a cached header |
| A mining pass invented figures that were not in any source | Every claim cites a path; an aggregate audit checks the whole batch, not just samples |
| A new data subdirectory was tracked by accident because gitignore entries were per-subdirectory | A gate check that fails on any tracked subdirectory not listed in the data contract |
| A sync ran while a librarian session was mid-edit, with no lock | Freeze a checkout at a specific commit before syncing, and publish the result atomically |

## 10. What the harness already provides

| Piece | What it gives you |
|---|---|
| `templates/project/.project-state/` | The state-file shape to copy into a new corpus repository |
| [`docs/operating-boundaries.md`](operating-boundaries.md) | What leaves the machine, where agent output lands, and the hard stops already enforced |
| `verify.sh` | The scrub-gate pattern: fail closed, scan the shipped set, check more than one byte source |
| `config/upstream.conf` | A reference for tracking a plugin dependency; do not vendor its contents |
| `hooks/require-agent-model.sh` | The shape of a deny hook to copy for the corpus write-surface hook in section 5 |
| `skills/external-llm-review/SKILL.md` | The pattern for sending one artifact by path to a read-only external reviewer |
| `skills/autorun-plan/SKILL.md` | The per-wave gate stack to wire the record lint into |
| `agents/plan-synthesizer.md` | The human-gate rule and the list of protections a plan may never weaken |
| [`docs/model-tiering.md`](model-tiering.md) | The tier vocabulary this document uses for the mining pipeline: a small tier for candidate generation, a mid tier for per-group investigation, a frontier tier for synthesis and adversarial review |
