# RunClaude

A macOS menu bar companion for Claude Code that shows token burn rate in real time.

RunClaude watches your local Claude Code session logs and renders a tiny running stick figure in the menu bar. The figure sleeps when you're idle, walks between turns, runs while tokens flow, and sprints under heavy load — inspired by [RunCat](https://kyome.io/runcat/). Click the icon for a live breakdown of cost, tokens, and per-model usage.

## Features

- Live burn rate (tokens/second) over a 60-second sliding window
- Per-model cost breakdown (Opus, Sonnet, Haiku) with cache-aware pricing
- Active session list with project and token totals
- Animated menu bar icon that reflects current activity
- Zero configuration — reads `~/.claude/projects/` directly
- Single Swift binary, no background daemon

## Requirements

- macOS 14+
- Xcode command line tools

## Run

```sh
./start.sh
```

This compiles the Swift app and launches it. The menu bar icon appears within a second.

## Architecture

One process, one binary:

- **`app/RunClaude/BurnRateEngine.swift`** — aggregates usage, computes tokens/second, per-model costs.
- **`app/RunClaude/SessionScanner.swift`** — tails JSONL files in `~/.claude/projects/` with incremental offsets.
- **`app/RunClaude/EyeRenderer.swift`** — draws the animated stick figure into the menu bar icon.
- **`app/RunClaude/PopoverView.swift`** — SwiftUI popover with the stats dashboard.

The scanner polls every 2 seconds and reads only the new bytes appended to each file since the last read.

## Roadmap

- App Store submission (sandbox + user-selected folder access for `~/.claude/projects/`)
- Notarized `.dmg` for direct download
- Configurable window size and pricing overrides

## License

MIT
