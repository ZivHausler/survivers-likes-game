class_name GardenScatter extends Node
## Builds the Garden's clustered, art-directed props from the district recipe:
## one landmark, medium props, and small details, each grouped for scene clarity.
## Colliders are wrapped in Obstacle3D (collision + nav carve); decoration is plain.
## Also activates the navigation map (flat region) so enemy RVO avoidance works.

@export var recipe_path: String = "res://arena/maps/garden_map.gd"
@export var clear_radius: float = 12.0

const PropLayout = preload("res://arena/floor/prop_layout.gd")
const Obstacle3D = preload("res://obstacles/obstacle_3d.gd")
const _OBSTACLE_SCENE := preload("res://obstacles/obstacle_3d.tscn")

const _FP := {
	"garden_hero_tree_3d": [1.0, 6.0], "garden_bench_3d": [1.0, 0.6],
	"garden_planter_3d": [0.8, 0.8], "garden_trellis_3d": [1.2, 4.0],
	"garden_bollard_3d": [0.3, 1.1], "prop_lamp_3d": [0.4, 3.0],
}

func _ready() -> void:
	var parent := get_parent()
	if parent == null:
		return
	_activate_navigation(parent)
	var props := Node3D.new()
	props.name = "Props"
	_fill_props(props)
	parent.add_child.call_deferred(props)

## Synchronous test entry (no nav, no deferral).
func build_props(parent: Node3D) -> void:
	var props := Node3D.new()
	props.name = "Props"
	_fill_props(props)
	parent.add_child(props)

func _fill_props(props: Node3D) -> void:
	var groups := {
		&"landmark": Node3D.new(), &"medium": Node3D.new(), &"small": Node3D.new(),
	}
	groups[&"landmark"].name = "Landmarks"
	groups[&"medium"].name = "MediumProps"
	groups[&"small"].name = "SmallDetails"
	for g in groups.values():
		props.add_child(g)

	var recipe: Dictionary = load(recipe_path).RECIPE
	var placements := PropLayout.resolve(recipe["prop_clusters"], clear_radius)
	for pl in placements:
		var container: Node3D = groups.get(pl["role"], groups[&"small"])
		if pl["collide"]:
			_spawn_obstacle(container, pl)
		else:
			_spawn_decor(container, pl)

func _spawn_obstacle(container: Node3D, pl: Dictionary) -> void:
	var key: String = pl["key"]
	var fp: Array = _FP.get(key, [0.8, 2.0])
	var scale_mul: float = pl["scale"]
	var scene := load("res://obstacles/%s.tscn" % key) as PackedScene
	var obs: Obstacle3D = _OBSTACLE_SCENE.instantiate()
	if scene != null:
		var model := scene.instantiate()
		if model is Node3D:
			# Unscaled footprint: obs.scale (below) scales the whole node — collision cylinder
			# AND model — uniformly. Pre-multiplying here too would double-scale collision.
			obs.set_model(model as Node3D, fp[0], fp[1])
		elif model != null:
			model.free()
	obs.position = Vector3(pl["pos"].x, 0.0, pl["pos"].z)
	if scale_mul != 1.0:
		obs.scale = Vector3.ONE * scale_mul
	_add_contact_shadow(obs)
	container.add_child(obs, true)

func _spawn_decor(container: Node3D, pl: Dictionary) -> void:
	var scene := load("res://obstacles/%s.tscn" % pl["key"]) as PackedScene
	if scene == null:
		return
	var node := scene.instantiate()
	if node is Node3D:
		var n := node as Node3D
		n.position = Vector3(pl["pos"].x, 0.0, pl["pos"].z)
		var scale_mul: float = pl["scale"]
		if scale_mul != 1.0:
			n.scale = Vector3.ONE * scale_mul  # decor honors recipe scale, like colliders
		_add_contact_shadow(n)
		container.add_child(n, true)
	elif node != null:
		node.free()

## Attach a soft contact-shadow decal as a child of the prop (local y=1).
func _add_contact_shadow(node: Node3D) -> void:
	var d := Decal.new()
	d.size = Vector3(2.2, 3.0, 2.2)
	d.position = Vector3(0.0, 1.0, 0.0)
	var tex_path := "res://art/decals/contact_shadow.png"
	if ResourceLoader.exists(tex_path):
		d.texture_albedo = load(tex_path)
	d.modulate = Color(0, 0, 0, 0.5)
	d.name = "ContactShadow"
	node.add_child(d)

## Flat NavigationRegion3D so NavigationAgent3D RVO avoidance yields non-zero velocity.
func _activate_navigation(parent: Node) -> void:
	var region := NavigationRegion3D.new()
	region.name = "ArenaNavRegion"
	var navmesh := NavigationMesh.new()
	var e := 100.0
	navmesh.set_vertices(PackedVector3Array([
		Vector3(-e, 0.0, -e), Vector3(e, 0.0, -e), Vector3(e, 0.0, e), Vector3(-e, 0.0, e),
	]))
	navmesh.add_polygon(PackedInt32Array([0, 1, 2, 3]))
	region.navigation_mesh = navmesh
	parent.add_child.call_deferred(region)
