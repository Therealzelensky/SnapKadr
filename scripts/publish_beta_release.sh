#!/usr/bin/env bash
# Publish SnapKadrBeta.zip to GitHub Releases (download_count) + refresh Pages appcast.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TAG="${1:-v0.1.0-beta.2}"
ZIP="${2:-/tmp/SnapKadrBeta.zip}"
TOKEN=$(printf 'protocol=https\nhost=github.com\n\n' | git credential fill 2>/dev/null | awk -F= '/^password=/{print $2}')
test -n "$TOKEN"
test -f "$ZIP"

# Create release if missing
HTTP=$(curl -sS -o /tmp/rel.json -w '%{http_code}' \
  -H "Authorization: token $TOKEN" -H "Accept: application/vnd.github+json" \
  "https://api.github.com/repos/Therealzelensky/SnapKadr/releases/tags/$TAG" || true)
if [[ "$HTTP" == "404" ]]; then
  curl -sS -H "Authorization: token $TOKEN" -H "Accept: application/vnd.github+json" \
    https://api.github.com/repos/Therealzelensky/SnapKadr/releases \
    -d "{\"tag_name\":\"$TAG\",\"name\":\"$TAG\",\"prerelease\":true,\"body\":\"Snap.Kadr Beta\"}" > /tmp/rel.json
fi
UPLOAD=$(python3 -c 'import json; print(json.load(open("/tmp/rel.json")).get("upload_url","").split("{")[0])')
test -n "$UPLOAD"
curl -sS -H "Authorization: token $TOKEN" -H "Content-Type: application/zip" \
  --data-binary @"$ZIP" \
  "$UPLOAD?name=SnapKadrBeta.zip&label=SnapKadrBeta.zip" | python3 -c 'import sys,json; d=json.load(sys.stdin); print(d.get("browser_download_url"), d.get("download_count"))'
echo "Published $TAG"
