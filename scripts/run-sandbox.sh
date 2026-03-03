#!/usr/bin/env bash
# run-sandbox.sh — Run claude-sandbox VM with project directory mounted
#
# Usage:
#   ./scripts/run-sandbox.sh              # Mount current directory
#   ./scripts/run-sandbox.sh /path/to/project  # Mount specific directory
#
# Exit:
#   - Type 'poweroff' inside the VM
#   - Or press Ctrl-A X (QEMU escape sequence)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FLAKE_DIR="$(dirname "$SCRIPT_DIR")"
PROJECT_DIR="${1:-$(pwd)}"

# Resolve to absolute path
PROJECT_DIR="$(cd "$PROJECT_DIR" && pwd)"

echo "=== Claude Sandbox VM ==="
echo "Project: $PROJECT_DIR"
echo "Exit: poweroff or Ctrl-A X"
echo ""

# Build QEMU arguments for dynamic 9p shares
export MICROVM_EXTRA_ARGS="-virtfs local,path=$PROJECT_DIR,mount_tag=project,security_model=mapped-xattr"

# Add gitconfig if it exists
if [[ -f "$HOME/.gitconfig" ]]; then
    MICROVM_EXTRA_ARGS="$MICROVM_EXTRA_ARGS -virtfs local,path=$HOME/.gitconfig,mount_tag=gitconfig,security_model=none,readonly=on"
fi

# Add anthropic credentials if they exist
if [[ -d "$HOME/.anthropic" ]]; then
    MICROVM_EXTRA_ARGS="$MICROVM_EXTRA_ARGS -virtfs local,path=$HOME/.anthropic,mount_tag=anthropic,security_model=none,readonly=on"
fi

exec nix run "$FLAKE_DIR#claude-sandbox"
