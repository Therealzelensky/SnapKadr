#!/usr/bin/env bash
# Rasterize docs/mocks/scenes/*.html → docs/assets/shots/*-html.png via Chrome headless.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CHROME="${CHROME:-/Applications/Google Chrome.app/Contents/MacOS/Google Chrome}"
OUT="$ROOT/assets/shots"
SCENES="$ROOT/mocks/scenes"

render() {
  local name="$1" w="$2" h="$3"
  local html="$SCENES/$name.html"
  local png="$OUT/${name}-html.png"
  local abs
  abs="$(python3 -c "import pathlib; print(pathlib.Path('$html').resolve().as_uri())")"
  "$CHROME" --headless=new --disable-gpu --no-sandbox --hide-scrollbars \
    --window-size="$w,$h" \
    --screenshot="$png" \
    "$abs" >/dev/null 2>&1
  # Chrome writes to cwd sometimes — normalize
  if [[ ! -f "$png" && -f screenshot.png ]]; then
    mv screenshot.png "$png"
  fi
  # Also check chrome default in scene dir / cwd
  if [[ ! -f "$png" ]]; then
    find . "$SCENES" "$ROOT" -maxdepth 2 -name 'screenshot.png' 2>/dev/null | head -1 | while read -r f; do
      mv "$f" "$png"
    done
  fi
  echo "wrote $png ($(wc -c < "$png") bytes)"
}

cd "$ROOT"
render 02-multi-window 1600 1000
render 03-layout-before-record 1600 900
render 04-phone-in-frame 1600 1000
render 05-camera-pip 1600 1000
