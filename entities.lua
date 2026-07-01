local core = core or minetest
local pf = presence_footsteps

pf.entity_locomotion = dofile(pf.modpath .. "/data/entity_locomotion.lua")
pf.entity_locomotion_options = {}
pf.object_sounds = pf.golem_map and pf.golem_map.entities or {}
pf.object_item_sounds = pf.golem_map and pf.golem_map.itemstrings or {}

local states = {}
local timer = 0
local update_interval = 0.10
local teleport_distance = 8.00
local min_move_speed = 0.15
local run_enter_speed = 4.80
local run_stay_speed = 4.40
local max_remainder_multiplier = 0.65
local foliage_cooldown = 0.85

local profiles = {
	biped = {
		walk_distance = 1.45,
		run_distance = 1.85,
		walk_cooldown = 0.36,
		run_cooldown = 0.28,
	},
	quadruped = {
		walk_distance = 1.05,
		run_distance = 1.35,
		walk_cooldown = 0.24,
		run_cooldown = 0.18,
	},
	object = {
		walk_distance = 1.20,
		run_distance = 1.60,
		walk_cooldown = 0.30,
		run_cooldown = 0.22,
	},
}

local ignored_entities = {
	["mobs_mc:bat"] = true,
	["mobs_mc:bee"] = true,
	["mobs_mc:blaze"] = true,
	["mobs_mc:cod"] = true,
	["mobs_mc:dolphin"] = true,
	["mobs_mc:elder_guardian"] = true,
	["mobs_mc:ender_dragon"] = true,
	["mobs_mc:endermite"] = true,
	["mobs_mc:ghast"] = true,
	["mobs_mc:guardian"] = true,
	["mobs_mc:parrot"] = true,
	["mobs_mc:phantom"] = true,
	["mobs_mc:pufferfish"] = true,
	["mobs_mc:salmon"] = true,
	["mobs_mc:shulker_bullet"] = true,
	["mobs_mc:silverfish"] = true,
	["mobs_mc:slime"] = true,
	["mobs_mc:squid"] = true,
	["mobs_mc:tropical_fish"] = true,
	["mobs_mc:vex"] = true,
	["mobs_mc:wither"] = true,
}

local hostile_fragments = {
	"blaze", "bogged", "breeze", "creaking", "creeper", "drowned",
	"enderman", "evoker", "ghast", "guardian", "hoglin", "husk",
	"illusioner", "magma", "phantom", "piglin", "pillager", "ravager",
	"shulker", "skeleton", "slime", "spider", "stray", "vindicator",
	"warden", "witch", "wither", "zoglin", "zombie",
}

local ignored_fragments = {
	"arrow", "beam", "bobber", "charge", "crystal", "egg", "ender_eye",
	"fireball", "flying", "item_entity", "pearl", "potion", "shield",
	"snowball", "text", "tnt",
}

local user_ignored_entities = {}

local function rebuild_user_ignored_entities()
	user_ignored_entities = {}
	for name in tostring(pf.settings.ignored_entities or ""):gmatch("[^,%s]+") do
		user_ignored_entities[name:lower()] = true
	end
end

rebuild_user_ignored_entities()

function pf.register_entity_locomotion(entity_name, locomotion, opts)
	if not entity_name or entity_name == "" or not locomotion or locomotion == "" then
		return
	end
	pf.entity_locomotion[entity_name] = tostring(locomotion):lower()
	pf.entity_locomotion_options[entity_name] = opts or {}
end

function pf.register_object_sound(entity_name, acoustic_key)
	if not entity_name or entity_name == "" or not acoustic_key or acoustic_key == "" then
		return
	end
	pf.object_sounds[entity_name] = acoustic_key
end

local function vector_distance_xz(a, b)
	local dx = a.x - b.x
	local dz = a.z - b.z
	return math.sqrt(dx * dx + dz * dz)
end

local function round_pos(pos)
	return {
		x = math.floor(pos.x + 0.5),
		y = math.floor(pos.y + 0.5),
		z = math.floor(pos.z + 0.5),
	}
end

local function get_velocity(obj)
	if type(obj.get_velocity) == "function" then
		return obj:get_velocity() or { x = 0, y = 0, z = 0 }
	end
	return { x = 0, y = 0, z = 0 }
end

local function probe_ground(pos)
	local node = core.get_node_or_nil(round_pos({
		x = pos.x,
		y = pos.y - 0.6,
		z = pos.z,
	}))
	local def = node and core.registered_nodes[node.name]
	if def and def.walkable
		and (not pf.is_surface_candidate or pf.is_surface_candidate(node.name, def)) then
		return node
	end
	return nil
end

