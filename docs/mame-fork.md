# Related MAME fork

| Item | Value |
|------|--------|
| Fork | https://github.com/visionik/mame |
| Upstream | https://github.com/mamedev/mame |
| Branch | default / `master` (aligned with `att-3b1`) |
| Driver tree | `src/mame/att/` |
| In-tree pointer | `src/mame/att/README.md` |

## Where notes live

Deep implementation notes are **canonical in this lab repo**:

| Doc | Path |
|-----|------|
| Hardware / board / ethernet | [`unixpc_hw.md`](unixpc_hw.md) |
| Disk images | [`unixpc_image.md`](unixpc_image.md) |
| Host filsys | [`unixpc_filsys.md`](unixpc_filsys.md) |
| Branch changelog | [`changelog-att-3b1.md`](changelog-att-3b1.md) |

The MAME fork keeps short stubs under `src/mame/att/unixpc_*.md` that link
here. Non-obvious hardware constraints that affect code stay as comments
in the driver sources (MAME practice: the source is the documentation).

Emulator changes go to PRs on `visionik/mame`. Lab/runbook changes go here.
