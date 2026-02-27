#!/usr/bin/env bash
# Pre-Compact Hook
# Saves a timestamped snapshot of critical state files before compaction.
# Fires on: auto and manual compaction
# Output: none (PreCompact does not support decision output)

set -euo pipefail

# Read stdin (Claude Code hook protocol)
INPUT=$(cat)
CWD=$(echo "$INPUT" | jq -r '.cwd // "."' 2>/dev/null || echo ".")

PROJECT_ROOT="$CWD"
STATE_DIR="$PROJECT_ROOT/.claude/project-state"
BACKUP_DIR="$PROJECT_ROOT/.claude/backups"

# Create backup directory with timestamp
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
SNAPSHOT_DIR="$BACKUP_DIR/$TIMESTAMP"
mkdir -p "$SNAPSHOT_DIR"

# Backup all state files
for file in tasks.md decisions.md session-current.md observations.md experiments.md agent-log.jsonl; do
    src="$STATE_DIR/$file"
    if [[ -f "$src" ]]; then
        cp "$src" "$SNAPSHOT_DIR/$file"
    fi
done

# Backup session history
HISTORY_FILE="$PROJECT_ROOT/.claude/session-history.jsonl"
if [[ -f "$HISTORY_FILE" ]]; then
    cp "$HISTORY_FILE" "$SNAPSHOT_DIR/session-history.jsonl"
fi

# Clean up old backups — keep only the last 10 (macOS-compatible)
if [[ -d "$BACKUP_DIR" ]]; then
    backup_count=$(find "$BACKUP_DIR" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')
    if [[ "$backup_count" -gt 10 ]]; then
        remove_count=$((backup_count - 10))
        find "$BACKUP_DIR" -mindepth 1 -maxdepth 1 -type d | sort | head -n "$remove_count" | while IFS= read -r dir; do
            rm -rf "$dir"
        done
    fi
fi

# PreCompact does not support output — write to stderr for diagnostics only
echo "Pre-compact backup saved to $SNAPSHOT_DIR" >&2
