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
need "$ROOT/download.js"
grep -q -- '--bg:' "$ROOT/styles.css" || { echo "styles.css missing --bg"; fail=1; }
grep -q -- '#C026D3' "$ROOT/styles.css" || { echo "missing magenta accent"; fail=1; }
grep -q -- '#38BDF8' "$ROOT/styles.css" || { echo "missing cyan accent"; fail=1; }
need "$ROOT/appcast.xml"
need "$ROOT/appcast-beta.xml"

grep -q 'page-suite' "$ROOT/index.html" || { echo "root not page-suite"; fail=1; }
grep -q 'page-snap' "$ROOT/snap/index.html" || { echo "snap page missing class"; fail=1; }
grep -q 'page-kadr' "$ROOT/kadr/index.html" || { echo "kadr page missing class"; fail=1; }
grep -q 'releases/download/' "$ROOT/index.html" || { echo "missing direct zip download CTA"; fail=1; }
grep -q 'releases/tag/' "$ROOT/index.html" && { echo "CTA still points to release HTML page"; fail=1; }
grep -q 'SnapKadrBeta.zip' "$ROOT/index.html" || { echo "missing SnapKadrBeta.zip in CTA"; fail=1; }
grep -q 'data-download="beta"' "$ROOT/index.html" || { echo "missing data-download hooks"; fail=1; }
grep -q 'class="grid"' "$ROOT/index.html" && { echo "old hub grid still present"; fail=1; }
[[ -s "$ROOT/appcast-beta.xml" ]] || { echo "appcast-beta empty"; fail=1; }
grep -q '../styles.css' "$ROOT/snap/index.html" || { echo "snap missing ../styles.css"; fail=1; }
grep -q '../styles.css' "$ROOT/kadr/index.html" || { echo "kadr missing ../styles.css"; fail=1; }
grep -q 'motion.js' "$ROOT/index.html" || { echo "root missing motion.js"; fail=1; }
grep -q 'download.js' "$ROOT/index.html" || { echo "root missing download.js"; fail=1; }
need "$ROOT/carousel.js"
grep -q 'carousel.js' "$ROOT/index.html" || { echo "root missing carousel.js"; fail=1; }
grep -q 'data-carousel' "$ROOT/index.html" || { echo "missing hero carousel"; fail=1; }
grep -q 'hero-carousel' "$ROOT/styles.css" || { echo "missing hero-carousel CSS"; fail=1; }

if grep -E 'Dual status|два значка|Один значок|Sparkle|\bOCR\b|scrolling|suite:' "$ROOT/index.html" >/dev/null; then
  echo "forbidden jargon in index.html"; fail=1
fi
grep -q 'href="snap/"' "$ROOT/index.html" && { echo "root should not link to /snap/"; fail=1; }
grep -q 'href="kadr/"' "$ROOT/index.html" && { echo "root should not link to /kadr/"; fail=1; }
grep -q 'Несколько окон' "$ROOT/index.html" || { echo "missing multi-window killer copy"; fail=1; }
grep -q 'Автозумы по кликам' "$ROOT/index.html" || { echo "missing autozoom copy"; fail=1; }
grep -q 'Длинная страница целиком' "$ROOT/index.html" || { echo "missing scrolling capture copy"; fail=1; }
grep -q 'Текст и QR со скрина' "$ROOT/index.html" || { echo "missing text/QR copy"; fail=1; }
grep -q 'mid-cta' "$ROOT/index.html" || { echo "missing mid-cta"; fail=1; }
grep -q 'wave-label' "$ROOT/index.html" || { echo "missing wave labels"; fail=1; }
grep -q 'data-reveal' "$ROOT/index.html" || { echo "missing data-reveal"; fail=1; }
grep -q 'data-parallax' "$ROOT/index.html" || { echo "missing data-parallax"; fail=1; }
grep -q 'install-steps' "$ROOT/index.html" || { echo "missing install steps"; fail=1; }
grep -q 'SnapKadrBeta' "$ROOT/index.html" || { echo "missing SnapKadrBeta in install guide"; fail=1; }
grep -q 'assets/shots/' "$ROOT/index.html" || { echo "missing real feature shots"; fail=1; }
grep -q 'shot-slot' "$ROOT/index.html" && { echo "shot-slot placeholders still present"; fail=1; }
need "$ROOT/assets/shots/02-multi-window-anon.png"
need "$ROOT/assets/shots/03-layout-before-record-anon.png"
need "$ROOT/assets/shots/04-phone-in-frame-anon.png"
need "$ROOT/assets/shots/05-camera-pip-anon.png"
grep -q '02-multi-window-anon.png' "$ROOT/index.html" || { echo "landing missing multi-window anon"; fail=1; }
grep -q '05-camera-pip-anon.png' "$ROOT/index.html" || { echo "landing missing camera anon"; fail=1; }
# Wave A must not still point at schematic mocks
for f in 02-multi-window 03-layout-before-record 04-phone-in-frame 05-camera-pip; do
  grep -q "${f}-mock.png" "$ROOT/index.html" && { echo "wave A still uses ${f}-mock"; fail=1; }
done
grep -q 'feature-band--killer' "$ROOT/styles.css" || { echo "missing killer band CSS"; fail=1; }
grep -q 'wave-label' "$ROOT/styles.css" || { echo "missing wave-label CSS"; fail=1; }
grep -q 'data-reveal-child' "$ROOT/styles.css" || { echo "missing reveal CSS"; fail=1; }
grep -q 'js-motion' "$ROOT/styles.css" || { echo "missing js-motion CSS gate"; fail=1; }
grep -q 'reveal-up' "$ROOT/styles.css" || { echo "missing reveal-up keyframes"; fail=1; }
grep -q 'initParallax' "$ROOT/motion.js" || { echo "missing parallax in motion.js"; fail=1; }
grep -q 'js-motion' "$ROOT/motion.js" || { echo "missing js-motion class toggle"; fail=1; }
grep -q 'appcast-beta.xml' "$ROOT/download.js" || { echo "download.js must read appcast"; fail=1; }

band_count="$(grep -c 'class="feature-band' "$ROOT/index.html" || true)"
if [[ "$band_count" -lt 20 ]]; then
  echo "expected 20+ feature bands, got $band_count"; fail=1
fi

shot_count="$(grep -c 'assets/shots/' "$ROOT/index.html" || true)"
if [[ "$shot_count" -lt 20 ]]; then
  echo "expected 20+ shot references, got $shot_count"; fail=1
fi

exit "$fail"
