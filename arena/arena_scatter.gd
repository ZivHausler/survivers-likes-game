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
## Uniform scale applied to instanced models (real-world gltf scale can be large).
@export var model_scale: float = 1.0

const _OBSTACLE_SCENE := preload("res://obstacles/obstacle_3d.tscn")
const _TREE_PATH := "res://art/models/nature/fir_tree_01/fir_tree_01_1k.gltf"
const _ROCK_PATH := "res://art/models/nature/boulder_01/boulder_01_1k.gltf"

func _ready() -> void:
	var parent := get_parent()
	if parent == null:
		return
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
			(model as Node3D).scale = Vector3.ONE * model_scale
			obs.set_model(model as Node3D, footprint, height)
		else:
			if model != null:
				model.free()  # not a Node3D — discard and fall back
			obs.configure(_fallback_mesh(footprint, height), footprint, height)
		obs.position = Vector3(pos.x, 0.0, pos.z)
		obstacles.add_child(obs)

	# Defer the single attach to the arena: during scene entry the parent is
	# "busy setting up children", so a direct add_child() would be rejected.
	parent.add_child.call_deferred(obstacles)

## Primitive stand-in used only when a prop model fails to load.
func _fallback_mesh(footprint_radius: float, height: float) -> Mesh:
	var box := BoxMesh.new()
	box.size = Vector3(footprint_radius * 2.0, height, footprint_radius * 2.0)
	return box
