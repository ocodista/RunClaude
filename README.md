# RunClaude

A macOS menu bar companion for Claude Code that shows token burn rate in real time.

RunClaude watches your local Claude Code session logs and renders a tiny running stick figure in the menu bar. The figure sleeps when you're idle, walks between turns, runs while tokens flow, and sprints under heavy load — inspired by [RunCat](https://kyome.io/runcat/). Click the icon for a live breakdown of cost, tokens, and per-model usage.

## Features

- Live burn rate (tokens/second) over a 60-second sliding window
- Per-model cost breakdown (Opus, Sonnet, Haiku) with cache-aware pricing
- Active session list with project and token totals
- Animated menu bar icon that reflects current activity
- Zero configuration — reads `~/.claude/projects/` directly

## Requirements

- macOS 14+
- [Bun](https://bun.sh) (for the local server)
- Xcode command line tools (for the Swift app)

## Run

```sh
./start.sh
```

This kills anything on port 17888, starts the Bun server, builds the Swift app, and opens it. The menu bar icon appears within a second.

## Architecture

Two processes talk over `localhost:17888`:

- **`server/`** — Bun + TypeScript. Tails JSONL files in `~/.claude/projects/`, aggregates usage, and serves `GET /status`.
- **`app/RunClaude/`** — SwiftUI menu bar app. Polls the server and animates the icon.

## Roadmap: single-binary Swift app

The current split (Bun server + Swift app) is great for iteration but blocks App Store distribution. Sandboxed apps cannot spawn a Bun subprocess or reach `~/.claude/projects/` without an entitlement.

The plan is to fold the server logic into the Swift app:

- Port `SessionScanner` and `BurnRateCalculator` to Swift (`FileManager` + `DispatchSource` for file watching).
- Drop the HTTP layer — the UI reads the calculator directly.
- Ship a single signed `.app` through the App Store, or a notarized `.dmg` for direct download.

Until then, the `.sh` launcher and Bun server stay as the dev workflow.

## License

MIT
