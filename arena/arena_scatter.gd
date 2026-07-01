# See docs/notes/arena-scatter.md
class_name ArenaScatter extends Node
## Seeded, deterministic placement of arena obstacles on the XZ plane.
## Pure logic (compute_positions) is unit-tested headless — DO NOT change its
## signature or logic. _ready() places a central plaza hub plus dense, CLUSTERED
## district props and flora clumps that match the organic floor built by MapBuilder
## (arena/maps/final_city_map.gd). Clusters are tight with calm grass gaps between
## them so the map has rhythm (busy <-> open) rather than uniform clutter.

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

## Obstacle clusters (collision + nav). Centered on the MapBuilder districts; kept
## loose enough (min_sep) that the player always has lanes through them.
## Each: { c:Vector2, ext, seed, sep, items:[[key,count],…] }
const _OBSTACLE_CLUSTERS := [
	{  # W cyber-tech
		"c": Vector2(-64, 10), "ext": 28.0, "seed": 100, "sep": 7.0,
		"items": [["sci_fi_pylon_3d", 4], ["sci_fi_barrier_3d", 3], ["prop_generator_3d", 3]],
	},
	{  # NE cobble town
		"c": Vector2(56, -58), "ext": 26.0, "seed": 200, "sep": 6.5,
		"items": [["prop_crate_3d", 4], ["prop_barrel_3d", 3], ["prop_dumpster_3d", 1],
				["prop_fence_3d", 3], ["prop_concrete_barrier_3d", 2]],
	},
	{  # SE beach
		"c": Vector2(55, 64), "ext": 28.0, "seed": 300, "sep": 7.0,
		"items": [["prop_rock_3d", 4], ["prop_concrete_barrier_3d", 2], ["prop_crate_3d", 2],
				["prop_barrel_3d", 2], ["prop_pillar_3d", 2]],
	},
	{  # E brick yard
		"c": Vector2(84, 2), "ext": 13.0, "seed": 400, "sep": 5.0,
		"items": [["prop_crate_3d", 3], ["prop_concrete_barrier_3d", 2], ["prop_barrel_3d", 2]],
	},
	{  # tree groves in the grass (verticality)
		"c": Vector2(-22, 44), "ext": 12.0, "seed": 500, "sep": 5.0,
		"items": [["prop_tree_3d", 3]],
	},
	{
		"c": Vector2(38, -16), "ext": 12.0, "seed": 600, "sep": 5.0,
		"items": [["prop_tree_3d", 2], ["prop_rock_3d", 1]],
	},
	{
		"c": Vector2(-14, -50), "ext": 12.0, "seed": 700, "sep": 5.0,
		"items": [["prop_tree_3d", 2]],
	},
	{  # grove filling the central-south lawn
		"c": Vector2(16, 30), "ext": 12.0, "seed": 800, "sep": 5.0,
		"items": [["prop_tree_3d", 2], ["prop_bush_3d", 1]],
	},
]

## Dense decoration clumps (no collision). Flowers/grass/bushes/mushrooms packed
## tightly into pockets across the grass and biome edges, with bare gaps between.
## Each: { c:Vector2, ext, seed, sep, items:[[key,count],…] }
const _DECOR_CLUMPS := [
	{"c": Vector2(-20, 30), "ext": 8.0, "seed": 11, "sep": 2.2,
		"items": [["prop_flowers_3d", 6], ["prop_tall_grass_3d", 5], ["prop_bush_3d", 2]]},
	{"c": Vector2(25, -22), "ext": 8.0, "seed": 12, "sep": 2.2,
		"items": [["prop_flowers_3d", 5], ["prop_tall_grass_3d", 6], ["prop_mushroom_3d", 2]]},
	{"c": Vector2(8, 42), "ext": 8.0, "seed": 13, "sep": 2.0,
		"items": [["prop_tall_grass_3d", 7], ["prop_flowers_3d", 4]]},
	{"c": Vector2(-32, -22), "ext": 8.0, "seed": 14, "sep": 2.2,
		"items": [["prop_bush_3d", 3], ["prop_flowers_3d", 5], ["prop_tall_grass_3d", 4]]},
	{"c": Vector2(34, 14), "ext": 8.0, "seed": 15, "sep": 2.0,
		"items": [["prop_flowers_3d", 6], ["prop_tall_grass_3d", 5]]},
	{"c": Vector2(-10, -34), "ext": 8.0, "seed": 16, "sep": 2.2,
		"items": [["prop_tall_grass_3d", 6], ["prop_flowers_3d", 4], ["prop_mushroom_3d", 2]]},
	{"c": Vector2(2, 60), "ext": 9.0, "seed": 17, "sep": 2.2,
		"items": [["prop_flowers_3d", 6], ["prop_tall_grass_3d", 6]]},
	{"c": Vector2(-44, 32), "ext": 8.0, "seed": 18, "sep": 2.2,
		"items": [["prop_mushroom_3d", 3], ["prop_bush_3d", 2], ["prop_tall_grass_3d", 4]]},
	{"c": Vector2(52, 74), "ext": 9.0, "seed": 19, "sep": 2.4,
		"items": [["prop_tall_grass_3d", 5], ["prop_flowers_3d", 3]]},
	{"c": Vector2(-64, 10), "ext": 10.0, "seed": 20, "sep": 3.0,
		"items": [["prop_holo_sign_3d", 2]]},
	{"c": Vector2(56, -58), "ext": 10.0, "seed": 21, "sep": 3.0,
		"items": [["prop_cone_3d", 3], ["prop_holo_sign_3d", 1]]},
	{"c": Vector2(-50, 56), "ext": 8.0, "seed": 22, "sep": 2.6,
		"items": [["prop_mushroom_3d", 3], ["prop_bush_3d", 2]]},
	{"c": Vector2(0, 38), "ext": 9.0, "seed": 23, "sep": 2.2,
		"items": [["prop_flowers_3d", 6], ["prop_tall_grass_3d", 5]]},
	{"c": Vector2(34, 38), "ext": 9.0, "seed": 24, "sep": 2.2,
		"items": [["prop_flowers_3d", 5], ["prop_tall_grass_3d", 5], ["prop_bush_3d", 2]]},
	{"c": Vector2(46, 26), "ext": 8.0, "seed": 25, "sep": 2.2,
		"items": [["prop_flowers_3d", 4], ["prop_tall_grass_3d", 4]]},
]

