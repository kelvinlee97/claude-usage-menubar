# Claude Balance

A macOS menu bar utility, inspired by Cortex Balance, that shows your Claude usage limits in real time:

- **5-hour limit**: percentage used in the current window, with a reset countdown
- **7-day limit**: percentage used in the current window, with a reset countdown

## Current status

Reads the `rate_limits` payload that Claude Code's statusline hook writes to `~/Library/Application Support/ClaudeBalance/usage.json`, so it stays in sync with whatever your local Claude Code session last reported. If that cache is missing or older than 6 hours, the data is treated as stale.

## Running

Requires macOS 13+ and Xcode 15+ / Swift 5.9+.

```bash
swift run
```

Or open `Package.swift` in Xcode and run it directly.

## Project structure

```
Sources/ClaudeBalance/
  ClaudeBalanceApp.swift      # App entry point, MenuBarExtra scene
  UsageModel.swift            # Usage data model and store
  MenuBarContentView.swift    # Menu bar dropdown UI
```
