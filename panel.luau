--!nonstrict
-- Panel for Sony Pods
-- Battery status, noise control (ANC / Ambient + level slider).

local SNAPSHOT_KEY = "sony_pods_snapshot"
local COMMAND_KEY = "sony_pods_command"

local snapshot = noctalia.state.get(SNAPSHOT_KEY) or {}

-- User-provided device artwork: drop PNG/WEBP files into assets/ and map
-- model_name -> file here. Shown at the top of the panel when connected.
-- (snapshot.device_image from the backend, e.g. a downloaded render,
-- takes precedence when set.)
local DEVICE_ART = {
	["WH-1000XM6"] = "assets/wh-1000xm6.png",
	["WH-1000XM5"] = "assets/wh-1000xm5.png",
	["WH-1000XM4"] = "assets/wh-1000xm4.png",
	["WH-1000XM3"] = "assets/wh-1000xm3.png",
	["WF-1000XM5"] = "assets/wf-1000xm5.png",
	["WF-1000XM4"] = "assets/wf-1000xm4.png",
	["WF-1000XM3"] = "assets/wf-1000xm3.png",
	["LinkBuds S"] = "assets/linkbuds-s.png",
	["WH-CH720N"] = "assets/wh-ch720n.png",
	["ULT WEAR"] = "assets/ult-wear.png",
}

local function deviceImagePath()
	if snapshot.device_image and snapshot.device_image ~= "" then
		return snapshot.device_image
	end
	local model = snapshot.model_name or snapshot.device_name
	if model and DEVICE_ART[model] then
		return DEVICE_ART[model]
	end
	return nil
end

local commandSeq = 0
local function sendCommand(action, value)
	commandSeq += 1
	noctalia.state.set(COMMAND_KEY, {
		action = action,
		value = value,
		nonce = tostring(noctalia.nowMs()) .. "-" .. tostring(commandSeq),
	})
end

local function levelFraction(level)
	local n = tonumber(level)
	if n == nil or n < 0 then
		return 0
	end
	return math.max(0, math.min(100, n)) / 100
end

