local core = core or minetest
local pf = presence_footsteps

pf.node_sounds = {}
pf.exact_node_sounds = {}

local function load_exact_node_sounds(path)
	for node_name, acoustic in pairs(dofile(path)) do
		pf.node_sounds[node_name] = acoustic
		pf.exact_node_sounds[node_name] = true
	end
end

load_exact_node_sounds(pf.modpath .. "/data/mcl_nodes.lua")
load_exact_node_sounds(pf.modpath .. "/data/minetest_game_nodes.lua")

pf.foliage_sounds = {}
pf.group_rules = {}
pf.foliage_rules = {}
pf.node_cache = {}
pf.node_cache_sources = {}
pf.substrate_cache = {}
pf.substrate_cache_sources = {}
pf.foliage_cache = {}
pf.mapped_nodes = {}
pf.mapped_exact_nodes = {}
pf.muted_nodes = {}
pf.skipped_builtin_mute_nodes = {}
pf.node_sound_stats = {}
pf.cache_ready = false

local function copy_table(source)
	local result = {}
	for key, value in pairs(source or {}) do
		result[key] = value
	end
	return result
end

local function has_group(def, group)
	return def.groups and (def.groups[group] or 0) > 0
end

local function contains_any(value, needles)
	value = value or ""
	for _, needle in ipairs(needles) do
		if value:find(needle, 1, true) then
			return true
		end
	end
	return false
end

local function sound_name(def)
	if type(def.sounds) == "table" and type(def.sounds.footstep) == "table" then
		return def.sounds.footstep.name or ""
	end
	if type(def.sounds) == "table" and type(def.sounds.footstep) == "string" then
		return def.sounds.footstep
	end
	return ""
end

local silent_acoustics = {
	NOT_EMITTED = true,
	NOT_EMITTER = true,
	NON_EMITTER = true,
	MESSY_GROUND = true,
	VANILLA = true,
}

local primitive_alias_skip = {
	air = true,
	dirt = true,
	glass = true,
	grass = true,
	metal = true,
	sand = true,
	snow = true,
	stone = true,
	water = true,
	wood = true,
}

local function is_silent_acoustic(acoustic)
	return acoustic and silent_acoustics[tostring(acoustic)] == true
end

local function acoustic_exists(acoustic)
	for key in tostring(acoustic or ""):gmatch("[^,%s]+") do
		if pf.acoustics[key] then
			return true
		end
	end
	return false
end

local function valid_resolved_acoustic(acoustic)
	return acoustic and not is_silent_acoustic(acoustic) and acoustic_exists(acoustic)
end

local function primitive_lookup(sound)
	sound = (sound or ""):lower()
	if sound == "" or not pf.primitive_map then
		return nil
	end

	local map = pf.primitive_map.map or {}
	local acoustic = map[sound] or map["minecraft:" .. sound]
	if acoustic then
		return acoustic
	end

	for alias, alias_acoustic in pairs(pf.primitive_map.aliases or {}) do
		if not primitive_alias_skip[alias] and sound:find(alias, 1, true) then
			return alias_acoustic
		end
	end
	return nil
end

local function normalize_block_name(node_name)
	local name = (node_name or ""):lower()
	name = name:gsub("^.-:", "")
	name = name:gsub("^stair_", ""):gsub("^slab_", "")
	name = name:gsub("_stair$", "_stairs")
	name = name:gsub("_slab_top$", "_slab"):gsub("_slab_double$", "_slab")
	return name
end

