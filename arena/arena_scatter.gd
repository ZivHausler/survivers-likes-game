# See docs/notes/arena-scatter.md
class_name ArenaScatter extends Node
## Seeded, deterministic placement of arena obstacles on the XZ plane.
## Pure logic (compute_positions) is unit-tested headless; node instantiation is
## handled by the arena scene (Task 8) which loads obstacle_3d.tscn per position.

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

# --- Instance-side spawner -------------------------------------------------
# When this script is attached to a node inside the arena scene, _ready() uses
# the seeded compute_positions() above to scatter real, collidable nature props
# (tree / rock) into an `Obstacles` Node3D added to the arena. All knobs are
# exported so placement density and prop footprints are playtest-tunable.

@export var obstacle_count: int = 35
@export var rng_seed: int = 1
@export var extent: float = 88.0
@export var clear_radius: float = 14.0
@export var min_separation: float = 7.0
## Footprint (collision + nav) per prop type; trees are slim+tall, rocks wide+low.
@export var tree_footprint_radius: float = 0.8
@export var tree_height: float = 6.0
@export var rock_footprint_radius: float = 1.4
@export var rock_height: float = 2.0
## Uniform scale applied to rock / generic instanced models (real-world gltf scale can be large).
@export var model_scale: float = 1.0
## Scale applied specifically to the tree prop. The raw fir_tree_01 mesh is ~18 units tall
## while the player capsule is ~2 units, so 0.35 gives ~6 units — tunable in the inspector.
@export var tree_model_scale: float = 0.35

const _OBSTACLE_SCENE := preload("res://obstacles/obstacle_3d.tscn")
const _TREE_PATH := "res://art/models/nature/fir_tree_01/fir_tree_01_1k.gltf"
const _ROCK_PATH := "res://art/models/nature/boulder_01/boulder_01_1k.gltf"

func _ready() -> void:
	var parent := get_parent()
	if parent == null:
		return
	# Activate a navigation map so enemy NavigationAgent3D RVO avoidance actually
	# simulates (the world's default map is INACTIVE until a region exists, which
	# makes velocity_computed return zero — enemies' own desired-velocity fallback
	# covers that, but this lets avoidance steering work in the rendered game).
	_activate_navigation(parent)
	var obstacles := Node3D.new()
	obstacles.name = "Obstacles"

	var tree_scene := load(_TREE_PATH) as PackedScene
	if tree_scene == null:
		push_warning("ArenaScatter: failed to load tree model '%s'; using fallback box" % _TREE_PATH)
	var rock_scene := load(_ROCK_PATH) as PackedScene
	if rock_scene == null:
		push_warning("ArenaScatter: failed to load rock model '%s'; using fallback box" % _ROCK_PATH)

	var positions := compute_positions(rng_seed, obstacle_count, extent, clear_radius, min_separation)
	for i in positions.size():
		var pos: Vector3 = positions[i]
		var is_tree := (i % 2) == 0
		var prop_scene: PackedScene = tree_scene if is_tree else rock_scene
		var footprint := tree_footprint_radius if is_tree else rock_footprint_radius
		var height := tree_height if is_tree else rock_height

		var obs: Obstacle3D = _OBSTACLE_SCENE.instantiate()
		var model: Node = prop_scene.instantiate() if prop_scene != null else null
		if model is Node3D:
			var visual: Node3D = model as Node3D
			if is_tree:
				visual = _extract_tree_variant(visual)
				visual.scale = Vector3.ONE * tree_model_scale
			else:
				visual.scale = Vector3.ONE * model_scale
			obs.set_model(visual, footprint, height)
		else:
			if model != null:
				model.free()  # not a Node3D — discard and fall back
			obs.configure(_fallback_mesh(footprint, height), footprint, height)
		obs.position = Vector3(pos.x, 0.0, pos.z)
		obstacles.add_child(obs)

	# Defer the single attach to the arena: during scene entry the parent is
	# "busy setting up children", so a direct add_child() would be rejected.
	parent.add_child.call_deferred(obstacles)

## The fir_tree_01 gltf packs THREE sibling variants (fir_tree_01_a_LOD0,
## fir_tree_01_b_LOD0, fir_tree_01_c_LOD0) offset along X. This helper
## extracts ONE variant so the visible tree matches the single cylindrical
## collision + NavigationObstacle3D footprint. Falls back to the whole instance
## (with a warning) if no "fir_tree" named child is found.
func _extract_tree_variant(tree_instance: Node3D) -> Node3D:
	var chosen: Node3D = null
	for child in tree_instance.get_children():
		if child is Node3D and "fir_tree" in child.name:
			chosen = child as Node3D
			break
	if chosen == null:
		push_warning("ArenaScatter: tree gltf has no 'fir_tree' named child — " +
				"using whole instance as fallback (visuals may not match collision)")
		return tree_instance
	tree_instance.remove_child(chosen)
	chosen.transform = Transform3D.IDENTITY  # re-seat at obstacle origin
	tree_instance.free()  # discards the other variants still attached
	return chosen

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
