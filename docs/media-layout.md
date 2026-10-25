# Local media layout

Expected under `$MAME_DIR/roms/3b1/` (not in this git repo):

```text
roms/3b1/
  72-00616.14c          # ROM
  72-00617.15c          # ROM
  3b1.hd                # guest hard disk (raw)
  floppies/             # Bitsavers 3.51 IMDs (+ .work copies)
  ethernet/ETHERNET+IN  # WIN/3B install package
  snapview.lua          # copy from lab lua/
  savestate_*.lua
```

Checksums: [`../media/CHECKSUMS.sha256`](../media/CHECKSUMS.sha256).

Keep Bitsavers originals write-protected / as `*.bitsavers_pristine`.
Use `*.work` copies for Diagnostic Disk write/surface tests.
