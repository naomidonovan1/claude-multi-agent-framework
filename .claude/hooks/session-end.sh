#!/usr/bin/env bash
# Session End Hook
# Generates and appends a structured session summary to session-history.jsonl.
# Fires on: all session exit reasons
# Output: none (SessionEnd does not support decision output)
# Compatible with Bash 3.2+ (stock macOS)

set -euo pipefail

# --- Dependencies & safety ---
command -v jq &>/dev/null || exit 0

# Read stdin and parse all fields in a single jq call
INPUT=$(cat)
eval "$(echo "$INPUT" | jq -r '
  "SESSION_ID=" + (.session_id // "unknown") + "\n" +
  "REASON=" + (.reason // "unknown") + "\n" +
  "CWD_RAW=" + (.cwd // ".")
' 2>/dev/null || echo 'SESSION_ID=unknown; REASON=unknown; CWD_RAW=.')"

PROJECT_ROOT="$CWD_RAW"
[[ -d "$PROJECT_ROOT/.claude" ]] || exit 0

trap 'echo "[$(date)] $0: ERROR line $LINENO" >> "$PROJECT_ROOT/.claude/hooks/error.log"' ERR

STATE_DIR="$PROJECT_ROOT/.claude/project-state"
HISTORY_FILE="$PROJECT_ROOT/.claude/session-history.jsonl"
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# Read current session context for summary (resilient extraction)
SESSION_FILE="$STATE_DIR/session-current.md"
SUMMARY="No session context available."
if [[ -f "$SESSION_FILE" ]]; then
    ACTIVE_FOCUS=$(grep -A1 '### Active Focus' "$SESSION_FILE" 2>/dev/null | tail -1 | sed 's/^_//;s/_$//' || echo "unknown")
    ACTIVE_FOCUS="${ACTIVE_FOCUS:-unknown}"
    TASKS_TOUCHED=$(sed -n '/### Tasks Touched This Session/,/### /{/### Tasks Touched/d;/### /d;p}' "$SESSION_FILE" 2>/dev/null | grep -E '^\s*-' | head -5 | tr '\n' ', ' | sed 's/, $//' || echo "none")
    TASKS_TOUCHED="${TASKS_TOUCHED:-none}"
    SUMMARY="Focus: ${ACTIVE_FOCUS}. Tasks: ${TASKS_TOUCHED}"
fi

# Count tasks using flat-list inline status format
TASKS_FILE="$STATE_DIR/tasks.md"
TOTAL_DONE=${TOTAL_DONE:-0}
TOTAL_IN_REVIEW=${TOTAL_IN_REVIEW:-0}
TOTAL_IN_PROGRESS=${TOTAL_IN_PROGRESS:-0}
TOTAL_TODO=${TOTAL_TODO:-0}
if [[ -f "$TASKS_FILE" ]]; then
    TOTAL_DONE=$(grep -c 'Status: done' "$TASKS_FILE" 2>/dev/null || echo "0")
    TOTAL_IN_REVIEW=$(grep -c 'Status: in-review' "$TASKS_FILE" 2>/dev/null || echo "0")
    TOTAL_IN_PROGRESS=$(grep -c 'Status: in-progress' "$TASKS_FILE" 2>/dev/null || echo "0")
    TOTAL_TODO=$(grep -c 'Status: todo' "$TASKS_FILE" 2>/dev/null || echo "0")
fi

# Build and append JSON entry
ENTRY=$(jq -n \
    --arg sid "$SESSION_ID" \
    --arg ts "$TIMESTAMP" \
    --arg reason "$REASON" \
    --arg summary "$SUMMARY" \
    --argjson done "${TOTAL_DONE:-0}" \
    --argjson in_review "${TOTAL_IN_REVIEW:-0}" \
    --argjson in_progress "${TOTAL_IN_PROGRESS:-0}" \
    --argjson todo "${TOTAL_TODO:-0}" \
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

# Rotate session-history.jsonl — keep last 50 entries
if [[ -f "$HISTORY_FILE" ]]; then
    entry_count=$(wc -l < "$HISTORY_FILE" | tr -d ' ')
    if [[ "$entry_count" -gt 50 ]]; then
        tail -50 "$HISTORY_FILE" > "${HISTORY_FILE}.tmp" && mv "${HISTORY_FILE}.tmp" "$HISTORY_FILE"
    fi
fi
