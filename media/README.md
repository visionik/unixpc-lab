# Media (not stored here)

Guest disks and WIN/3B packages are **not** committed. Place them on the
machine that runs MAME and verify against `CHECKSUMS.sha256`.

```bash
cd "$MAME_DIR"
shasum -a 256 -c "$LAB_DIR/media/CHECKSUMS.sha256"
```

Lines that fail are expected if you have a newer guest HD after WIN/3B
install or Contiki use — update the checksum file when you intentionally
refresh a golden image.
