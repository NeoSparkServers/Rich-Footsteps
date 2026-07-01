local core = core or minetest
local pf = presence_footsteps

local players = {}
local timer = 0
local update_interval = 0.05

local walk_distance = 1.85
local run_distance = 2.05
local climb_distance = 0.90
local stair_distance_multiplier = 0.75
local walk_cooldown = 0.45
local run_cooldown = 0.34
local climb_cooldown = 0.45
local swim_cooldown = 0.65
local foliage_cooldown = 0.65
local foliage_entry_cooldown = 0.70
local foliage_distance_min = 2.40
local foliage_distance_max = 3.30
local wander_cooldown = 1.05
local wander_after_step_gap = 0.30
local stand_min_time = 8.00
local stand_interval_min = 12.00
local stand_interval_max = 24.00
local jump_cooldown = 0.22
local land_cooldown = 0.20
local jump_step_suppress = 0.18
local land_step_suppress = 0.20
local min_air_time = 0.14
local takeoff_speed = 0.05
local moving_takeoff_speed = 0.75
local false_takeoff_timeout = 0.18
local moving_jump_speed = 0.35
local airborne_height = 0.07
local min_event_gap = 0.08
local min_move_speed = 0.20
local run_enter_speed = 5.10
local run_stay_speed = 4.80
local stair_y_threshold = 0.12
local wander_turn_dot = 0.15
local teleport_distance = 6.00
local max_distance_multiplier = 1.50
local max_remainder_multiplier = 0.75
local surface_transition_multiplier = 0.70
local trace_limit = 18
local wing_idle_interval = 0.85
local wing_fly_interval = 0.48
local wing_dash_interval = 0.30
local wing_coast_interval = 2.00
local wing_transition_time = 0.20
local wing_jump_rest_time = 0.70
local wing_gain = 0.55
local swift_gain = 0.45
local swift_large_fall_distance = 3.00
local quadruped_walk_multiplier = 1.12
local quadruped_run_multiplier = 1.05
local quadruped_second_delay = 0.10
local quadruped_second_gain = 0.55

pf.player_locomotion = pf.player_locomotion or {}

function pf.set_player_locomotion(name, locomotion)
	if not name or name == "" then
		return
	end
	locomotion = tostring(locomotion or "biped"):lower()
	if locomotion ~= "biped" and locomotion ~= "quadruped" and locomotion ~= "winged" then
		locomotion = "biped"
	end
	pf.player_locomotion[name] = locomotion
end

function pf.get_player_locomotion(name)
	return pf.player_locomotion[name] or "biped"
end

local ground_samples = {
	{ x = 0, z = 0 },
	{ x = 0.28, z = 0 },
	{ x = -0.28, z = 0 },
	{ x = 0, z = 0.28 },
	{ x = 0, z = -0.28 },
	{ x = 0.28, z = 0.28 },
	{ x = -0.28, z = 0.28 },
	{ x = 0.28, z = -0.28 },
	{ x = -0.28, z = -0.28 },
}

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

local function get_node(pos)
	return core.get_node_or_nil(pos)
end

local function get_def(node)
	return node and core.registered_nodes[node.name] or nil
end

local function get_feet_node(pos)
	local feet_pos = round_pos(pos)
	local feet_node = get_node(feet_pos)
	return feet_node, get_def(feet_node)
end

local function probe_ground(pos)
	local fallback_node
	local fallback_def

	for index, sample in ipairs(ground_samples) do
		local sample_pos = round_pos({
			x = pos.x + sample.x,
			y = pos.y - 0.6,
			z = pos.z + sample.z,
		})
		local node = get_node(sample_pos)
		local def = get_def(node)
		if def and def.walkable
			and (not pf.is_surface_candidate or pf.is_surface_candidate(node.name, def)) then
			if index == 1 then
				return node, def, true
			end
			fallback_node = fallback_node or node
			fallback_def = fallback_def or def
		end
	end

	return fallback_node, fallback_def, fallback_node ~= nil
end

local function liquid_acoustic(def, node_name)
	if not def or not def.liquidtype or def.liquidtype == "none" then
		return nil
	end
	if node_name and node_name:find("lava", 1, true) then
		return "swim_lava"
	end
	return "swim_water"
end

local wet_events = {
	walk = true,
	run = true,
	up = true,
	up_run = true,
	down = true,
	down_run = true,
}

