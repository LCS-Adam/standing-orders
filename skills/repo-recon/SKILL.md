---
name: repo-recon
description: Read-only inventory of a repo, source tree, or installed binary with file:line citations. Use for "inspect X and report", config-claim verification, or career-evidence harvest. Write-guarded (never mutates the target). Not for web research (use deep-research); dispatch parallel recon via multi-agent-inline.
---

# repo-recon

## Purpose
Produce a structured, cited inventory of a target without reinventing the `find`/`grep -rn`/`sed -n`/`wc -l` traversal and "quote precise paths" constraint each time. This is the read-only payload; to run several slices in parallel, dispatch this skill via the `multi-agent-inline` skill (that skill owns the SWARM CONFIG + disjoint-slice contract).

## Hard write-guard
NEVER mutates the target. Uses only `find`, `ls`, `grep`, `sed -n`, `wc`, `cat`, `git log/show/ls-files`, `jq`/`python3 -c` reads. The ONLY file written is the report, outside the target tree.

## Identity preamble (learned rule #34)
If the target is a deployed tool whose "live version/config" is the question, run AS the owning identity (a service installed under a dedicated account must be inspected as that account; recon from another admin account resolves a stale copy and reports false drift). State the identity at the top of the report; if you cannot become the owner, mark those findings LOW-CONFIDENCE.

## Procedure
1. **Scope + identity.** Record target path, `id -un`, `git -C <target> rev-parse HEAD 2>/dev/null`, branch.
2. **Structure.** File-type shape + per-dir size/count:
   ```bash
   find <target> -maxdepth 2 -type f | sed 's#.*/##' | sort | uniq -c | sort -rn
   for d in <target>/*/; do n=$(find "$d" -type f | wc -l); sz=$(find "$d" -type f -exec stat -f '%z' {} + | awk '{s+=$1}END{print s+0}'); printf '%12s B %5s files  %s\n' "$sz" "$n" "$d"; done
   ```
3. **Manifests / exports / config keys.** Read package/plist/config files; for a binary dist, `grep -n` entry points + exported commands. Cite `path:line` for every claim.
4. **Hard numbers.** LOC, script/phase counts, etc., each captured with the command that produced it (reproducible).
5. **Practices / gates.** Conventions, hooks, gates observed (with citations).

## Report schema (write OUTSIDE the target)
```markdown
# Recon — <target>
Ran-as: <id -un>   HEAD: <sha>   Branch: <branch>   Date: <YYYY-MM-DD>

## What exists
- <path:line> - <what it is>

## Hard numbers
- <metric>: <value>   (via: <command>)

## Practices / gates
- <observation> (<path:line>)

## Gaps / notable absences
- <what was searched for and NOT found, with the search command>
```

## Output contract
- Report file path + a 3-line top-line summary returned to the caller.
- Every factual claim carries a `path:line` or a reproducible command.
- Target unchanged (verify: `git -C <target> status --porcelain` empty, if a git repo).

## Invocation / automation
Interactive `/repo-recon`, or dispatched in parallel via `multi-agent-inline` for multi-slice recon. Not a scheduled job.

## Career-evidence variant (client-facing output — glyph rule applies)
When harvesting evidence for external publication: additionally apply a codename -> generic map (e.g. an internal project codename -> "autonomous agent platform"), keep the brief 500-1000 words, and run the UTF-8 glyph scan (`perl -CSD` / `rg`) on the output before declaring done (global CLAUDE.md human-voice rule). The harvest half is this skill; the de-codename + glyph-clean render is the only added step.
