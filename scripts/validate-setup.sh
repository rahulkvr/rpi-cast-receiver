#!/usr/bin/env bash
# Validate basic Cast receiver setup on Raspberry Pi.
# This does not guarantee YouTube/Spotify compatibility, but checks local plumbing.

set -e

BUILD_DIR="${CAST_RECEIVER_BUILD_DIR:-$HOME/openscreen_build}"
BIN="${CAST_RECEIVER_BIN:-$BUILD_DIR/openscreen/out/Default/cast_receiver}"
CREDS_DIR="${CAST_RECEIVER_CREDS_DIR:-$HOME/.cast_receiver}"
INTERFACE="${1:-${CAST_RECEIVER_INTERFACE:-eth0}}"

echo "Checking interface: $INTERFACE"
if ! ip link show "$INTERFACE" &>/dev/null; then
  echo "ERROR: interface '$INTERFACE' not found."
  ip -o link show | awk -F': ' '{print "  - " $2}'
  exit 1
fi

echo "Checking receiver binary: $BIN"
if [[ ! -x "$BIN" ]]; then
  echo "ERROR: cast_receiver binary not found or not executable."
  exit 1
fi

echo "Checking TLS credentials in: $CREDS_DIR"
if [[ ! -f "$CREDS_DIR/generated_root_cast_receiver.key" || ! -f "$CREDS_DIR/generated_root_cast_receiver.crt" ]]; then
  echo "WARN: credentials not found. Run ./scripts/run-receiver.sh once to generate."
fi

echo "Checking local audio test (aplay)..."
if command -v aplay &>/dev/null; then
  aplay -q /usr/share/sounds/alsa/Front_Center.wav && echo "Audio OK." || echo "WARN: audio test failed."
else
  echo "WARN: aplay not found."
fi

echo "Checking Cast mDNS advertisement (if receiver is running)..."
if command -v avahi-browse &>/dev/null; then
  avahi-browse -rt _googlecast._tcp 2>/dev/null | head -n 5 || true
else
  echo "WARN: avahi-browse not found (install avahi-utils if needed)."
fi

echo "Checking listener on Cast port (8010) if receiver is running..."
if command -v ss &>/dev/null; then
  ss -ltnp | grep -E ':8010\\b' || echo "WARN: nothing listening on 8010."
else
  echo "WARN: ss not found."
fi

echo "Done."