local function copy_options(opts)
	local result = {}
	for key, value in pairs(opts or {}) do
		result[key] = value
	end
	return result
end

local function scaled_options(opts, multiplier)
	local result = copy_options(opts)
	result.gain_multiplier = (result.gain_multiplier or 1) * multiplier
	return result
end

local function safe_call(fn, ...)
	if type(fn) ~= "function" then
		return nil
	end
	local ok, result = pcall(fn, ...)
	if ok then
		return result
	end
	return nil
end

local function normalize_biome_name(name)
	if not name then
		return nil
	end
	return tostring(name):lower():gsub("^minecraft:", ""):gsub("[^%w]", "")
end

function pf.get_biome_variance(pos)
	if not pos or not pf.biome_variance then
		return nil
	end
	local name
	local dispatch = rawget(_G, "mcl_biome_dispatch")
	if dispatch then
		name = safe_call(dispatch.get_biome_name, pos)
	end
	if not name and core.get_biome_data and core.get_biome_name then
		local data = safe_call(core.get_biome_data, pos)
		if data and data.biome then
			name = safe_call(core.get_biome_name, data.biome)
		end
	end
	if not name then
		return nil
	end

	local aliases = pf.biome_variance.aliases or {}
	return aliases[name] or aliases[normalize_biome_name(name)]
end

local function apply_context_options(player, opts, context)
	local result = copy_options(opts)
	if context and context.pos then
		local variance = pf.get_biome_variance(context.pos)
		if variance then
			result.gain_multiplier = (result.gain_multiplier or 1) * (tonumber(variance.volume) or 1)
			result.pitch_multiplier = (result.pitch_multiplier or 1) * (tonumber(variance.pitch) or 1)
		end
	end
	if player and type(player.is_player) == "function" and player:is_player() then
		result.audience_gain = {
			self = pf.settings.player_gain or 1,
			other = pf.settings.other_player_gain or 1,
		}
	end
	return result
end
pf.apply_context_options = apply_context_options

function pf.is_wet_position(pos, context)
	if not pf.settings.wet_surfaces or not pos then
		return false
	end
	if pf.is_wet_context and pf.is_wet_context(context) then
		return true
	end
	local weather = rawget(_G, "mcl_weather")
	if not weather then
		return false
	end
	local state = safe_call(weather.get_weather) or weather.state
	if state ~= "rain" and state ~= "thunder" then
		return false
	end
	local has_rain = safe_call(weather.has_rain, pos)
	if has_rain == false then
		return false
	end
	local outdoor = safe_call(weather.is_outdoor, pos)
	if outdoor == nil then
		outdoor = safe_call(weather.can_see_outdoors, pos)
	end
	return outdoor ~= false
end

local function play_for_surface(player, node_name, event_name, opts, context)
	local acoustic = context and context.surface_node and context.surface_node.name == node_name
		and context.surface_acoustic or nil
	acoustic = acoustic or pf.get_node_sound(node_name)
	if not acoustic then
		return false
	end

	opts = apply_context_options(player, opts, context)
	local footwear_acoustic
	local footwear_opts
	if pf.get_footwear_sound then
		footwear_acoustic, footwear_opts = pf.get_footwear_sound(player)
	end

	local played = false
	local surface_opts = opts
	if footwear_acoustic then
		surface_opts = scaled_options(opts, (footwear_opts and footwear_opts.surface_gain) or 0.50)
	end
	played = pf.play_step(player, acoustic, event_name, surface_opts) or played

	if footwear_acoustic then
		local gain = (footwear_opts and footwear_opts.gain_multiplier) or 1.00
		played = pf.play_step(player, footwear_acoustic, event_name, scaled_options(opts, gain)) or played
	end

	if wet_events[event_name or "walk"] and context and pf.is_wet_position(context.pos, context) then
		played = pf.play_step(player, context.wet_acoustic or "waterfine", event_name, scaled_options(opts, pf.settings.wet_gain)) or played
	end

	return played
end
pf.play_surface_step = play_for_surface

local function clamp_distance(distance, threshold)
	return math.min(distance, threshold * max_distance_multiplier)
end

local function consume_distance(distance, threshold)
	local remainder = math.max(distance - threshold, 0)
	return math.min(remainder, threshold * max_remainder_multiplier)
end

