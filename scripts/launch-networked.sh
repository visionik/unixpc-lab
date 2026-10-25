#!/usr/bin/env bash
# Launch unixpc with Contiki + modem stub + ethernet/pcap.
set -euo pipefail
MAME_DIR="${MAME_DIR:-$HOME/Projects/mame}"
LAB_DIR="${LAB_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"
GUEST_HD="${GUEST_HD:-$MAME_DIR/roms/3b1/3b1.hd}"
LUA="${LUA:-$MAME_DIR/roms/3b1/snapview.lua}"
BIN="${BIN:-}"

if [[ -z "$BIN" ]]; then
  for c in "$MAME_DIR/unixpc" "$MAME_DIR/mame" "$MAME_DIR/mame64"; do
    [[ -x "$c" ]] && BIN=$c && break
  done
fi
if [[ -z "${BIN}" || ! -x "$BIN" ]]; then
  echo "Set BIN= to your unixpc/mame binary (looked under $MAME_DIR)" >&2
  exit 1
fi
if [[ ! -f "$GUEST_HD" ]]; then
  echo "missing guest HD: $GUEST_HD (see media/README.md)" >&2
  exit 1
fi
if [[ ! -f "$LUA" ]]; then
  echo "missing $LUA — run: ./scripts/sync-lua.sh" >&2
  exit 1
fi

if ! ifconfig feth1 >/dev/null 2>&1; then
  echo "feth1 missing — run: sudo $LAB_DIR/scripts/feth-up.sh" >&2
  exit 1
fi

cd "$MAME_DIR"
echo "launch: $BIN  (cwd=$MAME_DIR)"
exec "$BIN" 3b1 \
  -hard "$GUEST_HD" \
  -rs232 pty \
  -modem \
  -exp1 ethernet \
  -networkprovider pcap \
  -verbose \
  -autoboot_script "$LUA" \
  "$@"
