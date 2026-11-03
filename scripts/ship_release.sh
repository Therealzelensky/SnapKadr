#!/usr/bin/env bash
# Bump release tag → build SnapKadr.app → GitHub Release → appcast.xml → push.
# Updates are published only on the release feed. Beta stays a local dev build.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

die() { echo "error: $*" >&2; exit 1; }
need() { command -v "$1" >/dev/null || die "missing $1"; }

need git
need curl
need python3
need ditto
need make

if [[ -n "$(git status --porcelain --untracked-files=no)" ]]; then
  die "tracked working tree dirty; commit or stash first"
fi

BRANCH="$(git rev-parse --abbrev-ref HEAD)"
if [[ "$BRANCH" != "main" ]]; then
  die "ship the release from main (now: $BRANCH)"
fi

git checkout main
git pull --ff-only origin main

if [[ -n "${SHIP_TAG:-}" ]]; then
  TAG="$SHIP_TAG"
else
  git fetch --tags origin 2>/dev/null || true
  TAG="$(
    python3 - <<'PY'
import re, subprocess
raw = subprocess.check_output(["git", "tag", "-l", "v0.1*"], text=True)
nums = []
for t in raw.split():
    m = re.fullmatch(r"v0\.1\.(\d+)(?:-beta)?", t)
    if m:
        nums.append(int(m.group(1)))
        continue
    m = re.fullmatch(r"v0\.1\.0-beta\.?(\d+)", t)
    if m:
        nums.append(int(m.group(1)))
n = (max(nums) if nums else 0) + 1
print(f"v0.1.{n}")
PY
  )"
fi
echo "==> Shipping release $TAG"

if [[ -n "${SNAPKADR_VERSION:-}" ]]; then
  VERSION="$SNAPKADR_VERSION"
else
  VERSION="$(
    python3 - <<PY
import re
m = re.fullmatch(r"v0\.1\.(\d+)", "${TAG}")
print(f"0.1.{m.group(1)}" if m else "0.1.0")
PY
  )"
fi
BUILD="${SNAPKADR_BUILD:-$(date +%Y%m%d%H%M)}"
export SNAPKADR_VERSION="$VERSION" SNAPKADR_BUILD="$BUILD" SNAPKADR_VARIANT=stable SNAPKADR_TAG="$TAG"

make app

APP="$ROOT/dist/SnapKadr.app"
ZIP="$ROOT/dist/SnapKadr.zip"
test -d "$APP" || die "missing $APP"
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"
LENGTH=$(stat -f%z "$ZIP")

chmod +x "$ROOT/scripts/make_dmg.sh"
"$ROOT/scripts/make_dmg.sh" "$APP"
DMG="$ROOT/dist/SnapKadr.dmg"
test -f "$DMG" || die "missing $DMG"

SIGN_UPDATE=$(find "$ROOT/.build" -type f -name sign_update 2>/dev/null | grep -v old_dsa | head -1 || true)
test -n "$SIGN_UPDATE" || die "sign_update not found (run swift build / make app once)"

PRIV=""
for cand in "$ROOT/keys/ed25519" "$ROOT/keys/sparkle_account"; do
  [[ -f "$cand" ]] || continue
  if ! grep -q 'PENDING_SPARKLE_PRIVATE' "$cand" 2>/dev/null; then
    PRIV="$cand"
    break
  fi
done

if [[ -n "$PRIV" ]]; then
  SIG_OUT=$("$SIGN_UPDATE" "$ZIP" -f "$PRIV")
else
  SIG_OUT=$("$SIGN_UPDATE" --account "${SPARKLE_ACCOUNT:-snapkadr}" "$ZIP") \
    || die "sign_update failed; put private key in keys/ed25519 or unlock Sparkle keychain key (account=${SPARKLE_ACCOUNT:-snapkadr})"
fi

ED_SIG=$(printf '%s' "$SIG_OUT" | sed -n 's/.*edSignature="\([^"]*\)".*/\1/p')
if [[ -z "$ED_SIG" ]]; then
  ED_SIG=$(printf '%s' "$SIG_OUT" | tr -d '\n' | awk '{print $1}')
fi
test -n "$ED_SIG" || die "failed to parse edSignature from: $SIG_OUT"

chmod +x "$ROOT/scripts/publish_release.sh"
DOWNLOAD_URL=$("$ROOT/scripts/publish_release.sh" "$TAG" "$ZIP" "$DMG")
echo "==> Asset: $DOWNLOAD_URL"

ENCLOSURE_URL="https://github.com/Therealzelensky/SnapKadr/releases/download/${TAG}/SnapKadr.zip"
DMG_URL="https://github.com/Therealzelensky/SnapKadr/releases/download/${TAG}/SnapKadr.dmg"
TAG_URL="https://github.com/Therealzelensky/SnapKadr/releases/tag/${TAG}"

PUBDATE=$(date -u '+%a, %d %b %Y %H:%M:%S +0000')
cat > docs/appcast.xml <<XML
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" xmlns:dc="http://purl.org/dc/elements/1.1/">
  <channel>
    <title>Snap.Kadr</title>
    <link>https://therealzelensky.github.io/SnapKadr/</link>
    <description>Щёлк.Кадр updates</description>
    <language>ru</language>
    <item>
      <title>${VERSION}</title>
      <pubDate>${PUBDATE}</pubDate>
      <sparkle:version>${BUILD}</sparkle:version>
      <sparkle:shortVersionString>${VERSION}</sparkle:shortVersionString>
      <description><![CDATA[<p>Snap.Kadr ${TAG}</p>]]></description>
      <enclosure
        url="${ENCLOSURE_URL}"
        sparkle:edSignature="${ED_SIG}"
        length="${LENGTH}"
        type="application/octet-stream" />
    </item>
  </channel>
</rss>
XML

chmod +x "$ROOT/docs/check-landings.sh"
./docs/check-landings.sh

git add docs/appcast.xml
if git diff --cached --quiet; then
  die "nothing staged after appcast update"
fi
git commit -m "docs: ship ${TAG}"

git push origin main

if git ls-remote --tags origin "refs/tags/${TAG}" | grep -q .; then
  echo "==> Tag ${TAG} already on remote (GitHub Release); syncing locally"
  git fetch origin "refs/tags/${TAG}:refs/tags/${TAG}" 2>/dev/null || true
else
  if git rev-parse "$TAG" >/dev/null 2>&1; then
    die "tag $TAG already exists locally"
  fi
  git tag -a "$TAG" -m "$TAG"
  git push origin "$TAG"
fi

echo ""
echo "==> Done"
echo "    Release:      $TAG_URL"
echo "    Download DMG: $DMG_URL"
echo "    Sparkle ZIP:  $ENCLOSURE_URL"
echo "    Feed:         https://therealzelensky.github.io/SnapKadr/appcast.xml"
