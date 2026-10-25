-- Phase 2: launched with -state smoke. Confirm PC in diag RAM.
local SETTLE = 90
local frame = 0
local DIAG_LO, DIAG_HI = 0x1000, 0x80000
local result_path = "/tmp/unixpc_savestate_resume.result"

local function reg(name)
	local st = manager.machine.devices[":maincpu"].state
	return (st[name] and st[name].value) or -1
end

local function write_result(ok, detail)
	local f = io.open(result_path, "w")
	if f then
		f:write(string.format("%s %s\n", ok and "PASS" or "FAIL", detail))
		f:close()
	end
	emu.print_info(string.format("savestate_resume: %s %s", ok and "PASS" or "FAIL", detail))
	manager.machine:exit()
end

_G.unixpc_savestate_resume_sub = emu.add_machine_frame_notifier(function ()
	frame = frame + 1
	if frame < SETTLE then
		return
	end
	local pc = reg("PC") & 0xffffff
	local sr = reg("SR") & 0xffff
	local detail = string.format("pc=%06x sr=%04x", pc, sr)
	if pc >= DIAG_LO and pc < DIAG_HI then
		write_result(true, detail)
	else
		write_result(false, detail)
	end
end)

emu.print_info("savestate_resume: armed")
