-- Periodic emulated-screen snapshot for agent viewing.
-- Keeps the notifier subscription in a global so it is not GC'd when
-- the autoboot script returns. Writes snap/3b1/view.png every ~1s.

local frame = 0

local function snap()
	local scr = manager.machine.screens[":screen"]
	if scr == nil then
		for _, s in pairs(manager.machine.screens) do
			scr = s
			break
		end
	end
	if scr == nil then
		return
	end
	local err = scr:snapshot("/Users/visionik/Projects/mame/snap/3b1/view.png")
	if err then
		emu.print_error(string.format("snapview: %s", tostring(err)))
	end
end

local last_pc = -1
local stable = 0
local function sample_cpu()
	local cpu = manager.machine.devices[":maincpu"]
	if cpu == nil then
		return
	end
	local st = cpu.state
	local function v(name)
		return (st[name] and st[name].value) or -1
	end
	local pc = v("PC") & 0xffffff
	local f = io.open("/tmp/unixpc_pc.sample", "w")
	if f then
		f:write(string.format(
			"pc=%06x sr=%04x d0=%08x d1=%08x a0=%08x a6=%08x\n",
			pc, v("SR") & 0xffff,
			v("D0") & 0xffffffff, v("D1") & 0xffffffff,
			v("A0") & 0xffffffff, v("A6") & 0xffffffff))
		f:close()
	end
	if pc == last_pc then
		stable = stable + 1
	else
		stable = 0
		last_pc = pc
	end
	-- Dump when PC is stable, or when it sits in the Transfer hang band
	-- (0x5070-0x50a0) even if it wobbles slightly.
	local hang_band = (pc >= 0x5070 and pc <= 0x50a0)
	if stable >= 2 or hang_band then
		local mem = manager.machine.devices[":maincpu"].spaces["program"]
		if mem then
			local out = io.open("/tmp/unixpc_pc.mem", "w")
			if out then
				out:write(string.format("pc=%06x\n", pc))
				local lo = hang_band and 0x5050 or (pc - 16)
				local hi = hang_band and 0x50c0 or (pc + 48)
				for a = lo, hi do
					local ok, b = pcall(function() return mem:read_u8(a) end)
					if ok then
						out:write(string.format("%06x: %02x\n", a & 0xffffff, b & 0xff))
					end
				end
				local a0 = v("A0") & 0xffffffff
				out:write(string.format("a0=%08x\n", a0))
				for _, adr in ipairs({0x410000, 0x470000, 0x4a0000, 0x4f0000, 0x1c2a6, 0x18340}) do
					local ok, w = pcall(function()
						if adr < 0x100000 then
							return mem:read_u8(adr)
						end
						return mem:read_u16(adr)
					end)
					if ok then
						out:write(string.format("mem[%06x]=%04x\n", adr, w & 0xffff))
					end
				end
				out:close()
			end
		end
	end
end