local function block_map_lookup(node_name, substrate)
	if not node_name or not pf.block_map then
		return nil
	end
	substrate = substrate or ""
	local key = normalize_block_name(node_name)

	local substrates = pf.block_map.substrates or {}
	local aliases = substrates[substrate] or {}
	local acoustic = aliases[key]
	if acoustic then
		return acoustic
	end
	if key:find("_wall", 1, true) and substrate == "" then
		acoustic = aliases[key .. ".bigger"]
		if acoustic then
			return acoustic
		end
	end
	if aliases["*"] then
		return aliases["*"]
	end

	local tags = (pf.block_map.substrate_tags or {})[substrate] or {}
	for tag, tag_acoustic in pairs(tags) do
		local plain_tag = normalize_block_name(tag):gsub("s$", "")
		if plain_tag ~= "" and key:find(plain_tag, 1, true) then
			return tag_acoustic
		end
	end

	if substrate == "" then
		aliases = pf.block_map.aliases or {}
		acoustic = aliases[key]
		if acoustic then
			return acoustic
		end
	end
	return nil
end

local function is_named_thin_surface(node_name)
	node_name = node_name or ""
	return node_name:find("carpet", 1, true)
		or node_name:find("snow_layer", 1, true)
		or node_name:find("pressure_plate", 1, true)
		or node_name:find("trapdoor", 1, true)
		or node_name:find("lily_pad", 1, true)
		or node_name:find("scaffolding", 1, true)
end

local function collision_top(def)
	local box = def and (def.collision_box or def.node_box)
	if not box or box.type ~= "fixed" then
		return nil
	end
	local fixed = box.fixed
	if type(fixed) ~= "table" then
		return nil
	end
	if type(fixed[1]) == "number" then
		return fixed[5]
	end
	local top
	for _, part in ipairs(fixed) do
		if type(part) == "table" and type(part[5]) == "number" then
			top = top and math.max(top, part[5]) or part[5]
		end
	end
	return top
end

local function collision_footprint(def)
	local box = def and (def.collision_box or def.node_box)
	if not box or box.type ~= "fixed" then
		return nil, nil
	end
	local fixed = box.fixed
	if type(fixed) ~= "table" then
		return nil, nil
	end

	local min_x, max_x, min_z, max_z
	local function measure(part)
		if type(part) ~= "table" then
			return
		end
		min_x = min_x and math.min(min_x, part[1]) or part[1]
		max_x = max_x and math.max(max_x, part[4]) or part[4]
		min_z = min_z and math.min(min_z, part[3]) or part[3]
		max_z = max_z and math.max(max_z, part[6]) or part[6]
	end

	if type(fixed[1]) == "number" then
		measure(fixed)
	else
		for _, part in ipairs(fixed) do
			measure(part)
		end
	end

	if not min_x or not max_x or not min_z or not max_z then
		return nil, nil
	end
	return max_x - min_x, max_z - min_z
end

local function is_thin_surface(node_name, def)
	if not def or not def.walkable then
		return false
	end
	if is_named_thin_surface(node_name) then
		return true
	end
	local top = collision_top(def)
	return top ~= nil and top <= -0.20
end

function pf.is_surface_candidate(node_name, def)
	node_name = node_name or ""
	if not def or not def.walkable then
		return false
	end
	if is_thin_surface(node_name, def) then
		return true
	end
	if contains_any(node_name, {
		"fence", "wall", "pane", "bars", "chain", "post",
		"door", "gate", "button", "lever", "torch", "candle",
	}) then
		return false
	end

	local width, depth = collision_footprint(def)
	if width and depth and (width < 0.56 or depth < 0.56) then
		return false
	end
	return true
end

local function is_wet_node(node_name, def)
	if not node_name or not def then
		return false
	end
	if def.liquidtype and def.liquidtype ~= "none" then
		return true
	end
	if has_group(def, "water") or has_group(def, "liquid") then
		return true
	end
	return node_name:find("water", 1, true) ~= nil
		or node_name:find("kelp", 1, true) ~= nil
		or node_name:find("seagrass", 1, true) ~= nil
		or node_name:find("wet_", 1, true) ~= nil
		or node_name:find("_wet", 1, true) ~= nil
end

local function mute_builtin_footstep(node_name)
	local def = core.registered_nodes[node_name]
	if def and type(def.sounds) == "table" then
		local sounds = copy_table(def.sounds)
		sounds.footstep = { name = "", gain = 0 }
		core.override_item(node_name, { sounds = sounds })
		pf.muted_nodes[node_name] = true
	end
