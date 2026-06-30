# See docs/notes/arena-scatter.md
class_name ArenaScatter extends Node
## Seeded, deterministic placement of arena obstacles on the XZ plane.
## Pure logic (compute_positions) is unit-tested headless — DO NOT change its
## signature or logic. _ready() places biome-themed props per region
## (NW Forest, NE City, SW Tech, SE Beach) plus a central plaza hub and road lamps.

## Returns up to `count` XZ positions (y=0) inside [-extent, extent], none within
## `clear_radius` of origin, all at least `min_separation` apart. Deterministic for
## a fixed `rng_seed`. Rejection sampling with a bounded attempt budget so an
## over-dense request terminates instead of looping forever.
static func compute_positions(rng_seed: int, count: int, extent: float,
		clear_radius: float, min_separation: float, attempts_per: int = 30) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	var out: Array = []
	var min_sep_sq := min_separation * min_separation
	var clear_sq := clear_radius * clear_radius
	for _i in count:
		var placed := false
		for _a in attempts_per:
			var x := rng.randf_range(-extent, extent)
			var z := rng.randf_range(-extent, extent)
			if x * x + z * z < clear_sq:
				continue  # too close to the spawn center
			var candidate := Vector3(x, 0.0, z)
			var ok := true
			for p in out:
				if candidate.distance_squared_to(p) < min_sep_sq:
					ok = false
					break
			if ok:
				out.append(candidate)
				placed = true
				break
		if not placed:
			# Could not fit another after attempts_per tries — area is saturated.
			break
	return out

# --- Footprint (collision + nav) per prop key: [radius, height] ---
const _FP := {
	"prop_tree_3d":             [0.8,  6.0],
	"prop_rock_3d":             [1.2,  2.0],
	"prop_crate_3d":            [0.7,  1.5],
	"prop_barrel_3d":           [0.5,  1.5],
	"prop_dumpster_3d":         [1.2,  2.0],
	"prop_fence_3d":            [0.5,  1.5],
	"prop_concrete_barrier_3d": [1.0,  1.5],
	"prop_pillar_3d":           [0.5,  4.0],
	"prop_fountain_3d":         [1.5,  3.0],
	"sci_fi_pylon_3d":          [0.8,  6.0],
	"sci_fi_barrier_3d":        [1.4,  2.0],
	"prop_generator_3d":        [1.0,  2.0],
}

## Per-region definitions. Each entry: { cx, cz, ext, seed, obs, dec }
##   obs → [[prop_key, count], …] — wrapped in Obstacle3D (collision + nav)
##   dec → [[prop_key, count], …] — plain visual node, no collision
## Regional centers are at ±50 with extent 34, so all placed props are ≥ 16 units
## from the global origin — well outside the 10-unit spawn disc.
const _REGIONS := [
	{  # NW Forest: x<0, z<0, center (-50,-50)
		"cx": -50.0, "cz": -50.0, "ext": 34.0, "seed": 100,
		"obs": [["prop_tree_3d", 4], ["prop_rock_3d", 2]],
		"dec": [["prop_bush_3d", 3], ["prop_flowers_3d", 2],
				["prop_tall_grass_3d", 2], ["prop_mushroom_3d", 1]],
	},
	{  # NE City: x>0, z<0, center (50,-50)
		"cx": 50.0, "cz": -50.0, "ext": 34.0, "seed": 200,
		"obs": [["prop_crate_3d", 3], ["prop_barrel_3d", 2],
				["prop_dumpster_3d", 1], ["prop_fence_3d", 2],
				["prop_concrete_barrier_3d", 2]],
		"dec": [["prop_cone_3d", 2], ["prop_holo_sign_3d", 1]],
	},
	{  # SW Tech: x<0, z>0, center (-50,50)
		"cx": -50.0, "cz": 50.0, "ext": 34.0, "seed": 300,
		"obs": [["sci_fi_pylon_3d", 3], ["sci_fi_barrier_3d", 2],
				["prop_generator_3d", 2]],
		"dec": [["prop_holo_sign_3d", 2]],
	},
	{  # SE Beach: x>0, z>0, center (50,50)
		"cx": 50.0, "cz": 50.0, "ext": 34.0, "seed": 400,
		"obs": [["prop_rock_3d", 3], ["prop_concrete_barrier_3d", 2],
				["prop_crate_3d", 2], ["prop_barrel_3d", 2],
				["prop_pillar_3d", 2]],
		"dec": [],
	},
]

