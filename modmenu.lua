local core = core or minetest
local pf = presence_footsteps

-- ModMenu (Mod_Menu) settings screen, mirroring the layout of the original
-- Presence Footsteps PFOptionsScreen: disable toggle, volume group with
-- per-source sliders, layer toggles, entity options, and debugging.
-- The Luanti port has no resource-pack sound packs or update checker, and
-- block reports are replaced by the /presence_footsteps_* chat commands.

local api = rawget(_G, "mod_menu")
if type(api) ~= "table" or type(api.register_settings) ~= "function" then
	return
end

local VOLUME_MAX = 4.0

local function volume(key, label, default)
	return {
		key = key,
		type = "number",
		label = label,
		default = default,
		min = 0.0,
		max = VOLUME_MAX,
		ui = "slider",
		slider_style = "text_over_thumb",
	}
end

local commands_description = "Chat commands: /presence_footsteps_node, /presence_footsteps_trace, /presence_footsteps_audit, /presence_footsteps_entity_audit."

api.register_settings(core.get_current_modname(), {
	title = "Rich Footsteps",
	tabs = {
		{
			id = "general",
			label = "General",
			settings = {
				{
					key = "presence_footsteps_enabled",
					type = "bool",
					label = "Enabled",
					description = "Enable or disable Rich Footsteps completely.",
					default = true,
				},
				{
					type = "section",
					label = "Volume",
					children = {
						volume("presence_footsteps_gain", "Global volume", 1.0),
						{
							key = "presence_footsteps_max_hear_distance",
							type = "int",
							label = "Hear distance",
							description = "Positional sound range in nodes.",
							default = 16,
							min = 1,
							max = 64,
							ui = "slider",
						},
					},
				},
				{
					type = "section",
					label = "Built-in footsteps",
					children = {
						{
							key = "presence_footsteps_replace_builtin",
							type = "bool",
							label = "Mute built-in steps on mapped nodes",
							description = "Mute the game's built-in footsteps on nodes with known Rich Footsteps mappings.",
							default = true,
						},
						{
							key = "presence_footsteps_replace_inferred_builtin",
							type = "bool",
							label = "Also mute inferred nodes",
							description = "Also mute built-in footsteps on inferred group/name and blockmap fallback nodes.",
							default = true,
						},
					},
				},
			},
		},
		{
			id = "volumes",
			label = "Volumes",
			settings = {
				{
					type = "section",
					label = "Players",
					children = {
						volume("presence_footsteps_player_gain", "Your own steps", 1.0),
						volume("presence_footsteps_other_player_gain", "Other players", 1.0),
					},
				},
				{
					type = "section",
					label = "Entities",
					children = {
						volume("presence_footsteps_hostile_entity_gain", "Hostile entities", 0.85),
						volume("presence_footsteps_passive_entity_gain", "Passive entities", 0.70),
						volume("presence_footsteps_object_gain", "Objects (boats, minecarts...)", 0.75),
					},
				},
			},
		},
		{
			id = "layers",
			label = "Layers",
			settings = {
				{
					type = "section",
					label = "Foliage",
					children = {
						{
							key = "presence_footsteps_foliage",
							type = "bool",
							label = "Foliage brush sounds",
							default = true,
						},
						volume("presence_footsteps_foliage_gain", "Foliage volume", 0.65),
					},
				},
				{
					type = "section",
					label = "Wet surfaces",
					children = {
						{
							key = "presence_footsteps_wet_surfaces",
							type = "bool",
							label = "Wet layer sounds",
							default = true,
						},
						volume("presence_footsteps_wet_gain", "Wet layer volume", 0.50),
					},
				},
				{
					key = "presence_footsteps_footwear",
					type = "bool",
					label = "Footwear layers (armor boots)",
					default = true,
				},
				{
					key = "presence_footsteps_stand_sounds",
					type = "bool",
					label = "Rare standing sounds",
					default = false,
				},
			},
		},
		{
			id = "entities",
			label = "Entities and debug",
			settings = {
				{
					type = "section",
					label = "Entity footsteps",
					children = {
						{
							key = "presence_footsteps_entities",
							type = "bool",
							label = "Entity footsteps (experimental)",
							description = "Experimental. Applies fully after rejoining the world.",
							default = false,
						},
						{
							key = "presence_footsteps_entity_targets",
							type = "enum",
							label = "Tracked entities",
							values = { "all", "players_and_hostiles", "players_only" },
							default = "all",
						},
						{
							key = "presence_footsteps_max_entities",
							type = "int",
							label = "Max tracked entities",
							description = "Limit of simultaneously tracked entities. Edited as a plain number field (ModMenu otherwise shows a squeezed slider, an input box, and a value label at once).",
							default = 50,
							min = 1,
							max = 500,
							ui = "field",
						},
						{
							key = "presence_footsteps_ignored_entities",
							type = "string",
							label = "Ignored entities",
							description = "Comma-separated entity name fragments to skip, on top of the built-in ignore list.",
							default = "",
							advanced = true,
						},
						{
							key = "presence_footsteps_winged_players",
							type = "bool",
							label = "Winged player locomotion",
							description = "Opt-in API-controlled winged flight sounds.",
							default = false,
							advanced = true,
						},
					},
				},
				{
					type = "section",
					label = "Debugging",
					children = {
						{
							key = "presence_footsteps_debug",
							type = "bool",
							label = "Debug mode",
							description = commands_description,
							default = false,
							advanced = true,
						},
					},
				},
			},
		},
	},
	on_save = function()
		if pf and pf.reload_settings then
			pf.reload_settings()
		end
	end,
})
