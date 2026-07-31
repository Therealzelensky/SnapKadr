#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export SNAPKADR_VARIANT=beta
exec "$ROOT/scripts/build_app.sh"
