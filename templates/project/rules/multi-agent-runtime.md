## Multi-Agent Runtime Policy

### --dangerously-skip-permissions Usage

Reserved for isolated, operator-approved worker sessions only. Specifically:
- Enabled only via the `--bypass` flag on `active/multi-agent/launch_agents.sh`
- Never the default for interactive Claude Code sessions
- Never used outside a git worktree
- Never used for tasks touching auth, billing, secrets, production, or deployment

### Launch Gate Requirements

Before launching any multi-agent run, the orchestrator must verify:
- Each agent has an isolated git worktree under `active/multi-agent/agent-N/` (flat mode, Phase 5C) or `active/multi-agent/agent-<role>-<i>/` (multi-role mode, Phase 6a)
- Each agent's work directory is explicitly bounded by that worktree
- The parent operator has approved the launch (Level B gate minimum; Level C if `--bypass` is used)
- The contract specifies what each agent produces and how outputs will be aggregated

### chat.md section semantics

Under flat mode (Phase 5C), `active/multi-agent/chat.md` uses one `## agent-<N>` section per agent. Under multi-role mode (Phase 6a, when the task file declares `schema: multi-role`), it uses `## role: <name>` headers with `### <role>-<i>` sub-sections per agent. The "assigned section" requirements below apply to whichever scheme matches the active run.

### Agent Scope Enforcement

Each worker agent may:
- Read any file in its assigned worktree
- Write only to files in its assigned worktree
- Commit only to its assigned branch
- Write its status line only to its assigned section of `active/multi-agent/chat.md`

Each worker agent must not:
- Write to another agent's worktree or branch
- Write to the main worktree from within an agent session
- Edit `active/multi-agent/chat.md` outside its assigned section
- Spawn further agents

### Aggregation Step

Before accepting multi-agent output as final:
- Orchestrator reviews each agent's worktree output
- Orchestrator writes a single consolidated report
- Standard verification loop runs against the consolidated report, not against individual agent outputs
- Worktrees are torn down by `kill_agents.sh` after aggregation completes

### Emergency Shutdown

Any multi-agent run can be aborted by running `active/multi-agent/kill_agents.sh`. This:
- Sends SIGTERM to all agent processes
- Marks their chat.md sections with `[ABORT]`
- Does not delete worktrees (so outputs remain inspectable)