end

local function matches_rule(name, def, rule)
	if rule.groups then
		for _, group in ipairs(rule.groups) do
			if not has_group(def, group) then
				return false
			end
		end
	end

	if rule.any_group then
		local found = false
		for _, group in ipairs(rule.any_group) do
			if has_group(def, group) then
				found = true
				break
			end
		end
		if not found then
			return false
		end
	end

	if rule.name_contains and not contains_any(name, rule.name_contains) then
		return false
	end

	if rule.sound_contains and not contains_any(sound_name(def), rule.sound_contains) then
		return false
	end

	return true
end

function pf.register_node_sound(node_name, acoustic_key)
	pf.node_sounds[node_name] = acoustic_key
	pf.exact_node_sounds[node_name] = true
	pf.node_cache[node_name] = acoustic_key
	pf.node_cache_sources[node_name] = "exact"
	pf.mapped_nodes[node_name] = true
	pf.mapped_exact_nodes[node_name] = true
	if pf.settings and pf.settings.replace_builtin then
		mute_builtin_footstep(node_name)
	end
end

function pf.register_foliage_sound(node_name, acoustic_key)
	pf.foliage_sounds[node_name] = acoustic_key
	pf.foliage_cache[node_name] = acoustic_key
end

function pf.register_group_rule(rule)
	table.insert(pf.group_rules, rule)
	if pf.cache_ready then
		pf.rebuild_node_cache()
		if pf.settings and pf.settings.replace_builtin then
			pf.disable_builtin_footsteps()
		end
	end
end

local function register_foliage_rule(rule)
	table.insert(pf.foliage_rules, rule)
end

