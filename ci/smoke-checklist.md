# Manual smoke checklist

Run against a local `att-3b1` build + media from `media/CHECKSUMS.sha256`.

- [ ] `sudo ./scripts/feth-up.sh` — `feth0`/`feth1` up
- [ ] `./scripts/sync-lua.sh`
- [ ] `./scripts/launch-networked.sh` — Contiki Login
- [ ] Ether autoload — `ping 192.168.9.50` 0% loss
- [ ] `/usr/bin/nc 192.168.9.50 23` — banner; login root / empty / `s4`
- [ ] `./scripts/telnet-stress.sh` — 20/20 OK
- [ ] Diag Disk (optional): floppy Format/WriteSector with `*.work` IMD
- [ ] Save/load smoke Lua (optional)
- [ ] When finished: `sudo ./scripts/bpf-restore.sh --apply` if BPF was loosened
