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
		&"grass":       { "color": Color(0.27, 0.47, 0.28), "tex": "", "variants": 3, "y": 0.02, "emissive": false },
		&"stone_plaza": { "color": Color(0.60, 0.61, 0.66), "tex": "", "variants": 2, "y": 0.03, "emissive": false },
		&"stone_path":  { "color": Color(0.70, 0.68, 0.62), "tex": "", "variants": 3, "y": 0.03, "emissive": false },
		&"dirt_path":   { "color": Color(0.42, 0.34, 0.25), "tex": "", "variants": 2, "y": 0.025, "emissive": false },
		&"flowerbed":   { "color": Color(0.30, 0.24, 0.20), "tex": "", "variants": 2, "y": 0.025, "emissive": false },
	},
	# Pond inset (world coords). Aligned with the '~' cells (upper-right).
	"pond": {
		"center": Vector2(30.0, -60.0), "radius": 20.0, "y": 0.0,
		"water_color": Color(0.14, 0.52, 0.68, 0.85), "rim_color": Color(0.55, 0.9, 1.0),
	},
	# Authored floor decals (Task 8). type maps to a texture in Task 10; size in world units.
	"decals": [
		{ "type": "plaza_medallion", "pos": Vector2(0, 0),   "size": 40.0, "rot": 0.0 },
		{ "type": "path_wear",       "pos": Vector2(0, 40),  "size": 10.0, "rot": 0.0 },
		{ "type": "path_wear",       "pos": Vector2(0, -40), "size": 10.0, "rot": 0.0 },
		{ "type": "leaves",          "pos": Vector2(-40, 40), "size": 8.0, "rot": 0.7 },
		{ "type": "moss",            "pos": Vector2(-44, 24), "size": 7.0, "rot": 0.0 },
		{ "type": "crack",           "pos": Vector2(24, 8),  "size": 6.0, "rot": 1.2 },
	],
	# Prop clusters (Task 5 PropLayout shape). role ∈ landmark|medium|small.
	# item = [scene_key, count, collide, scale].
	"prop_clusters": [
		{ "role": &"landmark", "center": Vector2(0, 40), "ext": 1.0, "seed": 1, "sep": 1.0,
			"items": [["garden_hero_tree_3d", 1, true, 1.0]] },
		{ "role": &"medium", "center": Vector2(-30, 20), "ext": 10.0, "seed": 10, "sep": 6.0,
			"items": [["garden_bench_3d", 2, true, 1.0], ["garden_planter_3d", 2, true, 1.0]] },
		{ "role": &"medium", "center": Vector2(34, 30), "ext": 10.0, "seed": 11, "sep": 6.0,
			"items": [["garden_trellis_3d", 1, true, 1.0], ["prop_lamp_3d", 1, false, 1.0]] },
		{ "role": &"small", "center": Vector2(-40, 40), "ext": 10.0, "seed": 20, "sep": 3.0,
			"items": [["prop_bush_3d", 3, false, 1.0], ["prop_flowers_3d", 4, false, 1.0]] },
		{ "role": &"small", "center": Vector2(40, -20), "ext": 10.0, "seed": 21, "sep": 3.0,
			"items": [["prop_tall_grass_3d", 5, false, 1.0], ["prop_mushroom_3d", 2, false, 1.0]] },
		{ "role": &"small", "center": Vector2(-44, -20), "ext": 8.0, "seed": 22, "sep": 3.0,
			"items": [["garden_bollard_3d", 3, true, 1.0], ["prop_flowers_3d", 3, false, 1.0]] },
	],
}
