---
name: external-llm-review
description: Use when a Claude-authored plan, wave diff, or design doc needs an independent non-Claude review; when invoking or probing codex, cursor-agent, or gemini as that reviewer; when planning vs execution name different reviewer CLIs; or when a gate might treat empty or silent reviewer output as clean.
version: 0.2.0
user-invocable: true
argument-hint: "[path-to-artifact] [optional: what to attack hardest]"
tools: Bash, Read, Grep, Glob, Edit, Write
---

# External LLM Review (independent second opinion, fold-back loop)

A different model family catches defects Claude review misses. A Claude reviewer is NEVER a
substitute. If no external reviewer is reachable, say UNAVAILABLE and let the operator decide.

This skill defines **codex**, **cursor-agent**, and **gemini**. It does **not** choose the CLI
for a run. The **plan** (or the operator) chooses. Planning skills default to **codex** only
when the plan is silent.

**REQUIRED for execution-time placement:** skill `autorun-plan`.

## Resolve which CLI

| Priority | Source |
|---|---|
| 1 | Operator instruction this session |
| 2 | Plan field for **this phase** (`planning_reviewer` vs `execution_reviewer` / A.5 step 4). They MAY differ. |
| 3 | **Planning-skill default:** **codex** (`deep-plan-swarm`, `plan-synthesizer`) |
| 4 | Named CLI dead: report UNAVAILABLE; offer the next reachable of codex → cursor-agent → gemini. Do not silently swap. |

Pin a **non-Claude model**. The CLI is not the family. `cursor-agent --list-models` serves
`claude-*`; pinning one makes the pass same-family.

Probe availability AND auth. Installed ≠ logged in. Logged in ≠ has credit.

**Exhaustion is usually PROVIDER-wide, not per-model.** When a model returns a usage-limit error,
do NOT walk its siblings hoping for a cheaper tier — measured: `gpt-5.3-codex-xhigh` and
`gpt-5.6-sol-xhigh` failed identically on one CLI, because the cap is on the provider. **Probe ONE
model per provider, then cross to a different provider** (a Grok or Gemini tier on the same CLI is a
different provider and may well be alive when every GPT tier is dead). Note the reset date from the
error text — it tells you when the plan's named model comes back, and the gate should revert to it.

**Re-probe a reviewer recorded as dead before believing it.** A standing "gemini auth is broken" note
was carried across sessions and was simply STALE: gemini was authenticated and only needed
`--skip-trust`, and it has a real read-only mode (`--approval-mode plan`). A dead-reviewer note is an
observation with a timestamp, not a property.

```bash
which codex && codex login status 2>&1 | head -1
which cursor-agent && cursor-agent status 2>&1 | head -1
which gemini
```

## Planning vs execution

| Phase | Artifact | When | Default CLI if plan silent |
|---|---|---|---|
| Planning | PLAN file | After synthesis, before approval | **codex** |
| Execution | wave's **final simplified DIFF file** | After tests + `adversary` + `simplify` | whatever the plan names |

Pass the artifact **by path**. You apply fixes; the reviewer stays read-only.

## Option A — codex (planning default)

```bash
codex exec --sandbox read-only -C <repo-root> -m <plan-or-pinned-model> "<attack prompt>"
```

May take the artifact on stdin (`< path`). Pin the id the plan names; plausible ids get
rejected (observed: `gpt-5` / `gpt-5-codex` rejected; `gpt-5.6-sol` worked). **Auth is not a
credit check:** `codex login status` can say logged in while exhausted; that is UNAVAILABLE,
not CLEAN.

If execution names "codex CLI" and it is exhausted, do not invent a cursor-agent GPT stand-in
unless the plan names that replacement.

## Option B — cursor-agent

Recommended gate command (after write-lock proof on a throwaway):

```bash
cursor-agent -p --mode ask --trust --sandbox enabled \
  --model <non-claude, from the plan> \
  --output-format text \
  --workspace <repo-root> \
  "<attack prompt naming the artifact BY PATH>"
```

| Flag | Why |
|---|---|
| `--mode ask` | Last assistant message **is** the report (`-p` captures it). |
| `--sandbox enabled` | Read-only shell (`rg`). Without it, no multi-file verify. Does not re-open writes. |
| `--trust` | Without it, empty return. Not `-f`/`--yolo`. Never pass those. |
| `--output-format text` | `json.result` is still last-message text; metadata is not a verdict. |
| model | From the plan. Never `claude-*`. Never `CURSOR_API_KEY` / `--api-key`. |

