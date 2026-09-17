---
paths:
  - "**/*.sh"
  - "**/*.bash"
  - "**/hooks/**"
---

# Shell script portability

These are load-bearing gotchas, each one learned from a script that passed on one machine and
failed on another. They load only when working on shell scripts.

## Scripts that run from hooks or other low-context environments

Use an absolute-path shebang and normalize `PATH` on line 2:

```bash
#!/bin/bash
PATH="/usr/local/bin:/usr/bin:/bin:/opt/homebrew/bin:${PATH:-}"; export PATH
```

`#!/usr/bin/env bash` depends on `env` finding bash on `PATH`, and some spawn environments arrive
with a sparse `PATH` and fail with `env: bash: No such file or directory`. Even once bash starts,
`sed`, `awk`, `git`, `sort`, and `head` all fail with "command not found" unless `PATH` is
normalized. One line removes the entire class of failure.

## Reading stdin in a script that runs both ways

A hook receives its event payload on stdin and will see EOF. The same script run by a person at a
terminal will not, so an unguarded drain blocks forever:

```bash
[[ ! -t 0 ]] && cat >/dev/null    # the guard goes with the drain, always
```

Whenever you add a stdin drain anywhere in a script, add the tty guard in the same edit. Treat them
as one pattern, not as a main-path detail.

## Hooks must not do slow work inline

Hooks run synchronously and block the action they fire on. If a hook needs to do anything slower
than about a second, read the payload in the foreground, then re-exec the heavy path detached and
return immediately:

```bash
nohup "$0" --bg "$@" </dev/null >>"$LOG" 2>&1 &
```

Keep the `--bg` branch at the top of the same script so the whole detach lives in one file. Note
that stock macOS has no `timeout`, so gate any timeout wrapper on `command -v timeout` and degrade
gracefully.

## A hook whose success path is silent cannot be verified

If a hook logs nothing on success, then the absence of a log line is consistent with both success
and a wrong-input failure, so reading the log proves nothing. Either give the success path its own
log line, observe the hook's durable effect directly, or add a temporary probe that captures the
raw stdin, trigger it once, and revert.

## bash 3.2 cannot parse a one-line `case` inside a command substitution

`/bin/bash` on macOS is 3.2, and every script here starts `#!/bin/bash`, so that is the interpreter
whatever else is installed. It rejects this:

```bash
X=$(
  while read -r a b; do
    case "$a" in ''|'#'*) continue ;; esac
    echo "$a"
  done < file
)
```

with `syntax error near unexpected token ';;'`. The same `case` outside a command substitution is
fine, and bash 5 accepts both.

**`bash -n` does not catch it.** It parses the substitution lazily, reports nothing, and the script
dies at runtime on the line it just approved. A syntax check passing is not evidence here.

Write it with parameter expansion instead, which every shell handles:

```bash
[ -n "$a" ] || continue
[ "${a#\#}" = "$a" ] || continue
```

Or put `;;` and `esac` on their own lines. If you need certainty, run the script under `/bin/bash`
rather than `bash`: the two are different programs on this platform.
## BSD versus GNU tools

macOS ships BSD userland. These differ from GNU in ways that pass on Linux CI and fail on a Mac:

- `sed -i` requires an explicit backup suffix: `sed -i '' 's/a/b/' file`.
- **Choose a substitution delimiter that does not appear in the pattern.** A pattern containing a
  literal `|`, such as a Markdown table row, breaks `sed -E "s|...|...|"` with
  `RE error: empty (sub)expression`, while GNU sed accepts it silently. A `#` delimiter fails the
  same way on a pattern containing `#`, such as a Markdown heading. Pick `#`, `,`, or `:` after
  looking at the pattern.
- `awk -v VAR="$VALUE"` rejects embedded newlines on BSD awk. Pass a tempfile path instead and read
  it inside the awk program with `while ((getline line < f) > 0) print line; close(f)`.
- `date -j -f "%Y-%m-%d" "$s" +%s` fills the missing time-of-day fields from the **current clock**,
  so parsing a bare date returns roughly now, not midnight. Append `T00:00:00` and parse with
  `-f "%Y-%m-%dT%H:%M:%S"`.
- For word-boundary replacements, prefer `perl -CSD -i -pe` over `sed`: it is UTF-8 aware and its
  `\b` behaves consistently across platforms.

## Matching a row in a registry or table

Match on a unique full-path column using a literal `awk 'index($0,target)==1'`, never a
basename-keyed `sed -E` with the path wildcarded and no line address. The regex form rewrites every
row sharing a basename, and a metacharacter in the name silently mis-targets unrelated rows.
`index()` is literal and collision-proof.

## Shell differences inside the agent's own tooling

`zsh` does not word-split unquoted parameter expansions the way `bash` does, so
`for x in $LIST` iterates once over the whole string. Use an explicit array, a `while IFS= read -r`
loop, or `find -exec` instead of relying on word splitting.
