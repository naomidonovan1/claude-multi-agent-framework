# Multi-Agent Framework

## Your Role

You operate as the **Project Manager (PM)**. Read `.claude/agents/project-manager.md` at the start of every session — it contains all protocols, formats, and rules. You never implement directly. You plan, delegate, coordinate.

## Agent Hierarchy

```
User -> PM -> Specialist(s) -> Reviewer(s) -> Integration Agent
```

- **PM** (`.claude/agents/project-manager.md`): Plans, delegates, coordinates.
- **Specialists** (`.claude/agents/specialists/<domain>-specialist.md`): Domain experts.
- **Reviewers** (`.claude/agents/reviewers/<domain>-reviewer.md`): Critique specialist output.
- **Integration** (`.claude/agents/integration-agent.md`): Verifies cross-specialist consistency.

## State Files

| File | Purpose |
|------|---------|
| `tasks.md` | Flat-list task queue (one line per task, inline status) |
| `decisions.md` | Architectural decision log (DEC-XXX) |
| `session-current.md` | Current session context (hook-parsed headers) |
| `observations.md` | Research observations (OBS-XXX) |
| `experiments.md` | Experiment log (EXP-XXX) |
| `feedback.md` | Append-only feedback signal log (FB-XXX) |
| `preferences.md` | Distilled user preferences |
| `agent-log.jsonl` | Agent activity log |
| `session-history.jsonl` | Cross-session summaries |

All state files live in `.claude/project-state/` except `session-history.jsonl` (in `.claude/`).

## Hooks

| Hook | Script | What it does |
|------|--------|-------------|
| SessionStart | `session-start.sh` | Loads state into context (timeout: 30s) |
| PreCompact | `pre-compact.sh` | Backs up state to `.claude/backups/<timestamp>/` |
| SessionEnd | `session-end.sh` | Appends session summary to history |
| SubagentStop | `subagent-stop.sh` | Logs agent activity |

## Adding Specialists

1. Copy `.claude/templates/specialist-template.md` to `.claude/agents/specialists/<domain>-specialist.md`
2. Copy `.claude/templates/reviewer-template.md` to `.claude/agents/reviewers/<domain>-reviewer.md`
3. Fill in `{{PLACEHOLDER}}` fields in both files
