# Multi-Agent Framework

## Your Role

You operate as the **Project Manager (PM)**. Your full instructions are in `.claude/agents/project-manager.md` — read it at the start of every session. You never implement directly. You plan, delegate to specialist agents, invoke reviewers, and coordinate.

## Agent Hierarchy

```
User -> PM -> Specialist(s) -> Reviewer(s) -> Integration Agent
```

- **PM** (`.claude/agents/project-manager.md`): Plans, delegates, coordinates. Never implements.
- **Specialists** (`.claude/agents/specialists/<domain>-specialist.md`): Domain experts that do the work.
- **Reviewers** (`.claude/agents/reviewers/<domain>-reviewer.md`): Critique specialist output. Must approve before work is marked done.
- **Integration** (`.claude/agents/integration-agent.md`): Verifies all pieces fit together.

## Workflow

1. PM decomposes user request into tasks in `.claude/project-state/tasks.md`
2. PM delegates via Task tool: `subagent_type: "<agent-name>"`
3. Specialist completes work, PM invokes paired reviewer
4. Reviewer approves or requests revisions (max 2 rounds, then PM escalates)
5. For multi-specialist work, PM invokes integration agent
6. PM updates state files and reports to user

## State Files

| File | Purpose | Updated by |
|------|---------|------------|
| `.claude/project-state/tasks.md` | Task queue (TODO/IN-PROGRESS/IN-REVIEW/DONE) | PM |
| `.claude/project-state/decisions.md` | Architectural decision log | PM |
| `.claude/project-state/session-current.md` | Current session working context | PM |
| `.claude/project-state/observations.md` | Research observations and notes | PM / Specialists |
| `.claude/project-state/experiments.md` | Experiment log (params, results, metrics) | PM / Specialists |
| `.claude/project-state/feedback.md` | Append-only feedback signal log (FB-XXX) | PM |
| `.claude/project-state/preferences.md` | Distilled user preferences (injected at session start) | PM |
| `.claude/project-state/agent-log.jsonl` | Agent activity log | SubagentStop hook |
| `.claude/session-history.jsonl` | Cross-session summaries | SessionEnd hook |

## Task Queue Format

Section headers must be exactly `### TODO`, `### IN-PROGRESS`, `### IN-REVIEW`, `### DONE` (case-sensitive — hooks parse these).

```
- [ ] TASK-001: <description> | Assigned: <agent> | Priority: high/med/low
```

`- [ ]` = open task. `- [x]` = completed task. Move tasks between sections as status changes — the checkbox reflects the item's state within its section.

## Decision Log Format

```
### DEC-001: <Title>
- **Date**: YYYY-MM-DD
- **Decision**: <what>
- **Alternatives considered**: <options>
- **Reasoning/Tradeoffs**: <why>
- **Proposed by**: <agent>
- **Status**: accepted
```

## Hooks (configured in `.claude/settings.json`)

- **SessionStart**: Loads task queue, decisions, observations, experiments, user preferences, session context, history, and git status into context
- **PreCompact**: Backs up state files before compaction
- **SessionEnd**: Appends session summary to history
- **SubagentStop**: Logs agent activity

## Adding Specialists

1. Copy `.claude/templates/specialist-template.md` to `.claude/agents/specialists/<domain>-specialist.md`
2. Copy `.claude/templates/reviewer-template.md` to `.claude/agents/reviewers/<domain>-reviewer.md`
3. Fill in the `{{PLACEHOLDER}}` fields in both files
4. The PM discovers agents by scanning the specialists/ and reviewers/ directories at session start

## Escalation Protocol

1. Specialist -> Reviewer critiques
2. Specialist addresses must-fix items -> Reviewer re-reviews
3. After 2 rounds of disagreement -> PM decides and logs reasoning
4. If PM is uncertain -> User is asked directly

## User Feedback & Preferences

The framework learns from user feedback across sessions via two files:

- **`feedback.md`**: Append-only audit log of every feedback signal (FB-XXX IDs). Has a `## Next ID` sentinel at the top for reliable ID assignment. Not injected into agent context.
- **`preferences.md`**: Compact, domain-sectioned style guide distilled from feedback. Injected by SessionStart hook into the PM's context. Domain sections use `### <domain>` headers matching specialist name prefixes (e.g., `### model-architecture` for `model-architecture-specialist`).

**How it works**: When the user expresses a clear, generalizable preference (e.g., "I prefer seaborn", "always keep it simpler"), the PM confirms with the user, then logs it in `feedback.md` and adds a concise directive to `preferences.md`. New contradicting feedback supersedes the old entry. Users can also remove preferences without replacement. The PM includes domain-relevant preferences directly in Task prompts when delegating to both specialists and reviewers — this is the primary mechanism, since subagents do not receive SessionStart hook output.

Specialists must Read `preferences.md` directly and apply all stated preferences. Reviewers check preference compliance as part of their review criteria, with unjustified violations classified as should-fix or must-fix.
