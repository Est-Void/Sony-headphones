--!nonstrict
-- Panel for Sony Pods
-- Device photo, horseshoe battery gauge (% in the center), 3 noise mode buttons.

local SNAPSHOT_KEY = "sony_pods_snapshot"
local COMMAND_KEY = "sony_pods_command"

local snapshot = noctalia.state.get(SNAPSHOT_KEY) or {}

-- User-provided device artwork: drop PNG/WEBP files into assets/ and map
-- model_name -> file here. Shown at the top of the panel when connected.
-- (snapshot.device_image from the backend, e.g. a downloaded render,
-- takes precedence when set.)
local DEVICE_ART = {
	["WH-1000XM6"] = "assets/1000xm6_black.webp",
	["WH-1000XM5"] = "assets/1000xm5_black.webp",
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

local function gaugeBlock()
	-- Battery block: % label over a striped gradient bar (SVG rendered
	-- by scripts/sony_ctl.py in the system accent). Text fallback
	-- when the bar file is missing.
	local gaugePath = snapshot.battery_gauge
	local bLevel = snapshot.battery
	if bLevel == nil or bLevel < 0 then
		bLevel = snapshot.battery_left
	end
	local hasLevel = bLevel ~= nil and bLevel >= 0
	local low = hasLevel and bLevel <= 20 and not snapshot.charging

	local barNode
	if gaugePath and gaugePath ~= "" then
		barNode = ui.image({
			path = gaugePath,
			width = 300,
			height = 32,
			fit = "contain",
		})
	else
		barNode = ui.progress({
			progress = hasLevel and (math.max(0, math.min(100, bLevel)) / 100) or 0,
			height = 12,
			radius = 6,
			fill = low and "error" or "primary",
			width = 300,
		})
	end

	return ui.column({ gap = 4, align = "center" }, {
		ui.label({
			text = hasLevel and (tostring(bLevel) .. "%") or "--%",
			fontSize = 22,
			fontWeight = "bold",
			color = low and "error" or "on_surface",
			textAlign = "center",
		}),
		barNode,
		ui.label({
			text = snapshot.charging and noctalia.tr("panel.charging") or noctalia.tr("panel.battery"),
			fontSize = 11,
			color = snapshot.charging and "secondary" or "on_surface_variant",
			textAlign = "center",
		}),
	})
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
					width = 260,
					height = 228,
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

		-- Horseshoe battery gauge with % in the center
		table.insert(body, gaugeBlock())

		table.insert(body, ui.separator({ thickness = 1, color = "on_surface/0.12" }))

		-- Noise control: 3 small circular buttons in one row
		-- (ui.box takes no children, so circles are rows with fill+radius)
		local currentMode = snapshot.noise_mode or "off"
		local function modeButton(key, mode, glyph)
			local active = currentMode == mode
			return ui.row({
				key = key,
				width = 52,
				height = 52,
				fill = active and "primary/0.28" or "on_surface/0.07",
				radius = 26,
				align = "center",
				justify = "center",
				onClick = function()
					sendCommand("set-noise", mode)
				end,
			}, {
				ui.glyph({
					name = glyph,
					size = 22,
					color = active and "primary" or "on_surface_variant",
				}),
			})
		end
		table.insert(body, ui.column({ gap = 8, align = "center" }, {
			ui.label({
				text = noctalia.tr("panel.noise_control"),
				fontSize = 11,
				fontWeight = "bold",
				color = "on_surface_variant",
			}),
			ui.row({ gap = 16, align = "center", justify = "center" }, {
				modeButton("mode-anc", "anc", "shield-check"),
				modeButton("mode-transparency", "transparency", "ear"),
				modeButton("mode-off", "off", "volume-off"),
			}),
		}))

		-- NOTE: no ambient-level control here by design: the XM5 does not
		-- report the level back, so a slider would display a fake value.
		-- Level is adjustable via IPC: `set-ambient 0..20`.
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

	panel.render(ui.column({ flexGrow = 1, gap = 8, padding = 10 }, {
		ui.row({ align = "center", justify = "space_between", gap = 8 }, {
			ui.glyph({
				name = connected and "headphones" or "headphones-off",
				size = 26,
				color = connected and "primary" or "on_surface_variant",
			}),
			ui.label({
				text = titleText,
				fontSize = 15,
				fontWeight = "bold",
				color = "on_surface",
				maxLines = 1,
				flexGrow = 1,
			}),
			ui.button({
				glyph = "close",
				variant = "ghost",
				onClick = "onCloseClicked",
			}),
		}),
		ui.scroll({ flexGrow = 1 }, {
			ui.column({ flexGrow = 1, gap = 10 }, body),
		}),
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
