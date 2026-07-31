#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
fail=0
need() { [[ -f "$1" ]] || { echo "MISSING: $1"; fail=1; }; }
need "$ROOT/assets/neon-iris.png"
need "$ROOT/assets/app-icon.png"
need "$ROOT/assets/app-icon-beta.png"
need "$ROOT/styles.css"
need "$ROOT/index.html"
need "$ROOT/snap/index.html"
need "$ROOT/kadr/index.html"
need "$ROOT/motion.js"
grep -q -- '--bg:' "$ROOT/styles.css" || { echo "styles.css missing --bg"; fail=1; }
grep -q -- '#C026D3' "$ROOT/styles.css" || { echo "missing magenta accent"; fail=1; }
grep -q -- '#38BDF8' "$ROOT/styles.css" || { echo "missing cyan accent"; fail=1; }
need "$ROOT/appcast.xml"
need "$ROOT/appcast-beta.xml"

grep -q 'page-suite' "$ROOT/index.html" || { echo "root not page-suite"; fail=1; }
grep -q 'page-snap' "$ROOT/snap/index.html" || { echo "snap page missing class"; fail=1; }
grep -q 'page-kadr' "$ROOT/kadr/index.html" || { echo "kadr page missing class"; fail=1; }
grep -q 'v0.1.0-beta.2' "$ROOT/index.html" || { echo "suite beta CTA missing"; fail=1; }
grep -q 'class="grid"' "$ROOT/index.html" && { echo "old hub grid still present"; fail=1; }
[[ -s "$ROOT/appcast-beta.xml" ]] || { echo "appcast-beta empty"; fail=1; }
grep -q '../styles.css' "$ROOT/snap/index.html" || { echo "snap missing ../styles.css"; fail=1; }
grep -q '../styles.css' "$ROOT/kadr/index.html" || { echo "kadr missing ../styles.css"; fail=1; }
grep -q 'motion.js' "$ROOT/index.html" || { echo "root missing motion.js"; fail=1; }

if grep -E 'Dual status|два значка|Один значок|Sparkle|\bOCR\b|scrolling|suite:' "$ROOT/index.html" >/dev/null; then
  echo "forbidden jargon in index.html"; fail=1
fi
grep -q 'href="snap/"' "$ROOT/index.html" && { echo "root should not link to /snap/"; fail=1; }
grep -q 'href="kadr/"' "$ROOT/index.html" && { echo "root should not link to /kadr/"; fail=1; }
grep -q 'Несколько окон' "$ROOT/index.html" || { echo "missing multi-window killer copy"; fail=1; }
grep -q 'shot-slot' "$ROOT/index.html" || { echo "missing shot-slot placeholders"; fail=1; }
grep -q 'assets/shots/' "$ROOT/index.html" && { echo "root still references assets/shots images"; fail=1; }
grep -q 'feature-band--killer' "$ROOT/styles.css" || { echo "missing killer band CSS"; fail=1; }
grep -q 'shot-slot' "$ROOT/styles.css" || { echo "missing shot-slot CSS"; fail=1; }

exit "$fail"