local function surface_info_at(pos)
	local feet_node = core.get_node_or_nil(round_pos(pos))
	local feet_def = feet_node and core.registered_nodes[feet_node.name]
	local ground_node = probe_ground(pos)
	local ground_def = ground_node and core.registered_nodes[ground_node.name]
	if pf.resolve_player_surface then
		return pf.resolve_player_surface(pos, feet_node, feet_def, ground_node, ground_def, false)
	end
	return {
		feet_node = feet_node,
		feet_def = feet_def,
		surface_node = ground_node,
		surface_def = ground_def,
		surface_acoustic = ground_node and pf.get_node_sound(ground_node.name),
		wet = false,
	}
end

local function contains_any(value, patterns)
	value = value or ""
	for _, pattern in ipairs(patterns) do
		if value:find(pattern, 1, true) then
			return true
		end
	end
	return false
end

local function object_acoustic(luaentity)
	if not luaentity then
		return nil
	end
	if luaentity._itemstring and pf.object_item_sounds[luaentity._itemstring] then
		return pf.object_item_sounds[luaentity._itemstring]
	end
	if type(luaentity._staticdata) == "table" and luaentity._staticdata.cart_type
		and pf.object_sounds[luaentity._staticdata.cart_type] then
		return pf.object_sounds[luaentity._staticdata.cart_type]
	end
	return pf.object_sounds[luaentity.name]
end

local function user_ignored(name)
	local lower = (name or ""):lower()
	return user_ignored_entities[lower] == true
end

local function classify_entity(luaentity, category)
	if category then
		return category
	end
	if luaentity.type == "monster" or luaentity._type == "monster"
		or contains_any(luaentity.name, hostile_fragments) then
		return "hostile"
	end
	return "passive"
end

local function target_allows(category)
	local targets = tostring(pf.settings.entity_targets or "all"):lower()
	if targets == "players_only" then
		return false
	end
	if targets == "players_and_hostiles" then
		return category == "hostile"
	end
	return true
end

local function options_for_entity(entity_name, category)
	local opts = {}
	for key, value in pairs(pf.entity_locomotion_options[entity_name] or {}) do
		opts[key] = value
	end
	local gain = 1
	if category == "object" then
		gain = pf.settings.object_gain or 1
	elseif category == "hostile" then
		gain = pf.settings.hostile_entity_gain or 1
	else
		gain = pf.settings.passive_entity_gain or 1
	end
	opts.gain_multiplier = (opts.gain_multiplier or 1) * gain
	return opts
end

local function get_locomotion(obj)
	local luaentity = obj:get_luaentity()
	if not luaentity or not luaentity.name then
		return nil, nil, nil, nil
	end
	if user_ignored(luaentity.name) or (luaentity.health and luaentity.health <= 0) then
		return nil, nil, nil, nil
	end
	if type(obj.get_attach) == "function" and obj:get_attach() then
		return nil, nil, nil, nil
	end
	local object_sound = object_acoustic(luaentity)
	if object_sound then
		return target_allows("object") and "object" or nil, luaentity.name, object_sound, "object"
	end
	if ignored_entities[luaentity.name] or contains_any(luaentity.name, ignored_fragments) then
		return nil, nil, nil, nil
	end
	local locomotion = pf.entity_locomotion[luaentity.name]
	if not locomotion or locomotion == "none" then
		return nil, nil, nil, nil
	end
	local category = classify_entity(luaentity)
	if not target_allows(category) then
		return nil, luaentity.name, nil, category
	end
	return locomotion, luaentity.name, nil, category
end

local function get_state(obj, pos)
	local state = states[obj]
	if not state then
		state = {
			last_pos = pos,
			distance = 0,
			last_step = 0,
			last_surface = nil,
			last_foliage = 0,
			running = false,
		}
		states[obj] = state
	end
	return state
end