local function register_builtin_rules()
	local rules = {
		{ name_contains = { "glass_pane", "glasspane" }, acoustic = "glass" },
		{ name_contains = { "stained_glass", "glass" }, acoustic = "glass" },
		{ name_contains = { "blue_ice", "packed_ice", "ice" }, acoustic = "ice" },
		{ name_contains = { "snowblock", "snow_block", "snow_layer", "snow" }, acoustic = "snow" },
		{ name_contains = { "carpet", "wool", "bed" }, acoustic = "rug" },
		{ name_contains = { "grass_path", "dirt_path", "path" }, acoustic = "grass" },
		{ name_contains = { "sandstone" }, acoustic = "sandstone" },
		{ name_contains = { "gravel" }, acoustic = "gravel" },
		{ name_contains = { "soul_sand" }, acoustic = "quicksand" },
		{ name_contains = { "soul_soil" }, acoustic = "souls" },
		{ name_contains = { "redsand", "red_sand", "desert_sand", "sand" }, acoustic = "sand" },
		{ name_contains = { "mangrove_roots" }, acoustic = "mud,slick" },
		{ name_contains = { "packed_mud" }, acoustic = "dirt" },
		{ name_contains = { "mud", "wet_soil", "soil_wet" }, acoustic = "mud" },
		{ name_contains = { "grass", "mycelium", "podzol", "nylium" }, acoustic = "grass" },
		{ name_contains = { "dirt", "farmland", "clay" }, acoustic = "dirt" },
		{ name_contains = { "chest", "barrel" }, acoustic = "squeakywood" },
		{ name_contains = { "bookshelf", "shelf" }, acoustic = "wood" },
		{ name_contains = { "leaves", "leaf", "azalea" }, acoustic = "leaves" },
		{ name_contains = { "rail" }, acoustic = "rails" },
		{ name_contains = { "chain" }, acoustic = "chain" },
		{ name_contains = { "lantern", "spawner", "trial_spawner", "vault" }, acoustic = "metalbar" },
		{ name_contains = { "grate" }, acoustic = "metalgrate" },
		{ name_contains = { "copper" }, acoustic = "copper" },
		{ name_contains = { "netherite", "heavy_core" }, acoustic = "hollowmetal" },
		{ name_contains = { "iron_bars", "ironbars", "iron", "gold", "metal", "anvil" }, acoustic = "hardmetal" },
		{ name_contains = { "bamboo" }, acoustic = "squeakywood" },
		{ name_contains = { "pale_oak", "creaking_heart" }, acoustic = "softwood,creaking" },
		{ name_contains = { "cherry", "mangrove" }, acoustic = "softwood" },
		{ name_contains = { "crimson", "warped" }, acoustic = "wood,mushroom" },
		{ name_contains = { "wood", "planks", "log", "tree", "stem", "hyphae" }, acoustic = "wood" },
		{ name_contains = { "decorated_pot", "flower_pot", "candle" }, acoustic = "brickstone" },
		{ name_contains = { "brick" }, acoustic = "brickstone" },
		{ name_contains = { "deepslate_ore", "deepslate_with" }, acoustic = "slate_ore" },
		{ name_contains = { "ore", "raw_iron", "raw_gold", "raw_copper" }, acoustic = "ore" },
		{ name_contains = { "obsidian" }, acoustic = "obsidian" },
		{ name_contains = { "polished_granite", "polished_diorite", "polished_andesite", "polished_tuff", "polished_blackstone" }, acoustic = "marble" },
		{ name_contains = { "deepslate_tile", "deepslate_brick", "end_stone_brick", "nether_brick" }, acoustic = "brickstone" },
		{ name_contains = { "cobbled_deepslate", "reinforced_deepslate" }, acoustic = "rough_slate" },
		{ name_contains = { "deepslate" }, acoustic = "slate" },
		{ name_contains = { "blackstone", "basalt", "tuff", "calcite", "dripstone", "prismarine", "end_stone", "netherrack", "stone", "cobble", "granite", "diorite", "andesite", "slate" }, acoustic = "stone" },
		{ name_contains = { "bone" }, acoustic = "bone" },
		{ name_contains = { "resin" }, acoustic = "resin" },
		{ name_contains = { "sculk" }, acoustic = "organic_solid" },
		{ name_contains = { "honey" }, acoustic = "honey" },
		{ name_contains = { "slime" }, acoustic = "slime" },
		{ name_contains = { "magma" }, acoustic = "magma" },
		{ name_contains = { "glowstone" }, acoustic = "glowstone" },
		{ name_contains = { "wet_sponge" }, acoustic = "mud" },
		{ name_contains = { "shroomlight", "froglight", "wart_block", "sponge" }, acoustic = "organic" },
		{ any_group = { "wool" }, acoustic = "rug" },
		{ any_group = { "glass" }, acoustic = "glass" },
		{ any_group = { "ice" }, acoustic = "ice" },
		{ any_group = { "snowy" }, acoustic = "snow" },
		{ any_group = { "sand" }, acoustic = "sand" },
		{ any_group = { "soil", "dirt" }, acoustic = "dirt" },
		{ any_group = { "leaves" }, acoustic = "leaves" },
		{ any_group = { "wood", "tree", "choppy", "axey" }, acoustic = "wood" },
		{ any_group = { "cracky", "stone", "pickaxey" }, acoustic = "stone" },
		{ any_group = { "crumbly", "shovely" }, acoustic = "dirt" },
		{ sound_contains = { "glass" }, acoustic = "glass" },
		{ sound_contains = { "snow" }, acoustic = "snow" },
		{ sound_contains = { "gravel" }, acoustic = "gravel" },
		{ sound_contains = { "sand" }, acoustic = "sand" },
		{ sound_contains = { "grass" }, acoustic = "grass" },
		{ sound_contains = { "dirt" }, acoustic = "dirt" },
		{ sound_contains = { "wood" }, acoustic = "wood" },
		{ sound_contains = { "stone" }, acoustic = "stone" },
		{ sound_contains = { "metal" }, acoustic = "hardmetal" },
	}

	for _, rule in ipairs(rules) do
		pf.register_group_rule(rule)
	end
end

register_builtin_rules()

