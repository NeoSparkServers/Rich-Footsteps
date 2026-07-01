-- Optional integration smoke test. It is not loaded by Luanti.

local wrapped_calls = {}
local raw_calls = {}
local fake_player = {}

function fake_player:is_valid()
	return true
end

function fake_player:is_player()
	return true
end

function fake_player:get_player_name()
	return "tester"
end

function fake_player:get_pos()
	return { x = 0, y = 0, z = 0 }
end

core = {
	sound_play = function(spec, params, ephemeral)
		wrapped_calls[#wrapped_calls + 1] = { spec = spec, params = params, ephemeral = ephemeral }
		return #wrapped_calls
	end,
	after = function(_, fn)
		fn()
	end,
	get_connected_players = function()
		return { fake_player }
	end,
	get_player_by_name = function(name)
		return name == "tester" and fake_player or nil
	end,
}
minetest = core

sound_physics = {
	play_unprocessed = function(spec, params, ephemeral)
		raw_calls[#raw_calls + 1] = { spec = spec, params = params, ephemeral = ephemeral }
		return 100 + #raw_calls
	end,
}

presence_footsteps = {
	settings = {
		enabled = true,
		gain = 1,
		max_hear_distance = 16,
	},
	sound_groups = {
		jump_fallback = { "presence_footsteps_stone_wander1" },
		land = { "presence_footsteps_stone_land1" },
		walk = { "presence_footsteps_stone_walk1" },
	},
	acoustics = {
		stone = {
			type = "events",
			land = { type = "basic", name = "land", volume = 100, pitch = 100 },
			walk = { type = "basic", name = "walk", volume = 100, pitch = 100 },
			wander = { type = "basic", name = "jump_fallback", volume = 100, pitch = 100 },
		},
	},
	debug = function() end,
}

dofile("../sound.lua")

assert(presence_footsteps.play_step(fake_player, "stone", "jump", { to_player = "tester" }))
assert(#raw_calls == 1 and #wrapped_calls == 0)

assert(presence_footsteps.play_step(fake_player, "stone", "land", { to_player = "tester" }))
assert(#raw_calls == 2 and #wrapped_calls == 0)

assert(presence_footsteps.play_step(fake_player, "stone", "walk", { to_player = "tester" }))
assert(#raw_calls == 2 and #wrapped_calls == 1)

sound_physics = nil
assert(presence_footsteps.play_step(fake_player, "stone", "jump", { to_player = "tester" }))
assert(#wrapped_calls == 2)

return true
