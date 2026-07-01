extends Node
## Garden district recipe: ASCII zone map + per-zone materials + pond inset + authored
## decals + prop clusters. One recipe = one district (replicable). Read by FloorBuilder
## and GardenScatter. Pure data — no logic.

# static var (not const): the recipe holds PackedStringArray/Vector2/Color values, and a
# PackedStringArray literal is not a constant expression in GDScript. Accessed the same way
# (`load("res://arena/maps/garden_map.gd").RECIPE`).
static var RECIPE := {
	"cell_size": 8.0,
	"rows": PackedStringArray([
		"...........==...........",
		"...........==...........",
		"...........==...~~~~~...",
		"...**......==...~~~~~...",
		"...**......==...~~~~~...",
		"...........==...~~~~~...",
		"...........==...~~~~~...",
		"...........==...........",
		"........########........",
		"........########........",
		"........########........",
		"========########========",
		"========########========",
		"........########........",
		"........########........",
		"......-.########........",
		"......-....==...........",
		"......-....==....***....",
		"....***....==....***....",
		"....***....==....***....",
		"....***----==...........",
		"...........==...........",
		"...........==...........",
		"...........==...........",
	]),
	"legend": {
		".": &"grass", "#": &"stone_plaza", "=": &"stone_path",
		"-": &"dirt_path", "*": &"flowerbed", "~": &"pond",
	},
	# Higher owns the seam. pond/void intentionally absent (handled as insets / walls).
	"priority": {
		&"stone_plaza": 5, &"stone_path": 4, &"dirt_path": 3, &"flowerbed": 2, &"grass": 1,
	},
	# Painterly matte StandardMaterial3D defs. tex filled in Task 10 (SDXL); color is the
	# fallback/tint. y is the base-layer height (tiny steps avoid z-fighting).
	"zones": {
		# WALKABLE floor must stay ~flat at the entity plane (y~0): player/enemies live on a
		# flat navmesh, so any raised walkable zone visually swallows them. Height/relief comes
		# from normals, non-walkable edge curbs, and props — never from raising the combat floor.
		# Tiny per-zone offsets are for draw order only.
		&"grass":       { "color": Color(0.96, 0.98, 0.96), "tex": "res://art/textures/garden_grass.png", "variants": 3, "y": 0.02, "emissive": false },
		&"stone_plaza": { "color": Color(0.98, 0.98, 0.98), "tex": "res://art/textures/garden_stone_plaza.png", "variants": 1, "y": 0.08, "emissive": false },
		&"stone_path":  { "color": Color(0.98, 0.98, 0.98), "tex": "res://art/textures/garden_stone_path.png", "variants": 3, "y": 0.05, "emissive": false },
		&"dirt_path":   { "color": Color(0.98, 0.98, 0.98), "tex": "res://art/textures/garden_dirt_path.png", "variants": 2, "y": 0.02, "emissive": false },
		&"flowerbed":   { "color": Color(1.0, 1.0, 1.0), "tex": "res://art/textures/garden_flowerbed.png", "variants": 2, "y": 0.02, "emissive": false },
	},
	# Pond inset (world coords). Aligned with the '~' cells (upper-right).
	"pond": {
		"center": Vector2(52.0, -60.0), "radius": 26.0, "y": 0.0,
		"water_color": Color(0.14, 0.52, 0.68, 0.85), "rim_color": Color(0.55, 0.9, 1.0),
	},
	# Authored floor decals (Task 8). type maps to a texture in Task 10; size in world units.
	"decals": [
		{ "type": "path_wear",       "pos": Vector2(0, 40),  "size": 10.0, "rot": 0.0 },
		{ "type": "path_wear",       "pos": Vector2(0, -40), "size": 10.0, "rot": 0.0 },
		{ "type": "leaves",          "pos": Vector2(-40, 40), "size": 8.0, "rot": 0.7 },
		{ "type": "moss",            "pos": Vector2(-44, 24), "size": 7.0, "rot": 0.0 },
		{ "type": "crack",           "pos": Vector2(24, 8),  "size": 6.0, "rot": 1.2 },
	],
	# Prop clusters (Task 5 PropLayout shape). role ∈ landmark|medium|small.
	# item = [scene_key, count, collide, scale].
	# Dense, clustered, intentional layout (~90 props). Landmarks anchor; trees + furniture
	# ring the plaza; lamps/bollards line the paths; foliage fills the four grass quadrants.
	"prop_clusters": [
		# --- Landmarks (hero tree + off-center fountain; center stays open for combat) ---
		{ "role": &"landmark", "center": Vector2(0, 44), "ext": 1.0, "seed": 1, "sep": 1.0,
			"items": [["garden_hero_tree_3d", 1, true, 1.8]] },
		{ "role": &"landmark", "center": Vector2(-34, -34), "ext": 1.0, "seed": 2, "sep": 1.0,
			"items": [["garden_fountain_3d", 1, true, 1.6]] },
		# --- Ornamental trees in the grass quadrants ---
		{ "role": &"medium", "center": Vector2(46, 46), "ext": 14.0, "seed": 30, "sep": 8.0,
			"items": [["garden_hero_tree_3d", 3, true, 0.9]] },
		{ "role": &"medium", "center": Vector2(-48, 46), "ext": 14.0, "seed": 31, "sep": 8.0,
			"items": [["garden_hero_tree_3d", 2, true, 0.85]] },
		{ "role": &"medium", "center": Vector2(48, -44), "ext": 12.0, "seed": 32, "sep": 8.0,
			"items": [["garden_hero_tree_3d", 2, true, 0.9]] },
		# --- Plaza-edge furniture ---
		{ "role": &"medium", "center": Vector2(-30, 20), "ext": 10.0, "seed": 10, "sep": 6.0,
			"items": [["garden_bench_3d", 2, true, 1.4], ["garden_planter_3d", 2, true, 1.4]] },
		{ "role": &"medium", "center": Vector2(30, 22), "ext": 10.0, "seed": 11, "sep": 6.0,
			"items": [["garden_trellis_3d", 1, true, 1.4], ["garden_planter_3d", 2, true, 1.3]] },
		{ "role": &"medium", "center": Vector2(20, -30), "ext": 10.0, "seed": 12, "sep": 6.0,
			"items": [["garden_bench_3d", 2, true, 1.3], ["garden_planter_3d", 1, true, 1.3]] },
		# --- Lamps + bollards lining the four paths ---
		{ "role": &"small", "center": Vector2(0, 66), "ext": 6.0, "seed": 40, "sep": 5.0,
			"items": [["prop_lamp_3d", 2, false, 1.3], ["garden_bollard_3d", 3, true, 1.2]] },
		{ "role": &"small", "center": Vector2(0, -66), "ext": 6.0, "seed": 41, "sep": 5.0,
			"items": [["prop_lamp_3d", 2, false, 1.3], ["garden_bollard_3d", 3, true, 1.2]] },
		{ "role": &"small", "center": Vector2(66, 4), "ext": 6.0, "seed": 42, "sep": 5.0,
			"items": [["prop_lamp_3d", 2, false, 1.3], ["garden_bollard_3d", 2, true, 1.2]] },
		{ "role": &"small", "center": Vector2(-66, 4), "ext": 6.0, "seed": 43, "sep": 5.0,
			"items": [["prop_lamp_3d", 2, false, 1.3], ["garden_bollard_3d", 2, true, 1.2]] },
		# --- Dense foliage in the four grass quadrants ---
		{ "role": &"small", "center": Vector2(44, 38), "ext": 16.0, "seed": 50, "sep": 3.5,
			"items": [["prop_bush_3d", 5, false, 1.3], ["prop_flowers_3d", 5, false, 1.3], ["prop_tall_grass_3d", 5, false, 1.3]] },
		{ "role": &"small", "center": Vector2(-46, 38), "ext": 16.0, "seed": 51, "sep": 3.5,
			"items": [["prop_bush_3d", 5, false, 1.3], ["prop_tall_grass_3d", 6, false, 1.3], ["prop_mushroom_3d", 3, false, 1.3]] },
		{ "role": &"small", "center": Vector2(46, -40), "ext": 14.0, "seed": 52, "sep": 3.5,
			"items": [["prop_bush_3d", 4, false, 1.3], ["prop_flowers_3d", 5, false, 1.3], ["prop_tall_grass_3d", 4, false, 1.3]] },
		{ "role": &"small", "center": Vector2(-46, -42), "ext": 14.0, "seed": 53, "sep": 3.5,
			"items": [["prop_bush_3d", 4, false, 1.3], ["prop_mushroom_3d", 3, false, 1.3], ["prop_tall_grass_3d", 4, false, 1.3]] },
		# --- Flowers hugging the pond shore ---
		{ "role": &"small", "center": Vector2(52, -44), "ext": 8.0, "seed": 60, "sep": 3.0,
			"items": [["prop_flowers_3d", 5, false, 1.3], ["prop_bush_3d", 2, false, 1.2]] },
	],
}
