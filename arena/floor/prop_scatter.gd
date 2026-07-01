class_name GardenScatter extends Node
## Builds the Garden's clustered, art-directed props from the district recipe:
## one landmark, medium props, and small details, each grouped for scene clarity.
## Colliders are wrapped in Obstacle3D (collision + nav carve); decoration is plain.
## Also activates the navigation map (flat region) so enemy RVO avoidance works.

@export var recipe_path: String = "res://arena/maps/garden_map.gd"
@export var clear_radius: float = 12.0

## Half-extent (world units) of the flat playfield the navmesh covers — matches the
## 200x200 ground plane. Passed to the bake so paths span the whole arena.
const NAV_EXTENT := 100.0
## Clearance baked into the navmesh so routed paths keep a body-width away from carved
## terrain (enemy NavigationAgent3D radius is 0.6). Kept an exact multiple of the bake
## cell_size (0.5) so the radius is not voxel-ceiled and no bake warning is emitted.
const NAV_AGENT_RADIUS := 1.0

## Footprints ({pos:Vector3, radius:float}) of every collidable obstacle placed this
## build, collected in _spawn_obstacle and carved out of the navmesh in _activate_navigation.
var _carve_footprints: Array = []

const PropLayout = preload("res://arena/floor/prop_layout.gd")
const ZoneGrid = preload("res://arena/floor/zone_grid.gd")
const Obstacle3D = preload("res://obstacles/obstacle_3d.gd")
const _OBSTACLE_SCENE := preload("res://obstacles/obstacle_3d.tscn")

const _FP := {
	"garden_hero_tree_3d": [1.0, 6.0], "garden_bench_3d": [1.0, 0.6],
	"garden_planter_3d": [0.8, 0.8], "garden_trellis_3d": [1.2, 4.0],
	"garden_bollard_3d": [0.3, 1.1], "prop_lamp_3d": [0.4, 3.0],
	"garden_fountain_3d": [1.9, 2.2],
	"prop_pillar_3d": [0.5, 3.5], "prop_brazier_3d": [0.6, 1.6], "prop_rock_3d": [1.0, 1.2],
}

func _ready() -> void:
	var parent := get_parent()
	if parent == null:
		return
	var props := Node3D.new()
	props.name = "Props"
	_fill_props(props)                 # populates _carve_footprints as obstacles are placed
	_activate_navigation(parent)       # bakes the navmesh with those footprints carved out
	parent.add_child.call_deferred(props)

## Synchronous test entry (no nav, no deferral).
func build_props(parent: Node3D) -> void:
	var props := Node3D.new()
	props.name = "Props"
	_fill_props(props)
	parent.add_child(props)

func _fill_props(props: Node3D) -> void:
	_carve_footprints.clear()
	var groups := {
		&"landmark": Node3D.new(), &"medium": Node3D.new(), &"small": Node3D.new(),
	}
	groups[&"landmark"].name = "Landmarks"
	groups[&"medium"].name = "MediumProps"
	groups[&"small"].name = "SmallDetails"
	for g in groups.values():
		props.add_child(g)

	var recipe: Dictionary = load(recipe_path).RECIPE
	# Grid + per-zone elevation so props sit ON the raised plaza/paths, not sunk in them.
	var grid := ZoneGrid.new(recipe["rows"], recipe["legend"], recipe["cell_size"])
	var zone_y := {}
	for zn in recipe["zones"]:
		zone_y[zn] = float(recipe["zones"][zn].get("y", 0.02))
	var placements := PropLayout.resolve(recipe["prop_clusters"], clear_radius)
	for pl in placements:
		pl["ground_y"] = _ground_y(grid, zone_y, pl["pos"].x, pl["pos"].z)
		var container: Node3D = groups.get(pl["role"], groups[&"small"])
		if pl["collide"]:
			_spawn_obstacle(container, pl)
		else:
			_spawn_decor(container, pl)

## World XZ -> the elevation of the zone under that point (props rest on top of it).
func _ground_y(grid: ZoneGrid, zone_y: Dictionary, wx: float, wz: float) -> float:
	var cx := int(round(wx / grid.cell_size + (float(grid.width) - 1.0) * 0.5))
	var cy := int(round(wz / grid.cell_size + (float(grid.height) - 1.0) * 0.5))
	return float(zone_y.get(grid.zone_at(cx, cy), 0.02))

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
	obs.position = Vector3(pl["pos"].x, pl.get("ground_y", 0.0), pl["pos"].z)
	if scale_mul != 1.0:
		obs.scale = Vector3.ONE * scale_mul
	# Record the world footprint so the navmesh bake carves a hole here (obs.scale scales
	# the whole node, so the effective collision radius is fp[0] * scale_mul).
	_carve_footprints.append({
		"pos": Vector3(pl["pos"].x, 0.0, pl["pos"].z),
		"radius": fp[0] * scale_mul,
	})
	_add_contact_shadow(obs)
	container.add_child(obs, true)

func _spawn_decor(container: Node3D, pl: Dictionary) -> void:
	var scene := load("res://obstacles/%s.tscn" % pl["key"]) as PackedScene
	if scene == null:
		return
	var node := scene.instantiate()
	if node is Node3D:
		var n := node as Node3D
		n.position = Vector3(pl["pos"].x, pl.get("ground_y", 0.0), pl["pos"].z)
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

## NavigationRegion3D whose navmesh is BAKED with every obstacle footprint carved out,
## so enemy NavigationAgent3D pathfinding routes AROUND terrain (not just RVO-dodges it).
func _activate_navigation(parent: Node) -> void:
	var region := NavigationRegion3D.new()
	region.name = "ArenaNavRegion"
	region.navigation_mesh = build_carved_navmesh(NAV_EXTENT, NAV_AGENT_RADIUS, _carve_footprints)
	parent.add_child.call_deferred(region)

## Pure static bake: a flat [-extent, extent] floor navmesh with each `footprints`
## entry ({pos:Vector3, radius:float}) carved out as a hole, keeping `agent_radius`
## clearance. Runs headless (no rendering) so it is unit-testable. Uses projected
## obstructions rather than parsing 3D collider geometry: deterministic and cheap.
static func build_carved_navmesh(extent: float, agent_radius: float, footprints: Array) -> NavigationMesh:
	var src := NavigationMeshSourceGeometryData3D.new()
	# Walkable floor: two triangles spanning the playfield quad.
	src.add_faces(PackedVector3Array([
		Vector3(-extent, 0.0, -extent), Vector3(extent, 0.0, -extent), Vector3(extent, 0.0, extent),
		Vector3(-extent, 0.0, -extent), Vector3(extent, 0.0, extent), Vector3(-extent, 0.0, extent),
	]), Transform3D.IDENTITY)
	# Carve a square hole per obstacle footprint (half-side = footprint radius). A vertical
	# span around the floor (elevation -1 → height 3) guarantees the projection cuts the mesh.
	for fp: Dictionary in footprints:
		var c: Vector3 = fp["pos"]
		var r: float = fp["radius"]
		src.add_projected_obstruction(PackedVector3Array([
			Vector3(c.x - r, 0.0, c.z - r), Vector3(c.x + r, 0.0, c.z - r),
			Vector3(c.x + r, 0.0, c.z + r), Vector3(c.x - r, 0.0, c.z + r),
		]), -1.0, 3.0, true)
	var navmesh := NavigationMesh.new()
	navmesh.agent_radius = agent_radius
	navmesh.agent_height = 1.0
	navmesh.agent_max_climb = 0.5
	navmesh.cell_size = 0.5
	NavigationServer3D.bake_from_source_geometry_data(navmesh, src)
	return navmesh
