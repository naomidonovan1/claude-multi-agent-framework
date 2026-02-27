#!/usr/bin/env bash
# Session Start Hook
# Loads project state and injects it as additional context via JSON output.
# Fires on: startup, resume, clear, compact
# Output: JSON with hookSpecificOutput.additionalContext
# Compatible with Bash 3.2+ (stock macOS)

set -euo pipefail

# --- Dependencies & safety ---
command -v jq &>/dev/null || exit 0

# Read stdin and parse all fields in a single jq call
INPUT=$(cat)
eval "$(echo "$INPUT" | jq -r '
  "SESSION_ID=" + (.session_id // "unknown") + "\n" +
  "SOURCE=" + (.source // "unknown") + "\n" +
  "CWD_RAW=" + (.cwd // ".")
' 2>/dev/null || echo 'SESSION_ID=unknown; SOURCE=unknown; CWD_RAW=.')"

PROJECT_ROOT="$CWD_RAW"
[[ -d "$PROJECT_ROOT/.claude" ]] || exit 0

trap 'echo "[$(date)] $0: ERROR line $LINENO" >> "$PROJECT_ROOT/.claude/hooks/error.log"' ERR

STATE_DIR="$PROJECT_ROOT/.claude/project-state"
HISTORY_FILE="$PROJECT_ROOT/.claude/session-history.jsonl"
AGENT_LOG="$STATE_DIR/agent-log.jsonl"

# Build context string
CONTEXT=""

CONTEXT+="=== PROJECT STATE (session: $SESSION_ID, source: $SOURCE) ==="$'\n\n'

# --- Task Queue (flat-list format: filter out done tasks when >20) ---
TASKS_FILE="$STATE_DIR/tasks.md"
if [[ -f "$TASKS_FILE" ]]; then
    done_count=$(grep -c 'Status: done' "$TASKS_FILE" 2>/dev/null || echo "0")
    line_count=$(wc -l < "$TASKS_FILE" | tr -d ' ')
    if [[ "$done_count" -gt 20 ]]; then
        CONTEXT+="## Task Queue (${done_count} done tasks hidden)"$'\n'
        CONTEXT+=$(grep -v 'Status: done' "$TASKS_FILE" 2>/dev/null || true)$'\n'
    elif [[ "$line_count" -gt 50 ]]; then
        CONTEXT+="## Task Queue (summarized — $line_count lines)"$'\n'
        CONTEXT+=$(grep -E '^(##|- \[)' "$TASKS_FILE" 2>/dev/null || true)$'\n'
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

# --- Observations (last 3 if large) ---
OBS_FILE="$STATE_DIR/observations.md"
if [[ -f "$OBS_FILE" ]]; then
    line_count=$(wc -l < "$OBS_FILE" | tr -d ' ')
    if [[ "$line_count" -gt 60 ]]; then
        CONTEXT+="## Research Observations (last 3 of many)"$'\n'
        start_line=$(grep -n '^### OBS-' "$OBS_FILE" 2>/dev/null | tail -3 | head -1 | cut -d: -f1)
        if [[ -n "$start_line" ]]; then
            CONTEXT+=$(sed -n "${start_line},\$p" "$OBS_FILE")$'\n'
        fi
    else
        CONTEXT+=$(cat "$OBS_FILE")$'\n'
    fi
fi
CONTEXT+=$'\n'

# --- Experiments (last 3 if large) ---
EXP_FILE="$STATE_DIR/experiments.md"
if [[ -f "$EXP_FILE" ]]; then
    line_count=$(wc -l < "$EXP_FILE" | tr -d ' ')
    if [[ "$line_count" -gt 60 ]]; then
        CONTEXT+="## Experiment Log (last 3 of many)"$'\n'
        start_line=$(grep -n '^### EXP-' "$EXP_FILE" 2>/dev/null | tail -3 | head -1 | cut -d: -f1)
        if [[ -n "$start_line" ]]; then
            CONTEXT+=$(sed -n "${start_line},\$p" "$EXP_FILE")$'\n'
        fi
    else
        CONTEXT+=$(cat "$EXP_FILE")$'\n'
    fi
fi
CONTEXT+=$'\n'

# --- Session Context (capped at 100 lines) ---
SESSION_FILE="$STATE_DIR/session-current.md"
if [[ -f "$SESSION_FILE" ]]; then
    line_count=$(wc -l < "$SESSION_FILE" | tr -d ' ')
    if [[ "$line_count" -gt 100 ]]; then
        CONTEXT+="## Current Session Context (truncated — $line_count lines)"$'\n'
        CONTEXT+=$(head -100 "$SESSION_FILE")$'\n'
        CONTEXT+="... (truncated)"$'\n'
    else
        CONTEXT+=$(cat "$SESSION_FILE")$'\n'
    fi
else
    CONTEXT+="## Current Session Context"$'\n'
    CONTEXT+="_No session context found._"$'\n'
fi
CONTEXT+=$'\n'

# --- User Preferences (strip comments, structure-aware truncation) ---
PREFS_FILE="$STATE_DIR/preferences.md"
if [[ -f "$PREFS_FILE" ]] && [[ -s "$PREFS_FILE" ]]; then
    prefs_clean=$(sed '/^<!--/,/-->/d' "$PREFS_FILE" | grep -v '^# ' | sed '/^$/N;/^\n$/d')
    entry_total=$(echo "$prefs_clean" | grep -c '^- ' 2>/dev/null || echo "0")
    if [[ "$entry_total" -gt 0 ]]; then
        CONTEXT+="## User Preferences"$'\n'
        if [[ "$entry_total" -gt 40 ]]; then
            current_section=""
            entry_count=0
            while IFS= read -r pline; do
                if [[ "$pline" =~ ^###\  ]]; then
                    current_section="$pline"
                    entry_count=0
                    CONTEXT+=$'\n'"$pline"$'\n'
                elif [[ "$pline" =~ ^-\  ]] && [[ -n "$current_section" ]]; then
                    entry_count=$((entry_count + 1))
                    if [[ "$entry_count" -le 10 ]]; then
                        CONTEXT+="$pline"$'\n'
                    elif [[ "$entry_count" -eq 11 ]]; then
                        CONTEXT+="- ... (more entries — read preferences.md)"$'\n'
                    fi
                elif [[ -z "$pline" ]]; then
                    CONTEXT+=$'\n'
                fi
            done <<< "$prefs_clean"
            CONTEXT+=$'\n'"_(${entry_total} total preferences — read .claude/project-state/preferences.md for full list)_"$'\n'
        else
            CONTEXT+="$prefs_clean"$'\n'
        fi
        CONTEXT+=$'\n'
    fi
fi

# --- Recent Agent Activity (last 5 entries) ---
if [[ -f "$AGENT_LOG" ]] && [[ -s "$AGENT_LOG" ]]; then
    CONTEXT+="## Recent Agent Activity (last 5)"$'\n'
    while IFS= read -r line; do
        ts=$(echo "$line" | jq -r '.timestamp // "?"' 2>/dev/null || echo "?")
        atype=$(echo "$line" | jq -r '.agent_type // "?"' 2>/dev/null || echo "?")
        action=$(echo "$line" | jq -r '.action // "?"' 2>/dev/null || echo "?")
        CONTEXT+="- [$ts] $atype: $action"$'\n'
    done < <(tail -5 "$AGENT_LOG")
    CONTEXT+=$'\n'
fi

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
