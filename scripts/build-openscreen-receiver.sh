#!/usr/bin/env bash
# Build Open Screen cast_receiver on Raspberry Pi OS (or any Debian-based Linux).
# Run this on the Raspberry Pi (or cross-compile elsewhere and copy the binary).
# See RESEARCH.md and README.md for context.

set -e

BUILD_DIR="${CAST_RECEIVER_BUILD_DIR:-$HOME/openscreen_build}"
DEPOT_TOOLS_DIR="${DEPOT_TOOLS_DIR:-$HOME/depot_tools}"
OPENSCREEN_DIR="$BUILD_DIR/openscreen"

echo "Build directory: $BUILD_DIR"
echo "depot_tools:     $DEPOT_TOOLS_DIR"

# --- 1. Install depot_tools if missing ---
if [[ ! -d "$DEPOT_TOOLS_DIR" ]]; then
  echo "Cloning depot_tools..."
  git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git "$DEPOT_TOOLS_DIR"
fi
export PATH="$DEPOT_TOOLS_DIR:$PATH"

# --- 2. Checkout Open Screen ---
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"
if [[ ! -d openscreen ]]; then
  echo "Fetching Open Screen (this may take a while)..."
  fetch openscreen
fi
cd "$OPENSCREEN_DIR"

# --- 3. Install system dependencies (Debian / Raspberry Pi OS) ---
echo "Installing build dependencies..."
sudo apt-get update
sudo apt-get install -y \
  git python3 curl \
  libsdl2-dev libavcodec-dev libavformat-dev libavutil-dev libswresample-dev \
  libopus-dev libvpx-dev pkg-config

# Optional: if your distro uses different package names, you may need:
#   libavcodec-dev libavformat-dev libavutil-dev libswresample-dev
# On older Raspberry Pi OS you might need: libavcodec58-dev, etc.

# --- 4. GN args for cast_receiver with audio/video playback ---
# use_sysroot=false so we use system libs; required on many Linux distros.
OUT_DIR="out/Default"
gn gen "$OUT_DIR" --args='is_debug=false use_sysroot=false have_ffmpeg=true have_libsdl2=true have_libopus=true have_libvpx=true'

# --- 5. Build ---
echo "Building cast_receiver (this can take 15–30+ minutes on a Pi 4)..."
ninja -C "$OUT_DIR" cast_receiver

echo "Done. Binary: $OPENSCREEN_DIR/$OUT_DIR/cast_receiver"
echo "Generate credentials and run with: scripts/run-receiver.sh"
