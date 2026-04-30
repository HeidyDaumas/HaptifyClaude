#!/bin/bash
# uninstall.sh — Remove HaptiClaude hooks from Claude Code settings
set -euo pipefail

SETTINGS_FILE="$HOME/.claude/settings.json"

echo "=== HaptiClaude Uninstaller ==="

if [[ ! -f "$SETTINGS_FILE" ]]; then
  echo "No settings file found. Nothing to uninstall."
  exit 0
fi

/usr/bin/python3 -c "
import json

settings_path = '$SETTINGS_FILE'
with open(settings_path, 'r') as f:
    settings = json.load(f)

hooks = settings.get('hooks', {})

for event in ['Stop', 'Notification']:
    entries = hooks.get(event, [])
    filtered = []
    for group in entries:
        group_hooks = [h for h in group.get('hooks', []) if 'haptic-notify' not in h.get('command', '')]
        if group_hooks:
            group['hooks'] = group_hooks
            filtered.append(group)
    if filtered:
        hooks[event] = filtered
    elif event in hooks:
        del hooks[event]

if not hooks:
    settings.pop('hooks', None)

# Also clean up disabled hooks backup
settings.pop('_disabled_hooks', None)

with open(settings_path, 'w') as f:
    json.dump(settings, f, indent=2)
    f.write('\n')
"

echo "HaptiClaude hooks removed from $SETTINGS_FILE"
echo "You can safely delete this directory to fully remove HaptiClaude."
