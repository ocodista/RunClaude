#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "Starting RunClaude..."

cd "$SCRIPT_DIR/app"
./build.sh
open "build/RunClaude.app"

echo ""
echo "RunClaude is running in your menu bar."
