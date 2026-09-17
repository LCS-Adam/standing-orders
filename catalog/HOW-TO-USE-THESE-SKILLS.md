# How to use these skills

This tree holds several thousand skill files, each one a set of instructions written for an AI
coding assistant rather than for you. You do not read them and apply them yourself. You point your
assistant at one and it follows the procedure.

## Find the one you want

The folders are grouped by the kind of problem they solve, two levels deep. Start with the level-1
folder that matches the work, then the level-2 folder that matches the specific job:

```text
security-and-trust/secrets-and-key-management/credential-rotation-campaigns-blast-radius-notes/
data-platform-and-analytics/pipelines-and-ingestion/airflow-cost-guardrails/
frontend-and-user-experience/accessibility/accessibility-audit/
```

Every folder holds a `SKILL.md`. That file is the skill.

If you are not sure which folder, search instead. Each `SKILL.md` has a `trigger:` line listing the
phrases it answers to, so grep for how you would describe the problem out loud:

```bash
grep -rl "rate limit" --include=SKILL.md .
grep -rl "trigger:.*churn" --include=SKILL.md .
```

`joanium-taxonomy.md` explains what each folder is for and why the boundaries fall where they do.

## Use one, without installing anything

Open your assistant in the repository you are working on, and tell it to read the skill and follow
it. This works in any assistant that can read a file from disk:

```text
Read <path>/SKILL.md and follow it for this task: <what you want done>.
Tell me first what the skill says to do, then do it.
```

That second sentence matters. A skill is a procedure with steps and stopping points, and you want
to see the plan before the work starts, not after.

If the skill asks for something you have not given it, answer the question rather than telling the
assistant to continue. Most of these procedures resolve a decision early and then act on it; an
assistant that guesses the decision will confidently do the wrong work.

## Install one, so it is always available

Reading a skill by path works but you have to remember the path. Installing it makes the assistant
find it on its own and offer it when the work matches.

Copy the leaf folder, the one containing `SKILL.md`, into your user skills directory:

```bash
cp -R <path>/accessibility-audit ~/.claude/skills/
```

It is available in your next session. On Windows, run that from Git Bash or WSL, not PowerShell;
see `docs/windows.md` in the harness repository.

**Copy the ones you will use, not all of them.** Every installed skill is offered to the assistant
on every task, so a directory holding thousands of them makes it harder for the right one to
surface, not easier. A handful you actually reach for beats the whole tree.

## Why the folders are not the skill names

An assistant discovers skills in a flat directory: one folder per skill, no categories. The two
levels here are for you to browse, and they disappear when you install a leaf. That is why the copy
above takes the leaf folder and not the path above it.

## Where these came from

They are a third-party collection, referenced in `config/upstream.conf` and cloned by
`harness upstream`. This tree is generated from that clone by `catalog/build-joanium-tree.sh`, so
anything you edit here is overwritten on the next build. Change a skill by copying it into
`~/.claude/skills/` first and editing the copy.

The bodies are the original author's work, unmodified. Only the frontmatter `name:` was rewritten,
so that it matches the folder it sits in.
