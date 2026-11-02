#!/usr/bin/env python3
"""Apply SysV m68k COFF symbols from ether.o onto the flat BinaryLoader image.

The win3b-ether project loads the whole COFF file at BASE (default 0x367000),
including headers. Section contents therefore live at BASE+scnptr. COFF
n_value is in the relocatable section VMA space (e.g. .text @ 0x80000), so:

    ghidra_va = BASE + scnptr + (n_value - sect.vaddr)

Runtime lddrv addresses (softc ~0x3795d0) use a different section layout;
do not treat these Ghidra VAs as guest runtime VAs without remapping.

Usage:
  scripts/ghidra-label-ether-coff.py              # label board en* (+setreg)
  scripts/ghidra-label-ether-coff.py --all-twg    # also tcp_/ip_/arp_/if_
  scripts/ghidra-label-ether-coff.py --dry-run
"""
from __future__ import annotations

import argparse
import json
import struct
import urllib.request
from pathlib import Path

DEFAULT_BIN = Path.home() / "Projects/unixpc-lab/re/binaries/ether.o"
DEFAULT_BASE = 0x367000
DEFAULT_URL = "http://127.0.0.1:8089"
BOARD = [
    "enintr", "enprobe", "enattach", "eninit", "enrint", "enoutput", "setreg",
    "enioctl", "enreset", "ensetaddr", "enrelease", "enstart", "enprintf",
    "enget", "enput", "enmemfree",
]


def parse_coff(path: Path, base: int):
    data = path.read_bytes()
    magic, nscns, _timdat, symptr, nsyms, opthdr, _flags = struct.unpack_from(">HHIIIHH", data, 0)
    if magic not in (0x150, 0x152):
        raise SystemExit(f"unexpected COFF magic 0x{magic:x}")
    scnhdr_off = 20 + opthdr
    sections = []
    for i in range(nscns):
        off = scnhdr_off + i * 40
        name = data[off:off + 8].split(b"\0", 1)[0].decode("ascii", "replace")
        _paddr, vaddr, size, scnptr, _rel, _ln, _nr, _nl, _sf = struct.unpack_from(">IIIIIIHHI", data, off + 8)
        sections.append({"name": name, "vaddr": vaddr, "size": size, "scnptr": scnptr})
    strtab = data[symptr + nsyms * 18:]

    def sym_name(entry: bytes) -> str:
        zeros, offset = struct.unpack_from(">II", entry, 0)
        if zeros == 0:
            end = strtab.find(b"\0", offset)
            if end < 0:
                end = len(strtab)
            return strtab[offset:end].decode("ascii", "replace")
        return entry[:8].split(b"\0", 1)[0].decode("ascii", "replace")

    def ghidra_va(scnum: int, value: int):
        if not (1 <= scnum <= len(sections)):
            return None
        sect = sections[scnum - 1]
        return base + sect["scnptr"] + (value - sect["vaddr"])

    syms = {}
    i = 0
    while i < nsyms:
        off = symptr + i * 18
        entry = data[off:off + 18]
        name = sym_name(entry)
        value, scnum, _typ, _sclass, numaux = struct.unpack_from(">iHHbB", entry, 8)
        va = ghidra_va(scnum, value)
        if va is not None:
            syms[name] = va
        i += 1 + numaux
    return sections, syms


def post_json(url: str, path: str, body: dict):
    req = urllib.request.Request(
        url.rstrip("/") + path,
        data=json.dumps(body).encode(),
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=120) as resp:
        return json.loads(resp.read().decode())


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--bin", type=Path, default=DEFAULT_BIN)
    ap.add_argument("--base", type=lambda s: int(s, 0), default=DEFAULT_BASE)
    ap.add_argument("--url", default=DEFAULT_URL)
    ap.add_argument("--all-twg", action="store_true")
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    sections, syms = parse_coff(args.bin, args.base)
    print("sections:")
    for s in sections:
        print(f"  {s['name']!r} vaddr=0x{s['vaddr']:x} scnptr=0x{s['scnptr']:x} size=0x{s['size']:x}")

    names = list(BOARD)
    if args.all_twg:
        names.extend(sorted(n for n in syms if n.startswith(("tcp_", "ip_", "arp_", "if_"))))

    labels = []
    for name in names:
        if name in syms:
            labels.append({"address": f"0x{syms[name]:x}", "name": name})
            print(f"  {name:20s} 0x{syms[name]:08x}")
        else:
            print(f"  {name:20s} MISSING")

    if args.dry_run:
        return

    print(post_json(args.url, "/create_label", {"labels": labels}))
    for lab in labels:
        # Ensure a function exists, then rename (idempotent-ish).
        try:
            print(lab["name"], post_json(args.url, "/create_function", {
                "address": lab["address"], "name": lab["name"],
            }))
        except Exception as e:
            print(lab["name"], "create_function:", e)
        try:
            print(lab["name"], post_json(args.url, "/rename_function", {
                "old_name": lab["address"], "new_name": lab["name"],
            }))
        except Exception as e:
            print(lab["name"], "rename_function:", e)


if __name__ == "__main__":
    main()