## Minimum pairwise separation used for all seeded regional placements.
const _MIN_SEP := 6.0
## Base RNG seed; each region adds its own seed offset for independence.
const _BASE_SEED := 1

const _OBSTACLE_SCENE := preload("res://obstacles/obstacle_3d.tscn")

func _ready() -> void:
	var parent := get_parent()
	if parent == null:
		return
	# Activate navigation map so enemy RVO avoidance produces non-zero safe velocity.
	_activate_navigation(parent)

	var obstacles := Node3D.new()
	obstacles.name = "Obstacles"
	var decor := Node3D.new()
	decor.name = "Decor"

	_place_plaza_hub(obstacles, decor)
	_place_road_lamps(decor)
	for region in _REGIONS:
		_place_region(obstacles, decor, region)

	# Deferred: parent is busy adding children during scene entry.
	parent.add_child.call_deferred(obstacles)
	parent.add_child.call_deferred(decor)

# --- Plaza hub ---

## Place the fountain centerpiece, pillar ring, and brazier corners in the plaza.
func _place_plaza_hub(obstacles: Node3D, decor: Node3D) -> void:
	# Fountain obstacle — offset from spawn origin so the player doesn't spawn inside it.
	_spawn_obstacle(obstacles, "prop_fountain_3d", Vector3(0, 0, 16), "Fountain")
	# 6 pillars in a ring at radius 20 around plaza center.
	var pillar_ring := [
		Vector3(20, 0, 0),   Vector3(10, 0, 17),  Vector3(-10, 0, 17),
		Vector3(-20, 0, 0),  Vector3(-10, 0, -17), Vector3(10, 0, -17),
	]
	for pos in pillar_ring:
		_spawn_obstacle(obstacles, "prop_pillar_3d", pos)
	# 4 braziers as decorative accent — no collision.
	var brazier_ring := [
		Vector3(10, 0, 10), Vector3(-10, 0, 10),
		Vector3(-10, 0, -10), Vector3(10, 0, -10),
	]
	for pos in brazier_ring:
		_spawn_decor(decor, "prop_brazier_3d", pos)

# --- Road lamps ---

## Line each road arm with lamps every ~22 units, offset ±7 to either side.
func _place_road_lamps(decor: Node3D) -> void:
	var steps := [30.0, 52.0, 74.0, 96.0]
	for d in steps:
		_spawn_decor(decor, "prop_lamp_3d", Vector3(-7, 0, -d))  # N arm, left
		_spawn_decor(decor, "prop_lamp_3d", Vector3( 7, 0, -d))  # N arm, right
		_spawn_decor(decor, "prop_lamp_3d", Vector3(-7, 0,  d))  # S arm, left
		_spawn_decor(decor, "prop_lamp_3d", Vector3( 7, 0,  d))  # S arm, right
		_spawn_decor(decor, "prop_lamp_3d", Vector3(-d, 0, -7))  # W arm, top
		_spawn_decor(decor, "prop_lamp_3d", Vector3(-d, 0,  7))  # W arm, bottom
		_spawn_decor(decor, "prop_lamp_3d", Vector3( d, 0, -7))  # E arm, top
		_spawn_decor(decor, "prop_lamp_3d", Vector3( d, 0,  7))  # E arm, bottom

# --- Regional placement ---

