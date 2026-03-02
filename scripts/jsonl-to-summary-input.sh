#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: $(basename "$0") <session.jsonl> [output.txt]"
  echo "Transforms Claude session JSONL to plain text for summarization"
  exit 1
}

[[ $# -lt 1 ]] && usage
[[ ! -f "$1" ]] && { echo "File not found: $1" >&2; exit 1; }

INPUT="$1"
OUTPUT="${2:-/dev/stdout}"

jq -r '
  select(.type == "user" or .type == "assistant") |
  .role = .type |
  .texts = (
    if (.message.content | type) == "string" then
      [.message.content]
    elif (.message.content | type) == "array" then
      [.message.content[] | select(.type == "text") | .text]
    else
      []
    end
  ) |
  select(.texts | length > 0) |
  select(.texts | any(. != "")) |
  "\(.role | ascii_upcase):\n\(.texts | join("\n"))\n"
' "$INPUT" 2>/dev/null > "$OUTPUT"
