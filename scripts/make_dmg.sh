#!/usr/bin/env bash
# Build a simple drag-to-Applications DMG. Name follows the .app.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="${1:-$ROOT/dist/SnapKadr.app}"
NAME="$(basename "$APP" .app)"
DMG="$ROOT/dist/${NAME}.dmg"
VOL="$NAME"

test -d "$APP" || { echo "error: missing app: $APP" >&2; exit 1; }

STAGE="$(mktemp -d "${TMPDIR:-/tmp}/sk-dmg.XXXXXX")"
cleanup() { rm -rf "$STAGE"; }
trap cleanup EXIT

ditto "$APP" "$STAGE/$(basename "$APP")"
ln -s /Applications "$STAGE/Applications"

rm -f "$DMG"
# UDZO = compressed read-only DMG suitable for distribution
hdiutil create \
  -volname "$VOL" \
  -srcfolder "$STAGE" \
  -ov \
  -format UDZO \
  "$DMG"

test -f "$DMG" || { echo "error: DMG not created" >&2; exit 1; }
echo "==> DMG: $DMG ($(stat -f%z "$DMG") bytes)"
