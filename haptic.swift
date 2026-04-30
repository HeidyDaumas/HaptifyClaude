#!/usr/bin/env swift
//
// haptic.swift
// A macOS command-line tool that triggers Force Touch trackpad haptic feedback.
//
// Uses two strategies:
//   1. MultitouchSupport.framework (private API) — works from background processes
//   2. NSHapticFeedbackManager fallback — works when app is frontmost
//
// Build:   swiftc haptic.swift -o haptic -framework AppKit -O
// Usage:   ./haptic [pattern] [time] [--repeat N] [--delay MS]
//

import AppKit
import Foundation

// ---------------------------------------------------------------------------
// MultitouchSupport private API for background haptic actuation
// ---------------------------------------------------------------------------

// These are the private C functions from MultitouchSupport.framework.
// They drive the Taptic Engine directly and work from background processes.

typealias MTActuatorRef = UnsafeMutableRawPointer

@_silgen_name("MTActuatorCreateFromDeviceID")
func MTActuatorCreateFromDeviceID(_ deviceID: UInt64) -> MTActuatorRef?

@_silgen_name("MTActuatorOpen")
func MTActuatorOpen(_ actuator: MTActuatorRef) -> Int32

@_silgen_name("MTActuatorClose")
func MTActuatorClose(_ actuator: MTActuatorRef) -> Int32

@_silgen_name("MTActuatorActuate")
func MTActuatorActuate(_ actuator: MTActuatorRef, _ actuationID: Int32, _ unknown1: UInt32, _ unknown2: Float, _ unknown3: Float) -> Int32

// Actuator IDs map to different haptic intensities:
//   1 = weak click (like .generic / .alignment)
//   2 = medium click
//   3 = strong click (like .levelChange)
//   4+ = progressively stronger

// Try the built-in trackpad first (device ID 0x2000000FF),
// then fall back to external Magic Trackpad IDs.
let trackpadDeviceIDs: [UInt64] = [
    0x200000001,      // Built-in trackpad (common)
    0x2000000FF,      // Built-in trackpad (alternate)
]

func triggerHapticViaMultitouch(strength: Int32, count: Int, delayMS: Int) -> Bool {
    for deviceID in trackpadDeviceIDs {
        guard let actuator = MTActuatorCreateFromDeviceID(deviceID) else {
            continue
        }
        let openResult = MTActuatorOpen(actuator)
        guard openResult == 0 else {
            continue
        }

        for i in 0..<count {
            _ = MTActuatorActuate(actuator, strength, 0, 0.0, 0.0)
            if i < count - 1 && delayMS > 0 {
                usleep(UInt32(delayMS) * 1000)
            }
        }

        usleep(50_000)  // let the last actuation complete
        _ = MTActuatorClose(actuator)
        return true
    }
    return false
}

// ---------------------------------------------------------------------------
// NSHapticFeedbackManager fallback (works when app is frontmost)
// ---------------------------------------------------------------------------

func triggerHapticViaAppKit(pattern: NSHapticFeedbackManager.FeedbackPattern, count: Int, delayMS: Int) {
    // Create minimal app context so haptics can fire
    let app = NSApplication.shared
    app.setActivationPolicy(.accessory)

    let performer = NSHapticFeedbackManager.defaultPerformer
    for i in 0..<count {
        performer.perform(pattern, performanceTime: .now)
        if i < count - 1 && delayMS > 0 {
            usleep(UInt32(delayMS) * 1000)
        }
    }
    usleep(100_000)
}

// ---------------------------------------------------------------------------
// Parse CLI arguments
// ---------------------------------------------------------------------------

let args = CommandLine.arguments

func printUsage() {
    let name = (args.first as NSString?)?.lastPathComponent ?? "haptic"
    fputs("""
    Usage: \(name) [pattern] [time] [--repeat N] [--delay MS]

    Patterns:
      generic      General-purpose feedback (default)
      alignment    Snap/alignment guide feedback
      levelChange  Significant state change feedback

    Performance time:
      default       System chooses optimal time (default)
      now           Play immediately
      drawCompleted Play after current draw cycle

    Options:
      --repeat N    Repeat the haptic N times (default: 1)
      --delay MS    Delay in milliseconds between repeats (default: 50)
      --help        Show this help

    Examples:
      \(name)                        # generic feedback, once
      \(name) levelChange now        # level-change feedback, immediately
      \(name) generic now --repeat 3 # triple buzz
    """, stderr)
}

if args.contains("--help") || args.contains("-h") {
    printUsage()
    exit(0)
}

// Parse --repeat and --delay flags
var repeatCount = 1
var delayMS = 50

if let idx = args.firstIndex(of: "--repeat"), idx + 1 < args.count,
   let n = Int(args[idx + 1]) {
    repeatCount = max(1, n)
}

if let idx = args.firstIndex(of: "--delay"), idx + 1 < args.count,
   let ms = Int(args[idx + 1]) {
    delayMS = max(0, ms)
}

// Parse positional arguments (pattern, time) — skip flags and their values
var positional: [String] = []
do {
    let rest = Array(args.dropFirst())
    var i = 0
    while i < rest.count {
        if rest[i] == "--repeat" || rest[i] == "--delay" {
            i += 2
        } else if rest[i].hasPrefix("--") {
            i += 1
        } else {
            positional.append(rest[i])
            i += 1
        }
    }
}

// ---------------------------------------------------------------------------
// Map string arguments to haptic parameters
// ---------------------------------------------------------------------------

let patternStr = positional.count > 0 ? positional[0].lowercased() : "generic"

let appKitPattern: NSHapticFeedbackManager.FeedbackPattern
let mtActuatorStrength: Int32

// Parse --strength override (1-16, raw MTActuator value)
var strengthOverride: Int32? = nil
if let idx = args.firstIndex(of: "--strength"), idx + 1 < args.count,
   let s = Int32(args[idx + 1]) {
    strengthOverride = max(1, min(16, s))
}

switch patternStr {
case "alignment":
    appKitPattern = .alignment
    mtActuatorStrength = strengthOverride ?? 2
case "generic":
    appKitPattern = .generic
    mtActuatorStrength = strengthOverride ?? 4
case "levelchange":
    appKitPattern = .levelChange
    mtActuatorStrength = strengthOverride ?? 6
default:
    fputs("Error: Unknown pattern '\(patternStr)'. Use: generic, alignment, levelChange\n", stderr)
    exit(1)
}

// ---------------------------------------------------------------------------
// Trigger haptic feedback — try MultitouchSupport first, then AppKit fallback
// ---------------------------------------------------------------------------

let mtSuccess = triggerHapticViaMultitouch(
    strength: mtActuatorStrength,
    count: repeatCount,
    delayMS: delayMS
)

if !mtSuccess {
    // Fallback to AppKit (only works if terminal is frontmost)
    triggerHapticViaAppKit(
        pattern: appKitPattern,
        count: repeatCount,
        delayMS: delayMS
    )
}
