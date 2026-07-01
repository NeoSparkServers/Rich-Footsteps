local nodes = {
	["bones:bones"] = "bone",
	["default:acacia_bush_stem"] = "wood",
	["default:acacia_tree"] = "wood",
	["default:acacia_wood"] = "wood",
	["default:apple_mark"] = "wood",
	["default:bookshelf"] = "wood",
	["default:bronzeblock"] = "hardmetal",
	["default:bush_stem"] = "wood",
	["default:chest"] = "squeakywood",
	["default:chest_locked"] = "squeakywood",
	["default:clay"] = "dirt",
	["default:coalblock"] = "stone",
	["default:cobble"] = "stone",
	["default:copperblock"] = "copper",
	["default:coral_brown"] = "organic",
	["default:coral_cyan"] = "organic",
	["default:coral_green"] = "organic",
	["default:desert_cobble"] = "stone",
	["default:desert_sand"] = "sand",
	["default:desert_sandstone"] = "sandstone",
	["default:desert_sandstone_block"] = "sandstone",
	["default:desert_sandstone_brick"] = "sandstone",
	["default:desert_stone"] = "stone",
	["default:desert_stone_block"] = "marble",
	["default:desert_stonebrick"] = "brickstone",
	["default:diamondblock"] = "composite",
	["default:dirt"] = "dirt",
	["default:dirt_with_coniferous_litter"] = "grass",
	["default:dirt_with_dry_grass"] = "grass",
	["default:dirt_with_grass"] = "grass",
	["default:dirt_with_grass_footsteps"] = "grass",
	["default:dirt_with_rainforest_litter"] = "grass",
	["default:dry_dirt"] = "dirt",
	["default:dry_dirt_with_dry_grass"] = "grass",
	["default:furnace"] = "stonemachine",
	["default:furnace_active"] = "stonemachine",
	["default:glass"] = "glass",
	["default:goldblock"] = "hardmetal",
	["default:gravel"] = "gravel",
	["default:ice"] = "ice",
	["default:jungle_tree"] = "wood",
	["default:junglewood"] = "wood",
	["default:ladder_steel"] = "ladder_default",
	["default:ladder_wood"] = "ladder_default",
	["default:meselamp"] = "stoneutility",
	["default:mese"] = "composite",
	["default:mossycobble"] = "stone",
	["default:obsidian"] = "obsidian",
	["default:obsidian_block"] = "obsidian",
	["default:obsidian_glass"] = "glass",
	["default:obsidianbrick"] = "brickstone",
	["default:permafrost"] = "dirt",
	["default:permafrost_with_moss"] = "grass",
	["default:permafrost_with_stones"] = "gravel",
	["default:pine_bush_stem"] = "wood",
	["default:pine_tree"] = "wood",
	["default:pine_wood"] = "wood",
	["default:river_water_flowing"] = "waterfine",
	["default:river_water_source"] = "waterfine",
	["default:sand"] = "sand",
	["default:sandstone"] = "sandstone",
	["default:sandstone_block"] = "sandstone",
	["default:sandstonebrick"] = "sandstone",
	["default:silver_sand"] = "sand",
	["default:silver_sandstone"] = "sandstone",
	["default:silver_sandstone_block"] = "sandstone",
	["default:silver_sandstone_brick"] = "sandstone",
	["default:snow"] = "snow",
	["default:snowblock"] = "snow",
	["default:steelblock"] = "hardmetal",
	["default:stone"] = "stone",
	["default:stone_block"] = "marble",
	["default:stone_with_coal"] = "ore",
	["default:stone_with_copper"] = "ore",
	["default:stone_with_diamond"] = "ore",
	["default:stone_with_gold"] = "ore",
	["default:stone_with_iron"] = "ore",
	["default:stone_with_mese"] = "ore",
	["default:stone_with_tin"] = "ore",
	["default:stonebrick"] = "brickstone",
	["default:tinblock"] = "hardmetal",
	["default:tree"] = "wood",
	["default:water_flowing"] = "waterfine",
	["default:water_source"] = "waterfine",
	["default:wood"] = "wood",
	["doors:door_glass_a"] = "glass",
	["doors:door_glass_b"] = "glass",
	["doors:door_obsidian_glass_a"] = "glass",
	["doors:door_obsidian_glass_b"] = "glass",
	["doors:door_steel_a"] = "hardmetal",
	["doors:door_steel_b"] = "hardmetal",
	["doors:door_wood_a"] = "wood",
	["doors:door_wood_b"] = "wood",
	["doors:trapdoor"] = "wood",
	["doors:trapdoor_open"] = "wood",
	["doors:trapdoor_steel"] = "hardmetal",
	["doors:trapdoor_steel_open"] = "hardmetal",
	["farming:desert_sand_soil"] = "sand",
	["farming:desert_sand_soil_wet"] = "mud",
	["farming:soil"] = "dirt",
	["farming:soil_wet"] = "mud",
	["xpanes:bar"] = "hardmetal",
	["xpanes:bar_flat"] = "hardmetal",
	["xpanes:pane"] = "glass",
	["xpanes:pane_flat"] = "glass",
}

local colors = {
	"white", "grey", "dark_grey", "black", "violet", "blue", "cyan",
	"dark_green", "green", "yellow", "brown", "orange", "red", "magenta",
	"pink",
}

local stair_materials = {
	stone = "stone",
	cobble = "stone",
	mossycobble = "stone",
	desert_cobble = "stone",
	desert_stone = "stone",
	sandstone = "sandstone",
	desert_sandstone = "sandstone",
	silver_sandstone = "sandstone",
	stone_block = "marble",
	desert_stone_block = "marble",
	stonebrick = "brickstone",
	desert_stonebrick = "brickstone",
	obsidianbrick = "brickstone",
	wood = "wood",
	junglewood = "wood",
	pine_wood = "wood",
	acacia_wood = "wood",
	aspen_wood = "wood",
	steelblock = "hardmetal",
	copperblock = "copper",
	bronzeblock = "hardmetal",
}

local function add(prefix, names, acoustic)
	for _, name in ipairs(names) do
		nodes[prefix .. name] = acoustic
	end
end

for _, color in ipairs(colors) do
	nodes["wool:" .. color] = "rug"
	nodes["beds:bed_" .. color] = "rug"
	nodes["beds:fancy_bed_" .. color] = "rug"
end

nodes["beds:bed_bottom"] = "rug"
nodes["beds:bed_top"] = "rug"
nodes["beds:fancy_bed_bottom"] = "rug"
nodes["beds:fancy_bed_top"] = "rug"

add("default:", {
	"acacia_leaves", "aspen_leaves", "bush_leaves", "emergent_jungle_tree",
	"jungleleaves", "leaves", "pine_bush_needles", "pine_needles",
}, "leaves")

add("default:", {
	"aspen_tree", "aspen_wood", "fence_acacia_wood", "fence_aspen_wood",
	"fence_junglewood", "fence_pine_wood", "fence_wood", "fence_rail_acacia_wood",
	"fence_rail_aspen_wood", "fence_rail_junglewood", "fence_rail_pine_wood",
	"fence_rail_wood", "sign_wall_wood",
}, "wood")

add("default:", {
	"lava_flowing", "lava_source",
}, "lavafine")

for material, acoustic in pairs(stair_materials) do
	nodes["stairs:slab_" .. material] = acoustic
	nodes["stairs:stair_" .. material] = acoustic
	nodes["stairs:stair_inner_" .. material] = acoustic
	nodes["stairs:stair_outer_" .. material] = acoustic
end

return nodes