local function register_builtin_foliage_rules()
	local rules = {
		{ name_contains = { "leaf_litter", "dry_grass", "dead_bush" }, acoustic = "straw" },
		{ name_contains = { "wheat", "carrot", "potato", "beetroot", "cotton", "crop", "stem" }, acoustic = "brush_straw_transition" },
		{ name_contains = { "tall_grass", "short_grass", "grass_", "_grass", "junglegrass", "marram_grass", "fern", "papyrus", "bush" }, acoustic = "brush_straw_transition" },
		{ name_contains = { "flower", "rose", "lilac", "peony", "tulip", "daisy", "dandelion", "allium", "orchid", "cornflower", "petals" }, acoustic = "brush" },
		{ name_contains = { "vine", "roots", "sprouts", "sapling", "azalea", "mushroom" }, acoustic = "brush" },
		{ name_contains = { "coral", "sea_pickle", "kelp", "seagrass" }, acoustic = "brush" },
		{ name_contains = { "leaves", "leaf" }, acoustic = "leaves" },
		{ any_group = { "flora", "flower", "plant", "sapling" }, acoustic = "brush" },
		{ any_group = { "leaves" }, acoustic = "leaves" },
	}

	for _, rule in ipairs(rules) do
		register_foliage_rule(rule)
	end
end

register_builtin_foliage_rules()

local function valid_acoustic_key(acoustic)
	return valid_resolved_acoustic(acoustic)
end

local function resolve_foliage_sound(node_name, def)
	if pf.foliage_sounds[node_name] then
		return pf.foliage_sounds[node_name]
	end
	if not def then
		return nil
	end
	for _, rule in ipairs(pf.foliage_rules) do
		if matches_rule(node_name, def, rule) then
			return rule.acoustic
		end
	end
	return nil
end

local function resolve_node_sound_with_source(node_name, def, substrate)
	if not def then
		return nil
	end
	substrate = substrate or ""

	if substrate ~= "" then
		local substrate_acoustic = block_map_lookup(node_name, substrate)
		if substrate_acoustic then
			if is_silent_acoustic(substrate_acoustic) then
				return nil
			end
			if valid_resolved_acoustic(substrate_acoustic) then
				return substrate_acoustic, "blockmap:" .. substrate
			end
		end
		return nil
	end

	if pf.node_sounds[node_name] then
		return pf.node_sounds[node_name], "exact"
	end

	if def.liquidtype and def.liquidtype ~= "none" then
		if node_name:find("lava", 1, true) then
			return "lavafine", "special"
		end
		return "waterfine", "special"
	end

	if def.climbable then
		return "ladder_default", "special"
	end

	if not def.walkable then
		return nil
	end

	local block_map_acoustic = block_map_lookup(node_name, "")
	if block_map_acoustic then
		if is_silent_acoustic(block_map_acoustic) then
			return nil
		end
		if valid_resolved_acoustic(block_map_acoustic) then
			return block_map_acoustic, "blockmap"
		end
	end

	local primitive = primitive_lookup(sound_name(def))
	if primitive then
		if is_silent_acoustic(primitive) then
			return nil
		end
		if valid_resolved_acoustic(primitive) then
			return primitive, "primitive"
		end
	end

	for _, rule in ipairs(pf.group_rules) do
		if matches_rule(node_name, def, rule) then
			return rule.acoustic, "inferred"
		end
	end

	return nil
end

function pf.resolve_node_sound(node_name, def)
	local acoustic = resolve_node_sound_with_source(node_name, def)
	return acoustic
end

