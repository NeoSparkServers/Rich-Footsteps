local nodes = {
	["mcl_amethyst:amethyst_block"] = "chimes",
	["mcl_amethyst:budding_amethyst_block"] = "chimes",
	["mcl_amethyst:calcite"] = "marble,stone",
	["mcl_amethyst:amethyst_cluster"] = "chimes",
	["mcl_anvils:anvil"] = "metalcompressed,hardmetal",
	["mcl_anvils:anvil_damage_1"] = "metalcompressed,hardmetal",
	["mcl_anvils:anvil_damage_2"] = "metalcompressed,hardmetal",
	["mcl_barrels:barrel_closed"] = "squeakywood",
	["mcl_barrels:barrel_open"] = "squeakywood",
	["mcl_chests:chest"] = "squeakywood",
	["mcl_chests:ender_chest"] = "obsidian",
	["mcl_compass:lodestone"] = "stonemachine",
	["mcl_composters:composter"] = "woodutility",
	["mcl_composters:composter_ready"] = "organic_dry",
	["mcl_furnaces:furnace"] = "stonemachine",
	["mcl_furnaces:furnace_active"] = "stonemachine",
	["mcl_furnaces:blast_furnace"] = "stonemachine",
	["mcl_furnaces:blast_furnace_active"] = "stonemachine",
	["mcl_furnaces:smoker"] = "stonemachine",
	["mcl_furnaces:smoker_active"] = "stonemachine",
	["mcl_honey:honey_block"] = "honey",
	["mcl_slime:slimeblock"] = "slime",
	["mcl_slime:slime_block"] = "slime",
	["mcl_stonecutter:stonecutter"] = "stonemachine",
	["mcl_crafting_table:crafting_table"] = "woodutility",
	["mcl_cartography_table:cartography_table"] = "woodutility",
	["mcl_fletching_table:fletching_table"] = "woodutility",
	["mcl_smithing_table:table"] = "hardmetal,woodutility",
	["mcl_loom:loom"] = "woodutility",
}

local colors = {
	"white", "grey", "gray", "dark_grey", "dark_gray", "black",
	"red", "orange", "yellow", "lime", "green", "cyan", "light_blue",
	"blue", "purple", "magenta", "pink", "brown",
}

local wood_sets = {
	"wood", "tree", "oakwood", "oaktree", "birchwood", "birchtree",
	"sprucewood", "sprucetree", "junglewood", "jungletree", "acaciawood",
	"acaciatree", "darkwood", "darktree", "dark_oak_wood", "dark_oak_tree",
}

local function add(modname, names, acoustic)
	for _, name in ipairs(names) do
		nodes[modname .. ":" .. name] = acoustic
	end
end

local function add_prefixed(modname, prefixes, names, acoustic)
	for _, prefix in ipairs(prefixes) do
		for _, name in ipairs(names) do
			nodes[modname .. ":" .. prefix .. name] = acoustic
		end
	end
end

local function add_stairs(names, acoustic)
	add_prefixed("mcl_stairs", { "stair_", "slab_" }, names, acoustic)
end

add("mcl_books", {
	"bookshelf", "chiseled_bookshelf", "shelf",
}, "wood")

add("mcl_pots", {
	"decorated_pot", "flower_pot",
}, "brickstone")

add("mcl_sponges", { "sponge" }, "organic")
add("mcl_sponges", { "wet_sponge" }, "mud")

add("mcl_lanterns", {
	"lantern", "soul_lantern",
}, "metalbar")

add("mcl_mobspawners", {
	"spawner", "trial_spawner", "vault",
}, "metalbar")

add("mcl_roots", {
	"mangrove_roots", "muddy_mangrove_roots",
}, "mud,slick")

add("mcl_pale_oak", {
	"pale_oak_tree", "pale_oak_wood", "pale_oak_planks",
	"pale_oak_log", "pale_oak_leaves",
}, "softwood")

add("mcl_pale_oak", {
	"creaking_heart",
}, "softwood,creaking")

add("mcl_core", {
	"stone", "cobble", "mossycobble", "coalblock", "andesite", "diorite",
	"granite", "tuff", "calcite", "dripstone_block", "pointed_dripstone",
	"raw_iron_block", "raw_copper_block", "raw_gold_block",
}, "stone")

