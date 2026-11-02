# Ghidra + ghidra-mcp setup for WIN/3B `ether.o`

Concrete checklist to reverse `ether.o` (and the linked driver image) with
[bethington/ghidra-mcp](https://github.com/bethington/ghidra-mcp) from Grok
Build / other MCP clients.

**Goal:** deeper map of TWG TCP/IP / softc inside WIN/3B. The board `en*` /
status-ring path is already documented in [`unixpc_hw.md`](unixpc_hw.md) —
do not redo that from scratch unless something disagrees with MAME.

**This machine (checklist run complete):** Java 21 (`openjdk@21`), Ghidra
12.1.4 at `~/Tools/ghidra_12.1.4_PUBLIC` with `mac_arm_64` natives installed,
`bridge-mcp-ghidra` on PATH, GhidraMCP **7.0.0** extension + headless jar,
project `re/ghidra/win3b-ether` with `ether.o` open, board `en*` labeled from
COFF, Grok `[mcp_servers.ghidra-mcp]` wired. Restart the Grok session (or
reload MCPs) so the bridge tools appear.

### Quick start (already installed)

```bash
# Terminal 1 — headless HTTP API on :8089
~/Projects/unixpc-lab/scripts/ghidra-mcp-headless.sh

# Health
curl -s http://127.0.0.1:8089/check_connection
# {"status":"ok","server_kind":"headless","version":"7.0.0","program":"ether.o"}

# Re-apply COFF board labels if the project was wiped
~/Projects/unixpc-lab/scripts/ghidra-label-ether-coff.py
```

Grok config (`~/.grok/config.toml`):

```toml
[mcp_servers.ghidra-mcp]
command = "/Users/visionik/.local/bin/bridge-mcp-ghidra"
enabled = true
startup_timeout_sec = 60
tool_timeout_sec = 600

[mcp_servers.ghidra-mcp.env]
GHIDRA_MCP_URL = "http://127.0.0.1:8089"
```

### Address model (important)

Headless import used **BinaryLoader** on the whole COFF file at image base
**`0x367000`** (headers included). `.text` bytes therefore start at
`0x367400` (`BASE + scnptr`). COFF section VMAs inside the object are
relocatable (`.text @ 0x80000`); map with:

`ghidra_va = 0x367000 + scnptr + (n_value - sect.vaddr)`

Examples after labeling: `enprobe=0x374bf0`, `enintr=0x375316`,
`enrint=0x3755ac`. These are **Ghidra flat-file VAs**, not the guest
`lddrv` runtime map that places softc near `0x3795d0` in
[`unixpc_hw.md`](unixpc_hw.md). Do **not** call `/set_image_base` again on
this project — it double-shifted blocks once already; current layout is
correct with metadata `base_address` possibly reporting `0` while blocks
sit at `0x367000`.

`enintr` decomp already shows the status-ring high-byte decode
(`0x0100` IDON, `0x0200` TINT, `0x0400` RINT → `enrint`, else `enreset`),
matching the emulator notes.

---

## 0. Prerequisites (once)

| Need | Notes |
|------|--------|
| **Java 21** | `brew install openjdk@21` then follow the caveats (`PATH` / symlink). Check: `java -version` |
| **Ghidra 12.1.4** | Must match the extension build. Get from [NSA Ghidra releases](https://github.com/NationalSecurityAgency/ghidra/releases). Unpack e.g. to `~/Tools/ghidra_12.1.4_PUBLIC` |
| **uv** | Already common on this Mac: https://docs.astral.sh/uv/ |
| **ghidra-mcp v7.0.0** | Release assets: extension zip + Python bridge wheel |

```bash
# Example layout
export GHIDRA_HOME="$HOME/Tools/ghidra_12.1.4_PUBLIC"
export LAB_DIR="$HOME/Projects/unixpc-lab"
export MAME_DIR="$HOME/Projects/mame"
mkdir -p "$HOME/Tools" "$LAB_DIR/re/ghidra" "$LAB_DIR/re/binaries"
```

Do **not** commit Ghidra project DB or `ether.o` into git (copyrighted /
huge). Keep under `re/` and gitignore (see bottom).

---

## 1. Install ghidra-mcp

```bash
cd /tmp
curl -LO https://github.com/bethington/ghidra-mcp/releases/download/v7.0.0/GhidraMCP-7.0.0.zip
curl -LO https://github.com/bethington/ghidra-mcp/releases/download/v7.0.0/ghidra_mcp_bridge-7.0.0-py3-none-any.whl

# Bridge on PATH (absolute path required in Grok MCP config)
uv tool install ./ghidra_mcp_bridge-7.0.0-py3-none-any.whl
which bridge-mcp-ghidra   # e.g. ~/.local/bin/bridge-mcp-ghidra
```

In Ghidra (project window):

1. **File → Install Extensions → +** → select `GhidraMCP-7.0.0.zip`
2. Restart Ghidra
3. **File → Configure → Utility → Configure** → enable **GhidraMCPPlugin**
4. Open any project; **Tools → GhidraMCP → Start MCP Server** (default `http://127.0.0.1:8089`)

Health check:

```bash
curl -s http://127.0.0.1:8089/check_connection
# expect: {"status":"ok","server_kind":"gui","version":"7.0.0",...}
```

Illustrated GUI steps: upstream `docs/INSTALL_GUI.md` in the ghidra-mcp repo.

---

## 2. Wire MCP into Grok Build

Add to `~/.grok/config.toml` (use the **absolute** path from `which bridge-mcp-ghidra`):

```toml
[mcp_servers.ghidra-mcp]
command = "/Users/YOU/.local/bin/bridge-mcp-ghidra"
enabled = true
startup_timeout_sec = 60
# Optional: bump if decomp batches are huge
# tool_timeout_sec = 600
```

Then restart the Grok session (or `/mcps` → reload). Confirm tools appear
(`search_tool` / MCP list for `ghidra` / `decompile` / `list_functions`).

Grok MCP guide: `~/.grok/docs/user-guide/07-mcp-servers.md`.

---

## 3. Prepare the binary

Preferred artifact: **3.51 `new/etc/lddrv/ether.o`** (~111448 bytes) from
`ETHERNET+IN` (never unpack with Contiki `cpio -B`).

```bash
# Extract on the host (no -B)
mkdir -p "$LAB_DIR/re/binaries" /tmp/ethernet-in
cd /tmp/ethernet-in
cpio -icduvm < "$MAME_DIR/roms/3b1/ethernet/ETHERNET+IN"
cp -f new/etc/lddrv/ether.o "$LAB_DIR/re/binaries/ether.o"
ls -l "$LAB_DIR/re/binaries/ether.o"   # expect 111448
shasum -a 256 "$LAB_DIR/re/binaries/ether.o"
```

Optional: also keep a **linked `.text` dump** at load address `0x367000`
(from earlier Capstone work / `ifile.ether`) if COFF import is awkward —
import as raw + set language/base manually.

Load parameters (from prior RE):

| Item | Value |
|------|--------|
| Arch | **68000** family, **big-endian** (Ghidra: `68000:BE:32:default` or closest 68010-capable) |
| Format | SysV **m68k COFF** (magic `0x150` / `0x152`) |
| Image / link origin | **`0x367000`** (`ifile.ether`, length `0x13000`) |
| Softc window (loaded) | ~`0x3795d0`… (see `unixpc_hw.md`) |

---

## 4. Create the Ghidra project

```text
Project dir (local only):  ~/Projects/unixpc-lab/re/ghidra/
Project name:              win3b-ether
```

1. **File → New Project → Non-Shared** → `…/unixpc-lab/re/ghidra/win3b-ether`
2. **File → Import File** → `re/binaries/ether.o`
3. If format auto-detect fails: language **68000:BE:32:…**, compiler **default**
4. After import: **Options** / memory map — ensure image base is **`0x367000`**
   if the importer left it at 0 (Edit → Tool Options / Memory Map as needed)
5. Open in CodeBrowser → **Analysis → Auto Analyze** (defaults OK; keep
   “Create Address Tables” / reference analyzers on)
6. Start **GhidraMCP** server if not already running

Import COFF symbols if Ghidra did not: Script Manager → or MCP
`import`/`rename` batch from a symbol list exported by your COFF parser.
Kernel externals: guest `unix.sym` (`getslot = 0x…;` lines).

---

## 5. First agent session (smoke)

With Ghidra open on `ether.o` and MCP connected, ask the agent to:

1. `check_connection` / list open programs  
2. Find functions: `enprobe`, `enattach`, `eninit`, `enintr`, `enrint`, `setreg`, `NextCSR`  
3. Decompile `enintr` and compare to [`unixpc_hw.md`](unixpc_hw.md) status-ring rules  
4. List xrefs to the status-ring / softc addresses if labeled  

If `enintr` decomp matches the documented high-byte decode, the project is
aligned. Then expand into TWG symbols (`tcp_*`, `ip_*`, `arp_*`, socket
layer) — that is the new work.

---

## 6. Suggested RE order (after smoke)

1. **Confirm board path** — annotate only; do not rewrite lab docs unless wrong  
2. **`en_softc` / ring pointers** — define a Ghidra struct from the softc table in `unixpc_hw.md`  
3. **`enioctl` / ifnet** — bring-up and flags  
4. **Sample TWG path** — e.g. ARP reply or TCP input that leads to `enoutput`  
5. Export notes back into `docs/` (short additions to `unixpc_hw.md` or a new `docs/win3b-tcp.md`)

Keep MAME + pcap as runtime ground truth.

---

## 7. Headless (preferred on this Mac)

GUI works too (extension under `~/.ghidra/.ghidra_12.1.4_PUBLIC/Extensions/GhidraMCP`),
but the lab default is the headless server:

1. Build / refresh jar once: clone `bethington/ghidra-mcp` →
   `mvn -DskipTests package` →
   `/tmp/ghidra-mcp/target/GhidraMCP-7.0.0.jar` (override with `GHIDRA_MCP_JAR`).
2. After `support/gradle/./gradlew buildNatives`, copy
   `Ghidra/Features/*/build/os/mac_arm_64` → `…/os/mac_arm_64` (PUBLIC zip
   ships without Apple Silicon decompiler natives).
3. Launch: `scripts/ghidra-mcp-headless.sh` (binds `127.0.0.1:8089`, opens
   `win3b-ether` / `ether.o`).
4. Label: `scripts/ghidra-label-ether-coff.py` (board symbols) or
   `--all-twg` for `tcp_`/`ip_`/`arp_`/`if_`.

Upstream Docker (`ghidra-mcp/docker/entrypoint.sh`) is the classpath
template the lab script mirrors. Set `GHIDRA_MCP_AUTH_TOKEN` only if
binding off localhost.

---

## 8. Gitignore (lab)

Ensure `unixpc-lab/.gitignore` contains something like:

```gitignore
# Ghidra / RE artifacts (local only)
re/ghidra/
re/binaries/
*.gpr
*.rep/
*.lock*
```

`ETHERNET+IN` and guest HD stay under `$MAME_DIR/roms/3b1/` (already not in lab git).

---

## 9. Done when

- [x] `curl` health OK on `:8089` (headless 7.0.0, program `ether.o`)
- [x] Grok MCP config wired (`bridge-mcp-ghidra` + `GHIDRA_MCP_URL`); **reload session** for tools
- [x] `enintr` / `enprobe` resolve by name (`0x375316` / `0x374bf0` flat VAs)
- [x] Image blocks at `0x367000` (BinaryLoader; see address model above)
- [ ] Softc struct sketched; one TWG path documented in lab `docs/`  


---

## References

- https://github.com/bethington/ghidra-mcp (release **v7.0.0**)  
- https://github.com/NationalSecurityAgency/ghidra/releases  
- Lab: [`unixpc_hw.md`](unixpc_hw.md), [`unixpc_filsys.md`](unixpc_filsys.md)  
- Package: `$MAME_DIR/roms/3b1/ethernet/ETHERNET+IN`  