function pf.rebuild_node_cache()
	pf.node_cache = {}
	pf.node_cache_sources = {}
	pf.substrate_cache = {}
	pf.substrate_cache_sources = {}
	pf.foliage_cache = {}
	pf.mapped_nodes = {}
	pf.mapped_exact_nodes = {}
	pf.node_sound_stats = {}
	for substrate in pairs((pf.block_map and pf.block_map.substrates) or {}) do
		if substrate ~= "" then
			pf.substrate_cache[substrate] = {}
			pf.substrate_cache_sources[substrate] = {}
		end
	end

	for name, def in pairs(core.registered_nodes) do
		local acoustic, source = resolve_node_sound_with_source(name, def)
		if acoustic and valid_acoustic_key(acoustic) then
			pf.node_cache[name] = acoustic
			pf.node_cache_sources[name] = source
			pf.mapped_nodes[name] = true
			if source == "exact" then
				pf.mapped_exact_nodes[name] = true
			end
			local first = acoustic:match("^[^,]+")
			pf.node_sound_stats[first] = (pf.node_sound_stats[first] or 0) + 1
		end

		local foliage = resolve_foliage_sound(name, def)
		if foliage and valid_acoustic_key(foliage) then
			pf.foliage_cache[name] = foliage
		end
	end
	pf.cache_ready = true
end

function pf.get_node_sound(node_name, substrate)
	if substrate and substrate ~= "" then
		pf.substrate_cache[substrate] = pf.substrate_cache[substrate] or {}
		pf.substrate_cache_sources[substrate] = pf.substrate_cache_sources[substrate] or {}
		local cached = pf.substrate_cache[substrate][node_name]
		if cached ~= nil then
			return cached or nil
		end
		local def = core.registered_nodes[node_name]
		local acoustic, source = resolve_node_sound_with_source(node_name, def, substrate)
		if acoustic and valid_acoustic_key(acoustic) then
			pf.substrate_cache[substrate][node_name] = acoustic
			pf.substrate_cache_sources[substrate][node_name] = source
			return acoustic
		end
		pf.substrate_cache[substrate][node_name] = false
		return nil
	end
	return pf.node_cache[node_name]
end

function pf.get_node_sound_source(node_name, substrate)
	if substrate and substrate ~= "" then
		return pf.substrate_cache_sources[substrate] and pf.substrate_cache_sources[substrate][node_name] or nil
	end
	return pf.node_cache_sources[node_name]
end

function pf.get_foliage_sound(node_name)
	local cached = pf.foliage_cache[node_name]
	if cached ~= nil then
		return cached or nil
	end
	local def = core.registered_nodes[node_name]
	local foliage = select(1, resolve_node_sound_with_source(node_name, def, "foliage"))
		or select(1, resolve_node_sound_with_source(node_name, def, "messy"))
	if foliage and valid_acoustic_key(foliage) then
		pf.foliage_cache[node_name] = foliage
		return foliage
	end
	pf.foliage_cache[node_name] = false
	return nil
end

function pf.resolve_player_surface(pos, feet_node, feet_def, ground_node, ground_def, climbing)
	local surface_node = ground_node
	local surface_def = ground_def
	local source = "ground"
	local surface_acoustic
	local acoustic_source
	if climbing and feet_node then
		surface_node = feet_node
		surface_def = feet_def
		source = "climbable"
	elseif feet_node and feet_def and is_thin_surface(feet_node.name, feet_def)
		and (valid_resolved_acoustic(pf.get_node_sound(feet_node.name, "carpet"))
			or valid_resolved_acoustic(pf.get_node_sound(feet_node.name))) then
		surface_node = feet_node
		surface_def = feet_def
		source = pf.get_node_sound(feet_node.name, "carpet") and "carpet" or "thin"
	elseif surface_node and surface_def and not pf.is_surface_candidate(surface_node.name, surface_def) then
		surface_node = nil
		surface_def = nil
		source = "ignored"
	end
	if surface_node then
		surface_acoustic = pf.get_node_sound(surface_node.name, source == "carpet" and "carpet" or nil)
			or pf.get_node_sound(surface_node.name)
		acoustic_source = pf.get_node_sound_source(surface_node.name, source == "carpet" and "carpet" or nil)
			or pf.get_node_sound_source(surface_node.name)
	end
	local wet_acoustic = surface_node and pf.get_node_sound(surface_node.name, "wet") or nil
	if not wet_acoustic and feet_node then
		wet_acoustic = pf.get_node_sound(feet_node.name, "wet")
	end

	return {
		feet_node = feet_node,
		feet_def = feet_def,
		surface_node = surface_node,
		surface_def = surface_def,
		source = source,
		surface_acoustic = surface_acoustic,
		acoustic_source = acoustic_source,
		wet_acoustic = wet_acoustic,
		wet = is_wet_node(feet_node and feet_node.name, feet_def)
			or is_wet_node(surface_node and surface_node.name, surface_def),
	}