## Base RNG seed; each cluster adds its own seed offset for independence.
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
	for cluster in _OBSTACLE_CLUSTERS:
		_place_cluster(obstacles, cluster, true)
	for clump in _DECOR_CLUMPS:
		_place_cluster(decor, clump, false)

	# Deferred: parent is busy adding children during scene entry.
	parent.add_child.call_deferred(obstacles)
	parent.add_child.call_deferred(decor)

# --- Plaza hub ---

## Place the fountain centerpiece, pillar ring, brazier accents, and ring lamps,
## aligned to the central plaza medallion built by MapBuilder.
func _place_plaza_hub(obstacles: Node3D, decor: Node3D) -> void:
	# Larger hero fountain, offset from the spawn origin so the player clears it.
	_spawn_obstacle(obstacles, "prop_fountain_3d", Vector3(0, 0, 15), "Fountain", 1.7)
	# 8 pillars on the outer (cyan) ring at radius 20.
	for i in 8:
		var a := TAU * float(i) / 8.0
		_spawn_obstacle(obstacles, "prop_pillar_3d", Vector3(cos(a) * 20.0, 0, sin(a) * 20.0))
	# 4 braziers between the rings for warm glow — no collision.
	for i in 4:
		var a := TAU * (float(i) + 0.5) / 4.0
		_spawn_decor(decor, "prop_brazier_3d", Vector3(cos(a) * 10.0, 0, sin(a) * 10.0))
	# 8 lamps just outside the medallion at radius 24.
	for i in 8:
		var a := TAU * (float(i) + 0.25) / 8.0
		_spawn_decor(decor, "prop_lamp_3d", Vector3(cos(a) * 24.0, 0, sin(a) * 24.0))

# --- Cluster placement ---

## Place all props for one cluster using compute_positions, offset to its center.
## `as_obstacle` chooses collision wrapping (Obstacle3D) vs plain decoration.
func _place_cluster(container: Node3D, cluster: Dictionary, as_obstacle: bool) -> void:
	var center := Vector3(cluster["c"].x, 0.0, cluster["c"].y)
	var ext: float = cluster["ext"]
	var sep: float = cluster["sep"]
	var seed_off: int = cluster["seed"]

	var keys: Array = []
	for entry in cluster["items"]:
		for _i in entry[1]:
			keys.append(entry[0])
	if keys.is_empty():
		return

	var positions := compute_positions(_BASE_SEED + seed_off, keys.size(), ext, 0.0, sep)
	for i in positions.size():
		if as_obstacle:
			_spawn_obstacle(container, keys[i], center + positions[i])
		else:
			_spawn_decor(container, keys[i], center + positions[i])

# --- Helpers ---

## Create an Obstacle3D for `prop_key` at `pos`, optionally naming/scaling it.
func _spawn_obstacle(container: Node3D, prop_key: String, pos: Vector3,
		node_name: String = "", scale_mul: float = 1.0) -> void:
	var fp: Array = _FP.get(prop_key, [1.0, 2.0])
	var prop_scene := load("res://obstacles/%s.tscn" % prop_key) as PackedScene
	var obs: Obstacle3D = _OBSTACLE_SCENE.instantiate()
	if prop_scene != null:
		var model := prop_scene.instantiate()
		if model is Node3D:
			obs.set_model(model as Node3D, fp[0] * scale_mul, fp[1] * scale_mul)
		else:
			if model != null:
				model.free()
			obs.configure(_fallback_mesh(fp[0], fp[1]), fp[0], fp[1])
	else:
		push_warning("ArenaScatter: failed to load obstacle prop '%s'" % prop_key)
		obs.configure(_fallback_mesh(fp[0], fp[1]), fp[0], fp[1])
	obs.position = Vector3(pos.x, 0.0, pos.z)
	if scale_mul != 1.0:
		obs.scale = Vector3.ONE * scale_mul
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
