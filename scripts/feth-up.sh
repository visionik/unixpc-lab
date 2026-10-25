#!/usr/bin/env bash
# Create feth0/feth1 peer for MAME pcap. Requires root.
set -euo pipefail
HOST_IP="${HOST_IP:-192.168.9.1}"
MASK="${MASK:-255.255.255.0}"

if [[ "$(id -u)" -ne 0 ]]; then
  echo "re-run with sudo: sudo $0" >&2
  exit 1
fi

ifconfig feth0 >/dev/null 2>&1 || ifconfig feth0 create
ifconfig feth1 >/dev/null 2>&1 || ifconfig feth1 create
ifconfig feth0 peer feth1
ifconfig feth1 peer feth0
ifconfig feth0 inet "$HOST_IP" netmask "$MASK" up
ifconfig feth1 up
echo "feth peer ready: feth0=$HOST_IP  feth1=up (bind MAME pcap here)"
ifconfig feth0 feth1