add("mcl_core", {
	"polished_andesite", "polished_diorite", "polished_granite",
	"smoothstone", "smooth_stone",
}, "marble")

add("mcl_core", {
	"brick_block", "stonebrick", "stone_bricks", "stonebrickmossy",
	"mossy_stone_bricks", "stonebrickcracked", "cracked_stone_bricks",
	"stonebrickcarved", "chiseled_stone_bricks",
}, "brickstone")

add("mcl_core", {
	"stone_with_coal", "stone_with_copper", "stone_with_diamond",
	"stone_with_emerald", "stone_with_gold", "stone_with_iron",
	"stone_with_lapis", "stone_with_redstone", "stone_with_quartz",
}, "ore")

add("mcl_core", {
	"dirt", "coarse_dirt", "rooted_dirt", "dirt_with_snow", "clay",
	"farmland", "farmland_wet",
}, "dirt")

add("mcl_core", {
	"dirt_with_grass", "dirt_with_grass_snow", "mycelium", "podzol",
	"grass_path", "dirt_path", "path",
}, "grass")

add("mcl_core", {
	"sand", "desert_sand", "redsand", "red_sand",
}, "sand")

add("mcl_core", { "suspicious_sand" }, "sand")

add("mcl_core", {
	"sandstone", "desert_sandstone", "redsandstone", "red_sandstone",
	"smooth_sandstone", "smooth_red_sandstone", "cut_sandstone",
	"cut_red_sandstone",
}, "sandstone")

add("mcl_core", { "gravel", "suspicious_gravel" }, "gravel")
add("mcl_core", { "snow", "snowblock", "snow_block", "snow_layer" }, "snow")
add("mcl_core", { "ice", "packed_ice", "blue_ice", "frosted_ice" }, "ice")
add("mcl_core", { "glass", "glass_pane", "tinted_glass" }, "glass")
add("mcl_core", { "obsidian", "crying_obsidian" }, "obsidian")
add("mcl_core", { "ironblock", "goldblock" }, "hardmetal")
add("mcl_core", { "copperblock", "copper_block" }, "copper")
add("mcl_core", { "diamondblock", "emeraldblock", "lapisblock", "redstoneblock" }, "composite")
add("mcl_core", { "leaves", "appleleaves", "azalealeaves", "azalea_leaves" }, "leaves")
add("mcl_core", wood_sets, "wood")

add("mcl_deepslate", {
	"deepslate", "infested_deepslate",
}, "slate")

add("mcl_deepslate", {
	"cobbled_deepslate", "reinforced_deepslate",
}, "rough_slate")

add("mcl_deepslate", {
	"polished_deepslate",
}, "composite,ore")

add("mcl_deepslate", {
	"deepslate_bricks", "cracked_deepslate_bricks", "chiseled_deepslate",
	"deepslate_tiles", "cracked_deepslate_tiles",
}, "brickstone")

add("mcl_deepslate", {
	"deepslate_with_coal", "deepslate_with_copper", "deepslate_with_diamond",
	"deepslate_with_emerald", "deepslate_with_gold", "deepslate_with_iron",
	"deepslate_with_lapis", "deepslate_with_redstone", "deepslate_coal_ore",
	"deepslate_copper_ore", "deepslate_diamond_ore", "deepslate_emerald_ore",
	"deepslate_gold_ore", "deepslate_iron_ore", "deepslate_lapis_ore",
	"deepslate_redstone_ore",
}, "slate_ore")

add("mcl_blackstone", {
	"blackstone", "gilded_blackstone",
}, "stone")

add("mcl_blackstone", {
	"polished_blackstone",
}, "marble")

add("mcl_blackstone", {
	"polished_blackstone_brick", "polished_blackstone_bricks",
	"cracked_polished_blackstone_bricks", "chiseled_polished_blackstone",
}, "brickstone")

add("mcl_end", { "end_stone" }, "stone")
add("mcl_end", { "end_stone_bricks", "end_bricks" }, "brickstone")

add("mcl_ocean", {
	"prismarine", "dark_prismarine",
}, "stone")

add("mcl_ocean", {
	"prismarine_brick", "prismarine_bricks",
}, "brickstone")

add("mcl_ocean", { "sea_lantern" }, "stoneutility")

