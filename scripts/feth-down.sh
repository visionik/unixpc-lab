#!/usr/bin/env bash
# Destroy feth0/feth1. Requires root.
set -euo pipefail
if [[ "$(id -u)" -ne 0 ]]; then
  echo "re-run with sudo: sudo $0" >&2
  exit 1
fi
ifconfig feth0 destroy 2>/dev/null || true
ifconfig feth1 destroy 2>/dev/null || true
echo "feth0/feth1 destroyed"
