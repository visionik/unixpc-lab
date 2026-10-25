-- Phase 1: wait for diag, save "smoke", exit.
local FRAME_HZ = 60
local WAIT_SECS = 25
local SAVE_SETTLE = 60
local phase = "boot"
local frame = 0
local result_path = "/tmp/unixpc_savestate_quit.result"

local function reg(name)
	local st = manager.machine.devices[":maincpu"].state
	return (st[name] and st[name].value) or -1
end

_G.unixpc_savestate_quit_sub = emu.add_machine_frame_notifier(function ()
	frame = frame + 1
	if phase == "boot" and frame >= WAIT_SECS * FRAME_HZ then
		local pc = reg("PC") & 0xffffff
		local sr = reg("SR") & 0xffff
		local f = io.open(result_path, "w")
		if f then
			f:write(string.format("SAVED pc=%06x sr=%04x\n", pc, sr))
			f:close()
		end
		emu.print_info(string.format("savestate_quit: saving pc=%06x sr=%04x", pc, sr))
		manager.machine:save("smoke")
		phase = "saving"
		frame = 0
		return
	end
	if phase == "saving" and frame >= SAVE_SETTLE then
		manager.machine:exit()
		phase = "done"
	end
end)

emu.print_info("savestate_quit: armed")