**`--plan` writes nothing but drops the report.** `-p --trust` with no read-only mode **writes**
the repo. `--plan` stays byte-identical, then the model "files" a plan; `-p` captures
narration ("Filing the defects...") with exit 0. Observed: 8.75 min, 31k tokens, no findings.
Do not recommend `--plan` as the gate command.

If `--mode ask` fails a write-lock proof, stop. Temporary fallback: `--plan` + last-message
contract; narration still fails the round.

## Option C — gemini

```bash
gemini -p "<attack prompt naming the artifact BY PATH>"
```

Probe `gemini --help` for sandbox / approval-mode. Never yolo writes. If no read-only flag,
use a disposable worktree or park. Failed auth = UNAVAILABLE. Pin the plan's Gemini model.

## Attack prompt + last-message contract (all CLIs)

BREAK the artifact. Name 2-4 seams. Verify against live code (`path:line`). Severity list
with claim, verified, why wrong, fix.

Last message starts with `VERDICT: CLEAN` or `VERDICT: FINDINGS`, then blocks. No narration
as the last message.

## Harness traps that fake a verdict

- **`timeout` does not exist on macOS.** Wrapping the reviewer in it produces a ~38-byte output file
  and exit 0 — indistinguishable from a terse review if you check size instead of content. Use
  `gtimeout` if present, or no timeout at all. This burned a full round.
- **A reconnect loop is a FAILED round, not a slow one.** `cursor-agent` can stall emitting
  `Connection lost, reconnecting ... (attempt N)` indefinitely while the file grows. Check that
  connectivity is not the local side (`curl` the API host), then kill and re-run rather than waiting.
- **Never close a gate on a file you have not read line 1 of.** Every trap above passes `wc -c > 0`.

## Pass / fail (all CLIs)

Failed unless: exit 0, substantial stdout, line 1 is `VERDICT:`, FINDINGS have a severity
block. Empty, 1 byte, JSON-only metadata, swallowed trust prompt, credit death, and
"Filing the defects..." are FAILED rounds. Re-run; persist → UNAVAILABLE (flagged Claude
stand-in only if the operator accepts).

## Two reviewers disagree: rules that decided it correctly, twice

**1. An EXECUTING reviewer beats a READING one.** When one reviewer reproduces a behavior by running
it and the other reasons from the source, the executing one wins and the reading "CLEAN" is stale
rather than confirming. Observed both directions in one run: a reading reviewer attested eight classes
CLOSED while an executing one reproduced two BLOCKERs by running the code, one of them inside code the
reader had just cleared. Later, the two disagreed on whether to change a semantic; the executing
reviewer — which had run the mutations and counted the real data the change would act on — was right
that the proposed "fix" would install a worse defect than the gap it closed.

**2. A reviewer's SUMMARY can contradict its own BODY. Follow the body.** Measured: a reviewer's
must-fix list proposed a blanket refusal rule that its own body spent a paragraph arguing against,
having shown by execution that the blanket form would permanently break a large class of legitimate
existing work. Summaries compress and drop the exception; bodies carry the reasoning and the
reproduction. When they disagree, quote BOTH in the fix brief and say which you are following, so the
fix round does not resolve it by coin flip — and expect the naive form to look more decisive.

**3. The reviewers do not overlap, so do not treat one as a superset.** In one gate the external found
a BLOCKER the adversary missed entirely (a second chokepoint with the same defect the other had just
fixed), and the adversary found one the external missed. Fold BOTH into one brief; never skip a
reviewer because the other came back clean.

## Fold-back (both phases)

Re-verify first-hand → you apply CRITICAL/HIGH → re-review. **No round cap.** Same finding
twice unchanged, or a restatement round: escalate (needs restructuring). The reviewer is
single-shot; the parent drives the loop.

## Do NOT

- Hardcode an execution CLI in this skill. The plan does that.
- Treat Claude self-review as this pass.
- Invoke without that CLI's read-only flags.
- Close a gate on silence.
- Treat logged-in as has-credit.
- Send secrets / third-party PII off-box without operator say-so.
