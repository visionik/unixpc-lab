#!/usr/bin/env bash
# Copy lab Lua smokes into the MAME roms/3b1 tree.
set -euo pipefail
MAME_DIR="${MAME_DIR:-$HOME/Projects/mame}"
LAB_DIR="${LAB_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"
DEST="$MAME_DIR/roms/3b1"
mkdir -p "$DEST"
cp -v "$LAB_DIR"/lua/*.lua "$DEST/"
echo "synced → $DEST"