local function add_trace(state, now, event_name, detail)
	state.trace = state.trace or {}
	local entry = ("%8.2f %s"):format(now, event_name)
	if detail and detail ~= "" then
		entry = entry .. " " .. detail
	end
	table.insert(state.trace, entry)
	while #state.trace > trace_limit do
		table.remove(state.trace, 1)
	end
end

local function reset_player(name, player)
	local pos = player:get_pos()
	players[name] = {
		phase = "grounded",
		last_pos = pos,
		last_y = pos.y,
		last_velocity_y = 0,
		distance = 0,
		step_y = pos.y,
		ground_contact = false,
		was_ground_contact = false,
		jump_consumed_for_contact = false,
		takeoff_y = pos.y,
		takeoff_surface = nil,
		airborne_confirmed = false,
		descending = false,
		last_airborne_time = 0,
		last_step = 0,
		last_jump = 0,
		last_land = 0,
		last_swim = 0,
		last_foliage = 0,
		foliage_distance = 0,
		last_foliage_name = nil,
		next_foliage_distance = foliage_distance_min + math.random() * (foliage_distance_max - foliage_distance_min),
		last_wander = 0,
		last_stand = 0,
		next_stand_interval = stand_interval_min + math.random() * (stand_interval_max - stand_interval_min),
		next_wing = 0,
		wing_state = "idle",
		quad_phase = 0,
		max_air_y = pos.y,
		last_locomotion_sound = 0,
		suppress_steps_until = 0,
		running = false,
		horizontal_speed = 0,
		was_moving = false,
		still_since = nil,
		last_move_dir_x = nil,
		last_move_dir_z = nil,
		last_event = nil,
		last_step_event = nil,
		last_surface_name = nil,
		current_surface_name = nil,
		last_step_surface_name = nil,
		trace = {},
	}
	return players[name]
end

local function mark_locomotion(state, now, event_name, suppress_time, detail)
	state.last_locomotion_sound = now
	state.last_event = event_name
	state.suppress_steps_until = math.max(state.suppress_steps_until or 0, now + (suppress_time or 0))
	add_trace(state, now, event_name, detail)
end

local function set_airborne_confirmed(state, now, detail)
	if not state.airborne_confirmed then
		state.airborne_confirmed = true
		state.phase = "airborne"
		state.last_airborne_time = now
		add_trace(state, now, "airborne_confirmed", detail)
	end
end

local function update_motion_memory(state, pos, moved, moving, now)
	if moving and moved > 0.01 then
		state.last_move_dir_x = (pos.x - state.last_pos.x) / moved
		state.last_move_dir_z = (pos.z - state.last_pos.z) / moved
		state.still_since = nil
	elseif not moving and state.was_moving then
		state.still_since = now
	end
	state.was_moving = moving
end

local function reset_false_takeoff(state, now, detail)
	state.phase = "grounded"
	state.airborne_confirmed = false
	state.descending = false
	state.takeoff_surface = nil
	state.ground_contact = true
	state.distance = 0
	state.jump_consumed_for_contact = true
	add_trace(state, now, "cancel_takeoff", detail)
end

local function get_foliage_acoustic(feet_node, feet_def, surface_name)
	if not pf.settings.foliage or not feet_node then
		return nil, nil
	end
	if feet_node.name == surface_name and feet_def and feet_def.walkable then
		return nil, nil
	end
	local acoustic = pf.get_foliage_sound and pf.get_foliage_sound(feet_node.name)
	return acoustic, acoustic and feet_node.name or nil
end

local function next_foliage_threshold()
	return foliage_distance_min + math.random() * (foliage_distance_max - foliage_distance_min)
end

local function is_winged_player(name)
	return pf.settings.winged_players and pf.get_player_locomotion(name) == "winged"
end

local function wing_state_for(horizontal_speed, velocity_y)
	if horizontal_speed > 7.0 then
		return "dashing"
	end
	if horizontal_speed > 4.0 and math.abs(velocity_y) < 0.35 then
		return "coasting"
	end
	if horizontal_speed > 1.5 then
		return "flying"
	end
	if velocity_y > 0.5 then
		return "ascending"
	end
	if velocity_y < -0.5 then
		return "descending"
	end
	return "idle"
end

