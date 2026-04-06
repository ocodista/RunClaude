# RunClaude

<p align="center">
  <img src="icon.png" width="128" alt="RunClaude icon" />
</p>

Menu bar token monitor for [Claude Code](https://docs.anthropic.com/en/docs/claude-code). A stick figure runs faster as token burn rate increases — inspired by [RunCat](https://kyome.io/runcat/).

Click the icon for a live dashboard: burn rate, per-model token breakdown, and active sessions.

## Install

```sh
git clone https://github.com/ocodista/RunClaude.git
cd RunClaude/app
./build.sh
cp -R build/RunClaude.app /Applications/
open /Applications/RunClaude.app
```

## Features

- Burn rate (tokens/second) over a 60s sliding window
- Per-model breakdown (Opus, Sonnet, Haiku) with share bars
- Active session list with project and token counts
- Animated menu bar icon: sleeps, walks, runs, sprints
- Reads `~/.claude/projects/` directly — zero config, no network
- Single Swift binary, no daemon

## Requirements

- macOS 14+
- Xcode command line tools (`xcode-select --install`)

## Development

```sh
./start.sh  # builds and opens from app/build/
```

Regenerate the app icon:

```sh
cd app && swift generate-icon.swift
```

## Architecture

- `BurnRateEngine.swift` — token aggregation, snapshot publishing
- `SessionScanner.swift` — tails JSONL files with incremental offsets (2s poll)
- `EyeRenderer.swift` — NSBezierPath stick figure drawing
- `PopoverView.swift` — SwiftUI dashboard

## License

MIT
