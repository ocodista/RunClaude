#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PORT=17888

echo "Starting RunClaude..."

# Free the port if a previous instance is still listening
if lsof -ti tcp:"$PORT" >/dev/null 2>&1; then
  echo "  Port $PORT in use — stopping old process..."
  lsof -ti tcp:"$PORT" | xargs kill -9 2>/dev/null || true
  sleep 0.3
fi

# Start the Bun server in background
cd "$SCRIPT_DIR/server"
bun run src/index.ts &
SERVER_PID=$!

# Wait for server to be ready
sleep 1

# Build and launch the app
cd "$SCRIPT_DIR/app"
./build.sh
open "build/RunClaude.app"

echo ""
echo "RunClaude is running!"
echo "  Server PID: $SERVER_PID"
echo "  Press Ctrl+C to stop the server"
echo ""

# Wait for server (keeps script alive)
wait $SERVER_PID