local function update_winged_air(player, state, now, horizontal_speed, velocity_y, liquid_key)
	if liquid_key or not is_winged_player(player:get_player_name()) then
		return
	end
	if state.phase ~= "takeoff" and state.phase ~= "airborne" then
		return
	end
	if velocity_y < -3.5 and horizontal_speed < 2.0 then
		return
	end

	local wing_state = wing_state_for(horizontal_speed, velocity_y)
	if wing_state ~= state.wing_state then
		state.wing_state = wing_state
		state.next_wing = math.max(state.next_wing or 0, now + wing_transition_time)
		add_trace(state, now, "wing_state", wing_state)
	end

	local interval = wing_idle_interval
	if wing_state == "dashing" then
		interval = wing_dash_interval
	elseif wing_state == "coasting" then
		interval = wing_coast_interval
	elseif wing_state == "flying" or wing_state == "ascending" then
		interval = wing_fly_interval
	end
	if now >= (state.next_wing or 0)
		and pf.play_step(player, "wing", "walk", apply_context_options(player, {
			gain_multiplier = wing_gain,
		}, { pos = player:get_pos() })) then
		state.next_wing = now + interval + math.random() * 0.08
		add_trace(state, now, "wing", ("%s speed=%.2f"):format(wing_state, horizontal_speed))
	end
end

local function play_quadruped_followup(player, state, surface_name, event, sound_context, delay)
	local player_name = player:get_player_name()
	core.after(delay, function()
		local delayed_player = core.get_player_by_name(player_name)
		if delayed_player then
			play_for_surface(delayed_player, surface_name, event, {
				gain_multiplier = quadruped_second_gain,
			}, sound_context)
		end
	end)
	state.quad_phase = ((state.quad_phase or 0) + 1) % 4
end