local function dump_exp_id()
	local mem = manager.machine.devices[":maincpu"].spaces["program"]
	if mem == nil then return end
	local out = io.open("/tmp/unixpc_exp_id.txt", "w")
	if not out then return end
	local bases = {0xc00000, 0xc40000, 0xc80000}
	for wi, base in ipairs(bases) do
		out:write(string.format("window %d base=%06x\n", wi-1, base))
		for _, off in ipairs({0x3fff8, 0x3fff9, 0x3fffa, 0x3fffb, 0x3fffc, 0x3fffd, 0x3fffe, 0x3ffff}) do
			local addr = base + off
			local okb, b = pcall(function() return mem:read_u8(addr) end)
			local okw, w = pcall(function() return mem:read_u16(addr - (addr % 2)) end)
			out:write(string.format("  +%05x addr=%06x u8=%s u16@even=%s\n",
				off, addr,
				okb and string.format("%02x", b & 0xff) or "ERR",
				okw and string.format("%04x", w & 0xffff) or "ERR"))
		end
		-- also MAC region for enet
		for _, off in ipairs({0x3ffc1, 0x3ffc3, 0x3ffc5, 0x3ffc7, 0x3ffc9, 0x3ffcb}) do
			local addr = base + off
			local okb, b = pcall(function() return mem:read_u8(addr) end)
			out:write(string.format("  mac +%05x u8=%s\n", off, okb and string.format("%02x", b & 0xff) or "ERR"))
		end
	end
	-- card device presence
	for i = 0, 2 do
		local tag = string.format(":exp%d", i)
		local d = manager.machine.devices[tag]
		local card = manager.machine.devices[string.format(":exp%d:ethernet", i)]
			or manager.machine.devices[string.format(":exp%d:eia", i)]
		out:write(string.format("device %s present=%s card=%s\n", tag, tostring(d ~= nil), tostring(card ~= nil)))
	end
	-- kernel slots[] at 0x25e3c: 8 x 4 identity bytes
	out:write("slots@25e3c:\n")
	for i = 0, 31 do
		local ok, b = pcall(function() return mem:read_u8(0x25e3c + i) end)
		out:write(string.format(" %02x", ok and (b & 0xff) or 0xff))
		if (i % 4) == 3 then out:write(string.format("  window_guess %d\n", i // 4)) end
	end
	out:close()
	emu.print_info("snapview: wrote /tmp/unixpc_exp_id.txt")
end

local function dump_status_ring()
	local mem = manager.machine.devices[":maincpu"].spaces["program"]
	if mem == nil then return end
	local out = io.open("/tmp/unixpc_status_ring.txt", "w")
	if not out then return end
	local function ru16(addr)
		local ok, w = pcall(function() return mem:read_u16(addr) end)
		if ok then return w & 0xffff end
		return nil
	end
	local function ru32(addr)
		local hi = ru16(addr)
		local lo = ru16(addr + 2)
		if hi and lo then return (hi << 16) | lo end
		return nil
	end
	-- WIN/3B softc absolutes (ether.o linked into lddrv window).
	local addrs = {
		{ "rx_ring", 0x3795d0 },
		{ "tx_ring", 0x3795d4 },
		{ "rx_cons", 0x3795d8 },
		{ "tx_prod", 0x3795dc },
		{ "tx_recl", 0x3795e0 },
		{ "InitBlock", 0x3795f4 },
		{ "rdp", 0x37960c },
		{ "rap", 0x379610 },
		{ "ctl", 0x379614 },
		{ "ring_port", 0x379618 },
		{ "reset", 0x379620 },
		{ "mac_base", 0x379628 },
		{ "ring_base", 0x379644 },
		{ "NextCSR", 0x379648 },
		{ "dma_arena", 0x37964c },
		{ "en_softc", 0x379650 },
	}
	out:write("softc:\n")
	local ring_base, next_csr, dma = nil, nil, nil
	for _, e in ipairs(addrs) do
		local v = ru32(e[2])
		out:write(string.format("  %s @%06x = %s\n", e[1], e[2],
			v and string.format("%08x", v) or "ERR"))
		if e[1] == "ring_base" then ring_base = v end
		if e[1] == "NextCSR" then next_csr = v end
		if e[1] == "dma_arena" then dma = v end
	end
	-- Board window 1 (+4 control, +6 ring store is write-only from guest).
	local ctl = ru16(0xc40004)
	out:write(string.format("board ctl@c40004 = %s\n", ctl and string.format("%04x", ctl) or "ERR"))
	-- Init block (12 words at 0x3795f4)
	out:write("init_block@3795f4:")
	for i = 0, 22, 2 do
		local w = ru16(0x3795f4 + i)
		out:write(string.format(" %04x", w or 0xdead))
	end
	out:write("\n")
	local function dump_desc_ring(label, base, n)
		if not base or base == 0 or base == 0xffffffff then
			out:write(label .. ": invalid\n")
			return
		end
		out:write(string.format("%s @%08x\n", label, base))
		for di = 0, n - 1 do
			local a = base + di * 8
			local w0 = ru16(a) or 0xdead
			local w1 = ru16(a + 2) or 0xdead
			local w2 = ru16(a + 4) or 0xdead
			local w3 = ru16(a + 6) or 0xdead
			-- Skip fully zero idle slots after the first few
			if di < 4 or w1 ~= 0 or w0 ~= 0 or (w2 ~= 0 and w2 ~= 0xffff) then
				out:write(string.format(
					"  [%02d] %04x %04x %04x %04x  addr=%06x own=%d stp=%d enp=%d bcnt=%d\n",
					di, w0, w1, w2, w3,
					((w1 & 0xff) << 16) | w0,
					(w1 & 0x8000) ~= 0 and 1 or 0,
					(w1 & 0x0200) ~= 0 and 1 or 0,
					(w1 & 0x0100) ~= 0 and 1 or 0,
					(w2 == 0xf000) and 4096 or -((w2 | 0xf000) - 0x10000)))
			end
		end
	end
	local rx = ru32(0x3795d0)
	local tx = ru32(0x3795d4)
	local tx_prod = ru32(0x3795dc)
	local tx_recl = ru32(0x3795e0)
	dump_desc_ring("rx_ring", rx, 8)
	dump_desc_ring("tx_ring", tx, 8)
	if tx and tx_prod then
		out:write(string.format("tx_prod_off=%d tx_recl_off=%d\n",
			tx_prod - tx, tx_recl and (tx_recl - tx) or -1))
	end
	if ring_base and ring_base ~= 0 and ring_base ~= 0xffffffff then
		out:write(string.format("status_ring @%08x NextCSR=%s\n", ring_base,
			next_csr and string.format("%08x", next_csr) or "?"))
		local nonzero = {}
		for i = 0, 0x3fe, 2 do
			local w = ru16(ring_base + i)
			if w and w ~= 0xffff then
				nonzero[#nonzero + 1] = string.format("%03x:%04x", i, w)
			end
		end
		out:write(string.format("nonzero_slots=%d\n", #nonzero))
		for i = 1, math.min(32, #nonzero) do
			out:write("  " .. nonzero[i] .. "\n")
		end
		-- First 16 words always
		out:write("ring[0:16]:")
		for i = 0, 30, 2 do
			local w = ru16(ring_base + i)
			out:write(string.format(" %04x", w or 0xdead))
		end
		out:write("\n")
	else
		out:write("status_ring: not armed / invalid base\n")
	end
	out:close()
	emu.print_info("snapview: wrote /tmp/unixpc_status_ring.txt")
end

local function poll_exp_dump()
	local f = io.open("/tmp/unixpc_exp_dump_request", "r")
	if f then
		f:close()
		os.remove("/tmp/unixpc_exp_dump_request")
		dump_exp_id()
		local done = io.open("/tmp/unixpc_exp_dump_done", "w")
		if done then done:write("ok\n"); done:close() end
	end
	local rf = io.open("/tmp/unixpc_ring_dump_request", "r")
	if rf then
		rf:close()
		os.remove("/tmp/unixpc_ring_dump_request")
		dump_status_ring()
		local done = io.open("/tmp/unixpc_ring_dump_done", "w")
		if done then done:write("ok\n"); done:close() end
	end
end

local function poll_type()
	-- Host writes UTF-8 text (may include newlines). Optional leading
	-- "@coded " uses post_coded (e.g. "@coded {ENTER}").
	local tf = io.open("/tmp/unixpc_type_request", "r")
	if not tf then
		return
	end
	local body = tf:read("*a") or ""
	tf:close()
	os.remove("/tmp/unixpc_type_request")
	local nat = manager.machine.natkeyboard
	if not nat then
		emu.print_error("snapview: no natkeyboard")
		return
	end
	nat.in_use = true
	if body:sub(1, 7) == "@coded " then
		nat:post_coded(body:sub(8))
	else
		nat:post(body)
	end
	local done = io.open("/tmp/unixpc_type_done", "w")
	if done then
		done:write(string.format("%d\n", #body))
		done:close()
	end
	emu.print_info(string.format("snapview: typed %d bytes", #body))
end

local function poll_saveload()
	poll_exp_dump()
	poll_type()
	-- Agent/host triggers: write a one-line slot name (default "manual").
	local sf = io.open("/tmp/unixpc_save_request", "r")
	if sf then
		local slot = (sf:read("*l") or "manual"):gsub("%s+", "")
		sf:close()
		os.remove("/tmp/unixpc_save_request")
		if slot == "" then slot = "manual" end
		emu.print_info(string.format("snapview: save request slot=%s", slot))
		manager.machine:save(slot)
		local done = io.open("/tmp/unixpc_save_done", "w")
		if done then
			done:write(slot .. "\n")
			done:close()
		end
	end
	local lf = io.open("/tmp/unixpc_load_request", "r")
	if lf then
		local slot = (lf:read("*l") or "manual"):gsub("%s+", "")
		lf:close()
		os.remove("/tmp/unixpc_load_request")
		if slot == "" then slot = "manual" end
		emu.print_info(string.format("snapview: load request slot=%s", slot))
		manager.machine:load(slot)
		local done = io.open("/tmp/unixpc_load_done", "w")
		if done then
			done:write(slot .. "\n")
			done:close()
		end
	end
end

-- Global on purpose: must outlive this script's chunk.
_G.unixpc_snapview_sub = emu.add_machine_frame_notifier(function ()
	frame = frame + 1
	poll_saveload()
	if (frame % 60) == 0 then
		snap()
		sample_cpu()
	end
	if frame == 180 then
		dump_exp_id()
	end
end)

emu.print_info("snapview: frame notifier armed (save/load/type via /tmp/unixpc_{save,load,type}_request)")
