# Running this harness on Windows

The installer, the scrub gate and the hooks are bash. They use `perl`, `jq`, `awk`, `sed`, `find`,
`mktemp` and friends. There is no PowerShell port and there is not going to be one: a second
implementation of a security gate drifts from the first, and the drift is invisible until the day
it matters.

So Windows works through a POSIX shell. Two are supported, and one of them has a real hole in it.

## Pick one, and know what you are picking

| | WSL 2 | Native Windows + Git for Windows |
|---|---|---|
| Harness scripts | work as on Linux | work in Git Bash |
| The model-pin hook | enforced | **enforced only if Git Bash is detected**, see below |
| Sandboxing | supported | not supported |
| Config location | the Linux `$HOME/.claude` inside WSL | `%USERPROFILE%\.claude` |

**WSL 2 is the recommended path.** It is a first-class target in Claude Code's own setup
documentation, sandboxing works there, and everything in this repository behaves as it does on a
Mac. You install and launch `claude` from inside the WSL terminal, not from PowerShell.

## The one thing to read before trusting the gate

`hooks/require-agent-model.sh` denies a subagent spawn that would silently inherit the parent's
model. On native Windows it can fail to run at all, and when it does, **the spawn proceeds**.

Three facts stack up:

1. A `PreToolUse` hook blocks on exit code 2 and nothing else. Any other outcome, including the
   interpreter never launching, is treated as a non-blocking error and the tool call continues.
2. A shell-form hook command runs under Git Bash if Claude Code finds it, and falls back to
   PowerShell if it does not.
3. The shipped command is `bash ~/.claude/hooks/require-agent-model.sh`. Under PowerShell there is
   no `bash`, and `~` is not expanded the way a POSIX shell expands it.

Put together: on a stock Windows box with no Git for Windows, the gate never runs, nothing in the
session says so, and every dispatch is ungated. This matches an open upstream issue
(anthropics/claude-code#90077) reported in August 2026 and unresolved at the time of writing.

**What to do about it.** Install Git for Windows and confirm Claude Code finds it. Run
`claude doctor` as part of setting a machine up. If autodetection fails, point at it explicitly with
`CLAUDE_CODE_GIT_BASH_PATH`. Or use WSL 2 and skip the question.

If you are the person fixing this rather than working around it, [`docs/windows-gate-investigation.md`](windows-gate-investigation.md)
is the brief: the candidate fixes, what evidence would settle each, and the user instructions the
answer has to produce.

**What not to do.** Do not assume a green `harness verify` says anything about this. The gate checks
the repository; it cannot see whether a hook fired in your session. Nothing in this repository can
detect the failure, which is why it is written down here instead.

The command in `config/settings.portable.json` is deliberately unchanged. It is correct on macOS,
Linux and WSL, it is correct on Windows with Git Bash, and rewriting a working security hook against
documentation nobody here can test on the platform in question is how you break the thing you were
trying to protect.

## Commands, side by side

Everything in these docs is written for a POSIX shell. In Git Bash and WSL you type it exactly as
written. The differences are in getting there.

**Opening the right shell.** In Git Bash, right-click a folder and choose "Git Bash Here", or run
`"C:\Program Files\Git\bin\bash.exe"`. In WSL, open your distribution from the Start menu.

**Paths.** A path written here as a POSIX home directory is your Windows profile folder seen from
Git Bash, and the same folder appears under a mount point when seen from inside WSL:

```text
docs say          ~/projects/standing-orders
Git Bash sees     the same, mapped to your profile folder
File Explorer     %USERPROFILE%\projects\standing-orders
WSL sees          a /mnt mount of the same drive, then the same profile path
```

Keep the clone on the same side as the shell you use. A repository on the Windows filesystem
accessed from WSL is slow, and one on the WSL filesystem is invisible to Windows tools.

**Prerequisites.** Git Bash ships most of what the scripts need, but `jq` is not included. Install
it and put it on PATH before running the installer; `harness install` checks for it and stops rather
than half-installing. In WSL, `apt install jq` covers it.

**Line endings.** Set `git config --global core.autocrlf input` before cloning. A script checked out
with CRLF line endings fails with an unhelpful error about a missing interpreter.

**Redirection.** Commands in these docs such as `scripts/gen-reference.sh > docs/reference.md` are
safe in Git Bash and WSL. Do not run them from PowerShell: its redirection writes a different
encoding by default, and the generated-files check compares byte for byte.

## What is not tested here

Nobody has run this harness on Windows. Everything above comes from Claude Code's own documentation
and from reading this repository's scripts, the same standard the Augment material is held to. The
first person to set a Windows machine up should correct this page from what actually happened, and
the gate is the place to start: dispatch a subagent with no model pin and confirm it is refused.
