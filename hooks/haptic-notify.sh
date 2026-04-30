#!/bin/bash
# haptic-notify.sh — Claude Code hook that triggers trackpad haptic feedback
# when the session needs user input (permission prompt, idle, or MCP dialog).
#
# Called by Claude Code's Stop/Notification hook with JSON on stdin.
# Requires the `haptic` binary built from haptic.swift.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HAPTIC_BIN="$SCRIPT_DIR/../haptic"

if [[ ! -x "$HAPTIC_BIN" ]]; then
  exit 0
fi

# Drain stdin (hook payload — not needed for now)
cat > /dev/null

# 5-second continuous buzz at max strength
"$HAPTIC_BIN" levelChange now --strength 16 --repeat 100 --delay 50 &

exit 0
