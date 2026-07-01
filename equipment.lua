local core = core or minetest
local pf = presence_footsteps

pf.footwear_sounds = {}
pf.footwear_options = {}

local default_options = {
	surface_gain = 0.50,
	gain_multiplier = 1.00,
}

local function copy_options(opts)
	local result = {}
	for key, value in pairs(default_options) do
		result[key] = value
	end
	for key, value in pairs(opts or {}) do
		result[key] = value
	end
	return result
end

function pf.register_footwear_sound(item_name, acoustic_key, opts)
	if not item_name or item_name == "" or not acoustic_key or acoustic_key == "" then
		return
	end
	pf.footwear_sounds[item_name] = acoustic_key
	pf.footwear_options[item_name] = copy_options(opts)
end

local function register_default_footwear()
	local metal = { "gold", "iron", "diamond", "copper" }
	pf.register_footwear_sound("mcl_armor:boots_leather", "boots")
	pf.register_footwear_sound("mcl_armor:boots_chain", "chainmail")
	pf.register_footwear_sound("mcl_armor:boots_netherite", "heavyboots")
	for _, material in ipairs(metal) do
		pf.register_footwear_sound("mcl_armor:boots_" .. material, "metalboots")
	end
end

local function has_group(def, group)
	return def and def.groups and (def.groups[group] or 0) > 0
end

local function infer_footwear_sound(name, def)
	if not name or name == "" then
		return nil, nil
	end
	if pf.footwear_sounds[name] then
		return pf.footwear_sounds[name], pf.footwear_options[name]
	end
	if not name:find("boots", 1, true) and not has_group(def, "armor_feet")
		and not has_group(def, "combat_armor_feet") then
		return nil, nil
	end
	if name:find("netherite", 1, true) then
		return "heavyboots", default_options
	end
	if name:find("chain", 1, true) then
		return "chainmail", default_options
	end
	if name:find("iron", 1, true) or name:find("gold", 1, true)
		or name:find("diamond", 1, true) or name:find("copper", 1, true) then
		return "metalboots", default_options
	end
	return "boots", default_options
end

local function get_feet_index()
	local armor = rawget(_G, "mcl_armor")
	if armor and armor.elements and armor.elements.feet and armor.elements.feet.index then
		return armor.elements.feet.index
	end
	return 5
end

function pf.get_footwear_sound(target)
	if not pf.settings.footwear or not target or type(target.is_player) ~= "function" or not target:is_player() then
		return nil, nil
	end
	local inv = target:get_inventory()
	if not inv or inv:get_size("armor") <= 0 then
		return nil, nil
	end
	local stack = inv:get_stack("armor", get_feet_index())
	if not stack or stack:is_empty() then
		return nil, nil
	end
	local name = stack:get_name()
	local def = core.registered_items[name]
	return infer_footwear_sound(name, def)
end

register_default_footwear()
