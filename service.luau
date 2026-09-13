--!nonstrict
-- Service for Sony Headphones
-- Polls headphones via scripts/sony_ctl.py (MDR V2 over RFCOMM)

local SNAPSHOT_KEY = "sony_headphones_snapshot"
local COMMAND_KEY = "sony_headphones_command"

local scriptPath = noctalia.pluginDir() .. "/scripts/sony_ctl.py"

local function getCliCmd(args)
	local mac = noctalia.getConfig("device_mac")
	local cmd = "python3 " .. scriptPath .. " " .. args
	if mac and mac ~= "" then
		cmd = cmd .. " --mac " .. mac
	end
	return cmd
end

local function updateSnapshot(data)
	if type(data) == "table" then
		noctalia.state.set(SNAPSHOT_KEY, data)
	end
end

local function pollStatus()
	local cmd = getCliCmd("status")
	noctalia.runAsync(cmd, function(result)
		if result and result.stdout and result.stdout ~= "" then
			local ok, parsed = pcall(function()
				return noctalia.json.decode(result.stdout)
			end)
			if ok and parsed then
				updateSnapshot(parsed)
			end
		end
	end)
end

local function notifyMode(mode)
	local modeLabel = noctalia.tr("panel.mode." .. mode)
	local curState = noctalia.state.get(SNAPSHOT_KEY)
	local devName = (curState and (curState.model_name or curState.device_name)) or "Sony Headphones"
	noctalia.notify(devName, string.format(noctalia.tr("notify.mode_changed"), modeLabel), "headphones")
end

local function runCli(args, afterMode)
	local cmd = getCliCmd(args)
	noctalia.runAsync(cmd, function(result)
		if result and result.stdout then
			local ok, parsed = pcall(function() return noctalia.json.decode(result.stdout) end)
			if ok and parsed and parsed.mode and afterMode then
				notifyMode(parsed.mode)
			end
		end
		pollStatus()
	end)
end

local function executeCommand(cmdObj)
	if type(cmdObj) ~= "table" or not cmdObj.action then
		return
	end

	if cmdObj.action == "set-noise" and cmdObj.value then
		runCli("set-anc " .. tostring(cmdObj.value), true)
	elseif cmdObj.action == "set-ambient" and cmdObj.value then
		runCli("set-ambient " .. tostring(cmdObj.value), false)
	elseif cmdObj.action == "cycle-noise" then
		runCli("cycle-anc", true)
	elseif cmdObj.action == "refresh" then
		pollStatus()
	end
end

function onIpc(event, payload)
	if event == "cycle-noise" then
		runCli("cycle-anc", true)
	elseif event == "set-noise" and payload then
		runCli("set-anc " .. tostring(payload), true)
	elseif event == "set-ambient" and payload then
		runCli("set-ambient " .. tostring(payload), false)
	elseif event == "refresh" then
		pollStatus()
	end
end

noctalia.state.watch(COMMAND_KEY, executeCommand)

-- Initial fast poll, then interval polling every 10 seconds
-- (RFCOMM sessions are short-lived; 4s like oppo-pods risks audio stutter)
pollStatus()
noctalia.setUpdateInterval(10000)

function update()
	pollStatus()
end