end

function pf.is_wet_context(context)
	return context and context.wet == true
end

function pf.disable_builtin_footsteps()
	pf.muted_nodes = {}
	pf.skipped_builtin_mute_nodes = {}
	local mute_inferred = pf.settings and pf.settings.replace_inferred_builtin == true
	for node_name in pairs(pf.mapped_nodes) do
		local source = pf.node_cache_sources[node_name]
		if mute_inferred or source == "exact" or source == "special" then
			mute_builtin_footstep(node_name)
		else
			pf.skipped_builtin_mute_nodes[node_name] = true
		end
	end
end

function pf.count_mapped_nodes()
	local count = 0
	for _ in pairs(pf.mapped_nodes) do
		count = count + 1
	end
	return count
end

function pf.count_muted_nodes()
	local count = 0
	for _ in pairs(pf.muted_nodes) do
		count = count + 1
	end
	return count
end

local function node_name_or_unknown(node)
	return node and node.name or "<unknown>"
end

local function debug_allowed()
	return pf.settings and pf.settings.debug
end

function pf.inspect_player_node(player)
	local pos = player:get_pos()
	local feet_pos = {
		x = math.floor(pos.x + 0.5),
		y = math.floor(pos.y + 0.5),
		z = math.floor(pos.z + 0.5),
	}
	local below_pos = {
		x = math.floor(pos.x + 0.5),
		y = math.floor(pos.y - 0.6 + 0.5),
		z = math.floor(pos.z + 0.5),
	}
	local feet_node = core.get_node_or_nil(feet_pos)
	local below_node = core.get_node_or_nil(below_pos)
	local feet_def = feet_node and core.registered_nodes[feet_node.name]
	local below_def = below_node and core.registered_nodes[below_node.name]
	local surface_info = pf.resolve_player_surface(pos, feet_node, feet_def, below_node, below_def, feet_def and feet_def.climbable)
	local surface_node = surface_info.surface_node
	local surface_name = node_name_or_unknown(surface_node)
	local tracker = pf.get_player_tracker_info and pf.get_player_tracker_info(player:get_player_name()) or {}
	local footwear = pf.get_footwear_sound and pf.get_footwear_sound(player) or nil
	local wet = pf.is_wet_position and pf.is_wet_position(pos, surface_info) or false
	local variance = pf.get_biome_variance and pf.get_biome_variance(pos) or nil

	return {
		feet = node_name_or_unknown(feet_node),
		below = node_name_or_unknown(below_node),
		surface = surface_name,
		surface_source = surface_info.source or "<none>",
		acoustic = surface_info.surface_acoustic or pf.get_node_sound(surface_name) or "<unmapped>",
		acoustic_source = surface_info.acoustic_source or pf.get_node_sound_source(surface_name) or "<none>",
		foliage = feet_node and (pf.get_foliage_sound(feet_node.name) or "<none>") or "<none>",
		footwear = footwear or "<none>",
		wet = wet and "yes" or "no",
		wet_acoustic = surface_info.wet_acoustic or "<default>",
		biome_volume = variance and variance.volume or 1,
		biome_pitch = variance and variance.pitch or 1,
		muted = pf.muted_nodes[surface_name] and "yes" or "no",
		phase = tracker.phase or "<none>",
		ground_contact = tracker.ground_contact or "unknown",
		was_ground_contact = tracker.was_ground_contact or "unknown",
		jump_consumed = tracker.jump_consumed or "unknown",
		airborne_confirmed = tracker.airborne_confirmed or "unknown",
		descending = tracker.descending or "unknown",
		takeoff_surface = tracker.takeoff_surface or "<none>",
		current_surface = tracker.current_surface or "<none>",
		last_surface = tracker.last_surface or "<none>",
		last_step_surface = tracker.last_step_surface or "<none>",
		distance = tracker.distance or 0,
		running = tracker.running or "unknown",
		horizontal_speed = tracker.horizontal_speed or 0,
		locomotion = tracker.locomotion or "<none>",
		quad_phase = tracker.quad_phase or 0,
		wing_state = tracker.wing_state or "<none>",
		last_event = tracker.last_event or "<none>",
		suppression = tracker.suppression or 0,
	}
