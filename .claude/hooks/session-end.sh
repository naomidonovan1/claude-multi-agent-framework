#!/usr/bin/env bash
# Session End Hook
# Generates and appends a structured session summary to session-history.jsonl.
# Fires on: all session exit reasons
# Output: none (SessionEnd does not support decision output)
# Compatible with Bash 3.2+ (stock macOS)

set -euo pipefail

# Read stdin (Claude Code hook protocol)
INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"' 2>/dev/null || echo "unknown")
REASON=$(echo "$INPUT" | jq -r '.reason // "unknown"' 2>/dev/null || echo "unknown")
CWD=$(echo "$INPUT" | jq -r '.cwd // "."' 2>/dev/null || echo ".")

PROJECT_ROOT="$CWD"
STATE_DIR="$PROJECT_ROOT/.claude/project-state"
HISTORY_FILE="$PROJECT_ROOT/.claude/session-history.jsonl"
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# Read current session context for summary
SESSION_FILE="$STATE_DIR/session-current.md"
SUMMARY="No session context available."
if [[ -f "$SESSION_FILE" ]]; then
    ACTIVE_FOCUS=$(grep -A1 '### Active Focus' "$SESSION_FILE" 2>/dev/null | tail -1 | sed 's/^_//;s/_$//' || echo "unknown")
    TASKS_TOUCHED=$(sed -n '/### Tasks Touched This Session/,/### /{/### Tasks Touched/d;/### /d;p}' "$SESSION_FILE" 2>/dev/null | grep -E '^\s*-' | head -5 | tr '\n' ', ' | sed 's/, $//' || echo "none")
    SUMMARY="Focus: ${ACTIVE_FOCUS}. Tasks: ${TASKS_TOUCHED:-none}"
fi

# Count tasks by section for snapshot
# Section headers MUST be exactly: ### TODO, ### IN-PROGRESS, ### IN-REVIEW, ### DONE (case-sensitive)
TASKS_FILE="$STATE_DIR/tasks.md"
TOTAL_DONE=0
TOTAL_IN_REVIEW=0
TOTAL_IN_PROGRESS=0
TOTAL_TODO=0
if [[ -f "$TASKS_FILE" ]]; then
    TOTAL_DONE=$(sed -n '/^### DONE/,/^### \|^$/{ /^### /d; /^$/d; p; }' "$TASKS_FILE" 2>/dev/null | grep -c '^\- \[' || true)
    TOTAL_IN_REVIEW=$(sed -n '/^### IN-REVIEW/,/^### /{ /^### /d; p; }' "$TASKS_FILE" 2>/dev/null | grep -c '^\- \[' || true)
    TOTAL_IN_PROGRESS=$(sed -n '/^### IN-PROGRESS/,/^### /{ /^### /d; p; }' "$TASKS_FILE" 2>/dev/null | grep -c '^\- \[' || true)
    TOTAL_TODO=$(sed -n '/^### TODO/,/^### /{ /^### /d; p; }' "$TASKS_FILE" 2>/dev/null | grep -c '^\- \[' || true)
fi

# Build and append JSON entry using jq for safe escaping
ENTRY=$(jq -n \
    --arg sid "$SESSION_ID" \
    --arg ts "$TIMESTAMP" \
    --arg reason "$REASON" \
    --arg summary "$SUMMARY" \
    --argjson done "$TOTAL_DONE" \
    --argjson in_review "$TOTAL_IN_REVIEW" \
    --argjson in_progress "$TOTAL_IN_PROGRESS" \
    --argjson todo "$TOTAL_TODO" \
    '{
        session_id: $sid,
        timestamp: $ts,
        exit_reason: $reason,
        summary: $summary,
        task_snapshot: {
            done: $done,
            in_review: $in_review,
            in_progress: $in_progress,
            todo: $todo
        }
    }')

# Ensure the history file directory exists
mkdir -p "$(dirname "$HISTORY_FILE")"

# Append the entry
echo "$ENTRY" >> "$HISTORY_FILE"
