extends RefCounted
## Map recipe for the "Final City" arena. Pure data consumed by MapBuilder.
## Edit this file (or copy it to a new map_*.gd) to author new maps — the engine
## (arena/map_builder.gd) never hard-codes layout.
##
## Conventions:
##  - All positions are Vector2 in world XZ. x = east(+), z = south(+), north = -z.
##  - Playfield is bounded by walls at +/-95; keep content within ~+/-90.
##  - The base grass carpet (200x200) is the arena's flat Ground plane at y=0;
##    biomes/paths/features paint on top using small ascending y to avoid z-fighting.

const TEX := {
	"grass":     "res://art/textures/final_city_grass_albedo.png",
	"sand":      "res://art/textures/final_city_sand_albedo.png",
	"floor":     "res://art/textures/final_city_floor_albedo.png",
	"cobble":    "res://art/textures/final_city_cobble_albedo.png",
	"corrupted": "res://art/textures/final_city_corrupted_albedo.png",
	"pavement":  "res://art/textures/final_city_pavement_albedo.png",
	"plaza":     "res://art/textures/final_city_plaza_albedo.png",
	"hex":       "res://art/textures/final_city_hex_albedo.png",
	"dirt":      "res://art/textures/final_city_dirt_albedo.png",
	"brick":     "res://art/textures/final_city_brick_albedo.png",
}

