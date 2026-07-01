local core = core or minetest
local pf = presence_footsteps

local event_fallback = {
	stand = "wander",
	run = "walk",
	jump = "wander",
	land = "run",
	climb = "walk",
	climb_run = "run",
	down = "walk",
	down_run = "run",
	up = "walk",
	up_run = "run",
}

local function random_range(value, fallback)
	if type(value) == "table" then
		local min_value = tonumber(value.min) or fallback
		local max_value = tonumber(value.max) or min_value
		return (min_value + math.random() * (max_value - min_value)) / 100
	end
	if type(value) == "number" then
		return value / 100
	end
	return fallback
end

local function pick_sound(sound_group)
	if sound_group == nil or sound_group == "" then
		return nil
	end

	local sounds = pf.sound_groups[sound_group]
	if not sounds or #sounds == 0 then
		return nil
	end

	return sounds[math.random(#sounds)]
end

local function valid_target(player)
	return player and type(player.is_valid) == "function" and player:is_valid()
end

local function distance(a, b)
	local dx = a.x - b.x
	local dy = a.y - b.y
	local dz = a.z - b.z
	return math.sqrt(dx * dx + dy * dy + dz * dz)
end

local function play_sound(spec, params, ephemeral, bypass_sound_physics)
	if bypass_sound_physics then
		local physics = rawget(_G, "sound_physics")
		if physics and type(physics.play_unprocessed) == "function" then
			return physics.play_unprocessed(spec, params, ephemeral)
		end
	end
	return core.sound_play(spec, params, ephemeral)
end

local function play_positional(sound, player, params, gain, pitch, opts)
	local bypass_sound_physics = opts.sound_physics_bypass == true
	if not opts.audience_gain or opts.to_player or opts.exclude_player
		or type(player.is_player) ~= "function" or not player:is_player()
		or type(player.get_pos) ~= "function" then
		play_sound({ name = sound, gain = gain, pitch = pitch }, params, true, bypass_sound_physics)
		return true
	end

	local pos = player:get_pos()
	local source_name = type(player.get_player_name) == "function" and player:get_player_name() or nil
	if not pos or not source_name then
		play_sound({ name = sound, gain = gain, pitch = pitch }, params, true, bypass_sound_physics)
		return true
	end

	local played = false
	local max_distance = params.max_hear_distance or pf.settings.max_hear_distance
	for _, listener in ipairs(core.get_connected_players()) do
		local listener_pos = listener:get_pos()
		local listener_name = listener:get_player_name()
		local multiplier = listener_name == source_name and opts.audience_gain.self or opts.audience_gain.other
		if multiplier and multiplier > 0 and listener_pos
			and distance(pos, listener_pos) <= max_distance then
			play_sound({ name = sound, gain = gain * multiplier, pitch = pitch }, {
				pos = pos,
				to_player = listener_name,
				max_hear_distance = max_distance,
			}, true, bypass_sound_physics)
			played = true
		end
	end
	return played
end

local play_acoustic

local function find_single_basic(acoustic, preferred)
	if not acoustic then
		return nil, nil
	end

	if #acoustic > 0 then
		local fallback
		for _, entry in ipairs(acoustic) do
			local basic, preferred_match = find_single_basic(entry, preferred)
			if preferred_match then
				return basic, true
			end
			fallback = fallback or basic
		end
		return fallback, false
	end

	local acoustic_type = acoustic.type or "basic"
	if acoustic_type == "basic" then
		if preferred and acoustic.name and acoustic.name:find(preferred, 1, true) then
			return acoustic, true
		end
		return acoustic, false
	end

	if acoustic_type == "simultaneous" then
		return find_single_basic(acoustic.acoustics or acoustic.array or {}, preferred)
	end

	return nil, false
end

local function play_basic(acoustic, player, event, opts)
	local sound = pick_sound(acoustic.name)
	if sound == nil then
		pf.debug("missing sound group: " .. tostring(acoustic.name))
		return false
	end

	local gain = random_range(acoustic.volume, 1.0)
	gain = gain * (opts.gain_multiplier or 1.0) * pf.settings.gain
	if gain <= 0 then
		return false
	end

	local pitch = random_range(acoustic.pitch, 1.0) * (opts.pitch_multiplier or 1.0)
	if pitch <= 0 then
		pitch = 0.05
	elseif pitch < 0.05 then
		pitch = 0.05
	end

	local params = {
		max_hear_distance = opts.max_hear_distance or pf.settings.max_hear_distance,
	}
	if opts.pos then
		params.pos = opts.pos
	else
		params.object = player
	end
	if opts.to_player then
		params.to_player = opts.to_player
	end
	if opts.exclude_player then
		params.exclude_player = opts.exclude_player
	end

	return play_positional(sound, player, params, gain, pitch, opts)
end

local function play_events(acoustic, player, event, opts)
	local current = event or "walk"
	local guard = 0
	while current and guard < 8 do
		local selected = acoustic[current]
		if selected then
			return play_acoustic(selected, player, current, opts)
		end
		current = event_fallback[current]
		guard = guard + 1
	end
	return false
end

local function play_list(acoustics, player, event, opts)
	local played = false
	for _, acoustic in ipairs(acoustics) do
		played = play_acoustic(acoustic, player, event, opts) or played
	end
	return played
end

local function play_delayed(acoustic, player, event, opts)
	local delay = (tonumber(acoustic.delay) or 0) / 1000
	local name = type(player.get_player_name) == "function" and player:get_player_name() or nil
	core.after(delay, function()
		local delayed_target = name and core.get_player_by_name(name) or player
		if valid_target(delayed_target) then
			play_acoustic(acoustic.acoustic, delayed_target, event, opts)
		end
	end)
	return true
end

local function play_chance(acoustic, player, event, opts)
	local probability = tonumber(acoustic.probability) or 0
	if math.random() * 100 <= probability then
		return play_acoustic(acoustic.acoustic, player, event, opts)
	end
	return false
end

local function play_probability(acoustic, player, event, opts)
	local entries = acoustic.entries or acoustic.array or {}
	local total = 0
	for _, entry in ipairs(entries) do
		total = total + (tonumber(entry.weight) or 1)
	end
	if total <= 0 then
		return false
	end

	local roll = math.random() * total
	local marker = 0
	for _, entry in ipairs(entries) do
		marker = marker + (tonumber(entry.weight) or 1)
		if roll <= marker then
			return play_acoustic(entry.acoustic, player, event, opts)
		end
	end
	return false
end

play_acoustic = function(acoustic, player, event, opts)
	if not acoustic or not valid_target(player) then
		return false
	end

	opts = opts or {}
	local acoustic_type = acoustic.type or "basic"
	if opts.single_layer and acoustic_type ~= "events" then
		local basic = find_single_basic(acoustic, opts.prefer_sound_contains)
		if basic then
			return play_basic(basic, player, event, opts)
		end
	end

	if #acoustic > 0 then
		return play_list(acoustic, player, event, opts)
	end

	if acoustic_type == "basic" then
		return play_basic(acoustic, player, event, opts)
	elseif acoustic_type == "events" then
		return play_events(acoustic, player, event, opts)
	elseif acoustic_type == "delayed" then
		return play_delayed(acoustic, player, event, opts)
	elseif acoustic_type == "chance" then
		return play_chance(acoustic, player, event, opts)
	elseif acoustic_type == "probability" then
		return play_probability(acoustic, player, event, opts)
	elseif acoustic_type == "simultaneous" then
		return play_list(acoustic.acoustics or acoustic.array or {}, player, event, opts)
	end

	return false
end

function pf.play_step(player, acoustic_key, event_name, opts)
	if not pf.settings.enabled or not acoustic_key or acoustic_key == "" then
		return false
	end

	opts = opts or {}
	if event_name == "jump" or event_name == "land" then
		local bypass_opts = {}
		for key, value in pairs(opts) do
			bypass_opts[key] = value
		end
		bypass_opts.sound_physics_bypass = true
		opts = bypass_opts
	end

	local played = false
	for key in tostring(acoustic_key):gmatch("[^,%s]+") do
		local acoustic = pf.acoustics[key]
		if acoustic then
			played = play_acoustic(acoustic, player, event_name or "walk", opts) or played
		else
			pf.debug("missing acoustic: " .. key)
		end
	end
	return played
end

function pf.count_sound_groups()
	local count = 0
	for _ in pairs(pf.sound_groups) do
		count = count + 1
	end
	return count
end
