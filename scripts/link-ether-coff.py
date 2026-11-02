#!/usr/bin/env python3
"""Link WIN/3B ether.o into a flat load image at 0x367000.

Applies SysV m68k COFF R_RELLONG (type 17) relocations, places .text/.data/.bss
contiguously, then allocates COMMON symbols (en_softc, NextCSR, RxRing, …).

Output matches the guest lddrv layout used in unixpc_hw.md softc table within
a few bytes (COMMON order / alignment). Externals (getslot, bcopy, …) stay 0.

Usage:
  scripts/link-ether-coff.py
  scripts/link-ether-coff.py --base 0x367000 --out re/binaries/ether.linked.bin
"""
from __future__ import annotations

import argparse
import json
import struct
from pathlib import Path

R_RELLONG = 17
DEFAULT_BASE = 0x367000
DEFAULT_IFILE = 0x13000


def align(x: int, a: int = 4) -> int:
    return (x + a - 1) & ~(a - 1)


def link(src: Path, base: int, ifile_len: int):
    data = src.read_bytes()
    magic, nscns, _timdat, symptr, nsyms, opthdr, _flags = struct.unpack_from(">HHIIIHH", data, 0)
    if magic not in (0x150, 0x152):
        raise SystemExit(f"bad COFF magic {magic:#x}")

    scnhdr_off = 20 + opthdr
    sects = []
    for i in range(nscns):
        off = scnhdr_off + i * 40
        name = data[off:off + 8].split(b"\0", 1)[0].decode()
        _p, vaddr, size, scnptr, relptr, _ln, nreloc, _nl, _sf = struct.unpack_from(
            ">IIIIIIHHI", data, off + 8
        )
        sects.append(dict(name=name, vaddr=vaddr, size=size, scnptr=scnptr, relptr=relptr, nreloc=nreloc))

    strtab = data[symptr + nsyms * 18:]

    def sym_name(e: bytes) -> str:
        z, o = struct.unpack_from(">II", e, 0)
        if z == 0:
            end = strtab.find(b"\0", o)
            if end < 0:
                end = len(strtab)
            return strtab[o:end].decode("ascii", "replace")
        return e[:8].split(b"\0", 1)[0].decode("ascii", "replace")

    raw = []
    i = 0
    while i < nsyms:
        e = data[symptr + i * 18:symptr + (i + 1) * 18]
        name = sym_name(e)
        value, scnum, typ, sclass, numaux = struct.unpack_from(">iHHbB", e, 8)
        raw.append(dict(name=name, value=value & 0xffffffff, scnum=scnum, typ=typ,
                        sclass=sclass, numaux=numaux, aux=False, new=None))
        for _ in range(numaux):
            raw.append(dict(name="", value=0, scnum=0, typ=0, sclass=0, numaux=0, aux=True, new=None))
        i += 1 + numaux

    text, dat, bss = sects[0], sects[1], sects[2]
    text_base = base
    data_base = base + text["size"]
    bss_base = data_base + dat["size"]
    delta = {1: text_base - text["vaddr"], 2: data_base - dat["vaddr"], 3: bss_base - bss["vaddr"]}

    common_cursor = align(bss_base + bss["size"])
    for s in raw:
        if s["aux"]:
            continue
        if 1 <= s["scnum"] <= 3:
            s["new"] = (s["value"] + delta[s["scnum"]]) & 0xffffffff
        elif s["scnum"] == 0 and s["sclass"] == 2 and s["value"] > 0:
            common_cursor = align(common_cursor)
            s["new"] = common_cursor
            common_cursor += s["value"]
        elif s["scnum"] == -1:
            s["new"] = s["value"]

    end = align(common_cursor)
    img = bytearray(max(end - base, ifile_len))
    img[0:text["size"]] = data[text["scnptr"]:text["scnptr"] + text["size"]]
    img[text["size"]:text["size"] + dat["size"]] = data[dat["scnptr"]:dat["scnptr"] + dat["size"]]

    def apply(sect, sect_new_base):
        patched = external = 0
        for ri in range(sect["nreloc"]):
            off = sect["relptr"] + ri * 10
            r_vaddr, r_symndx, r_type = struct.unpack_from(">IIH", data, off)
            if r_type != R_RELLONG:
                raise SystemExit(f"unexpected reloc type {r_type} at {r_vaddr:#x}")
            sym = raw[r_symndx]
            site = sect_new_base + (r_vaddr - sect["vaddr"]) - base
            old = struct.unpack_from(">I", img, site)[0]
            if sym["new"] is None:
                struct.pack_into(">I", img, site, 0)
                external += 1
                continue
            if 1 <= sym["scnum"] <= 3:
                addend = (old - sym["value"]) & 0xffffffff
                new = (sym["new"] + addend) & 0xffffffff
            elif sym["scnum"] == 0 and sym["value"] > 0:
                new = (sym["new"] + old) & 0xffffffff
            else:
                new = sym["new"]
            struct.pack_into(">I", img, site, new)
            patched += 1
        return patched, external

    pt, et = apply(text, text_base)
    pd, ed = apply(dat, data_base)

    symbols = []
    for s in raw:
        if s["aux"] or not s["name"] or s["name"].startswith(".") or s["new"] is None:
            continue
        symbols.append({
            "name": s["name"],
            "addr": s["new"],
            "scnum": s["scnum"],
            "size": s["value"] if s["scnum"] == 0 else None,
        })

    meta = {
        "base": base,
        "text": text_base,
        "data": data_base,
        "bss": bss_base,
        "commons": bss_base + bss["size"],
        "end": end,
        "relocs": {"text_patched": pt, "text_external": et, "data_patched": pd, "data_external": ed},
        "symbols": symbols,
    }
    return img, meta


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--src", type=Path,
                    default=Path.home() / "Projects/unixpc-lab/re/binaries/ether.o")
    ap.add_argument("--out", type=Path,
                    default=Path.home() / "Projects/unixpc-lab/re/binaries/ether.linked.bin")
    ap.add_argument("--map", type=Path,
                    default=Path.home() / "Projects/unixpc-lab/re/binaries/ether.linked.map.json")
    ap.add_argument("--base", type=lambda s: int(s, 0), default=DEFAULT_BASE)
    ap.add_argument("--ifile-len", type=lambda s: int(s, 0), default=DEFAULT_IFILE)
    args = ap.parse_args()

    img, meta = link(args.src, args.base, args.ifile_len)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_bytes(img)
    args.map.write_text(json.dumps(meta, indent=2))
    print(f"wrote {args.out} ({len(img)} bytes)")
    print(f"wrote {args.map} ({len(meta['symbols'])} symbols)")
    print(f"TEXT {meta['text']:#x}  DATA {meta['data']:#x}  BSS {meta['bss']:#x}  END {meta['end']:#x}")
    for n in ("en_softc", "NextCSR", "RxRing", "TxRing", "InitBlock", "StatusRing", "arptab"):
        hit = next((s for s in meta["symbols"] if s["name"] == n), None)
        if hit:
            print(f"  {n:16s} {hit['addr']:#x}")


if __name__ == "__main__":
    main()
