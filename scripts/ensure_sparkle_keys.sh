#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export ROOT
mkdir -p "$ROOT/keys"
PUB="$ROOT/keys/ed25519.pub"

if [[ -f "$PUB" && -s "$PUB" ]]; then
  echo "==> Sparkle public key present"
  exit 0
fi

cd "$ROOT"
echo "==> Resolving packages (Sparkle)..."
swift package resolve

GEN="$(find "$ROOT/.build" -type f -name generate_keys 2>/dev/null | head -1 || true)"
if [[ -z "$GEN" ]]; then
  echo "==> Building once to fetch Sparkle tools..."
  swift build -c release --product SnapKadr || true
  GEN="$(find "$ROOT/.build" -type f -name generate_keys 2>/dev/null | head -1 || true)"
fi

if [[ -n "$GEN" && -x "$GEN" ]]; then
  echo "==> Running generate_keys"
  # Sparkle 2: generate_keys writes to ~/Library or -p path depending on version.
  OUT="$("$GEN" -p "$ROOT/keys/sparkle_account" 2>&1 || true)"
  echo "$OUT"
  # Parse public key line if printed
  echo "$OUT" | awk '/Public key:/{print $3}' | head -1 > "$PUB.tmp" || true
  if [[ -s "$PUB.tmp" ]]; then
    mv "$PUB.tmp" "$PUB"
  fi
fi

if [[ ! -s "$PUB" ]]; then
  echo "error: no Sparkle public key at $PUB" >&2
  echo "  Run Sparkle generate_keys (or place ed25519.pub under keys/) before building." >&2
  echo "  Refusing to embed a placeholder key — updates would be unverifiable or forgeable." >&2
  exit 1
fi

echo "==> Public key: $(cat "$PUB")"
