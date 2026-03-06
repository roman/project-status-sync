#!/usr/bin/env bash
# SessionEnd hook for Claude Code
# Reads session JSON from stdin, writes .available signal file
# Must stay fast — no LLM calls, no network, just write a file.
set -euo pipefail

SIGNAL_DIR="${CCS_SIGNAL_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/ccs/signals}"
mkdir -p "$SIGNAL_DIR"

INPUT=$(cat)

SESSION_ID=$(printf '%s' "$INPUT" | jq -r '.session_id')
TRANSCRIPT_PATH=$(printf '%s' "$INPUT" | jq -r '.transcript_path')
CWD=$(printf '%s' "$INPUT" | jq -r '.cwd')

if [ "$SESSION_ID" = "null" ] || [ "$TRANSCRIPT_PATH" = "null" ] || [ "$CWD" = "null" ]; then
  echo "ccs: missing required field in hook payload" >&2
  exit 0
fi

printf '%s' "$INPUT" | jq -c '{transcript_path, cwd}' \
  > "$SIGNAL_DIR/${SESSION_ID}.available"