add("mcl_ocean", {
	"coral_block", "tube_coral_block", "brain_coral_block",
	"bubble_coral_block", "fire_coral_block", "horn_coral_block",
	"dead_tube_coral_block", "dead_brain_coral_block",
	"dead_bubble_coral_block", "dead_fire_coral_block",
	"dead_horn_coral_block",
}, "organic")

add("mcl_nether", {
	"netherrack", "basalt", "smooth_basalt", "blackstone",
}, "stone")

add("mcl_nether", {
	"polished_basalt",
}, "marble")

add("mcl_nether", {
	"nether_brick", "nether_bricks", "red_nether_brick", "red_nether_bricks",
	"cracked_nether_bricks", "chiseled_nether_bricks",
}, "brickstone")

add("mcl_nether", {
	"nether_gold_ore", "quartz_ore", "nether_quartz_ore",
}, "ore")

add("mcl_nether", { "glowstone" }, "glowstone")
add("mcl_nether", { "shroomlight", "nether_wart_block", "warped_wart_block" }, "organic,mushroom")
add("mcl_nether", { "magma", "magma_block" }, "magma")
add("mcl_nether", { "soul_sand" }, "quicksand")
add("mcl_nether", { "soul_soil" }, "souls")
add("mcl_nether", { "netheriteblock", "netherite_block", "ancient_debris" }, "hollowmetal")

add("mcl_mud", {
	"mud", "muddy_mangrove_roots",
}, "mud")

add("mcl_mud", {
	"packed_mud",
}, "dirt")

add("mcl_mud", {
	"mud_bricks", "mud_brick",
}, "brickstone")

add("mcl_farming", { "soil" }, "dirt")
add("mcl_farming", { "soil_wet", "wet_soil" }, "mud")

add("mcl_sculk", {
	"sculk", "sculk_catalyst", "sculk_vein", "sculk_shrieker",
}, "organic_solid")

add("mcl_sculk", { "sculk_sensor" }, "sand,mud")
add("mcl_bone", { "bone_block" }, "bone")
add("mcl_resin", { "resin_block", "resin_bricks", "resin_brick" }, "resin")

add("mcl_bamboo", {
	"bamboo_block", "stripped_bamboo_block", "bamboo_mosaic",
	"bamboo_plank", "bamboo_planks",
}, "squeakywood")

add("mcl_cherry_blossom", {
	"cherrywood", "cherrytree", "cherry_wood", "cherry_log",
	"cherry_planks", "cherry_leaves",
}, "softwood")

add("mcl_trees", {
	"tree_cherry_blossom", "wood_cherry_blossom", "bark_cherry_blossom",
	"stripped_cherry_blossom", "bark_stripped_cherry_blossom",
}, "softwood")

add("mcl_stairs", {
	-- VoxeLibre names.
	"stair_cherrywood", "stair_cherrywood_inner", "stair_cherrywood_outer",
	"slab_cherrywood", "slab_cherrywood_top", "slab_cherrywood_double",
	-- Mineclonia plank and bark names.
	"stair_cherry_blossom", "stair_cherry_blossom_inner", "stair_cherry_blossom_outer",
	"slab_cherry_blossom", "slab_cherry_blossom_top", "slab_cherry_blossom_double",
	"stair_cherry_blossom_bark", "stair_cherry_blossom_bark_inner",
	"stair_cherry_blossom_bark_outer", "slab_cherry_blossom_bark",
	"slab_cherry_blossom_bark_top", "slab_cherry_blossom_bark_double",
}, "softwood")

add("mcl_trees", {
	"tree_oak", "tree_birch", "tree_spruce", "tree_jungle", "tree_dark_oak",
	"tree_mangrove", "tree_cherry", "wood_oak", "wood_birch", "wood_spruce",
	"wood_jungle", "wood_dark_oak", "mangrove_wood", "cherry_wood",
	"mangrove_planks", "cherry_planks",
}, "wood")

add("mcl_trees", {
	"leaves_oak", "leaves_birch", "leaves_spruce", "leaves_jungle",
	"leaves_dark_oak", "leaves_mangrove", "leaves_cherry", "mangrove_leaves",
	"cherry_leaves",
}, "leaves")

add("mcl_crimson", {
	"crimson_hyphae", "crimson_planks", "crimson_stem", "warped_hyphae",
	"warped_planks", "warped_stem",
}, "wood,mushroom")