end

function pf.audit_nodes(limit)
	limit = limit or 20
	local walkable = 0
	local mapped = 0
	local unmapped = {}

	for name, def in pairs(core.registered_nodes) do
		if def.walkable then
			walkable = walkable + 1
			if pf.node_cache[name] then
				mapped = mapped + 1
			elseif #unmapped < limit then
				table.insert(unmapped, name)
			end
		end
	end

	return walkable, mapped, unmapped, pf.node_sound_stats
end

core.register_chatcommand("presence_footsteps_node", {
	description = "Print Presence Footsteps node resolver data for the current player.",
	func = function(name)
		if not debug_allowed() then
			return true, "presence_footsteps_debug is disabled."
		end
		local player = core.get_player_by_name(name)
		if not player then
			return false, "Player not found."
		end
		local info = pf.inspect_player_node(player)
		return true, ("feet=%s below=%s surface=%s surface_source=%s acoustic=%s source=%s foliage=%s footwear=%s wet=%s wet_acoustic=%s biome=%.2f/%.2f builtin_muted=%s phase=%s locomotion=%s quad_phase=%d wing_state=%s ground_contact=%s jump_consumed=%s airborne_confirmed=%s descending=%s takeoff_surface=%s current_surface=%s last_surface=%s last_step_surface=%s running=%s speed=%.2f distance=%.2f suppression=%.2f last_event=%s")
			:format(info.feet, info.below, info.surface, info.surface_source, info.acoustic,
				info.acoustic_source, info.foliage, info.footwear, info.wet,
				info.wet_acoustic, info.biome_volume, info.biome_pitch, info.muted,
				info.phase, info.locomotion, info.quad_phase, info.wing_state,
				info.ground_contact, info.jump_consumed,
				info.airborne_confirmed, info.descending, info.takeoff_surface,
				info.current_surface, info.last_surface,
				info.last_step_surface, info.running, info.horizontal_speed,
				info.distance, info.suppression, info.last_event)
	end,
})

core.register_chatcommand("presence_footsteps_trace", {
	description = "Print recent Presence Footsteps tracker events for the current player.",
	func = function(name)
		if not debug_allowed() then
			return true, "presence_footsteps_debug is disabled."
		end
		local trace = pf.get_player_tracker_trace and pf.get_player_tracker_trace(name) or {}
		if #trace == 0 then
			return true, "<empty>"
		end
		return true, table.concat(trace, "\n")
	end,
})

core.register_chatcommand("presence_footsteps_audit", {
	description = "Print Presence Footsteps mapped/unmapped walkable node counts.",
	func = function()
		if not debug_allowed() then
			return true, "presence_footsteps_debug is disabled."
		end
		local walkable, mapped, unmapped, stats = pf.audit_nodes(25)
		local examples = table.concat(unmapped, ", ")
		if examples ~= "" then
			core.log("action", "[presence_footsteps] unmapped walkable examples: " .. examples)
		end
		return true, ("mapped=%d unmapped=%d walkable=%d stone=%d wood=%d grass=%d rug=%d glass=%d examples=%s")
			:format(mapped, walkable - mapped, walkable,
				stats.stone or 0, stats.wood or 0, stats.grass or 0,
				stats.rug or 0, stats.glass or 0,
				examples ~= "" and examples or "<none>")
	end,
})
