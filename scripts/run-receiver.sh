#!/usr/bin/env bash
# Run the Open Screen cast_receiver so the Pi appears in the Cast picker.
# Prerequisites: build with scripts/build-openscreen-receiver.sh, then generate credentials once.
# Usage:
#   ./run-receiver.sh [INTERFACE]
#   INTERFACE: network interface name (e.g. eth0, wlan0). Default: auto-detect or eth0.

set -e

# Paths (override with env vars)
BUILD_DIR="${CAST_RECEIVER_BUILD_DIR:-$HOME/openscreen_build}"
BIN="${CAST_RECEIVER_BIN:-$BUILD_DIR/openscreen/out/Default/cast_receiver}"
CREDS_DIR="${CAST_RECEIVER_CREDS_DIR:-$HOME/.cast_receiver}"
FRIENDLY_NAME="${CAST_RECEIVER_FRIENDLY_NAME:-RPi Speaker}"

# Network interface: first arg, or env, or default eth0
INTERFACE="${1:-${CAST_RECEIVER_INTERFACE:-eth0}}"

if [[ ! -x "$BIN" ]]; then
  echo "Cast receiver binary not found: $BIN"
  echo "Build first with: ./scripts/build-openscreen-receiver.sh"
  exit 1
fi

mkdir -p "$CREDS_DIR"
cd "$CREDS_DIR"

# Open Screen -g writes: generated_root_cast_receiver.key, generated_root_cast_receiver.crt
KEY="${CAST_RECEIVER_KEY:-$CREDS_DIR/generated_root_cast_receiver.key}"
CERT="${CAST_RECEIVER_CERT:-$CREDS_DIR/generated_root_cast_receiver.crt}"

if [[ ! -f "$KEY" || ! -f "$CERT" ]]; then
  echo "Generating TLS credentials (first run)..."
  (cd "$CREDS_DIR" && "$BIN" -g)
  KEY="$CREDS_DIR/generated_root_cast_receiver.key"
  CERT="$CREDS_DIR/generated_root_cast_receiver.crt"
  if [[ ! -f "$KEY" || ! -f "$CERT" ]]; then
    echo "Expected key: $KEY  cert: $CERT"
    echo "Generate manually: cd $CREDS_DIR && $BIN -g"
    exit 1
  fi
  echo "Credentials saved. Run this script again to start the receiver."
  exit 0
fi

# Key/cert already set above (with env override)

echo "Starting Cast receiver on interface $INTERFACE as \"$FRIENDLY_NAME\"..."
echo "Ensure phone/tablet/laptop are on the same Wi-Fi. Then open YouTube Music / Spotify and tap Cast."
exec "$BIN" -p "$KEY" -d "$CERT" -f "$FRIENDLY_NAME" "$INTERFACE"
