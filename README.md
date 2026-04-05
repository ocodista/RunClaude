# RunClaude

Menu bar token burn-rate monitor for Claude Code. A stick figure that sleeps when you're idle, walks between turns, runs while tokens flow, and sprints under load — inspired by [RunCat](https://kyome.io/runcat/).

Click the icon for live cost, tokens, and per-model breakdown.

## Features

- Burn rate over a 60s sliding window
- Per-model cost (Opus, Sonnet, Haiku) with cache-aware pricing
- Active session list with project and token totals
- Reads `~/.claude/projects/` directly — no config, no network
- Single Swift binary

## Requirements

- macOS 14+
- Xcode command line tools

## Install

```sh
git clone https://github.com/ocodista/RunClaude.git
cd RunClaude/app
./build.sh
cp -R build/RunClaude.app /Applications/
open /Applications/RunClaude.app
```

Or for dev (builds and launches from `app/build/`):

```sh
./start.sh
```

## Architecture

- `app/RunClaude/BurnRateEngine.swift` — aggregation, pricing, snapshot
- `app/RunClaude/SessionScanner.swift` — tails JSONL with incremental offsets
- `app/RunClaude/EyeRenderer.swift` — draws the stick figure
- `app/RunClaude/PopoverView.swift` — SwiftUI dashboard

Polls every 2s, reads only newly appended bytes.

## Roadmap

- App Store submission (sandbox + folder-access entitlement)
- Notarized `.dmg`
- Configurable window and pricing

## License

MIT
