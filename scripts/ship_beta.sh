#!/usr/bin/env bash
# Merge (confirm) → bump beta tag → build → GitHub Release → landing + appcast → push.
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

# --- dirty check (tracked only)
if [[ -n "$(git status --porcelain --untracked-files=no)" ]]; then
  die "tracked working tree dirty; commit or stash first"
fi

BRANCH="$(git rev-parse --abbrev-ref HEAD)"
if [[ "$BRANCH" == "HEAD" ]]; then
  die "detached HEAD; checkout a branch first"
fi

if [[ "$BRANCH" != "main" ]]; then
  if [[ "${SHIP_BETA_MERGE:-}" == "1" ]]; then
    ANSWER=y
  elif [[ -t 0 ]]; then
    read -r -p "Merge '$BRANCH' → main? [y/N] " ANSWER
  else
    die "not on main and no TTY; re-run with SHIP_BETA_MERGE=1 or checkout main"
  fi
  [[ "$ANSWER" == "y" || "$ANSWER" == "Y" ]] || die "aborted (merge declined)"
  git fetch origin
  git checkout main
  git pull --ff-only origin main
  git merge --no-ff "$BRANCH" -m "merge: $BRANCH → main для beta ship"
  git push origin main
fi

git checkout main
git pull --ff-only origin main

# --- next tag
if [[ -n "${SHIP_BETA_TAG:-}" ]]; then
  TAG="$SHIP_BETA_TAG"
else
  git fetch --tags origin 2>/dev/null || true
  LAST=$(git tag -l 'v0.1.0-beta.*' --sort=-v:refname | head -1 || true)
  if [[ -z "$LAST" ]]; then
    TAG="v0.1.0-beta.1"
  else
    N="${LAST##*.}"
    TAG="v0.1.0-beta.$((N + 1))"
  fi
fi
echo "==> Shipping $TAG"

VERSION="${SNAPKADR_VERSION:-0.1.0}"
BUILD="${SNAPKADR_BUILD:-$(date +%Y%m%d%H%M)}"
export SNAPKADR_VERSION="$VERSION" SNAPKADR_BUILD="$BUILD" SNAPKADR_VARIANT=beta

make app-beta

APP="$ROOT/dist/SnapKadrBeta.app"
ZIP="$ROOT/dist/SnapKadrBeta.zip"
test -d "$APP" || die "missing $APP"
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"
LENGTH=$(stat -f%z "$ZIP")

chmod +x "$ROOT/scripts/make_dmg.sh"
"$ROOT/scripts/make_dmg.sh" "$APP"
DMG="$ROOT/dist/SnapKadrBeta.dmg"
test -f "$DMG" || die "missing $DMG"

# --- sign zip for Sparkle
SIGN_UPDATE=$(find "$ROOT/.build" -type f -name sign_update 2>/dev/null | grep -v old_dsa | head -1 || true)
test -n "$SIGN_UPDATE" || die "sign_update not found (run swift build / make app-beta once)"

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
  # Sparkle may use the keychain account created by generate_keys.
  # Keychain account from generate_keys (default Sparkle name is "ed25519").
  SIG_OUT=$("$SIGN_UPDATE" --account "${SPARKLE_ACCOUNT:-snapkadr}" "$ZIP") \
    || die "sign_update failed; put private key in keys/ed25519 or unlock Sparkle keychain key (account=${SPARKLE_ACCOUNT:-snapkadr})"
fi

ED_SIG=$(printf '%s' "$SIG_OUT" | sed -n 's/.*edSignature="\([^"]*\)".*/\1/p')
if [[ -z "$ED_SIG" ]]; then
  # Some Sparkle builds print only the signature string
  ED_SIG=$(printf '%s' "$SIG_OUT" | tr -d '\n' | awk '{print $1}')
fi
test -n "$ED_SIG" || die "failed to parse edSignature from: $SIG_OUT"

# --- publish release
chmod +x "$ROOT/scripts/publish_beta_release.sh"
DOWNLOAD_URL=$("$ROOT/scripts/publish_beta_release.sh" "$TAG" "$ZIP" "$DMG")
echo "==> Asset: $DOWNLOAD_URL"

ENCLOSURE_URL="https://github.com/Therealzelensky/SnapKadr/releases/download/${TAG}/SnapKadrBeta.zip"
DMG_URL="https://github.com/Therealzelensky/SnapKadr/releases/download/${TAG}/SnapKadrBeta.dmg"
TAG_URL="https://github.com/Therealzelensky/SnapKadr/releases/tag/${TAG}"

# --- update landing CTAs (direct dmg, not release HTML page / zip)
python3 - <<PY
from pathlib import Path
import re
p = Path("docs/index.html")
text = p.read_text()
text2, n = re.subn(
    r"https://github.com/Therealzelensky/SnapKadr/releases/download/v0\.1\.0-beta\.\d+/SnapKadrBeta\.(?:zip|dmg)",
    "${DMG_URL}",
    text,
)
if n == 0:
    raise SystemExit("no beta CTA URLs replaced in docs/index.html")
text2, n2 = re.subn(
    r'download="SnapKadrBeta\.(?:zip|dmg)"',
    'download="SnapKadrBeta.dmg"',
    text2,
)
p.write_text(text2)
print(f"updated {n} CTA link(s) → ${DMG_URL}; download attrs={n2}")
PY

# --- appcast
PUBDATE=$(date -u '+%a, %d %b %Y %H:%M:%S +0000')
cat > docs/appcast-beta.xml <<XML
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" xmlns:dc="http://purl.org/dc/elements/1.1/">
  <channel>
    <title>Snap.Kadr Beta</title>
    <link>https://therealzelensky.github.io/SnapKadr/</link>
    <description>Щёлк.Кадр бета updates</description>
    <language>ru</language>
    <item>
      <title>${VERSION}</title>
      <pubDate>${PUBDATE}</pubDate>
      <sparkle:version>${BUILD}</sparkle:version>
      <sparkle:shortVersionString>${VERSION}</sparkle:shortVersionString>
      <description><![CDATA[<p>Snap.Kadr Beta ${TAG}</p>]]></description>
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

git add docs/index.html docs/appcast-beta.xml docs/check-landings.sh
# Include CHANNELS.md / scripts if already staged by developer; ship always commits docs delta:
if git diff --cached --quiet; then
  die "nothing staged after docs update"
fi
git commit -m "docs: ship ${TAG}"

if git rev-parse "$TAG" >/dev/null 2>&1; then
  die "tag $TAG already exists locally"
fi
git tag -a "$TAG" -m "$TAG"
git push origin main
git push origin "$TAG"

echo ""
echo "==> Done"
echo "    Release:      $TAG_URL"
echo "    Download DMG: $DMG_URL"
echo "    Sparkle ZIP:  $ENCLOSURE_URL"
echo "    Landing:      https://therealzelensky.github.io/SnapKadr/"