add("mcl_copper", {
	"copper_block", "cut_copper", "exposed_copper", "exposed_cut_copper",
	"weathered_copper", "weathered_cut_copper", "oxidized_copper",
	"oxidized_cut_copper", "waxed_copper_block", "waxed_cut_copper",
	"waxed_exposed_copper", "waxed_exposed_cut_copper",
	"waxed_weathered_copper", "waxed_weathered_cut_copper",
	"waxed_oxidized_copper", "waxed_oxidized_cut_copper",
}, "copper")

add("mcl_copper", {
	"copper_grate", "exposed_copper_grate", "weathered_copper_grate",
	"oxidized_copper_grate", "waxed_copper_grate",
	"waxed_exposed_copper_grate", "waxed_weathered_copper_grate",
	"waxed_oxidized_copper_grate",
}, "metalgrate")

add("mcl_copper", {
	"copper_bulb", "exposed_copper_bulb", "weathered_copper_bulb",
	"oxidized_copper_bulb", "waxed_copper_bulb",
	"waxed_exposed_copper_bulb", "waxed_weathered_copper_bulb",
	"waxed_oxidized_copper_bulb",
}, "squeakycopper")

add("mcl_chains", { "chain" }, "chain")
add("mcl_chain", { "chain" }, "chain")
add("mcl_bars", { "iron_bars", "bars" }, "hardmetal")
add("mcl_iron_bars", { "iron_bars", "bars" }, "hardmetal")

add("mcl_rails", {
	"rail", "golden_rail", "powered_rail", "detector_rail", "activator_rail",
}, "rails")

add("mcl_minecarts", {
	"rail", "golden_rail", "powered_rail", "detector_rail", "activator_rail",
}, "rails")

for _, color in ipairs(colors) do
	nodes["mcl_wool:" .. color] = "rug"
	nodes["mcl_wool:" .. color .. "_wool"] = "rug"
	nodes["mcl_carpets:" .. color] = "rug"
	nodes["mcl_carpets:" .. color .. "_carpet"] = "rug"
	nodes["mcl_beds:bed_" .. color] = "rug"
	nodes["mcl_stained_glass:" .. color] = "glass"
	nodes["mcl_stained_glass:" .. color .. "_glass"] = "glass"
	nodes["mcl_stained_glass:" .. color .. "_glass_pane"] = "glass"
	nodes["mcl_panes:" .. color .. "_glass_pane"] = "glass"
	nodes["mcl_colorblocks:concrete_" .. color] = "stone"
	nodes["mcl_colorblocks:concrete_powder_" .. color] = "sand"
	nodes["mcl_colorblocks:hardened_clay_" .. color] = "brickstone"
	nodes["mcl_colorblocks:glazed_terracotta_" .. color] = "brickstone"
	nodes["mcl_colorblocks:glazed_terracotta_pillar_" .. color] = "brickstone"
end

nodes["mcl_colorblocks:hardened_clay"] = "brickstone"

add_stairs({
	"stone", "cobble", "mossycobble", "andesite", "diorite", "granite",
	"blackstone", "prismarine", "dark_prismarine", "end_stone",
}, "stone")

add_stairs({
	"polished_andesite", "polished_diorite", "polished_granite",
	"polished_blackstone", "polished_tuff", "smooth_stone",
}, "marble")

add_stairs({
	"brick_block", "stonebrick", "stone_bricks", "deepslate_bricks",
	"deepslate_tiles", "blackstone_bricks", "polished_blackstone_bricks",
	"end_stone_bricks", "nether_bricks", "mud_bricks",
}, "brickstone")

add_stairs({
	"sandstone", "redsandstone", "red_sandstone", "desert_sandstone",
}, "sandstone")

add_stairs({
	"deepslate", "cobbled_deepslate",
}, "rough_slate")

add_stairs({
	"wood", "oakwood", "birchwood", "sprucewood", "junglewood",
	"acaciawood", "darkwood", "mangrove_wood", "cherry_wood",
}, "wood")

add_stairs({
	"bamboo", "bamboo_mosaic",
}, "squeakywood")

add_stairs({
	"crimson", "crimson_hyphae", "warped", "warped_hyphae",
}, "wood,mushroom")

return nodes
