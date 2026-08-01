#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CHROME="${CHROME:-/Applications/Google Chrome.app/Contents/MacOS/Google Chrome}"
OUT="$ROOT/assets/shots"
SCENES="$ROOT/mocks/scenes"
cd /tmp
render() {
  local name="$1" w="${2:-1600}" h="${3:-1000}"
  local html="$SCENES/$name.html"
  local png="$OUT/${name}-html.png"
  local abs; abs="$(python3 -c "import pathlib; print(pathlib.Path('$html').resolve().as_uri())")"
  "$CHROME" --headless=new --disable-gpu --no-sandbox --hide-scrollbars --window-size="$w,$h" --screenshot="$png" "$abs" >/dev/null 2>&1
  echo "wrote $name"
}
render 02-multi-window 1600 1000
render 03-layout-before-record 1600 900
render 04-phone-in-frame 1600 1000
render 05-camera-pip 1600 1000
render 06-tracks-separate 1600 1000
render 07-audio-tracks 1600 1000
render 08-timeline-assembly 1600 1000
render 09-autozoom 1600 1000
render 10-cursor 1600 1000
render 11-manual-zoom 1600 1000
render 12-masks 1600 1000
render 13-bg-card 1600 1000
render 14-device-frames 1600 1000
render 15-keys-overlay 1600 1000
render 16-subtitles 1600 1000
render 17-aspect 1600 1000
render 18-export 1600 1000
render 19-snap-capture 1600 1000
render 20-snap-annotate 1600 1000
render 21-snap-long 1600 1000
render 22-snap-ocr 1600 1000
render 23-snap-overlay 1600 1000
render 24-snap-bg 1600 1000
render 25-suite-together 1600 1000
render 26-suite-prefs 1600 1000
render 27-updates 1600 1000