## Place all obstacle and decor props for one biome region using compute_positions.
## Positions are generated relative to local (0,0) then offset to the region center.
func _place_region(obstacles: Node3D, decor: Node3D, region: Dictionary) -> void:
	var center := Vector3(region["cx"], 0.0, region["cz"])
	var ext: float = region["ext"]
	var seed_off: int = region["seed"]

	# Expand obstacle prop list: [[key, count], …] → [key, key, …]
	var obs_keys: Array = []
	for entry in region["obs"]:
		for _i in entry[1]:
			obs_keys.append(entry[0])

	if obs_keys.size() > 0:
		var positions := compute_positions(
				_BASE_SEED + seed_off, obs_keys.size(), ext, 0.0, _MIN_SEP)
		for i in positions.size():
			_spawn_obstacle(obstacles, obs_keys[i], center + positions[i])

	# Expand decor prop list
	var dec_keys: Array = []
	for entry in region["dec"]:
		for _i in entry[1]:
			dec_keys.append(entry[0])

	if dec_keys.size() > 0:
		# Offset seed by 50 so decor positions are independent of obstacle positions.
		var positions := compute_positions(
				_BASE_SEED + seed_off + 50, dec_keys.size(), ext, 0.0, _MIN_SEP)
		for i in positions.size():
			_spawn_decor(decor, dec_keys[i], center + positions[i])

# --- Helpers ---

## Create an Obstacle3D for `prop_key` at `pos`, optionally naming it `node_name`.
func _spawn_obstacle(container: Node3D, prop_key: String, pos: Vector3,
		node_name: String = "") -> void:
	var fp: Array = _FP.get(prop_key, [1.0, 2.0])
	var prop_scene := load("res://obstacles/%s.tscn" % prop_key) as PackedScene
	var obs: Obstacle3D = _OBSTACLE_SCENE.instantiate()
	if prop_scene != null:
		var model := prop_scene.instantiate()
		if model is Node3D:
			obs.set_model(model as Node3D, fp[0], fp[1])
		else:
			if model != null:
				model.free()
			obs.configure(_fallback_mesh(fp[0], fp[1]), fp[0], fp[1])
	else:
		push_warning("ArenaScatter: failed to load obstacle prop '%s'" % prop_key)
		obs.configure(_fallback_mesh(fp[0], fp[1]), fp[0], fp[1])
	obs.position = Vector3(pos.x, 0.0, pos.z)
	if node_name != "":
		obs.name = node_name
	container.add_child(obs)

## Instantiate a decoration (no collision) at `pos` and add it to `container`.
func _spawn_decor(container: Node3D, prop_key: String, pos: Vector3) -> void:
	var prop_scene := load("res://obstacles/%s.tscn" % prop_key) as PackedScene
	if prop_scene == null:
		push_warning("ArenaScatter: failed to load decor prop '%s'" % prop_key)
		return
	var node := prop_scene.instantiate()
	if node is Node3D:
		(node as Node3D).position = Vector3(pos.x, 0.0, pos.z)
		container.add_child(node)
	else:
		node.free()

## Add a flat NavigationRegion3D covering the playfield so the navigation map is
## ACTIVE. NavigationAgent3D avoidance (RVO) only produces a non-zero safe velocity
## on an active map; without a region the world's default map stays inactive and the
## avoidance callback returns zero. A single flat quad (no baking needed) is enough
## to activate the map; pathfinding navmesh detail is not required for pure avoidance.
func _activate_navigation(parent: Node) -> void:
	var region := NavigationRegion3D.new()
	region.name = "ArenaNavRegion"
	var navmesh := NavigationMesh.new()
	var e := 100.0  # matches the 200x200 ground plane half-extent
	navmesh.set_vertices(PackedVector3Array([
		Vector3(-e, 0.0, -e), Vector3(e, 0.0, -e), Vector3(e, 0.0, e), Vector3(-e, 0.0, e),
	]))
	navmesh.add_polygon(PackedInt32Array([0, 1, 2, 3]))
	region.navigation_mesh = navmesh
	# Deferred: the parent is busy adding children during scene entry.
	parent.add_child.call_deferred(region)

## Primitive stand-in used only when a prop model fails to load.
func _fallback_mesh(footprint_radius: float, height: float) -> Mesh:
	var box := BoxMesh.new()
	box.size = Vector3(footprint_radius * 2.0, height, footprint_radius * 2.0)
	return box
