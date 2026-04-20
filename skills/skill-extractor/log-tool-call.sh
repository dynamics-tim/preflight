#!/usr/bin/env bash
set -euo pipefail

# ── Rich Session Activity Logger ─────────────────────────────────────────────
# Appends a detailed JSONL entry for each tool call.
# Provides richer data than the inline hook (includes path + args summary).
#
# Usage: Replace the postToolUse inline command in session-logger.json with:
#   "bash": "bash .github/hooks/log-tool-call.sh 2>/dev/null || true"
#
# Environment variables (provided by Copilot hooks):
#   COPILOT_TOOL_NAME      — name of the tool that was called
#   COPILOT_TOOL_ARGS      — JSON string of tool arguments

stderr() { echo "$@" >&2; }

LOG_DIR=".copilot"
LOG_FILE="$LOG_DIR/session-activity.jsonl"

# Ensure log directory exists
mkdir -p "$LOG_DIR"

TOOL_NAME="${COPILOT_TOOL_NAME:-unknown}"
TOOL_ARGS="${COPILOT_TOOL_ARGS:-{}}"
TIMESTAMP=$(date -u '+%Y-%m-%dT%H:%M:%SZ')

# Extract file path from common tool arg patterns
extract_path() {
  echo "$TOOL_ARGS" | grep -oE '"(path|file|filePath|target)"\s*:\s*"[^"]*"' \
    | head -1 | sed 's/.*: *"//;s/"//' || true
}

# Extract a short summary from args (first 200 chars, single line)
summarize_args() {
  echo "$TOOL_ARGS" | tr '\n' ' ' | cut -c1-200
}

FILE_PATH=$(extract_path)
ARGS_SUMMARY=$(summarize_args)

# Escape strings for JSON (minimal: backslash, double-quote, newlines)
json_escape() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\n'/\\n}"
  s="${s//$'\r'/}"
  s="${s//$'\t'/\\t}"
  echo -n "$s"
}

ESCAPED_PATH=$(json_escape "$FILE_PATH")
ESCAPED_SUMMARY=$(json_escape "$ARGS_SUMMARY")

# Append JSONL entry (one line, no trailing newline issues)
echo "{\"ts\":\"$TIMESTAMP\",\"tool\":\"$TOOL_NAME\",\"path\":\"$ESCAPED_PATH\",\"args_summary\":\"$ESCAPED_SUMMARY\"}" >> "$LOG_FILE"
