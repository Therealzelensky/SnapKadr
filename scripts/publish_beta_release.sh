#!/usr/bin/env bash
# Upload SnapKadrBeta.zip and SnapKadrBeta.dmg to a GitHub prerelease tag.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TAG="${1:?usage: publish_beta_release.sh <tag> <zip> <dmg>}"
ZIP="${2:?usage: publish_beta_release.sh <tag> <zip> <dmg>}"
DMG="${3:?usage: publish_beta_release.sh <tag> <zip> <dmg>}"
REPO="Therealzelensky/SnapKadr"
test -f "$ZIP"
test -f "$DMG"

if [[ -n "${GH_TOKEN:-}" ]]; then
  TOKEN="$GH_TOKEN"
elif command -v gh >/dev/null && gh auth token >/dev/null 2>&1; then
  TOKEN="$(gh auth token)"
else
  TOKEN=$(printf 'protocol=https\nhost=github.com\n\n' | git credential fill 2>/dev/null | awk -F= '/^password=/{print $2}')
fi
test -n "${TOKEN:-}"

WORKDIR="$(mktemp -d "${TMPDIR:-/tmp}/sk-publish.XXXXXX")"
cleanup() { rm -rf "$WORKDIR"; }
trap cleanup EXIT
umask 077

# Keep token out of process argv / ps: curl --config reads Authorization from a 0600 file.
CURL_CFG="$WORKDIR/curl.cfg"
{
  printf 'header = "Authorization: Bearer %s"\n' "$TOKEN"
  printf 'header = "Accept: application/vnd.github+json"\n'
  printf 'silent\n'
  printf 'show-error\n'
} >"$CURL_CFG"
unset TOKEN

API="https://api.github.com/repos/$REPO"
REL_JSON="$WORKDIR/rel.json"
ASSET_JSON="$WORKDIR/asset.json"
UPLOAD_BASE="$WORKDIR/upload-base.txt"

HTTP=$(curl -K "$CURL_CFG" -o "$REL_JSON" -w '%{http_code}' "$API/releases/tags/$TAG" || true)
if [[ "$HTTP" == "404" ]]; then
  curl -K "$CURL_CFG" -X POST "$API/releases" \
    -H "Content-Type: application/json" \
    -d "{\"tag_name\":\"$TAG\",\"name\":\"$TAG\",\"prerelease\":true,\"body\":\"Snap.Kadr Beta $TAG\"}" \
    -o "$REL_JSON"
elif [[ "$HTTP" != "200" ]]; then
  echo "Failed to fetch release $TAG (HTTP $HTTP)" >&2
  exit 1
fi

export REL_JSON REPO CURL_CFG UPLOAD_BASE
python3 - <<'PY'
import json, os, subprocess, sys
rel = json.load(open(os.environ["REL_JSON"]))
repo = os.environ["REPO"]
cfg = os.environ["CURL_CFG"]
for a in rel.get("assets") or []:
    if a.get("name") in ("SnapKadrBeta.zip", "SnapKadrBeta.dmg"):
        subprocess.check_call([
            "curl", "-K", cfg, "-X", "DELETE",
            f"https://api.github.com/repos/{repo}/releases/assets/{a['id']}",
        ])
upload = (rel.get("upload_url") or "").split("{")[0]
if not upload:
    sys.exit("missing upload_url on release JSON")
open(os.environ["UPLOAD_BASE"], "w").write(upload)
PY

UPLOAD=$(cat "$UPLOAD_BASE")
curl -K "$CURL_CFG" -H "Content-Type: application/zip" \
  --data-binary @"$ZIP" \
  -o "$ASSET_JSON" \
  "$UPLOAD?name=SnapKadrBeta.zip"

curl -K "$CURL_CFG" -H "Content-Type: application/octet-stream" \
  --data-binary @"$DMG" \
  -o "$WORKDIR/dmg-asset.json" \
  "$UPLOAD?name=SnapKadrBeta.dmg"

python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); assert d.get("browser_download_url"), d' \
  "$WORKDIR/dmg-asset.json"

# Keep printing zip URL on stdout for ship_beta.sh compatibility
ASSET_JSON="$ASSET_JSON" python3 -c 'import json,os; d=json.load(open(os.environ["ASSET_JSON"])); u=d.get("browser_download_url"); assert u, d; print(u)'