const RECIPE := {
	"textures": TEX,

	# --- Organic biome blobs (overlapping circles -> soft non-grid outlines) ---
	# Districts are large and abut/overlap so the floor itself carries the map;
	# grass shows through the gaps as calm connective tissue, not an empty sea.
	"biomes": [
		{  # S/SE warm beach — sweeps across the bottom toward both edges
			"tex": "sand", "uv": 0.06, "color": Color(0.95, 0.88, 0.70), "y": 0.040,
			"blobs": [
				[Vector2(34, 56), 20.0], [Vector2(58, 62), 24.0], [Vector2(80, 74), 18.0],
				[Vector2(52, 82), 16.0], [Vector2(82, 50), 16.0], [Vector2(20, 74), 14.0],
				[Vector2(66, 40), 14.0], [Vector2(40, 80), 12.0], [Vector2(6, 64), 11.0],
			],
		},
		{  # W cyber-tech floor — runs the full left edge
			"tex": "floor", "uv": 0.07, "color": Color(0.70, 0.82, 0.95), "y": 0.050,
			"blobs": [
				[Vector2(-64, -6), 20.0], [Vector2(-72, 18), 22.0], [Vector2(-58, 38), 18.0],
				[Vector2(-50, -26), 16.0], [Vector2(-82, 6), 16.0], [Vector2(-66, 56), 15.0],
				[Vector2(-44, 14), 13.0], [Vector2(-84, -20), 12.0], [Vector2(-40, -6), 11.0],
			],
		},
		{  # NE cobble urban — fills the top-right
			"tex": "cobble", "uv": 0.10, "color": Color(0.78, 0.76, 0.72), "y": 0.045,
			"blobs": [
				[Vector2(42, -46), 18.0], [Vector2(60, -62), 22.0], [Vector2(78, -74), 16.0],
				[Vector2(52, -80), 15.0], [Vector2(80, -52), 14.0], [Vector2(32, -64), 13.0],
				[Vector2(66, -36), 12.0], [Vector2(20, -50), 11.0],
			],
		},
		{  # E brick district — right edge between cobble and beach
			"tex": "brick", "uv": 0.09, "color": Color(0.82, 0.55, 0.42), "y": 0.048,
			"blobs": [
				[Vector2(84, -10), 15.0], [Vector2(88, 14), 15.0],
				[Vector2(78, -26), 11.0], [Vector2(80, 30), 11.0],
			],
		},
		{  # SW corrupted patches (small, scattered)
			"tex": "corrupted", "uv": 0.10, "color": Color(0.55, 0.40, 0.65), "y": 0.060,
			"blobs": [
				[Vector2(-50, 56), 11.0], [Vector2(-62, 66), 9.0], [Vector2(-42, 70), 7.0],
				[Vector2(-66, 48), 6.0], [Vector2(-54, 46), 6.0], [Vector2(-74, 62), 6.0],
			],
		},
		{  # dirt verge softening the NW around the lake
			"tex": "dirt", "uv": 0.08, "color": Color(0.72, 0.62, 0.50), "y": 0.035,
			"blobs": [
				[Vector2(-38, -44), 13.0], [Vector2(-28, -62), 10.0], [Vector2(-46, -78), 9.0],
				[Vector2(-24, -46), 8.0], [Vector2(-16, -64), 7.0],
			],
		},
		{  # darker grass patches — break up the flat green of the open lawn
			"tex": "grass", "uv": 0.09, "color": Color(0.32, 0.44, 0.26), "y": 0.030,
			"blobs": [
				[Vector2(2, 38), 16.0], [Vector2(24, 22), 13.0], [Vector2(-8, 8), 13.0],
				[Vector2(18, -30), 12.0], [Vector2(42, 40), 12.0], [Vector2(-30, -10), 11.0],
			],
		},
		{  # warm/yellow grass patches — second tonal variation
			"tex": "grass", "uv": 0.085, "color": Color(0.56, 0.60, 0.34), "y": 0.032,
			"blobs": [
				[Vector2(-26, 4), 12.0], [Vector2(12, -14), 11.0], [Vector2(36, 6), 11.0],
				[Vector2(-4, 54), 12.0], [Vector2(50, 26), 10.0], [Vector2(-40, 44), 10.0],
			],
		},
	],

	# --- Water lake (NW) with a bright shoreline rim ---
	"water": [
		{
			"color": Color(0.16, 0.52, 0.66, 0.92), "rim_color": Color(0.80, 0.84, 0.78),
			"y": 0.090, "rim_y": 0.070, "rim_grow": 2.5,
			"blobs": [
				[Vector2(-58, -62), 15.0], [Vector2(-46, -70), 11.0], [Vector2(-70, -52), 10.0],
				[Vector2(-52, -52), 8.0], [Vector2(-40, -58), 8.0],
			],
		},
	],

	# --- Winding paths (pavement ribbons; wander, don't radiate) ---
	"paths": [
		{  # main NW -> SE S-curve through the central plaza
			"tex": "pavement", "uv": 0.10, "color": Color(0.80, 0.80, 0.84),
			"y": 0.130, "width": 9.0,
			"points": [
				Vector2(-90, -80), Vector2(-66, -50), Vector2(-34, -34), Vector2(-12, -8),
				Vector2(0, 0), Vector2(16, 18), Vector2(38, 30), Vector2(58, 58), Vector2(88, 84),
			],
		},
		{  # wandering connector: plaza -> W tech, bowing north
			"tex": "pavement", "uv": 0.10, "color": Color(0.80, 0.80, 0.84),
			"y": 0.128, "width": 7.0,
			"points": [Vector2(0, 0), Vector2(-22, -10), Vector2(-46, -4), Vector2(-66, 10),
				Vector2(-84, 4)],
		},
		{  # wandering connector: plaza -> NE cobble, bowing east
			"tex": "pavement", "uv": 0.10, "color": Color(0.80, 0.80, 0.84),
			"y": 0.126, "width": 7.0,
			"points": [Vector2(0, 0), Vector2(26, -10), Vector2(44, -28), Vector2(52, -52),
				Vector2(72, -68)],
		},
		{  # spur: beach -> brick along the SE/E
			"tex": "pavement", "uv": 0.10, "color": Color(0.78, 0.78, 0.82),
			"y": 0.124, "width": 6.0,
			"points": [Vector2(58, 58), Vector2(74, 36), Vector2(82, 10), Vector2(84, -12)],
		},
		{  # spur: plaza -> SW corrupted, meandering
			"tex": "pavement", "uv": 0.10, "color": Color(0.78, 0.78, 0.82),
			"y": 0.122, "width": 6.0,
			"points": [Vector2(0, 0), Vector2(-16, 24), Vector2(-38, 40), Vector2(-54, 62)],
		},
	],

	# --- Decorative floor features (medallion + capture-circle rings) ---
	"features": [
		# Central plaza medallion: stacked discs + glowing concentric rings.
		{"type": "disc", "pos": Vector2(0, 0), "r": 23.0, "tex": "plaza", "uv": 0.09,
			"color": Color(0.82, 0.80, 0.78), "y": 0.150},
		{"type": "ring", "pos": Vector2(0, 0), "inner": 19.5, "outer": 22.0,
			"color": Color(0.30, 0.85, 1.0), "emissive": true, "y": 0.160},
		{"type": "ring", "pos": Vector2(0, 0), "inner": 12.0, "outer": 13.5,
			"color": Color(1.0, 0.82, 0.30), "emissive": true, "y": 0.160},
		{"type": "disc", "pos": Vector2(0, 0), "r": 7.0, "tex": "hex", "uv": 0.16,
			"color": Color(0.55, 0.85, 1.0), "y": 0.170},
		# Capture-circle accents at each biome focal point.
		{"type": "ring", "pos": Vector2(58, 56), "inner": 8.0, "outer": 9.5,
			"color": Color(1.0, 0.70, 0.30), "emissive": true, "y": 0.110},
		{"type": "ring", "pos": Vector2(-62, 10), "inner": 9.0, "outer": 10.5,
			"color": Color(0.35, 0.90, 1.0), "emissive": true, "y": 0.110},
		{"type": "ring", "pos": Vector2(56, -56), "inner": 8.0, "outer": 9.5,
			"color": Color(1.0, 0.55, 0.25), "emissive": true, "y": 0.110},
	],
}
