# Investigation brief: the model-pin gate on Windows

[`docs/windows.md`](windows.md) and [`docs/operating-boundaries.md`](operating-boundaries.md) record a gap rather than fixing it. The
model-pin hook does not reliably enforce on native Windows, this repository cannot close that on its
own, and the honest disclosure is already in both places.

This page is the work of closing it. Everything below the line is a prompt, written to be handed
whole to a research agent or a capable model with web access. It is committed rather than kept as a
scratch file because the gap ships with the harness, and whoever picks it up should not have to
reconstruct the question first.

Nothing here has been researched or tested. It states what to find out and what evidence counts.
When someone completes it, the findings belong in [`docs/windows.md`](windows.md), the disclosure in
[`docs/operating-boundaries.md`](operating-boundaries.md) gets revised or removed, and this page can go.

---

## Your task

A security hook in an agent harness does not enforce on native Windows. Determine, from primary
sources, which of the candidate fixes below actually work; produce a recommended fix with the
evidence for it; and produce the instructions a user follows to confirm the gate is live on their
own machine.

Do not accept a fix as working because it looks reasonable. Every claim you make must be traceable
to vendor documentation, a released changelog, a tracked issue, or a test you ran yourself on
Windows. Where you cannot establish something, write NOT ESTABLISHED and say what evidence would
settle it. A confident wrong answer here silently disables a security control.

## The system

An agent harness ships a `PreToolUse` hook that denies any subagent dispatch which would inherit the
parent session's model instead of naming one explicitly. The point is cost and correctness control:
an unpinned dispatch silently runs frontier-tier work on whatever the parent happened to be.

Shipped configuration, in the user's `settings.json`:

```json
{
  "hooks": {
    "PreToolUse": [
      { "matcher": "Agent|Task",
        "hooks": [
          { "type": "command",
            "command": "bash ~/.claude/hooks/require-agent-model.sh",
            "timeout": 10,
            "statusMessage": "Right-fit model gate" } ] } ]
  }
}
```

The script reads the hook payload on stdin, and on refusal writes a JSON object to stdout with
`hookSpecificOutput.permissionDecision` set to `deny`, then exits 0.

## The three facts that combine into the failure

Verify each independently before you build on it. If any is wrong, say so; the conclusion changes.

1. A `PreToolUse` hook blocks a tool call on exit code 2 and on a `deny` decision. Any other
   outcome, including the interpreter failing to launch, is treated as a non-blocking error and the
   tool call proceeds.
2. A shell-form hook command on Windows runs under Git Bash when Claude Code detects it, and falls
   back to PowerShell when it does not.
3. Under that PowerShell fallback, `bash` is not a command and `~` is not expanded as a POSIX shell
   expands it, so the command cannot run.

Net effect to confirm or refute: on a Windows machine with no Git for Windows, the gate never runs,
every dispatch proceeds ungated, and nothing in the session reports it. A related open issue is
`anthropics/claude-code#90077`. Check its current state; it may have moved since this was written.

## Candidate fixes to evaluate

Assess each on: does it work, on which Windows configurations, does it fail open or closed when its
own precondition is missing, and what does it cost in maintenance. Rank them at the end.

1. **Exec form.** Replace the shell-form command with an `args` array naming a real executable, so
   no shell is involved. Establish what `command` must be, whether a `.cmd` or `.bat` shim can ever
   be used this way, and how the script path is expressed without a tilde.

2. **Explicit shell selection.** Set the hook's shell explicitly rather than relying on
   autodetection. Establish whether such a field exists in the current schema, its exact name and
   accepted values, what happens when the named shell is absent, and whether an unrecognised key is
   ignored or rejects the whole hook. That last point matters: a key that breaks parsing would
   disable the hook everywhere, including where it currently works.

3. **Remove the tilde.** Replace `~` with something expanded reliably on every platform. Establish
   which variables Claude Code itself substitutes into a hook command before execution, as opposed
   to variables the shell expands, and whether a user-scope hook has an equivalent of the
   project-directory placeholder.

4. **A PowerShell sibling.** Ship a `.ps1` alongside the `.sh` and select per platform. Establish
   whether one settings file can carry a platform-conditional hook, or whether the installer must
   write a different command per platform. Note the cost explicitly: two implementations of one
   security control, and the reason the maintainer has so far refused it is that the two drift and
   the drift is invisible until it matters. Say whether anything makes that risk manageable, such
   as a shared test vector both must pass.

5. **Generate the command at install time.** The installer already runs on the target machine and
   knows the platform. Have it write a platform-correct hook command into `settings.json` rather
   than shipping one string for everyone. Establish what it would have to detect, and what happens
   when the machine changes afterwards, for example Git Bash being uninstalled later.

6. **Make the failure loud, since it cannot be made to fail closed.** The hook cannot report a
   refusal it was never started to make. Establish whether a `SessionStart` hook, a statusline
   command, or any other surface can run a probe and warn when the gate cannot execute. State
   plainly whether that surface has the same fail-open property, which would make it decoration.

7. **Upstream.** Determine whether the vendor offers, or has indicated it will offer, a way to mark
   a hook as required so that a failure to launch blocks rather than proceeds. If not, draft the
   issue text that would ask for it, in one paragraph, with the security rationale.

Consider any option these miss. The list is a starting point, not a boundary.

## Deliverable

A single markdown document with these sections.

**Findings.** Each of the three facts confirmed, refuted or NOT ESTABLISHED, with the source.

**Evaluation.** One subsection per candidate: works or does not, on which configurations, fail-open
or fail-closed behaviour, maintenance cost, evidence.

**Recommendation.** One primary fix and one fallback. Say what the recommendation does NOT cover.
If the honest answer is that no fix makes this enforce on stock native Windows, say that plainly and
recommend the operational control instead, such as standardising on WSL 2.

**Instructions for users**, written for an engineer who is not the maintainer, split into three:

- *Setting up a Windows machine so the gate works.* Numbered, with the exact commands, and what
  correct output looks like at each step.
- *Confirming the gate is actually live.* This is the most important part and it must be a positive
  test, not an absence of errors. Give the user something to run that should be REFUSED, and say
  exactly what refusal looks like versus what silence looks like. Silence means the gate is off.
- *What to do when the check shows it is off.* In order, with the least disruptive option first.

**Residual risk.** What is still not covered after the recommendation is applied, in plain terms a
non-specialist manager can act on.

## Constraints

- Prefer primary sources: vendor documentation, changelogs, tracked issues. Community posts are a
  lead, not evidence.
- Quote the sentence you rely on rather than citing a page and leaving the reader to find it.
- Date every claim. This area moves and a reader six months from now needs to know what was current.
- Straight ASCII. No em dashes, curly quotes or ellipsis characters.
- If you test on Windows, state the Windows build, the Claude Code version, and whether Git for
  Windows and PowerShell 7 were installed. A test without that context cannot be reproduced.
