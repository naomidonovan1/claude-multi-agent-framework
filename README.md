# Multi-Agent Framework for Claude Code

A reusable template repository that implements a hierarchical multi-agent system for Claude Code projects. Designed for research-oriented workflows (neuroscience, ML, computational science) with persistent state management, automated quality assurance via reviewer agents, and cross-session context preservation via hooks.

## How It Works

```
User  -->  Project Manager  -->  Specialists  -->  Reviewers  -->  Integration Agent
```

- **Project Manager (PM)**: Your sole point of contact. Plans work, delegates to specialists, never implements directly.
- **Specialist Agents**: Domain experts that do the actual work (one per domain).
- **Reviewer Agents**: Paired with each specialist. Automatically critique all work before it's marked done. Run at a stronger model (opus) to catch specialist mistakes.
- **Integration Agent**: Verifies that outputs from multiple specialists fit together end-to-end.

## Quickstart

### 1. Use as a template

Use this as a GitHub template repository, or copy the framework files into your project:

```bash
# Option A: Use as GitHub template (recommended)
# Click "Use this template" on the GitHub repo page

# Option B: Copy into existing project
rsync -a --ignore-existing path/to/this-repo/.claude/ your-project/.claude/
cp path/to/this-repo/CLAUDE.md your-project/CLAUDE.md

# Ensure hooks are executable (cp may not preserve permissions)
chmod +x your-project/.claude/hooks/*.sh
```

**Note**: If you already have a `.claude/settings.json`, manually merge the hooks configuration rather than overwriting it.

### 2. Customize specialists for your project

Copy the templates and fill in the placeholders:

```bash
# Create a new specialist
cp .claude/templates/specialist-template.md .claude/agents/specialists/my-domain-specialist.md

# Create its paired reviewer
cp .claude/templates/reviewer-template.md .claude/agents/reviewers/my-domain-reviewer.md
```

Edit each file: replace the `{{PLACEHOLDER}}` fields with your specifics. See the example pair (`model-architecture-specialist.md` / `model-architecture-reviewer.md`) for the expected level of detail.

### 3. Start a session

```bash
claude
```

The SessionStart hook automatically loads project state (task queue, decisions, session history) into context. Describe your project goals and the PM will build the task backlog.

## Directory Structure

```
.claude/
├── agents/
│   ├── project-manager.md          # Central coordinator (opus)
│   ├── integration-agent.md        # End-to-end verification
│   ├── specialists/                # Domain expert agents (sonnet)
│   │   └── model-architecture-specialist.md  (example)
│   └── reviewers/                  # Paired critic agents (opus)
│       └── model-architecture-reviewer.md    (example)
├── hooks/
│   ├── session-start.sh            # Loads state on startup
│   ├── pre-compact.sh              # Backs up state before compaction
│   ├── session-end.sh              # Saves session summary
│   └── subagent-stop.sh            # Logs agent activity
├── project-state/
│   ├── tasks.md                    # Task queue (TODO/IN-PROGRESS/IN-REVIEW/DONE)
│   ├── decisions.md                # Architectural decision log
│   ├── observations.md             # Research observations and data insights
│   ├── experiments.md              # Experiment log (params, results, metrics)
│   ├── session-current.md          # Current session working context
│   └── agent-log.jsonl             # Structured agent activity log
├── session-history.jsonl           # Cross-session history
├── settings.json                   # Hook configuration
└── templates/
    ├── specialist-template.md      # Template for new specialists
    └── reviewer-template.md        # Template for new reviewers
```

## Adding a New Specialist/Reviewer Pair

1. Copy `specialist-template.md` to `.claude/agents/specialists/<domain>-specialist.md`
2. Copy `reviewer-template.md` to `.claude/agents/reviewers/<domain>-reviewer.md`
3. Fill in the placeholder fields in both files — see the example pair for expected detail level
4. The PM discovers agents by scanning the `specialists/` and `reviewers/` directories via Glob at session start

### Specialist placeholders
- `{{AGENT_NAME}}`: Agent name in kebab-case (e.g., `data-pipeline-specialist`)
- `{{DOMAIN}}`: Domain expertise (e.g., "data pipeline design and ETL")
- `{{SCOPE}}`: What the agent handles (e.g., "data loading, preprocessing, augmentation, and validation")
- `{{CONSTRAINTS}}`: Domain-specific rules and standards

### Reviewer placeholders
- `{{REVIEWER_NAME}}`: Reviewer name (e.g., `data-pipeline-reviewer`)
- `{{SPECIALIST_NAME}}`: Which specialist it reviews
- `{{DOMAIN}}`: Domain expertise
- `{{REVIEW_CRITERIA}}`: Structured review criteria with subsections (see example reviewer for format)

## Research Workflow

This framework includes research-specific state files:

- **`observations.md`**: Record data insights, unexpected findings, and patterns noticed during analysis. These persist across sessions and prevent re-discovering the same things.
- **`experiments.md`**: Log experiment configurations, hyperparameters, results, and seeds. Each entry should be detailed enough to reproduce the experiment.
- **`decisions.md`**: Track architectural and methodological decisions with full reasoning. Prevents revisiting settled questions.

### Tips for research projects

- **Reproducibility**: Always record random seeds, environment details, and data versions in experiment entries
- **Large files**: Use git-lfs or DVC for datasets and model checkpoints. The `.gitignore` already excludes common ML artifact patterns.
- **Data conventions**: Keep raw data in `data/raw/`, processed data in `data/processed/`, and interim data in `data/interim/`

## Hooks

All hooks are configured in `.claude/settings.json` and fire automatically:

| Hook | Trigger | Purpose |
|------|---------|---------|
| `session-start.sh` | Any session start | Loads project state into context via `additionalContext` |
| `pre-compact.sh` | Auto/manual compaction | Backs up state files to `.claude/backups/` |
| `session-end.sh` | Session exit | Appends structured session summary to history |
| `subagent-stop.sh` | Any subagent finishes | Logs agent activity to `agent-log.jsonl` |

## Customization

### For different project types

The framework is domain-agnostic. To adapt it:

- **Neuroscience**: Create specialists for data acquisition, spike sorting, neural decoding, statistical analysis
- **ML project**: Create specialists for data pipeline, model architecture, training, evaluation
- **Web app**: Create specialists for frontend, backend, database, API design
- **Infrastructure**: Create specialists for networking, compute, security, monitoring

### Model selection

- **PM and Reviewers**: Default to opus for stronger reasoning and oversight
- **Specialists**: Default to sonnet for cost efficiency. Consider switching to opus for complex research tasks where accuracy matters more than cost.
- **Integration Agent**: Default to sonnet. Adequate for checking interfaces and running tests.

### Review strictness

The default is strict: all `must-fix` items must be resolved before work is approved. The PM can skip review for trivial tasks. To adjust further, modify the reviewer templates' severity classification guidelines.

## Requirements

- Claude Code CLI
- `jq` (required by hook scripts for JSON parsing)
- `git` (optional, for git status in session-start hook)
- `rsync` (optional, for copying framework into existing projects — pre-installed on macOS)
- Bash 3.2+ (compatible with stock macOS)
