#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "Starting Claude Eyes..."

# Start the Bun server in background
cd "$SCRIPT_DIR/server"
bun run src/index.ts &
SERVER_PID=$!

# Wait for server to be ready
sleep 1

# Build and launch the app
cd "$SCRIPT_DIR/app"
./build.sh
open "build/Claude Eyes.app"

echo ""
echo "Claude Eyes is running!"
echo "  Server PID: $SERVER_PID"
echo "  Press Ctrl+C to stop the server"
echo ""

# Wait for server (keeps script alive)
wait $SERVER_PID
