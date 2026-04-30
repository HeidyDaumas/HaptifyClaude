# HaptifyClaude

Haptic feedback for Claude Code on MacBook. Your trackpad buzzes when Claude needs your attention.

## How it works

HaptifyClaude hooks into Claude Code's **Stop** and **Notification** events. When Claude finishes responding or needs permission, the MacBook's Force Touch trackpad Taptic Engine fires a haptic pattern you can physically feel.

Uses Apple's private `MultitouchSupport.framework` for reliable actuation from background processes, with an `NSHapticFeedbackManager` fallback.

## Requirements

- macOS with Force Touch trackpad (MacBook 2015+ or Magic Trackpad 2+)
- Swift compiler (`xcode-select --install`)
- [Claude Code](https://claude.ai/code)

## Install

```bash
git clone https://github.com/heidydaumas/HaptifyClaude.git
cd HaptifyClaude
./install.sh
```

The installer:
1. Builds the native haptic binary from Swift source
2. Tests that your trackpad responds
3. Registers the hook in `~/.claude/settings.json`

## Uninstall

```bash
./uninstall.sh
```

## How it feels

The default pattern is a **5-second continuous rumble at max strength** — 100 beats at strength 16, 50ms apart. You won't miss it.

### Customizing the pattern

Edit `hooks/haptic-notify.sh` and change the haptic command:

```bash
# Gentle single tap
./haptic generic now --strength 4

# Triple strong knock
./haptic levelChange now --strength 10 --repeat 3 --delay 80

# 5-second rumble (default)
./haptic levelChange now --strength 16 --repeat 100 --delay 50
```

### Haptic binary options

```
./haptic [pattern] [time] [--strength N] [--repeat N] [--delay MS]
```

| Parameter | Values | Default |
|-----------|--------|---------|
| pattern | `generic`, `alignment`, `levelChange` | `generic` |
| --strength | 1–16 (actuator intensity) | Pattern-dependent |
| --repeat | Number of beats | 1 |
| --delay | Milliseconds between beats | 50 |

### Base patterns

| Pattern | Feel |
|---------|------|
| `generic` | Soft, neutral tap |
| `alignment` | Subtle, precise click |
| `levelChange` | Pronounced thud |

## Architecture

```
HaptifyClaude/
  haptic.swift          # Swift CLI — drives Taptic Engine
  hooks/
    haptic-notify.sh    # Claude Code hook script
    hooks.json          # Hook config (project-level)
  install.sh            # Global installer
  uninstall.sh          # Clean uninstaller
```

## Technical details

The binary tries two actuation methods in order:

1. **MultitouchSupport.framework** (private API) — calls `MTActuatorActuate` directly. Works from background processes without needing to be the frontmost app.
2. **NSHapticFeedbackManager** (AppKit) — public API fallback with a minimal `NSApplication` context.

No permissions, entitlements, or code signing required.

## License

MIT
