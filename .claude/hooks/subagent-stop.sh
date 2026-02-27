#!/usr/bin/env bash
# Subagent Stop Hook
# Logs agent activity when any subagent finishes.
# Fires on: all subagent types completing
# Output: none (fire-and-forget logging)

set -euo pipefail

# Read stdin (Claude Code hook protocol)
INPUT=$(cat)
CWD=$(echo "$INPUT" | jq -r '.cwd // "."' 2>/dev/null || echo ".")
AGENT_ID=$(echo "$INPUT" | jq -r '.agent_id // "unknown"' 2>/dev/null || echo "unknown")
AGENT_TYPE=$(echo "$INPUT" | jq -r '.agent_type // "unknown"' 2>/dev/null || echo "unknown")
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"' 2>/dev/null || echo "unknown")

PROJECT_ROOT="$CWD"
AGENT_LOG="$PROJECT_ROOT/.claude/project-state/agent-log.jsonl"
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# Build structured log entry
ENTRY=$(jq -n \
    --arg ts "$TIMESTAMP" \
    --arg agent_id "$AGENT_ID" \
    --arg agent_type "$AGENT_TYPE" \
    --arg session_id "$SESSION_ID" \
    '{
        timestamp: $ts,
        agent_id: $agent_id,
        agent_type: $agent_type,
        session_id: $session_id,
        action: "completed"
    }')

# Ensure the log file directory exists
mkdir -p "$(dirname "$AGENT_LOG")"

# Append the entry
echo "$ENTRY" >> "$AGENT_LOG"
