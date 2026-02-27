#!/usr/bin/env bash
# Session Start Hook
# Loads project state and injects it as additional context via JSON output.
# Fires on: startup, resume, clear, compact
# Output: JSON with hookSpecificOutput.additionalContext
# Compatible with Bash 3.2+ (stock macOS)

set -euo pipefail

# Read stdin (Claude Code hook protocol)
INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"' 2>/dev/null || echo "unknown")
SOURCE=$(echo "$INPUT" | jq -r '.source // "unknown"' 2>/dev/null || echo "unknown")
CWD=$(echo "$INPUT" | jq -r '.cwd // "."' 2>/dev/null || echo ".")

PROJECT_ROOT="$CWD"
STATE_DIR="$PROJECT_ROOT/.claude/project-state"
HISTORY_FILE="$PROJECT_ROOT/.claude/session-history.jsonl"

# Build context string
CONTEXT=""

CONTEXT+="=== PROJECT STATE (session: $SESSION_ID, source: $SOURCE) ==="$'\n\n'

# --- Task Queue ---
TASKS_FILE="$STATE_DIR/tasks.md"
if [[ -f "$TASKS_FILE" ]]; then
    line_count=$(wc -l < "$TASKS_FILE" | tr -d ' ')
    if [[ "$line_count" -gt 50 ]]; then
        CONTEXT+="## Task Queue (summarized — $line_count lines)"$'\n'
        CONTEXT+=$(grep -E '^(##|###|- \[)' "$TASKS_FILE" 2>/dev/null || true)$'\n'
    else
        CONTEXT+="## Task Queue"$'\n'
        CONTEXT+=$(cat "$TASKS_FILE")$'\n'
    fi
else
    CONTEXT+="## Task Queue"$'\n'
    CONTEXT+="_No task queue found. Initialize .claude/project-state/tasks.md_"$'\n'
fi
CONTEXT+=$'\n'

# --- Decision Log (last 3 decisions if large) ---
DECISIONS_FILE="$STATE_DIR/decisions.md"
if [[ -f "$DECISIONS_FILE" ]]; then
    line_count=$(wc -l < "$DECISIONS_FILE" | tr -d ' ')
    if [[ "$line_count" -gt 80 ]]; then
        CONTEXT+="## Decision Log (last 3 of many)"$'\n'
        # Get the line number of the 3rd-from-last DEC- header (Bash 3.2 compatible)
        start_line=$(grep -n '^### DEC-' "$DECISIONS_FILE" 2>/dev/null | tail -3 | head -1 | cut -d: -f1)
        if [[ -n "$start_line" ]]; then
            CONTEXT+=$(sed -n "${start_line},\$p" "$DECISIONS_FILE")$'\n'
        fi
    else
        CONTEXT+=$(cat "$DECISIONS_FILE")$'\n'
    fi
else
    CONTEXT+="## Decision Log"$'\n'
    CONTEXT+="_No decision log found._"$'\n'
fi
CONTEXT+=$'\n'

# --- Session Context ---
SESSION_FILE="$STATE_DIR/session-current.md"
if [[ -f "$SESSION_FILE" ]]; then
    CONTEXT+=$(cat "$SESSION_FILE")$'\n'
else
    CONTEXT+="## Current Session Context"$'\n'
    CONTEXT+="_No session context found._"$'\n'
fi
CONTEXT+=$'\n'

# --- Recent Session History (last 5) ---
if [[ -f "$HISTORY_FILE" ]] && [[ -s "$HISTORY_FILE" ]]; then
    CONTEXT+="## Recent Session History (last 5)"$'\n'
    while IFS= read -r line; do
        ts=$(echo "$line" | jq -r '.timestamp // "?"' 2>/dev/null || echo "?")
        sid=$(echo "$line" | jq -r '.session_id // "?"' 2>/dev/null || echo "?")
        summary=$(echo "$line" | jq -r '.summary // "no summary"' 2>/dev/null || echo "no summary")
        CONTEXT+="- [$ts] $sid: $summary"$'\n'
    done < <(tail -5 "$HISTORY_FILE")
else
    CONTEXT+="## Recent Session History"$'\n'
    CONTEXT+="_No previous sessions recorded._"$'\n'
fi
CONTEXT+=$'\n'

# --- Git Status (single invocation) ---
if command -v git &>/dev/null && git -C "$PROJECT_ROOT" rev-parse --git-dir &>/dev/null 2>&1; then
    branch=$(git -C "$PROJECT_ROOT" branch --show-current 2>/dev/null || echo "detached")
    short_status=$(git -C "$PROJECT_ROOT" status --short 2>/dev/null)
    CONTEXT+="## Git Status"$'\n'
    CONTEXT+="Branch: $branch"$'\n'
    if [[ -n "$short_status" ]]; then
        total=$(echo "$short_status" | wc -l | tr -d ' ')
        if [[ "$total" -gt 20 ]]; then
            CONTEXT+=$(echo "$short_status" | head -20)$'\n'
            CONTEXT+="... and $((total - 20)) more changes"$'\n'
        else
            CONTEXT+="$short_status"$'\n'
        fi
    else
        CONTEXT+="Working tree clean"$'\n'
    fi
else
    CONTEXT+="## Git Status"$'\n'
    CONTEXT+="_Not a git repository._"$'\n'
fi

CONTEXT+=$'\n'"=== END PROJECT STATE ==="

# Output JSON with additionalContext for Claude Code to inject
jq -n --arg context "$CONTEXT" '{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": $context
  }
}'
