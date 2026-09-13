--!nonstrict
-- Panel for Sony Pods
-- Device photo, horseshoe battery gauge (% in the center), 3 noise mode buttons.

local SNAPSHOT_KEY = "sony_pods_snapshot"
local COMMAND_KEY = "sony_pods_command"

local snapshot = noctalia.state.get(SNAPSHOT_KEY) or {}

-- Forward declaration: render() is defined below but used by callbacks above.
local render

-- User-provided device artwork: per-model black/white variants from assets/.
-- The subtle photo button at the bottom cycles the variant (session-local).
-- (snapshot.device_image from the backend, e.g. a downloaded render,
-- takes precedence when set.)
local DEVICE_ART = {
	["WH-1000XM6"] = { black = "assets/wh_1000xm6_black.webp", white = "assets/wh_1000xm6_white.webp" },
	["WH-1000XM5"] = { black = "assets/wh_1000xm5_black.webp", white = "assets/wh_1000xm5_white.webp" },
	["WH-1000XM4"] = { black = "assets/wh_1000xm4_black.webp", white = "assets/wh_1000xm4_white.webp" },
	["WF-1000XM5"] = { black = "assets/wf_1000xm5_black.webp", white = "assets/wf_1000xm5_white.webp" },
	["WF-1000XM6"] = { black = "assets/wf_1000xm6_black.webp", white = "assets/wf_1000xm6_white.webp" },
	["WH-1000MX4C"] = { black = "assets/wh_1000mx4c_black.webp", white = "assets/wh_1000mx4c_siver.webp" },
	["WH-CH720N"] = { black = "assets/wh_ch730n_black.webp", white = "assets/wh_ch730n_white.webp" },
}
local artVariant = "black"

local function deviceImagePath()
	if snapshot.device_image and snapshot.device_image ~= "" then
		return snapshot.device_image
	end
	local model = snapshot.model_name or snapshot.device_name
	local variants = model and DEVICE_ART[model]
	if variants then
		return variants[artVariant] or variants.black
	end
	return nil
end

function onCycleArtwork()
	artVariant = (artVariant == "black") and "white" or "black"
	render()
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

-- Mode-switch animation state: crossfade the accent from animFrom to
-- animTo over ANIM_MS; pendingMode masks the slow Bluetooth poll so the
-- UI flips instantly and never snaps back mid-flight.
local ANIM_MS = 220
local animFrom = nil
local animTo = nil
local animT = 1
local pendingMode = nil
local pendingSince = 0

function onModeClicked(mode)
	local current = pendingMode or snapshot.noise_mode or "off"
	if mode == current then
		return
	end
	animFrom = current
	animTo = mode
	animT = 0
	pendingMode = mode
	pendingSince = noctalia.nowMs()
	panel.setNeedsFrameTick(true)
	sendCommand("set-noise", mode)
	render()
end

function onFrameTick(deltaMs)
	if animT < 1 then
		animT = math.min(1, animT + (tonumber(deltaMs) or 16) / ANIM_MS)
		render()
	end
	if pendingMode then
		if snapshot.noise_mode == pendingMode or (noctalia.nowMs() - pendingSince) > 6000 then
			pendingMode = nil
		end
	end
	if animT >= 1 and not pendingMode then
		animFrom = nil
		animTo = nil
		panel.setNeedsFrameTick(false)
	end
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
			width = 260,
			height = 28,
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

	return ui.column({ gap = 2, align = "center" }, {
		ui.label({
			text = snapshot.charging and noctalia.tr("panel.charging") or noctalia.tr("panel.battery"),
			fontSize = 11,
			fontWeight = "bold",
			color = "on_surface_variant",
			textAlign = "center",
		}),
		barNode,
		ui.label({
			text = hasLevel and (tostring(bLevel) .. "%") or "--%",
			fontSize = 16,
			fontWeight = "medium",
			color = low and "error" or "on_surface_variant",
			textAlign = "center",
		}),
	})
end

render = function()
	local connected = snapshot.connected == true
	local body = {}

	if connected then
		-- Device artwork (user assets) or a fallback glyph
		local artPath = deviceImagePath()
		if artPath then
			table.insert(body, ui.row({
				align = "center",
				justify = "center",
				padding = 0,
			}, {
				ui.image({
					path = artPath,
					width = 200,
					height = 175,
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

		-- Noise control: 3 small circular buttons in one row.
		-- (ui.box takes no children, so circles are rows with fill+radius.)
		-- Active button is solid accent; switching crossfades the accent
		-- from the old to the new button over ~220ms via frame ticks.
		local currentMode = pendingMode or snapshot.noise_mode or "off"
		local function heatFor(mode)
			if animFrom and animTo then
				if mode == animTo then
					return animT
				elseif mode == animFrom then
					return 1 - animT
				end
			end
			return (mode == currentMode) and 1 or 0
		end
		local function modeButton(key, mode, glyph)
			local h = heatFor(mode)
			local fill = (h >= 1) and "primary" or string.format("primary/%.2f", 0.07 + 0.93 * h)
			return ui.row({
				key = key,
				width = 35,
				height = 35,
				fill = fill,
				radius = 17,
				align = "center",
				justify = "center",
				onClick = function()
					onModeClicked(mode)
				end,
			}, {
				ui.glyph({
					name = glyph,
					size = 15,
					color = (h > 0.5) and "on_primary" or "on_surface_variant",
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

		-- Subtle artwork variant toggle (black/white unit color)
		local model = snapshot.model_name or snapshot.device_name
		if model and DEVICE_ART[model] and DEVICE_ART[model].white then
			table.insert(body, ui.row({ justify = "center" }, {
				ui.button({
					key = "art-toggle",
					glyph = "photo",
					glyphSize = 13,
					variant = "ghost",
					onClick = "onCycleArtwork",
				}),
			}))
		end

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

	panel.render(ui.column({ flexGrow = 1, gap = 6, padding = 10 }, {
		ui.label({
			text = titleText,
			fontSize = 15,
			fontWeight = "bold",
			color = "on_surface",
			maxLines = 1,
			textAlign = "center",
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
