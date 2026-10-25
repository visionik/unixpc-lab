# unixpc-lab

Lab companion for the AT&T 3B1 / UNIX PC work in
[visionik/mame](https://github.com/visionik/mame) (`att-3b1` branch).

This repo holds **recipes, host scripts, and Lua smokes**. It does **not**
hold guest hard disks, floppies, or WIN/3B packages (copyrighted). Put those
under your local MAME `roms/3b1/` tree; see [`media/README.md`](media/README.md).

## Layout

| Path | Role |
|------|------|
| `docs/` | Host networking, telnet, BPF, crash notes |
| `scripts/` | feth up/down, launch, telnet stress, BPF restore |
| `lua/` | `snapview.lua`, savestate smokes (copy into `roms/3b1/`) |
| `cfg/` | Example MAME cfg fragment for LANCE on `feth1` |
| `media/` | Expected filenames + SHA-256 (no binaries) |
| `ci/` | Optional smoke checklist |

## Prerequisites

- Build of `visionik/mame` @ `att-3b1` (binary often named `unixpc`)
- Guest media laid out as in `media/README.md`
- macOS: `feth` peer for same-host networking (Wi‑Fi unicast to a foreign MAC is unreliable)

## Quick start (networked Contiki)

```bash
# 1) peer interfaces (once per boot; needs root)
sudo ./scripts/feth-up.sh

# 2) launch from your MAME build tree
export MAME_DIR=~/Projects/mame          # adjust
export LAB_DIR=~/Projects/unixpc-lab
./scripts/launch-networked.sh

# 3) after Contiki + ether autoload (~2–3 min)
ping 192.168.9.50
/usr/bin/nc 192.168.9.50 23              # root / empty password / term s4
```

Default addressing:

| Role | Address |
|------|---------|
| Host `feth0` | `192.168.9.1/24` |
| Guest | `192.168.9.50` (`mame3b1`) |
| Guest MAC | `02:00:00:3b:00:01` |
| pcap bind | `feth1` |

Prefer `/usr/bin/nc` or `/usr/bin/python3`. Homebrew binaries often hit macOS
Local Network privacy (`EHOSTUNREACH`).

Driver theory and board map: `src/mame/att/unixpc_hw.md` in the MAME fork.
Branch changelog: `changelog.md` there.
