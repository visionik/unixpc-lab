#!/usr/bin/env bash
# Banner reconnect stress against guest telnetd. Uses /usr/bin/nc only.
set -euo pipefail
GUEST="${GUEST:-192.168.9.50}"
N="${N:-20}"
ok=0
fail=0
for i in $(seq 1 "$N"); do
  outf=$(mktemp)
  printf '\r\n' | /usr/bin/nc -w 3 "$GUEST" 23 >"$outf" 2>/dev/null || true
  if grep -a -q 'mame3b1\|UNIX System V\|login:' "$outf"; then
    ok=$((ok + 1))
    echo "  $i OK"
  else
    fail=$((fail + 1))
    echo "  $i FAIL ($(wc -c <"$outf") bytes)"
  fi
  rm -f "$outf"
  sleep 0.3
done
echo "telnet stress: ok=$ok fail=$fail (guest=$GUEST n=$N)"
[[ "$fail" -eq 0 ]]