local function render()
	local connected = snapshot.connected == true
	local body = {}

	if connected then
		-- Device artwork (user assets) or a fallback glyph
		local artPath = deviceImagePath()
		if artPath then
			table.insert(body, ui.row({
				align = "center",
				justify = "center",
				padding = 2,
			}, {
				ui.image({
					path = artPath,
					width = 180,
					height = 138,
					fit = "contain",
				}),
			}))
		else
			table.insert(body, ui.row({
				align = "center",
				justify = "center",
				padding = 2,
			}, {
				ui.glyph({
					name = "headphones",
					size = 64,
					color = "primary",
				}),
			}))
		end

		-- Battery section
		local bLevel = snapshot.battery
		if bLevel == nil or bLevel < 0 then
			bLevel = snapshot.battery_left
		end
		local hasLevel = bLevel ~= nil and bLevel >= 0
		local low = hasLevel and bLevel <= 20 and not snapshot.charging

		table.insert(body, ui.column({ gap = 4, align = "center" }, {
			ui.label({
				text = noctalia.tr("panel.battery"),
				fontSize = 11,
				fontWeight = "bold",
				color = "on_surface_variant",
			}),
			ui.label({
				text = hasLevel and (tostring(bLevel) .. "%") or "--%",
				fontSize = 28,
				fontWeight = "bold",
				color = low and "error" or "on_surface",
				textAlign = "center",
			}),
			ui.progress({
				progress = hasLevel and levelFraction(bLevel) or 0,
				height = 6,
				radius = 3,
				fill = low and "error" or (snapshot.charging and "secondary" or "primary"),
				width = 220,
			}),
			ui.label({
				text = snapshot.charging and noctalia.tr("panel.charging") or " ",
				fontSize = 11,
				color = "secondary",
				textAlign = "center",
			}),
		}))

		table.insert(body, ui.separator({ thickness = 1, color = "on_surface/0.12" }))

		-- Noise control
		local currentMode = snapshot.noise_mode or "off"
		table.insert(body, ui.column({ gap = 4 }, {
			ui.label({
				text = noctalia.tr("panel.noise_control"),
				fontSize = 11,
				fontWeight = "bold",
				color = "on_surface_variant",
			}),
			ui.button({
				key = "mode-anc",
				text = noctalia.tr("panel.mode.anc"),
				glyph = "shield-check",
				variant = (currentMode == "anc") and "tonal" or "ghost",
				selected = (currentMode == "anc"),
				contentAlign = "start",
				onClick = function()
					sendCommand("set-noise", "anc")
				end,
			}),
			ui.button({
				key = "mode-transparency",
				text = noctalia.tr("panel.mode.transparency"),
				glyph = "ear",
				variant = (currentMode == "transparency") and "tonal" or "ghost",
				selected = (currentMode == "transparency"),
				contentAlign = "start",
				onClick = function()
					sendCommand("set-noise", "transparency")
				end,
			}),
			ui.button({
				key = "mode-off",
				text = noctalia.tr("panel.mode.off"),
				glyph = "volume-off",
				variant = (currentMode == "off") and "tonal" or "ghost",
				selected = (currentMode == "off"),
				contentAlign = "start",
				onClick = function()
					sendCommand("set-noise", "off")
				end,
			}),
		}))

		-- Ambient level slider (only meaningful in transparency mode)
		local ambLevel = tonumber(snapshot.ambient_level) or 0
		table.insert(body, ui.column({ gap = 4 }, {
			ui.label({
				text = noctalia.tr("panel.ambient_level") .. ": " .. tostring(ambLevel),
				fontSize = 11,
				fontWeight = "bold",
				color = "on_surface_variant",
			}),
			ui.slider({
				key = "ambient-slider",
				min = 0,
				max = 20,
				step = 1,
				value = ambLevel,
				enabled = currentMode == "transparency",
				onDragEnd = function(value)
					sendCommand("set-ambient", tostring(math.floor(tonumber(value) or 0)))
				end,
			}),
		}))
	else
		table.insert(body, ui.column({ align = "center", gap = 12, padding = 24 }, {
			ui.glyph({
				name = "headphones-off",
				size = 48,
				color = "on_surface_variant",
			}),
			ui.label({
				text = noctalia.tr("widget.not_connected"),
				fontSize = 15,
				fontWeight = "bold",
				color = "on_surface",
				textAlign = "center",
			}),
			ui.label({
				text = noctalia.tr("panel.guidance"),
				fontSize = 12,
				color = "on_surface_variant",
				textAlign = "center",
			}),
		}))
	end

	local titleText = snapshot.model_name or snapshot.device_name or noctalia.tr("panel.title")
	local statusText = connected and noctalia.tr("panel.status.connected") or noctalia.tr("panel.status.disconnected")
	if connected and snapshot.mac then
		statusText = statusText .. " • " .. snapshot.mac
	end

	panel.render(ui.column({ flexGrow = 1, gap = 8, padding = 10 }, {
		ui.row({ align = "center", justify = "space_between", gap = 8 }, {
			ui.glyph({
				name = connected and "headphones" or "headphones-off",
				size = 26,
				color = connected and "primary" or "on_surface_variant",
			}),
			ui.column({ flexGrow = 1, gap = 2 }, {
				ui.label({
					text = titleText,
					fontSize = 15,
					fontWeight = "bold",
					color = "on_surface",
					maxLines = 1,
				}),
				ui.label({
					text = statusText,
					fontSize = 11,
					color = connected and "secondary" or "on_surface_variant",
					maxLines = 1,
				}),
			}),
			ui.button({
				glyph = "close",
				variant = "ghost",
				onClick = "onCloseClicked",
			}),
		}),
		ui.column({ flexGrow = 1, gap = 10 }, body),
	}))
end

noctalia.state.watch(SNAPSHOT_KEY, function(value)
	if type(value) == "table" then
		snapshot = value
		render()
	end
end)

function onOpen(_context)
	sendCommand("refresh", nil)
	render()
end

function onCloseClicked()
	panel.close()
end
