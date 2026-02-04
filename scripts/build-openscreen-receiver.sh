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
  git python3 curl ninja-build build-essential \
  libsdl2-dev libavcodec-dev libavformat-dev libavutil-dev libswresample-dev \
  libopus-dev libvpx-dev pkg-config

# Optional: if your distro uses different package names, you may need:
#   libavcodec-dev libavformat-dev libavutil-dev libswresample-dev
# On older Raspberry Pi OS you might need: libavcodec58-dev, etc.

# --- 4. On ARM (Raspberry Pi): build native gn; fetch provides x86_64 only ---
ARCH=$(uname -m)
GN_BINARY="$OPENSCREEN_DIR/buildtools/linux64/gn"
NINJA_CMD="ninja"
if [[ "$ARCH" == arm* || "$ARCH" == aarch* ]]; then
  NINJA_CMD="/usr/bin/ninja"
  # Build native gn if: gn missing/not runnable, or existing gn is x86_64 (e.g. runs via QEMU, slowly)
  NEED_BUILD_GN=false
  if [[ ! -x "$GN_BINARY" ]] || ! "$GN_BINARY" --version &>/dev/null; then
    NEED_BUILD_GN=true
  elif command -v file &>/dev/null; then
    if GN_DESC=$(file "$GN_BINARY" 2>/dev/null) && echo "$GN_DESC" | grep -qiE 'x86-64|x86_64'; then
      NEED_BUILD_GN=true
    fi
  fi
  if [[ "$NEED_BUILD_GN" == true ]]; then
    echo "Building gn for $ARCH (Open Screen only ships x86_64 buildtools)..."
    GN_SRC="$BUILD_DIR/gn_src"
    # Re-clone if existing dir is not a valid git repo (e.g. interrupted clone)
    if [[ -d "$GN_SRC" ]] && ! git -C "$GN_SRC" rev-parse HEAD &>/dev/null; then
      rm -rf "$GN_SRC"
    fi
    if [[ ! -d "$GN_SRC" ]]; then
      # Full clone: gen.py runs 'git describe HEAD --match initial-commit'; shallow clone has no tags and fails
      git clone https://gn.googlesource.com/gn "$GN_SRC"
    fi
    # Ensure history and tags are available for git describe (shallow clones can break this).
    if ! git -C "$GN_SRC" describe HEAD --abbrev=12 --match initial-commit &>/dev/null; then
      echo "git describe failed; fetching full history/tags for gn_src..."
      # --unshallow on a non-shallow repo is a no-op; fallback to deep fetch if unsupported.
      git -C "$GN_SRC" fetch --unshallow --tags --prune || \
        git -C "$GN_SRC" fetch --depth=100000 --tags --prune || \
        echo "Warning: Failed to fetch full history/tags for gn. The build may fail." >&2
      if ! git -C "$GN_SRC" describe HEAD --abbrev=12 --match initial-commit &>/dev/null; then
        echo "Error: git describe still failing. Remove '$GN_SRC' and rerun the build." >&2
        exit 1
      fi
    fi
    cd "$GN_SRC"
    # Use system gcc/g++ if clang++ is not installed (default in gn build).
    export CC="${CC:-gcc}"
    export CXX="${CXX:-g++}"
    export AR="${AR:-ar}"
    python3 build/gen.py
    $NINJA_CMD -C out
    mkdir -p "$(dirname "$GN_BINARY")"
    cp -f out/gn "$GN_BINARY"
    if ! "$GN_BINARY" --version &>/dev/null; then
      echo "Failed to build working gn binary"
      exit 1
    fi
    cd "$OPENSCREEN_DIR"
    echo "gn built and installed for ARM."
  fi
fi

# --- 5. GN args for cast_receiver with audio/video playback ---
# use_sysroot=false so we use system libs; required on many Linux distros.
OUT_DIR="out/Default"
"$GN_BINARY" gen "$OUT_DIR" --args='is_debug=false use_sysroot=false have_ffmpeg=true have_libsdl2=true have_libopus=true have_libvpx=true'

# --- 6. Build ---
echo "Building cast_receiver (this can take 15–30+ minutes on a Pi 4)..."
"$NINJA_CMD" -C "$OUT_DIR" cast_receiver

echo "Done. Binary: $OPENSCREEN_DIR/$OUT_DIR/cast_receiver"
echo "Generate credentials and run with: scripts/run-receiver.sh"
