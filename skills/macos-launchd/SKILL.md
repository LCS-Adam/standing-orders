---
name: macos-launchd
description: Troubleshoot a macOS launchd user agent that will not load, will not stay running, or cannot find its interpreter. Covers bootstrap errors, plist validation, KeepAlive semantics, the PATH problem that breaks version-managed runtimes, and reloading cleanly after an update. For per-user LaunchAgents; a system-wide LaunchDaemon runs as root and is a different risk category.
---

# macOS launchd

A user agent lives at `~/Library/LaunchAgents/<label>.plist` and runs as you, at login, without a
shell. Most launchd problems come from that last part.

## launchd does not source your shell configuration

This is the single most common cause of an agent that works in a terminal and fails under launchd.
Your `.zshrc` or `.bashrc` never runs, so anything that puts an interpreter on your PATH has not
happened. A version-managed runtime is the usual casualty: the binary exists, and launchd cannot
see it.

The fix is to be explicit. Put the full absolute path to the interpreter in `ProgramArguments`, and
set `PATH` in the plist's `EnvironmentVariables` rather than assuming one. Do not point at a
symlink that a version manager repoints later; name the resolved path, and expect to update it when
you change runtime versions. If your tooling warns that it cannot find the runtime the way a shell
would, that warning is expected under launchd and is not itself the fault.

## Bootstrap errors

`Input/output error` on load almost always means the label is already loaded. launchd will not
bootstrap a label twice. Unload first, then load.

Check what is actually loaded before assuming: list the loaded labels and grep for yours. A label
that is loaded but not running is a different problem from one that never loaded, and the two are
easy to confuse.

Validate the plist itself before blaming launchd. A malformed plist fails in ways that look like a
launchd problem. Lint it.

## KeepAlive means less than it looks

`KeepAlive` set to true restarts the job whenever it exits, for any reason. `KeepAlive` with a
`Crashed` subkey restarts it only on a non-zero exit, so a clean shutdown stays down. That
distinction is usually the answer to "why did it not come back".

Test the behaviour you think you configured rather than trusting the plist. Kill the process and
watch whether it returns. A restart policy nobody has exercised is a guess.

## Reloading after an update

Unload, update, load, then verify it is listed. Verifying is the step people skip, and it is the
only one that proves the new version is the one now running.

## Leftover labels from a previous install

Software that has been renamed or reinstalled can leave an old plist behind, and two agents
competing for the same port or the same state directory produce symptoms that look like corruption.
Look for stale labels from previous names before debugging the current one, and unload a stale
agent before deleting its plist, or launchd keeps the job until logout.

## What to check first

Loaded labels, then the plist lints clean, then the interpreter path is absolute and real, then the
log paths the plist names actually exist and are being written. Four observations, in that order,
resolve most of it.
