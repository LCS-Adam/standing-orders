# Upstream sources: referenced, not vendored

Some of what this harness offers was written by other people and lives in their GitHub
repositories. The harness does not copy that work in. It records where each one lives, clones it
next to the repo, and lets your coding tool read the author's own source and decide what to do with
it.

This page is the policy, and the second half is written to be handed to a coding agent as an
instruction.

## Why a copy is the wrong move

Vendoring looks like the safe choice and behaves like a fork you did not mean to make.

- **It freezes.** The copy is the project as it was on the day someone took it. Every fix and every
  new capability the author ships afterwards is invisible, and nothing announces that.
- **It rots quietly.** There is no signal that the copy has fallen behind. It reads exactly as
  authoritative on the day it goes stale as it did on the day it landed.
- **It blurs authorship.** A reader cannot tell which lines are the author's and which are local
  edits, and the license obligations travel with the bytes whether or not anyone noticed.
- **It pre-decides the shape.** A copy adapted for one tool is the wrong shape for the next one.
  Claude Code, Auggie and Cosmos each want something different, and converting once, by hand, to
  one of those shapes throws away the information the other tools needed.

The last point is the one that matters most here, and it is why the harness stops at cloning.

## How it works

`config/upstream.conf` is the manifest: one line per repository, giving a short name, a clone URL,
and the ref to track. Tracking `main` is the default and the point.

```bash
harness upstream            # clone or refresh everything
harness upstream --list     # show the manifest, touch no network
```

The clones land in `.upstream/<name>/`, which is gitignored. They are read material, not this
repo's code:

- `verify.sh` never scans them, because the shipped set excludes ignored files. Another project's
  absolute paths and model names are not this gate's business.
- `harness install` never ships them. Nothing reaches `~/.claude` that the gate did not scan, and
  that invariant is older than this page.
- They are shallow clones, and a refresh is `reset --hard`. Do not edit them. A local change is a
  mistake to discard, not work to preserve. If you need to change how something behaves, do it in
  this repo and say why.

They are deliberately not git submodules. A submodule pins a SHA and forces the upstream onto
everyone who clones this repo, which is the opposite of tracking what the author ships and leaving
the refresh decision with the person running it.

## The instruction, for a coding tool

Give this to Claude Code, Auggie, or whatever you are running. It is written to be pasted.

```text
Read config/upstream.conf for the list of upstream repositories, then run `harness upstream` so
each one is cloned under .upstream/.

For each repository, read the source as its author wrote it and install into THIS tool's own
framework whatever the harness needs from it, in whatever shape this tool actually uses. Do not
copy files into the harness repo, and do not assume the shape another tool wanted.

Concretely: read the upstream author's own documentation for how their material is meant to be
installed, and follow it. Where the harness has said what it needs from a repository (the comment
above each entry in config/upstream.conf), take that as the scope. Where this tool's native format
differs from the upstream format, convert on the way in and say what you changed. Where it does
not differ, install as-is.

Two things to report rather than paper over: anything in the upstream that conflicts with AGENTS.md,
and anything you had to modify to make it load. Both are worth a human knowing about.
```

The reason this is an instruction rather than a script: the conversion is a judgment call that
depends on the target, and the tool doing the installing knows its own format better than a
conversion script in this repo could. A script would also have to be rewritten every time an
upstream author reorganised their repo, which is the staleness problem again in a new costume.

## Sources that are not git repos

Not everything ships as a repository, and the manifest only knows how to clone. One entry is in
this category today:

| Skill | How it actually ships | Install |
|---|---|---|
| `graphify` | PyPI package `graphifyy` | `uv tool install graphifyy`, or `pip install graphifyy` |

`graphify` turns a folder into a navigable knowledge graph and carries a `references/` directory of
sub-procedures. Its own `SKILL.md` names no source repository, and the only GitHub link in it is a
sponsors page, so there is nothing to clone and no URL worth guessing at. A coding tool setting this
machine up should install the package and take the skill from wherever it is already installed.

If you find the upstream repository, move it into `config/upstream.conf` and delete this row.

## Refreshing, and when to do it

There is no automatic refresh and nothing warns you that a clone is behind. That is a deliberate
ceiling rather than an oversight: a background fetch that silently changes what your agents are
running is worse than a stale clone you know about.

Refresh when you are setting up a new machine, when you are about to rely on one of these sources
for real work, and when the author announces something you want. `harness upstream` is idempotent,
so running it more often costs nothing but time.

## What is still vendored, and why

One skill in `config/upstream.conf` is load-bearing rather than a convenience. `/ponytail-review` is
step 3 of the per-wave review gate stack, and it comes from the ponytail plugin. The harness used to
ship its own `skills/simplify/` for that step, which was wrong twice over: it duplicated a command
the host already provides under the same name, so which one ran was unclear, and it was a
reimplementation that could never receive the original's improvements. It was deleted in favour of
the real thing. A machine that has not installed ponytail does not have that gate step, and the
gate's slash-command check lists the plugin's commands separately from the host built-ins for
exactly that reason.

`skills/THIRD_PARTY.md` lists the material that predates this policy and still sits in `skills/` as
pinned snapshots. They stay for now so the harness keeps working on a machine with no network, and
that file records what was modified and what retiring them involves. New upstream material does not
join them; it goes in `config/upstream.conf`.