local function update_entity(obj, elapsed, now)
	if not obj or not obj:is_valid() or obj:is_player() then
		return
	end
	local locomotion, entity_name, acoustic_override, category = get_locomotion(obj)
	if not locomotion then
		return
	end
	local profile = profiles[locomotion] or profiles.biped
	local pos = obj:get_pos()
	if not pos then
		return
	end
	local state = get_state(obj, pos)
	local moved = vector_distance_xz(pos, state.last_pos)
	if moved > teleport_distance then
		moved = 0
		state.distance = 0
	end

	local velocity = get_velocity(obj)
	local horizontal_speed = math.sqrt((velocity.x or 0) * (velocity.x or 0) + (velocity.z or 0) * (velocity.z or 0))
	if horizontal_speed < min_move_speed and elapsed > 0 then
		horizontal_speed = moved / elapsed
	end

	local surface_node = probe_ground(pos)
	local surface_info = surface_info_at(pos)
	surface_node = surface_info.surface_node or surface_node
	local surface_name = surface_node and surface_node.name
	local acoustic = acoustic_override or surface_info.surface_acoustic or (surface_name and pf.get_node_sound(surface_name))
	local wet_context = pf.is_wet_position and pf.is_wet_position(pos, surface_info) or surface_info.wet
	if not acoustic or horizontal_speed <= min_move_speed then
		state.distance = 0
		state.last_pos = pos
		return
	end

	state.distance = state.distance + moved
	local running = horizontal_speed >= (state.running and run_stay_speed or run_enter_speed)
	state.running = running
	local threshold = running and profile.run_distance or profile.walk_distance
	local cooldown = running and profile.run_cooldown or profile.walk_cooldown
	local event = running and "run" or "walk"

	if state.last_surface and state.last_surface ~= surface_name and now - state.last_step < cooldown then
		state.distance = math.min(state.distance, threshold * 0.70)
	end

	if state.distance >= threshold and now - state.last_step >= cooldown
		and pf.play_step(obj, acoustic, event,
			pf.apply_context_options and pf.apply_context_options(obj, options_for_entity(entity_name, category), {
				pos = pos,
				feet_node = surface_info.feet_node,
				feet_def = surface_info.feet_def,
				surface_node = surface_node,
				surface_def = surface_info.surface_def,
				surface_acoustic = acoustic,
				wet_acoustic = surface_info.wet_acoustic,
				wet = wet_context,
			}) or options_for_entity(entity_name, category)) then
		state.last_step = now
		state.last_surface = surface_name
		state.distance = math.min(math.max(state.distance - threshold, 0), threshold * max_remainder_multiplier)
		if wet_context and pf.settings.wet_surfaces then
			pf.play_step(obj, surface_info.wet_acoustic or "waterfine", event, {
				gain_multiplier = (pf.settings.wet_gain or 0.5) * ((pf.settings.passive_entity_gain or 1) * 0.65),
			})
		end
		local foliage = surface_info.feet_node and pf.get_foliage_sound and pf.get_foliage_sound(surface_info.feet_node.name)
		if category ~= "object" and foliage and now - (state.last_foliage or 0) > foliage_cooldown then
			pf.play_step(obj, foliage, "walk", {
				gain_multiplier = (pf.settings.foliage_gain or 0.65) * 0.45,
			})
			state.last_foliage = now
		end
	end
	state.last_pos = pos
end

function pf.audit_entities(limit)
	limit = limit or 20
	rebuild_user_ignored_entities()
	local stats = {
		total = 0,
		tracked = 0,
		ignored = 0,
		object = 0,
		passive = 0,
		hostile = 0,
		examples = {},
	}
	local seen = {}
	for _, player in ipairs(core.get_connected_players()) do
		local pos = player:get_pos()
		for _, obj in ipairs(core.get_objects_inside_radius(pos, pf.settings.max_hear_distance)) do
			if not seen[obj] and not obj:is_player() then
				seen[obj] = true
				stats.total = stats.total + 1
				local locomotion, entity_name, _, category = get_locomotion(obj)
				if locomotion then
					stats.tracked = stats.tracked + 1
					stats[category] = (stats[category] or 0) + 1
					if #stats.examples < limit then
						table.insert(stats.examples, ("%s:%s"):format(category, entity_name or "<unknown>"))
					end
				else
					stats.ignored = stats.ignored + 1
				end
			end
		end
	end
	return stats
end

core.register_chatcommand("presence_footsteps_entity_audit", {
	description = "Print Presence Footsteps tracked/ignored entity counts.",
	func = function()
		if not (pf.settings and pf.settings.debug) then
			return true, "presence_footsteps_debug is disabled."
		end
		local stats = pf.audit_entities(20)
		return true, ("total=%d tracked=%d ignored=%d object=%d passive=%d hostile=%d examples=%s")
			:format(stats.total, stats.tracked, stats.ignored, stats.object or 0,
				stats.passive or 0, stats.hostile or 0,
				#stats.examples > 0 and table.concat(stats.examples, ", ") or "<none>")
	end,
})

local function cleanup_states()
	for obj in pairs(states) do
		if not obj or not obj:is_valid() then
			states[obj] = nil
		end
	end
end

core.register_globalstep(function(dtime)
	if not pf.settings.enabled or not pf.settings.entities then
		return
	end
	if tostring(pf.settings.entity_targets or "all"):lower() == "players_only" then
		return
	end

	timer = timer + dtime
	if timer < update_interval then
		return
	end

	local elapsed = timer
	timer = 0
	local now = core.get_us_time() / 1000000
	local seen = {}
	local processed = 0
	local max_entities = math.floor(pf.settings.max_entities or 50)

	for _, player in ipairs(core.get_connected_players()) do
		local pos = player:get_pos()
		for _, obj in ipairs(core.get_objects_inside_radius(pos, pf.settings.max_hear_distance)) do
			if not seen[obj] and not obj:is_player() then
				seen[obj] = true
				update_entity(obj, elapsed, now)
				processed = processed + 1
				if processed >= max_entities then
					cleanup_states()
					return
				end
			end
		end
	end
	cleanup_states()
end)
