#!/usr/bin/env bash
# Print (and optionally apply) restore of macOS /dev/bpf* after lab pcap use.
set -euo pipefail
APPLY="${1:-}"

echo "Current:"
ls -la /dev/bpf0 2>/dev/null || true
echo
echo "Restore commands:"
cat <<'EOF'
sudo chmod 600 /dev/bpf*
sudo chgrp wheel /dev/bpf*
ls -la /dev/bpf0
python3 -c 'import os; os.open("/dev/bpf0", os.O_RDWR)'  # expect PermissionError
EOF

if [[ "$APPLY" == "--apply" ]]; then
  if [[ "$(id -u)" -ne 0 ]]; then
    echo "re-run: sudo $0 --apply" >&2
    exit 1
  fi
  chmod 600 /dev/bpf*
  chgrp wheel /dev/bpf*
  ls -la /dev/bpf0
fi
