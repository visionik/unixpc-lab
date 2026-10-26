# unixpc-lab

Lab companion for AT&T **UNIX PC / 3B1** work in
[visionik/mame](https://github.com/visionik/mame) (default branch / `att-3b1`).

This repo holds **recipes, host scripts, Lua smokes, and docs**. It does
**not** ship guest hard disks, floppies, ROMs, or WIN/3B packages
(copyrighted). Put those under your local MAME `roms/3b1/` tree and check
them against [`media/CHECKSUMS.sha256`](media/CHECKSUMS.sha256).

| Related | Link |
|---------|------|
| MAME fork (driver) | https://github.com/visionik/mame |
| Driver hardware notes | `src/mame/att/unixpc_hw.md` in the fork |
| Branch changelog | `changelog.md` in the fork |
| This lab (private) | https://github.com/visionik/unixpc-lab |

---

## Contents

1. [What works / what does not](#what-works--what-does-not)
2. [Where to get ROMs, disks, and docs](#where-to-get-roms-disks-and-docs)
3. [Local media layout](#local-media-layout)
4. [Lab repo layout](#lab-repo-layout)
5. [Command-line parameters](#command-line-parameters)
6. [Complete command-line examples](#complete-command-line-examples)
7. [Networked Contiki quick start](#networked-contiki-quick-start)
8. [Telnet / FTP from the host](#telnet--ftp-from-the-host)
9. [OSD shortcuts and save states](#osd-shortcuts-and-save-states)
10. [Known host pitfalls](#known-host-pitfalls)

---

## What works / what does not

Driver still declares `MACHINE_NOT_WORKING` (expansion / phone / tape open),
but the interactive UNIX path is usable.

### Implemented (usable today)

| Area | Status |
|------|--------|
| Boot UNIX System V 3.51 | Yes — to root / Contiki login |
| 68010 + custom 4K MMU | Format-8 BERR, `RR=1` software re-run on RTE |
| Winchester HDC | Label geometry, interleaved DMA, raw CHS forced, writes clamped |
| Floppy (WD2797) | Format / WriteSector / surface; Diag Disk menu 2 PASS |
| Keyboard + mouse | Stable make/break; mouse `0xCE` packets; coalesced DMA |
| Video | 720×348, phosphor white/green/amber, window scales 1.5×–3× |
| TC8250 RTC | Real device; Diag Disk menu 11 PASS |
| Parallel printer | Centronics + `LPINT`; Diag Disk menu 10 PASS |
| RAM parity diag | Sparse BPPLUS model with **`-parity`**; menu 5 PASS |
| Built-in serial (UPD7201) | Interactive: **`-rs232 pty`** (or null_modem) |
| On-board modem stub | **`-modem`**: Contiki can open `/dev/ph0` (presence only) |
| Dual EIA expansion | Slot identity + Z8530; diag loopback |
| WIN/3B ethernet | AM7990 LANCE, status-ring, MMU DMA; peer ping/telnet/ftp on Darwin **feth+pcap** |
| Save states | `MACHINE_SUPPORTS_SAVE`; F6/F7 and Lua smokes |

### Diagnostic Disk Ver 3.51 (summary)

| Menu | Result | Notes |
|------|--------|-------|
| 1 Hard Disk | Partial | Non-destructive OK; **do not** answer Yes to Destructive Surface unless asked |
| 2 Floppy | **PASS** | Use a `*.work` IMD copy, not the Bitsavers pristine |
| 3 Keyboard | Exercised | |
| 4 Video | Exercised | |
| 5 Memory & Parity | **PASS** with `-parity` | |
| 6 Communications | **PASS** with loopback | **Diag only** — never loopback under interactive UNIX |
| 7–8 Modem / Dialer | Partial | Beep/dialer; no phone line |
| 9 Processor | **PASS** with `-hard` | |
| 10 Parallel Printer | **PASS** | Needs `-printer printer -prin …` |
| 11 Real Time Clock | **PASS** | |
| 12–14 Expansion / Phone / Tape | Open | |

### Not wired / incomplete

- Real **882A / phone line** / Diagnostic Modem (stub only)
- EIA/RAM combo **RAM size**; StarLAN; DOS-73
- FloppyTape; QIC-02; expansion chassis; Voice Power; PBX
- Third/fourth hard disks; RAM-only slot card
- Full DRAM / DMA parity generation
- Reliable same-host unicast on **Wi‑Fi `en0`** without feth/wired
- CoreAudio hotplug: rapid Speakers ↔ AirPods can SIGSEGV in
  `sound_manager::update_osd_streams` (host OSD bug, not the 3B1 driver)

---

## Where to get ROMs, disks, and docs

Nothing copyrighted is in this git repo. Obtain media yourself and keep it
under `$MAME_DIR/roms/3b1/`.

### Firmware (required)

| File (MAME name) | Source |
|------------------|--------|
| `72-00616.14c` | Bitsavers / FreeBee ROM set (board loc 14C) |
| `72-00617.15c` | Bitsavers / FreeBee ROM set (board loc 15C) |

FreeBee ROM notes: https://www.philpem.me.uk/code/3b1emu  
(ROMs are often distributed alongside FreeBee setup docs; rename to the
MAME names above.)

### Floppy / Foundation software

| What | Where |
|------|--------|
| System Software 3.51 IMDs (Diagnostic, Floppy Boot, Foundation Set, …) | http://www.bitsavers.org/bits/ATT/unixPC/ |
| PDFs (Owner’s, Service, Installation, …) | http://www.bitsavers.org/pdf/att/3b1/ |

Keep Bitsavers originals write-protected or as `*.bitsavers_pristine`.
Use `*.work` copies for Diagnostic Disk write/format tests (MAME IMD
rewrite has corrupted pristine disk 01 in the past).

### Hard disk images

This lab’s golden guest is a **local** raw image `roms/3b1/3b1.hd`
(~186 MB / 1400×16×17×512) with UNIX 3.51 + Contiki + WIN/3B already
installed (`mame3b1` / `192.168.9.50`). It is **not** redistributed here;
see `media/CHECKSUMS.sha256` for the hash of the current golden file.

Public / community HD starting points (for FreeBee or fresh installs):

| Resource | Notes |
|----------|--------|
| [FreeBee](https://github.com/philpem/freebee) | Emulator + build-your-own HD (`makehdimg`); points at community images |
| Arnold Robbins / VCF / Gesswein images | Linked from FreeBee “existing drive image” docs |
| Fresh install from Bitsavers Foundation IMDs | Install inside MAME or FreeBee, then copy the raw HD into `roms/3b1/3b1.hd` |

Host filesystem tools for SysV images (inspect/mount outside the guest):

- https://github.com/dad4x/s4-3b1-pc7300 (and forks) — `sysv` / libs4 for 3B1 volumes  
- Fork docs also describe `filsys` usage in `src/mame/att/unixpc_filsys.md`

### Networking package (WIN/3B)

| What | Where in lab tree |
|------|-------------------|
| `ETHERNET+IN` cpio package | `roms/3b1/ethernet/ETHERNET+IN` (local only) |

Install notes (omit `cpio -B`): see `unixpc_hw.md` “Fresh install” in the
MAME fork. The golden `3b1.hd` already has ether loaded via
`/etc/lddrv/drivers` + `ether.rc`.

### Community / archives (software & FAQ)

| Resource | URL |
|----------|-----|
| Taronga / STORE / FAQ mirrors | http://www.oldcomputers.it/parts/a/atet/3b1/docs/taronga/ |
| unixpc.org (FAQ, mirrors) | Often linked from FreeBee / Taronga pages |
| FreeBee emulator | https://github.com/philpem/freebee |
| Bitsavers ATT bits | http://www.bitsavers.org/bits/ATT/unixPC/ |
| Bitsavers ATT PDFs | http://www.bitsavers.org/pdf/att/3b1/ |

---

## Local media layout

Expected under `$MAME_DIR/roms/3b1/`:

```text
roms/3b1/
  72-00616.14c
  72-00617.15c
  3b1.hd                         # guest Winchester (raw)
  floppies/                      # Bitsavers IMDs + *.work copies
  ethernet/ETHERNET+IN           # WIN/3B package (optional if HD has it)
  snapview.lua                   # copy from this lab: ./scripts/sync-lua.sh
  savestate_*.lua
```

Verify:

```bash
cd "$MAME_DIR"
shasum -a 256 -c "$LAB_DIR/media/CHECKSUMS.sha256"
```

More detail: [`docs/media-layout.md`](docs/media-layout.md),
[`media/README.md`](media/README.md).

---

## Lab repo layout

| Path | Role |
|------|------|
| `docs/` | Networking, media layout, fork pointer |
| `scripts/` | `feth-up/down`, `launch-networked`, `telnet-stress`, `sync-lua`, `bpf-restore` |
| `lua/` | Snapview + savestate smokes |
| `cfg/` | LANCE / MAC cfg fragment notes |
| `media/` | SHA-256 only |
| `ci/smoke-checklist.md` | Manual smoke list |

---

## Command-line parameters

Paths below assume cwd = `$MAME_DIR` and a binary named `unixpc`
(or `mame` with system `3b1`).

### Machine / media

| Option | Purpose |
|--------|---------|
| `3b1` | System name (AT&T UNIX PC Model 3B1) |
| `-hard <file>` | Mount Winchester image (raw). Prefer always for UNIX boot / Processor diag |
| `-hard2 <file>` | Second drive (P5.1 path); rarely needed |
| `-flop1 <IMD>` | Floppy in drive 0. Use `*.work` for Diag Disk writes |
| `-flop2 <IMD>` | Second floppy |

### UNIX PC–specific options

| Option | Default | Purpose |
|--------|---------|---------|
| `-parity` / `-noparity` | off | Emulate RAM parity (BPPLUS/PIE) for Diag Disk Memory & Parity. Overrides Machine Configuration when set on the CLI. Takes effect on reset. |
| `-modem` / `-nomodem` | off | Stub on-board **882A** as present (`RR2` idle `CTS\|DSR\|1200`). Lets Contiki open `/dev/ph0`. **Not** a phone line. Overrides Machine Configuration when set. |

Ini keys: `parity`, `modem` (same meanings).

### Expansion slots

| Option | Window | Purpose |
|--------|--------|---------|
| `-exp0 <card>` | `$C00000` | Slot 0 — e.g. `eia` Dual EIA |
| `-exp1 <card>` | `$C40000` | Slot 1 — e.g. `ethernet` (LANCE / WIN/3B) |
| `-exp2 <card>` | `$C80000` | Slot 2 |

Examples: `-exp1 ethernet`, `-exp0 eia`.

Card subdevices (after the card is attached):

```text
-exp0:eia:port1 loopback
-exp0:eia:port2 loopback
```

### Serial / printer

| Option | Purpose |
|--------|---------|
| `-rs232 pty` | Built-in serial → host PTY (interactive getty / kermit-style). Prefer this for Contiki. |
| `-rs232 null_modem` | Alternate host serial attachment |
| `-rs232 loopback` | **Diagnostic Disk Communications only.** Under interactive UNIX this storms getty IRQs — do not use. |
| `-printer printer` | Attach generic Centronics printer |
| `-prin <file.prn>` | Printout file (creates/loads so paper is clear; bytes append) |

Log line `RS-232 pty /dev/ttysN` is the host PTY path.

### Networking (host OSD)

| Option | Purpose |
|--------|---------|
| `-networkprovider pcap` | Darwin/BSD pcap backend (required for real peer packets). Default provider is often `none` (TX completes in-guest only). |
| `-listnetwork` | List host interfaces / indices for cfg `interface=` |
| *(cfg)* LANCE `interface` + `mac` | Bind `:exp1:ethernet:lance` to `feth1` and MAC `02:00:00:3b:00:01` — see `cfg/3b1.lance.fragment.xml` |

Without `pcap`, WIN/3B can still load and count Opkts; host ping/telnet will not work.

### OSD / automation

| Option | Purpose |
|--------|---------|
| `-autoboot_script <lua>` | Run Lua after start (`snapview.lua`, savestate smokes) |
| `-verbose` | Extra logs (enet status-ring posts, etc.) |
| `-video none -sound none -nothrottle` | Headless / CI-style |
| `-state <name>` | Load save state `sta/3b1/<name>.sta` at start |
| `-autosave` | Save on exit |
| `-window` / `-resolution` / … | Standard MAME display options |

---

## Complete command-line examples

All examples: cwd = MAME build tree; adjust paths as needed.

### 1) Networked Contiki (recommended daily driver)

```bash
sudo ./scripts/feth-up.sh          # from this lab; once per boot
# cfg: lance on feth1, mac 02:00:00:3b:00:01

./unixpc 3b1 \
  -hard roms/3b1/3b1.hd \
  -rs232 pty \
  -modem \
  -exp1 ethernet \
  -networkprovider pcap \
  -verbose \
  -autoboot_script roms/3b1/snapview.lua
```

Same via lab wrapper:

```bash
export MAME_DIR=~/Projects/mame
export LAB_DIR=~/Projects/unixpc-lab
"$LAB_DIR/scripts/sync-lua.sh"
"$LAB_DIR/scripts/launch-networked.sh"
```

### 2) Interactive UNIX, serial only (no ethernet)

```bash
./unixpc 3b1 \
  -hard roms/3b1/3b1.hd \
  -rs232 pty \
  -modem
```

### 3) Diagnostic Disk — floppy Format / surface

```bash
./unixpc 3b1 \
  -flop1 roms/3b1/floppies/01_Diagnosic_Disk_Ver_3.51.IMD.work \
  -hard roms/3b1/3b1.hd \
  -autoboot_script roms/3b1/snapview.lua
```

### 4) Diagnostic Disk — Memory & Parity + Printer + RTC path

```bash
./unixpc 3b1 \
  -flop1 roms/3b1/floppies/01_Diagnosic_Disk_Ver_3.51.IMD.work \
  -hard roms/3b1/3b1.hd \
  -parity \
  -printer printer \
  -prin roms/3b1/printout.prn \
  -autoboot_script roms/3b1/snapview.lua
```

### 5) Diagnostic Disk — Communications (loopback — diag only)

```bash
./unixpc 3b1 \
  -flop1 roms/3b1/floppies/01_Diagnosic_Disk_Ver_3.51.IMD.work \
  -rs232 loopback \
  -autoboot_script roms/3b1/snapview.lua
```

### 6) Dual EIA loopback (diag)

```bash
./unixpc 3b1 \
  -flop1 roms/3b1/floppies/01_Diagnosic_Disk_Ver_3.51.IMD.work \
  -exp0 eia \
  -exp0:eia:port1 loopback \
  -exp0:eia:port2 loopback
```

### 7) Save-state smoke (headless)

```bash
./unixpc 3b1 \
  -flop1 roms/3b1/floppies/01_Diagnosic_Disk_Ver_3.51.IMD.work \
  -hard roms/3b1/3b1.hd \
  -video none -sound none -nothrottle \
  -autoboot_script roms/3b1/savestate_smoke.lua

./unixpc 3b1 \
  -hard roms/3b1/3b1.hd \
  -video none -sound none -nothrottle \
  -state smoke \
  -autoboot_script roms/3b1/savestate_resume.lua
```

### 8) Resume networked session from save (if you saved one)

```bash
./unixpc 3b1 \
  -hard roms/3b1/3b1.hd \
  -rs232 pty \
  -modem \
  -exp1 ethernet \
  -networkprovider pcap \
  -state win3b \
  -autoboot_script roms/3b1/snapview.lua
```

(`sta/3b1/win3b.sta` is local; not in git.)

---

## Networked Contiki quick start

Default lab addressing:

| Role | Value |
|------|--------|
| Host `feth0` | `192.168.9.1/24` |
| Guest | `192.168.9.50` (`mame3b1`) |
| Guest MAC | `02:00:00:3b:00:01` |
| pcap bind | `feth1` |

```bash
sudo "$LAB_DIR/scripts/feth-up.sh"
# loosen BPF if needed (restore later):
#   sudo chmod g+rw /dev/bpf*; sudo chgrp admin /dev/bpf*

"$LAB_DIR/scripts/sync-lua.sh"
"$LAB_DIR/scripts/launch-networked.sh"
```

Wait for Contiki Login, then ether autoload (~2–3 minutes after multi-user
is up). Host checks:

```bash
ping 192.168.9.50
/usr/bin/nc 192.168.9.50 23
```

Full write-up: [`docs/networking.md`](docs/networking.md).

Guest markers when healthy: `ifconfig en0` shows `192.168.9.50`; board
ctl `@c40004 = 0005`; Lua ring dump shows RX `own=1`.

---

## Telnet / FTP from the host

Prefer **`/usr/bin/nc`** or **`/usr/bin/python3`**. Homebrew `telnet` /
Python often hit macOS **Local Network** privacy (`EHOSTUNREACH` /
“No route to host”) even when `ping` works.

```bash
/usr/bin/nc 192.168.9.50 23
# login: root
# Password: <empty Return>
# terminal type: s4
```

FTP: `/usr/bin/nc 192.168.9.50 21` or a system ftp client after Local
Network permission is granted.

Banner stress:

```bash
"$LAB_DIR/scripts/telnet-stress.sh"    # N=20 by default
```

If a real `telnet` client’s Return does nothing: try `Ctrl+M` (CR), or at
the `telnet>` prompt (`Ctrl+]`): `toggle crmod`.

---

## OSD shortcuts and save states

| Chord / key | Action |
|-------------|--------|
| **Cmd+Shift+U** | Toggle MAME UI (keyboard machines often start UI-off) |
| **Cmd+Shift+M** | Free mouse pointer without pause |
| **F6** / **Shift+F6** | Save state |
| **F7** / **Shift+F7** | Load state |

States live under `sta/3b1/` in the MAME working directory.

Snapview Lua triggers (with `-autoboot_script …/snapview.lua`):

| Touch file | Result |
|------------|--------|
| `/tmp/unixpc_ring_dump_request` | Softc + status/RX/TX rings → `/tmp/unixpc_status_ring.txt` |
| `/tmp/unixpc_exp_dump_request` | Slot identity / MAC |
| `/tmp/unixpc_type_request` | Natkeyboard inject helpers |

---

## Known host pitfalls

1. **`-rs232 loopback` + Contiki/getty** — IRQ storm. Loopback is diag-only.
2. **Wi‑Fi `en0` unicast** — foreign guest MAC often never reaches BPF. Use **feth** (or wired / TB Ethernet).
3. **BPF permissions** — pcap needs rw on `/dev/bpf*`. Lab loosen then restore with `scripts/bpf-restore.sh`.
4. **Homebrew network tools** — Local Network privacy; use `/usr/bin/nc`.
5. **AirPods / audio device thrash** — can crash MAME in CoreAudio remapping; unrelated to LANCE.
6. **Destructive Hard Disk Surface** — leave at the Yes/No prompt unless you intend to wipe the image.

---

## Prerequisites checklist

- [ ] Build [visionik/mame](https://github.com/visionik/mame) (`unixpc` / `mame` binary)
- [ ] ROMs + `3b1.hd` (+ floppies as needed) under `roms/3b1/`
- [ ] `./scripts/sync-lua.sh`
- [ ] For networking: `sudo ./scripts/feth-up.sh`, pcap provider, lance cfg MAC/interface
- [ ] Optional: BPF group access for non-root pcap

Manual smoke list: [`ci/smoke-checklist.md`](ci/smoke-checklist.md).
