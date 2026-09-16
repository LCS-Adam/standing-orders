# Watching the context window

`docs/context-window-management.md` explains what the context window is and how to spend it well.
This document answers two narrower questions: what actually degrades as a window fills, according
to published measurements rather than folklore, and how you watch it happen in your own session.

Read it once before a long build. Come back to the table in "What this harness already does" when
a session starts feeling worse than it did an hour ago.

## What the research actually shows

Three separate effects get collapsed into one piece of advice. They are distinct, they were
measured separately, and they have different fixes.

### Position: where in the window a fact sits

Liu et al., "Lost in the Middle: How Language Models Use Long Contexts" (2023, TACL 2024,
https://arxiv.org/abs/2307.03172). Retrieval accuracy is highest when the relevant passage sits at
the very start or the very end of the input and lowest when it sits in the middle.

Scope, and it matters: the measurements are on a 2023 model generation and a synthetic
question-answering task. The shape of the curve is the durable finding. The exact percentages are
not current-model numbers, so do not quote them as if they were.

One thing this result is often stretched into saying, and does not: that the end of the window is
as good as the start. Recovery at the end is real but partial.

### Length: how much is in the window at all

Chroma, "Context Rot: How Increasing Input Tokens Impacts LLM Performance" (14 July 2025, Kelly
Hong, Anton Troynikov, Jeff Huber, https://www.trychroma.com/research/context-rot). Eighteen
models across Anthropic, OpenAI, Google and Alibaba.

The finding that matters here: accuracy falls as input length grows even on tasks with no
retrieval difficulty at all, including a repeated-words task where nothing has to be found. So
"the model has to search harder" is not the whole mechanism. Length alone costs something.

The practical consequence is the useful one. Trimming a prompt to what is relevant helps even when
nothing in it needs to be located.

### Advertised length is not usable length

Two independent benchmark families measured a real gap between the context length a model claims
and the length at which it still reasons reliably: RULER (2024,
https://arxiv.org/abs/2404.06654) and Michelangelo (2024, https://arxiv.org/abs/2409.12640). The
gap size is model-specific and task-specific. That it recurs across model generations is the
pattern worth carrying.

Related: needle-in-a-haystack scores overstate long-context ability, because most needle tests let
the model match on words shared between the question and the planted answer. NoLiMa (2025,
https://arxiv.org/abs/2502.05167) removes that shortcut and reports a much larger drop, GPT-4o
going from 99.3 percent to 69.7 percent. Treat a headline needle score as evidence about needle
tests, not about reasoning over a full window.

### Compacting a session costs more than it looks

"Lost in Compaction: Evaluating Side-Constraint Loss under Context Compaction" (Wang, Zhang, Lee
and Yang, submitted 31 July 2026, https://arxiv.org/abs/2608.11242). The abstract reports that
current compactors "retain only 17% of injected SCs on average", where a side constraint is an
explicit instruction the user gave earlier in the conversation. Their proposed fix, an extractor
run before compaction, recovers retention above 90 percent.

This is one recent paper introducing its own benchmark, and it has not had time to be replicated.
The direction is credible and the specific number is provisional. It is quoted here because it
matches what practitioners report: the instruction you gave forty minutes ago is the thing that
quietly stops being followed.

### Multi-turn decay is a different problem

Laban, Hayashi, Zhou and Neville, "LLMs Get Lost in Multi-Turn Conversation" (9 May 2025,
https://arxiv.org/abs/2505.06120). Over 200,000 simulated conversations, six generation tasks, with
"an average drop of 39% across six generation tasks" when the same task is delivered across turns
instead of all at once.

The authors attribute this to premature commitment: the model settles on an assumption early and
does not recover when that assumption was wrong. It is not a token-count effect. A session that is
short in tokens can still fail this way, which means a smaller window is not the fix. Restating
the goal cleanly, or starting a fresh session with a written handoff, is.

## What the research does not show

Two claims circulate widely and are not supported by any source above.

**There is no universal token count at which models degrade.** The Chroma report explicitly
declines to name one: the patterns are model-specific and task-dependent. Any round number offered
as a general threshold, including any in this repository, is a convention someone chose, not a
measurement. Ask for the citation.

**The end of the window does not fully match the start.** Recovery at the end is partial.

## Seeing it: the status line

`hooks/statusline.sh` renders the window as you work:

```text
Opus 5  |  [###-------] 39% (391k)  |  agent-harness docs/training
```

Wire it up by adding this to `~/.claude/settings.json`. The harness does not set it for you,
because a status line is a personal display choice:

```json
{
  "statusLine": {
    "type": "command",
    "command": "bash ~/.claude/hooks/statusline.sh"
  }
}
```

It needs `jq`. Without it the script prints one line saying so rather than failing, because a
status line that exits non-zero renders as empty and reads like a broken terminal.

Three things about what it reports are deliberate:

**It counts cache reads and cache writes, not just fresh input.** Every token the host holds counts
against the window regardless of how it got there. Late in a session most of the window is cache
reads, so summing only `input_tokens` undercounts exactly when the number starts to matter.

**It shows no percentage when the host reports no window size.** An earlier version assumed a
particular plan's window and divided by it, which on any other plan reads comfortable while the
session is nearly full. A missing denominator now prints the raw token count instead.

**The colours are a reading aid, not a threshold.** Green, yellow and red change at numbers this
repository picked so the bar moves before you are in trouble. Per the section above, no published
source supports a universal threshold, and the script says so in a comment beside the numbers.

## What this harness already does about it

Most of the harness's structure exists because of the effects above. Each row is a mechanism you
already have, and what it buys you.

| Mechanism | What it addresses | Where |
|---|---|---|
| `paths:` frontmatter on a rule | Loads the rule only when a matching file is read, instead of every session. One of the few things that genuinely reduces per-session context | `CLAUDE.md:47` |
| A nested `subdir/CLAUDE.md` | Phase instructions stay out of the window until work reaches that phase | `CLAUDE.md:48`, pattern in `templates/phase/` |
| Agent reports written to a file | A subagent's findings survive as bytes instead of as a long final message that has to re-enter the parent's window | `agents/exec-standard.md:36`, ignored at `.gitignore:12` |
| One worktree and one agent per workstream | Each agent reads only the files it owns, so no single window holds the whole build | `docs/writing-your-own.md` |
| The resume prompt rule | A handoff carries forward what a compaction would have dropped, in writing, and must name its own file so nothing below it is orphaned | `AGENTS.md:111-133` |
| `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` set to 85 | Compacts earlier, with more headroom, rather than at the last moment when there is more to lose | `config/settings.portable.json:4` |

The last two are the direct answer to the compaction and multi-turn findings. Compaction is lossy
and the loss is silent, so the harness writes the important state down before compaction happens
rather than trusting a summary to carry it.

## What to do, by situation

**The bar is yellow and the work is still going well.** Nothing. A full window is not itself a
defect; the research measures accuracy, not occupancy.

**The bar is red, or answers have started drifting from instructions you gave earlier.** This is
the side-constraint loss pattern. Run `/handoff`, read what it wrote, then `/clear` and resume from
the block. Do not keep going and hope.

**You are about to paste something long.** Trim it to what is relevant first. Length alone costs
accuracy even when nothing has to be found in it. If one fact matters most, put it at the start or
the end, not buried in the middle.

**The model has committed to a wrong assumption and keeps returning to it.** More context will not
fix this and a smaller window will not either. Start a fresh session and state the goal cleanly.

**A build will outlive one session.** Assume it will. Write the handoff before you need it, keep
phase instructions in nested files, and give each workstream its own agent and worktree.

## Sources

Every claim above traces to one of these. Dates matter: a 2023 result describes a 2023 model.

- Liu et al., Lost in the Middle, 2023 (TACL 2024). https://arxiv.org/abs/2307.03172
- Chroma, Context Rot, 14 July 2025. https://www.trychroma.com/research/context-rot
- RULER, 2024. https://arxiv.org/abs/2404.06654
- Michelangelo, 2024. https://arxiv.org/abs/2409.12640
- NoLiMa, 2025. https://arxiv.org/abs/2502.05167
- Lost in Compaction, 31 July 2026. https://arxiv.org/abs/2608.11242
- LLMs Get Lost in Multi-Turn Conversation, 9 May 2025. https://arxiv.org/abs/2505.06120
