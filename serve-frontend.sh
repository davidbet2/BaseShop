#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────
# BaseShop — Serve Flutter web build on http://localhost:8080
# Usage: bash serve-frontend.sh
# ─────────────────────────────────────────────────────────────

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WEB_DIR="$SCRIPT_DIR/frontend/build/web"
PORT=8080
FLUTTER="/c/Users/david/flutter/bin/flutter"

# Build if the web output doesn't exist
if [ ! -f "$WEB_DIR/index.html" ]; then
  echo "[serve-frontend] Build web output not found. Building..."
  cd "$SCRIPT_DIR/frontend"
  "$FLUTTER" build web
fi

echo "[serve-frontend] Serving $WEB_DIR on http://localhost:$PORT"
echo "[serve-frontend] Press Ctrl+C to stop."
cd "$WEB_DIR"
npx --yes serve -s . -l $PORT