local function update_player(player, dtime)
	local name = player:get_player_name()
	local state = players[name] or reset_player(name, player)
	local pos = player:get_pos()
	local velocity = player:get_velocity() or { x = 0, y = 0, z = 0 }
	local controls = player:get_player_control() or {}

	if not state.last_pos then
		state.last_pos = pos
		state.last_y = pos.y
		return
	end

	local feet_node, feet_def = get_feet_node(pos)
	local ground_node, ground_def, probe_contact = probe_ground(pos)
	local liquid_key = liquid_acoustic(feet_def, feet_node and feet_node.name)
	local climbing = feet_def and feet_def.climbable
	local velocity_y = velocity.y or 0
	local vertical_delta = pos.y - (state.last_y or pos.y)
	local horizontal_speed = math.sqrt((velocity.x or 0) * (velocity.x or 0) + (velocity.z or 0) * (velocity.z or 0))
	local moved = vector_distance_xz(pos, state.last_pos)
	local now = core.get_us_time() / 1000000
	local surface_info = pf.resolve_player_surface
		and pf.resolve_player_surface(pos, feet_node, feet_def, ground_node, ground_def, climbing)
		or { surface_node = climbing and feet_node or ground_node, surface_def = climbing and feet_def or ground_def }
	local surface_node = surface_info.surface_node
	local surface_name = surface_node and surface_node.name or state.current_surface_name or state.takeoff_surface or state.last_surface_name
	local locomotion = pf.get_player_locomotion(name)
	local sound_context = {
		pos = pos,
		feet_node = feet_node,
		feet_def = feet_def,
		surface_node = surface_node,
		surface_def = surface_info.surface_def,
		surface_acoustic = surface_info.surface_acoustic,
		wet_acoustic = surface_info.wet_acoustic,
		wet = surface_info.wet,
	}
	local event_played = false
	local step_played = false
	state.locomotion = locomotion

	if moved > teleport_distance then
		moved = 0
		state.distance = 0
		state.step_y = pos.y
	end

	if liquid_key then
		if (horizontal_speed > min_move_speed or math.abs(velocity_y) > 0.15) and now - state.last_swim > swim_cooldown then
			pf.play_step(player, liquid_key, "swim", apply_context_options(player, nil, sound_context))
			state.last_swim = now
			mark_locomotion(state, now, "swim", 0, liquid_key)
		end
		state.phase = "grounded"
		state.distance = 0
		state.step_y = pos.y
		state.ground_contact = true
		state.was_ground_contact = true
		state.jump_consumed_for_contact = false
		state.airborne_confirmed = false
		state.descending = false
		state.current_surface_name = surface_name
		state.last_surface_name = surface_name
		state.last_pos = pos
		state.last_y = pos.y
		state.last_velocity_y = velocity_y
		return
	end

	local in_jump_cycle = state.phase == "takeoff" or state.phase == "airborne"
	local descending_now = state.descending
		or (state.airborne_confirmed and (velocity_y < -0.02 or vertical_delta < -0.01))
	local landing_contact = probe_contact and state.airborne_confirmed
		and descending_now
		and now - (state.last_airborne_time or 0) >= min_air_time
		and now - (state.last_land or 0) > land_cooldown
	local ground_contact = probe_contact and not in_jump_cycle
	if climbing then
		ground_contact = true
	end

	state.ground_contact = ground_contact
	state.current_surface_name = surface_name
	state.horizontal_speed = horizontal_speed
	state.descending = descending_now
	if state.phase == "takeoff" or state.phase == "airborne" then
		state.max_air_y = math.max(state.max_air_y or pos.y, pos.y)
	end

	if landing_contact then
		local fall_distance = math.max((state.max_air_y or state.takeoff_y or pos.y) - pos.y, 0)
		if surface_name then
			play_for_surface(player, surface_name, "land", {
				single_layer = true,
				prefer_sound_contains = "_land",
			}, sound_context)
			if is_winged_player(name) and (fall_distance >= swift_large_fall_distance or horizontal_speed > 2.0) then
				pf.play_step(player, "swift", "land", apply_context_options(player, {
					gain_multiplier = swift_gain * math.min(2.0, math.max(1.0, fall_distance / swift_large_fall_distance)),
				}, sound_context))
				add_trace(state, now, "swift_land", ("fall=%.2f %s"):format(fall_distance, surface_name))
			end
		end
		state.phase = "grounded"
		state.last_land = now
		state.distance = 0
		state.step_y = pos.y
		state.jump_consumed_for_contact = false
		state.airborne_confirmed = false
		state.descending = false
		state.takeoff_surface = nil
		state.max_air_y = pos.y
		state.ground_contact = true
		mark_locomotion(state, now, "land", land_step_suppress,
			("land:single_layer locomotion=%s fall=%.2f %s"):format(locomotion, fall_distance, tostring(surface_name)))
		event_played = true
	elseif not in_jump_cycle and ground_contact and controls.jump == true
		and not state.jump_consumed_for_contact
		and now - (state.last_jump or 0) > jump_cooldown
		and (
			velocity_y > moving_takeoff_speed
			or (horizontal_speed <= moving_jump_speed and (velocity_y > takeoff_speed or vertical_delta > 0.01))
		) then
		state.phase = "takeoff"
		state.takeoff_y = pos.y
		state.max_air_y = pos.y
		state.takeoff_surface = surface_name
		state.last_jump = now
		state.distance = 0
		state.jump_consumed_for_contact = true
		state.airborne_confirmed = false
		state.descending = false
		state.ground_contact = false

		if horizontal_speed <= moving_jump_speed and surface_name then
			play_for_surface(player, surface_name, "jump", nil, sound_context)
			mark_locomotion(state, now, "takeoff", jump_step_suppress, surface_name)
		else
			mark_locomotion(state, now, "takeoff", jump_step_suppress, "silent")
		end
		if is_winged_player(name) then
			pf.play_step(player, "swift", "jump", apply_context_options(player, {
				gain_multiplier = swift_gain,
			}, sound_context))
			add_trace(state, now, "swift_jump", surface_name or "<none>")
		end
		event_played = true
	elseif in_jump_cycle then
		local height_from_takeoff = pos.y - (state.takeoff_y or pos.y)
		if not probe_contact then
			set_airborne_confirmed(state, now, "no_contact")
		elseif height_from_takeoff > airborne_height
			and (velocity_y > moving_takeoff_speed or horizontal_speed <= moving_jump_speed) then
			set_airborne_confirmed(state, now, "height")
		elseif velocity_y < -0.05 or vertical_delta < -0.02 then
			set_airborne_confirmed(state, now, "falling")
		elseif velocity_y > takeoff_speed or vertical_delta > 0.01 then
			state.phase = "takeoff"
		elseif not state.airborne_confirmed
			and probe_contact
			and now - (state.last_jump or 0) > false_takeoff_timeout then
			reset_false_takeoff(state, now, "probe_contact")
		end
	elseif not probe_contact and not climbing then
		state.phase = "airborne"
		state.takeoff_y = pos.y
		state.max_air_y = pos.y
		state.takeoff_surface = state.last_surface_name
		state.distance = 0
		set_airborne_confirmed(state, now, "walked_off")
	end

	if event_played then
		update_motion_memory(state, pos, moved, horizontal_speed > min_move_speed, now)
		state.was_ground_contact = state.ground_contact
		state.last_surface_name = surface_name
		state.last_pos = pos
		state.last_y = pos.y
		state.last_velocity_y = velocity_y
		return
	end

	update_winged_air(player, state, now, horizontal_speed, velocity_y, liquid_key)

	local steps_suppressed = now < (state.suppress_steps_until or 0)
	if steps_suppressed then
		if horizontal_speed > min_move_speed then
			add_trace(state, now, "skip_step_suppressed", state.last_event or "")
			pf.debug(name .. " skip_step_suppressed after " .. tostring(state.last_event))
		end
		state.distance = 0
	end

	local can_step = (state.phase == "grounded" or climbing) and ground_contact and not steps_suppressed
	if can_step then
		state.distance = state.distance + moved
		local running = horizontal_speed >= (state.running and run_stay_speed or run_enter_speed)
		state.running = running
		local event = running and "run" or "walk"
		local threshold = running and run_distance or walk_distance
		local cooldown = running and run_cooldown or walk_cooldown
		if locomotion == "quadruped" then
			threshold = threshold * (running and quadruped_run_multiplier or quadruped_walk_multiplier)
		end
		if climbing then
			event = running and "climb_run" or "climb"
			threshold = climb_distance
			cooldown = climb_cooldown
		else
			local height_change = pos.y - (state.step_y or pos.y)
			if height_change >= stair_y_threshold then
				event = running and "up_run" or "up"
				threshold = threshold * stair_distance_multiplier
			elseif height_change <= -stair_y_threshold then
				event = running and "down_run" or "down"
				threshold = threshold * stair_distance_multiplier
			end
		end

		local foliage_acoustic, foliage_name = get_foliage_acoustic(feet_node, feet_def, surface_name)
		if foliage_acoustic and horizontal_speed > min_move_speed then
			local entering_foliage = foliage_name ~= state.last_foliage_name
			state.foliage_distance = (state.foliage_distance or 0) + moved
			state.next_foliage_distance = state.next_foliage_distance or next_foliage_threshold()

			local enough_time = now - state.last_foliage > foliage_cooldown
			local entry_ready = entering_foliage and now - state.last_foliage > foliage_entry_cooldown
			local distance_ready = state.foliage_distance >= state.next_foliage_distance
			if (entry_ready or (enough_time and distance_ready))
				and pf.play_step(player, foliage_acoustic, "walk", {
					gain_multiplier = pf.settings.foliage_gain,
				}) then
				state.last_foliage = now
				state.foliage_distance = 0
				state.next_foliage_distance = next_foliage_threshold()
				add_trace(state, now, "foliage", ("%s %s"):format(entering_foliage and "entry" or "brush", tostring(foliage_name)))
			end
			state.last_foliage_name = foliage_name
		else
			state.foliage_distance = 0
			state.last_foliage_name = nil
		end

		local surface_changed = surface_name and state.last_surface_name and surface_name ~= state.last_surface_name
		if surface_changed and now - state.last_step < cooldown then
			state.distance = math.min(state.distance, threshold * surface_transition_multiplier)
			add_trace(state, now, "surface_clamp", state.last_surface_name .. " -> " .. surface_name)
			pf.debug(name .. " surface_transition_clamp " .. state.last_surface_name .. " -> " .. surface_name)
		end

		if horizontal_speed > min_move_speed and state.distance >= threshold then
			if now - state.last_step < cooldown or now - state.last_locomotion_sound < min_event_gap then
				state.distance = clamp_distance(state.distance, threshold)
			elseif surface_name and play_for_surface(player, surface_name, event, nil, sound_context) then
				state.last_step = now
				state.last_step_surface_name = surface_name
				state.last_step_event = event
				state.step_y = pos.y
				if locomotion == "quadruped" and event ~= "climb" and event ~= "climb_run" then
					play_quadruped_followup(player, state, surface_name, event, sound_context,
						running and quadruped_second_delay * 0.7 or quadruped_second_delay)
				end
				mark_locomotion(state, now, "step", 0,
					("%s speed=%.2f locomotion=%s quad_phase=%d wing_state=%s %s")
						:format(event, horizontal_speed, locomotion, state.quad_phase or 0,
							state.wing_state or "idle", surface_name))
				state.distance = consume_distance(state.distance, threshold)
				step_played = true
			else
				state.distance = math.min(state.distance, threshold)
			end
		end
	else
		state.distance = 0
	end

	local moving = horizontal_speed > min_move_speed and moved > 0.01
	if can_step and surface_name and not step_played and not steps_suppressed
		and now - state.last_wander > wander_cooldown
		and now - state.last_locomotion_sound > min_event_gap then
		local play_wander = false
		local detail = nil
		if moving and moved > 0.02 and state.last_move_dir_x and state.last_move_dir_z then
			local dir_x = (pos.x - state.last_pos.x) / moved
			local dir_z = (pos.z - state.last_pos.z) / moved
			local dot = dir_x * state.last_move_dir_x + dir_z * state.last_move_dir_z
			if dot < wander_turn_dot and now - state.last_step > wander_after_step_gap then
				play_wander = true
				detail = ("turn %.2f %s"):format(dot, surface_name)
			end
		elseif not moving and state.was_moving and now - state.last_step > wander_after_step_gap then
			play_wander = true
			detail = "stop " .. surface_name
		end

		if play_wander and play_for_surface(player, surface_name, "wander", {
			gain_multiplier = 0.55,
		}, sound_context) then
			state.last_wander = now
			mark_locomotion(state, now, "wander", 0.10, detail)
		end
	end

	if pf.settings.stand_sounds and can_step and surface_name and not moving and not step_played
		and now >= (state.suppress_steps_until or 0) then
		state.still_since = state.still_since or now
		if now - state.still_since >= stand_min_time
			and now - state.last_stand >= (state.next_stand_interval or stand_interval_min)
			and play_for_surface(player, surface_name, "stand", {
				gain_multiplier = 0.25,
			}, sound_context) then
			state.last_stand = now
			state.next_stand_interval = stand_interval_min + math.random() * (stand_interval_max - stand_interval_min)
			mark_locomotion(state, now, "stand", 0, surface_name)
		end
	end

	if not in_jump_cycle and ground_contact then
		state.phase = "grounded"
	end

	update_motion_memory(state, pos, moved, moving, now)
	state.was_ground_contact = state.ground_contact
	state.last_surface_name = surface_name
	state.last_pos = pos
	state.last_y = pos.y
	state.last_velocity_y = velocity_y
