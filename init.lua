local core = core or minetest

presence_footsteps = rawget(_G, "presence_footsteps") or {}

local pf = presence_footsteps
pf.modname = core.get_current_modname()
pf.modpath = core.get_modpath(pf.modname)

local function setting_bool(name, default)
	local value = core.settings:get_bool(name)
	if value == nil then
		return default
	end
	return value
end

local function setting_number(name, default, min_value)
	local value = tonumber(core.settings:get(name))
	if value == nil then
		return default
	end
	if min_value ~= nil and value < min_value then
		return min_value
	end
	return value
end

local function setting_string(name, default)
	local value = core.settings:get(name)
	if value == nil or value == "" then
		return default
	end
	return value
end

local function build_settings()
	local settings = {
		enabled = setting_bool("presence_footsteps_enabled", true),
		gain = setting_number("presence_footsteps_gain", 1.0, 0),
		max_hear_distance = setting_number("presence_footsteps_max_hear_distance", 16, 1),
		replace_builtin = setting_bool("presence_footsteps_replace_builtin", true),
		replace_inferred_builtin = setting_bool("presence_footsteps_replace_inferred_builtin", true),
		stand_sounds = setting_bool("presence_footsteps_stand_sounds", false),
		foliage = setting_bool("presence_footsteps_foliage", true),
		foliage_gain = setting_number("presence_footsteps_foliage_gain", 0.65, 0),
		wet_surfaces = setting_bool("presence_footsteps_wet_surfaces", true),
		wet_gain = setting_number("presence_footsteps_wet_gain", 0.50, 0),
		footwear = setting_bool("presence_footsteps_footwear", true),
		player_gain = setting_number("presence_footsteps_player_gain", 1.0, 0),
		other_player_gain = setting_number("presence_footsteps_other_player_gain", 1.0, 0),
		entities = setting_bool("presence_footsteps_entities", false),
		max_entities = setting_number("presence_footsteps_max_entities", 50, 1),
		entity_targets = setting_string("presence_footsteps_entity_targets", "all"),
		ignored_entities = setting_string("presence_footsteps_ignored_entities", ""),
		passive_entity_gain = setting_number("presence_footsteps_passive_entity_gain", 0.70, 0),
		hostile_entity_gain = setting_number("presence_footsteps_hostile_entity_gain", 0.85, 0),
		object_gain = setting_number("presence_footsteps_object_gain", 0.75, 0),
		winged_players = setting_bool("presence_footsteps_winged_players", false),
		debug = setting_bool("presence_footsteps_debug", false),
	}

	settings.entity_targets = tostring(settings.entity_targets):lower()
	if settings.entity_targets ~= "all"
		and settings.entity_targets ~= "players_and_hostiles"
		and settings.entity_targets ~= "players_only" then
		settings.entity_targets = "all"
	end

	return settings
end

pf.settings = build_settings()

function pf.reload_settings()
	pf.settings = build_settings()
	pf.debug("settings reloaded after ModMenu save")
end

pf.sound_groups = dofile(pf.modpath .. "/data/sounds.lua")
pf.acoustics = dofile(pf.modpath .. "/data/acoustics.lua")
pf.block_map = dofile(pf.modpath .. "/data/block_map.lua")
pf.primitive_map = dofile(pf.modpath .. "/data/primitive_map.lua")
pf.biome_variance = dofile(pf.modpath .. "/data/biome_variance.lua")
pf.golem_map = dofile(pf.modpath .. "/data/golem_map.lua")

function pf.debug(message)
	if pf.settings.debug then
		core.log("action", "[presence_footsteps] " .. message)
	end
end

dofile(pf.modpath .. "/sound.lua")
dofile(pf.modpath .. "/nodes.lua")
dofile(pf.modpath .. "/equipment.lua")
dofile(pf.modpath .. "/tracker.lua")
dofile(pf.modpath .. "/entities.lua")
dofile(pf.modpath .. "/modmenu.lua")

core.register_on_mods_loaded(function()
	pf.rebuild_node_cache()
	if pf.settings.replace_builtin then
		pf.disable_builtin_footsteps()
	end
	core.log("action", ("[presence_footsteps] loaded %d mapped nodes, %d muted builtin nodes, %d sound groups")
		:format(pf.count_mapped_nodes(), pf.count_muted_nodes(), pf.count_sound_groups()))
end)
