#!/usr/bin/env bash
# Upload SnapKadrBeta.zip to a GitHub prerelease tag.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TAG="${1:?usage: publish_beta_release.sh <tag> <zip>}"
ZIP="${2:?usage: publish_beta_release.sh <tag> <zip>}"
REPO="Therealzelensky/SnapKadr"
test -f "$ZIP"

if [[ -n "${GH_TOKEN:-}" ]]; then
  TOKEN="$GH_TOKEN"
elif command -v gh >/dev/null && gh auth token >/dev/null 2>&1; then
  TOKEN="$(gh auth token)"
else
  TOKEN=$(printf 'protocol=https\nhost=github.com\n\n' | git credential fill 2>/dev/null | awk -F= '/^password=/{print $2}')
fi
test -n "${TOKEN:-}"

API="https://api.github.com/repos/$REPO"
AUTH=(-H "Authorization: token $TOKEN" -H "Accept: application/vnd.github+json")

HTTP=$(curl -sS -o /tmp/sk-rel.json -w '%{http_code}' "${AUTH[@]}" "$API/releases/tags/$TAG" || true)
if [[ "$HTTP" == "404" ]]; then
  curl -sS "${AUTH[@]}" -X POST "$API/releases" \
    -d "{\"tag_name\":\"$TAG\",\"name\":\"$TAG\",\"prerelease\":true,\"body\":\"Snap.Kadr Beta $TAG\"}" \
    > /tmp/sk-rel.json
elif [[ "$HTTP" != "200" ]]; then
  echo "Failed to fetch release $TAG (HTTP $HTTP)" >&2
  exit 1
fi

export TOKEN REPO
python3 - <<'PY'
import json, os, subprocess, sys
rel = json.load(open("/tmp/sk-rel.json"))
token = os.environ["TOKEN"]
repo = os.environ["REPO"]
for a in rel.get("assets") or []:
    if a.get("name") == "SnapKadrBeta.zip":
        subprocess.check_call([
            "curl", "-sS", "-X", "DELETE",
            "-H", f"Authorization: token {token}",
            "-H", "Accept: application/vnd.github+json",
            f"https://api.github.com/repos/{repo}/releases/assets/{a['id']}",
        ])
upload = (rel.get("upload_url") or "").split("{")[0]
if not upload:
    sys.exit("missing upload_url on release JSON")
open("/tmp/sk-upload-base.txt", "w").write(upload)
PY

UPLOAD=$(cat /tmp/sk-upload-base.txt)
curl -sS "${AUTH[@]}" -H "Content-Type: application/zip" \
  --data-binary @"$ZIP" \
  "$UPLOAD?name=SnapKadrBeta.zip" > /tmp/sk-asset.json

python3 -c 'import json; d=json.load(open("/tmp/sk-asset.json")); u=d.get("browser_download_url"); assert u, d; print(u)'