end

function pf.get_player_tracker_info(name)
	local state = players[name]
	if not state then
		return nil
	end
	local now = core.get_us_time() / 1000000
	return {
		phase = state.phase or "<none>",
		ground_contact = state.ground_contact and "yes" or "no",
		was_ground_contact = state.was_ground_contact and "yes" or "no",
		jump_consumed = state.jump_consumed_for_contact and "yes" or "no",
		airborne_confirmed = state.airborne_confirmed and "yes" or "no",
		descending = state.descending and "yes" or "no",
		takeoff_surface = state.takeoff_surface or "<none>",
		current_surface = state.current_surface_name or "<none>",
		last_surface = state.last_surface_name or "<none>",
		last_step_surface = state.last_step_surface_name or "<none>",
		distance = state.distance or 0,
		running = state.running and "yes" or "no",
		horizontal_speed = state.horizontal_speed or 0,
		locomotion = state.locomotion or "biped",
		quad_phase = state.quad_phase or 0,
		wing_state = state.wing_state or "idle",
		last_event = state.last_event or "<none>",
		suppression = math.max((state.suppress_steps_until or 0) - now, 0),
	}
end

function pf.get_player_tracker_trace(name)
	local state = players[name]
	if not state or not state.trace then
		return {}
	end
	local result = {}
	for i, entry in ipairs(state.trace) do
		result[i] = entry
	end
	return result
end

core.register_globalstep(function(dtime)
	if not pf.settings.enabled then
		return
	end

	timer = timer + dtime
	if timer < update_interval then
		return
	end

	local elapsed = timer
	timer = 0
	for _, player in ipairs(core.get_connected_players()) do
		update_player(player, elapsed)
	end
end)

core.register_on_leaveplayer(function(player)
	if player then
		players[player:get_player_name()] = nil
	end
end)
