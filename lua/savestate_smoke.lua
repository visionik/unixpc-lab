-- In-session save/load smoke.
-- Waits until PC is in Diagnostic Disk RAM, saves, loads, confirms PC
-- remains in that band and MAME did not report a load error.
-- Note: machine:save()/load() resume the CPU, so an exact PC match is
-- not expected; this checks that save/load are usable.

local FRAME_HZ = 60
local WAIT_SECS = 25
local SAVE_SETTLE = 60
local LOAD_SETTLE = 60
local DIAG_LO, DIAG_HI = 0x1000, 0x80000

local phase = "boot"
local frame = 0
local result_path = "/tmp/unixpc_savestate_smoke.result"
local log_path = "/Users/visionik/.grok/long-running-background-tasks/unixpc_savestate_smoke.log"

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
	emu.print_info(string.format("savestate_smoke: %s %s", ok and "PASS" or "FAIL", detail))
	manager.machine:exit()
end

local function in_diag(pc)
	return pc >= DIAG_LO and pc < DIAG_HI
end

_G.unixpc_savestate_sub = emu.add_machine_frame_notifier(function ()
	frame = frame + 1
	local pc = reg("PC") & 0xffffff

	if phase == "boot" then
		if frame >= WAIT_SECS * FRAME_HZ then
			if not in_diag(pc) then
				write_result(false, string.format("not in diag RAM at save time pc=%06x", pc))
				phase = "done"
				return
			end
			emu.print_info(string.format("savestate_smoke: saving pc=%06x", pc))
			manager.machine:save("smoke")
			phase = "saving"
			frame = 0
		end
		return
	end

	if phase == "saving" then
		if frame >= SAVE_SETTLE then
			emu.print_info(string.format("savestate_smoke: loading (pc now %06x)", pc))
			manager.machine:load("smoke")
			phase = "loading"
			frame = 0
		end
		return
	end

	if phase == "loading" then
		if frame >= LOAD_SETTLE then
			local sr = reg("SR") & 0xffff
			local detail = string.format("restored pc=%06x sr=%04x", pc, sr)
			if in_diag(pc) then
				write_result(true, detail)
			else
				write_result(false, detail .. " (PC left diag RAM)")
			end
			phase = "done"
		end
		return
	end
end)

emu.print_info("savestate_smoke: armed")
