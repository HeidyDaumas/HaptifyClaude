#!/bin/bash
# install.sh — Install HaptiClaude globally for all Claude Code sessions
#
# This script:
#   1. Builds the haptic binary from Swift source
#   2. Installs the hook into ~/.claude/settings.json
#
# Usage: ./install.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HAPTIC_SRC="$SCRIPT_DIR/haptic.swift"
HAPTIC_BIN="$SCRIPT_DIR/haptic"
HOOK_SCRIPT="$SCRIPT_DIR/hooks/haptic-notify.sh"
SETTINGS_FILE="$HOME/.claude/settings.json"

echo "=== HaptiClaude Installer ==="
echo ""

# Step 1: Build the haptic binary
echo "[1/3] Building haptic binary..."
if [[ ! -f "$HAPTIC_SRC" ]]; then
  echo "Error: haptic.swift not found at $HAPTIC_SRC" >&2
  exit 1
fi

swiftc "$HAPTIC_SRC" -o "$HAPTIC_BIN" -framework AppKit -F /System/Library/PrivateFrameworks -framework MultitouchSupport -O
chmod +x "$HAPTIC_BIN"
echo "  Built: $HAPTIC_BIN"

# Step 2: Verify haptic works
echo "[2/3] Testing haptic feedback..."
"$HAPTIC_BIN" generic now 2>/dev/null && echo "  Haptic feedback OK (did you feel that?)" || echo "  Warning: haptic test returned non-zero (may still work)"

# Step 3: Install hook into Claude Code settings
echo "[3/3] Installing Claude Code hook..."

mkdir -p "$HOME/.claude"

HOOK_CMD="$HOOK_SCRIPT"

if [[ -f "$SETTINGS_FILE" ]]; then
  /usr/bin/python3 -c "
import json

settings_path = '$SETTINGS_FILE'
hook_cmd = '$HOOK_CMD'

with open(settings_path, 'r') as f:
    settings = json.load(f)

hooks = settings.setdefault('hooks', {})

# Install into both Stop and Notification events
for event in ['Stop', 'Notification']:
    entries = hooks.setdefault(event, [])

    # Check if HaptiClaude hook already exists
    found = False
    for group in entries:
        for h in group.get('hooks', []):
            if 'haptic-notify' in h.get('command', ''):
                h['command'] = hook_cmd
                h['timeout'] = 10
                found = True
                break

    if not found:
        entries.append({
            'matcher': '',
            'hooks': [{
                'type': 'command',
                'command': hook_cmd,
                'timeout': 10
            }]
        })

with open(settings_path, 'w') as f:
    json.dump(settings, f, indent=2)
    f.write('\n')

print('  Updated: ' + settings_path)
" || {
    echo "  Error: Failed to update settings. You may need to add the hook manually." >&2
    echo "  See README.md for manual installation instructions." >&2
    exit 1
  }
else
  cat > "$SETTINGS_FILE" << SETTINGSEOF
{
  "hooks": {
    "Stop": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "$HOOK_CMD",
            "timeout": 10
          }
        ]
      }
    ],
    "Notification": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "$HOOK_CMD",
            "timeout": 10
          }
        ]
      }
    ]
  }
}
SETTINGSEOF
  echo "  Created: $SETTINGS_FILE"
fi

echo ""
echo "=== Installation complete ==="
echo ""
echo "HaptiClaude is now active."
echo "Your trackpad will buzz for 5 seconds when Claude Code finishes responding."
echo ""
echo "To customize the pattern, edit hooks/haptic-notify.sh"
echo "To uninstall, run: ./uninstall.sh"
