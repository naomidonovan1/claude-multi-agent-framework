#!/usr/bin/env bash
# Subagent Stop Hook
# Logs agent activity when any subagent finishes.
# Fires on: all subagent types completing
# Output: none (fire-and-forget logging)

set -euo pipefail

# --- Dependencies & safety ---
command -v jq &>/dev/null || exit 0

# Read stdin and parse all fields in a single jq call
INPUT=$(cat)
eval "$(echo "$INPUT" | jq -r '
  "CWD_RAW=" + (.cwd // ".") + "\n" +
  "AGENT_ID=" + (.agent_id // "unknown") + "\n" +
  "AGENT_TYPE=" + (.agent_type // "unknown") + "\n" +
  "SESSION_ID=" + (.session_id // "unknown")
' 2>/dev/null || echo 'CWD_RAW=.; AGENT_ID=unknown; AGENT_TYPE=unknown; SESSION_ID=unknown')"

PROJECT_ROOT="$CWD_RAW"
[[ -d "$PROJECT_ROOT/.claude" ]] || exit 0

trap 'echo "[$(date)] $0: ERROR line $LINENO" >> "$PROJECT_ROOT/.claude/hooks/error.log"' ERR

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

# Rotate agent-log.jsonl — keep last 50 entries
entry_count=$(wc -l < "$AGENT_LOG" | tr -d ' ')
if [[ "$entry_count" -gt 50 ]]; then
    tail -50 "$AGENT_LOG" > "${AGENT_LOG}.tmp" && mv "${AGENT_LOG}.tmp" "$AGENT_LOG"
fi
