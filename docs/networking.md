# Host networking (Darwin feth + pcap)

## Why feth

Same-host traffic to a guest MAC on Wi‑Fi `en0` often fails for unicast.
A pair of fake Ethernet peers keeps ARP/ICMP/TCP on a private L2 segment.

```text
[ host apps ] -- feth0 (192.168.9.1) ⟷ feth1 -- [ MAME pcap / AM7990 ]
                                              guest 192.168.9.50
                                              MAC 02:00:00:3b:00:01
```

## Bring up

```bash
sudo ./scripts/feth-up.sh
ifconfig feth0 feth1
```

## MAME

```bash
./unixpc 3b1 \
  -hard roms/3b1/3b1.hd \
  -rs232 pty \
  -modem \
  -exp1 ethernet \
  -networkprovider pcap \
  -autoboot_script roms/3b1/snapview.lua
```

Bind LANCE to `feth1` and set MAC in cfg (see `cfg/3b1.lance.fragment.xml`)
or the Machine Configuration UI.

## Guest

- Hostname `mame3b1`, IP `192.168.9.50` (WIN/3B `ether.rc` / hosts)
- Package: `roms/3b1/ethernet/ETHERNET+IN`
- After Contiki login, wait for ether autoload (board ctl `@c40004 = 0005`)

## Telnet

```bash
/usr/bin/nc 192.168.9.50 23
# login: root
# Password: <empty>
# terminal: s4
```

If Return does nothing in real `telnet`, try `Ctrl+M` (CR) or at `telnet>`:
`toggle crmod`.

Stress banners:

```bash
./scripts/telnet-stress.sh
```

## BPF permissions (macOS)

pcap needs read/write on `/dev/bpf*`. Temporary lab loosen:

```bash
sudo chmod g+rw /dev/bpf*
sudo chgrp admin /dev/bpf*
```

Restore when done:

```bash
./scripts/bpf-restore.sh    # prints commands; run with sudo as shown
```

## Known crash (audio hotplug)

Rapid Speakers ↔ AirPods can SIGSEGV in `sound_manager::update_osd_streams`
when CoreAudio’s default device ID is missing from `m_nodes`. Separate from
ethernet. See MAME session notes / upstream Belmont CoreAudio fixes.
