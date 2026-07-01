class_name FloorBuilder extends Node
## Builds a modular tiled floor from a district recipe: one flat quad per cell with a
## painterly per-zone material + deterministic variation. Transition trims, authored
## decals, and the pond inset are added by later steps (containers created here).
## Assigning materials to the MESH SURFACE (not just material_override) avoids the
## per-frame "Parameter material is null" render spam. Replicable: new district = new recipe.

const ZoneGrid = preload("res://arena/floor/zone_grid.gd")
const TileVariants = preload("res://arena/floor/tile_variants.gd")

@export var recipe_path: String = "res://arena/maps/garden_map.gd"

var _mat_cache: Dictionary = {}  # "zone#variant" -> StandardMaterial3D

func _ready() -> void:
	var parent := get_parent()
	if parent == null:
		return
	var root := Node3D.new()
	root.name = "GardenFloor"
	build_into_root(root)
	parent.add_child.call_deferred(root)

## Test/direct entry: build the floor under `parent` synchronously.
func build_into(parent: Node3D) -> void:
	var root := Node3D.new()
	root.name = "GardenFloor"
	build_into_root(root)
	parent.add_child(root)

func build_into_root(root: Node3D) -> void:
	var recipe: Dictionary = load(recipe_path).RECIPE
	var grid := ZoneGrid.new(recipe["rows"], recipe["legend"], recipe["cell_size"])
	var zones: Dictionary = recipe["zones"]

	var base_tiles := Node3D.new(); base_tiles.name = "BaseTiles"
	var trims := Node3D.new(); trims.name = "TransitionTrims"
	var decals := Node3D.new(); decals.name = "Decals"
	var pond := Node3D.new(); pond.name = "Pond"
	root.add_child(base_tiles)
	root.add_child(trims)
	root.add_child(decals)
	root.add_child(pond)

	var cs: float = recipe["cell_size"]
	for y in grid.height:
		for x in grid.width:
			var z := grid.zone_at(x, y)
			if z == &"void" or z == &"pond":
				continue
			var zdef: Dictionary = zones[z]
			var variant := TileVariants.variant_for(x, y, int(zdef.get("variants", 1)))
			var mi := MeshInstance3D.new()
			var mesh := _tile_mesh(cs)
			mesh.surface_set_material(0, _material_for(z, variant, zdef))
			mi.mesh = mesh
			var wc := grid.cell_center_world(x, y)
			mi.position = Vector3(wc.x, zdef.get("y", 0.02), wc.z)
			base_tiles.add_child(mi, true)

## A flat, upward-facing quad of side `size` centered on its origin (XZ plane).
func _tile_mesh(size: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	var h := size * 0.5
	var p := [Vector3(-h, 0, -h), Vector3(h, 0, -h), Vector3(h, 0, h), Vector3(-h, 0, h)]
	var uv := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
	for tri in [[0, 1, 2], [0, 2, 3]]:
		for i in tri:
			st.set_uv(uv[i]); st.add_vertex(p[i])
	return st.commit()

func _material_for(zone: StringName, variant: int, zdef: Dictionary) -> StandardMaterial3D:
	var key := "%s#%d" % [zone, variant]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := StandardMaterial3D.new()
	m.roughness = 0.92
	m.metallic = 0.0
	# Slight per-variant value shift so repeated tiles read as varied, not loud.
	var base: Color = zdef.get("color", Color.WHITE)
	var shift := 1.0 + (float(variant) - 1.0) * 0.06
	m.albedo_color = Color(base.r * shift, base.g * shift, base.b * shift, base.a)
	var tex_path: String = zdef.get("tex", "")
	if tex_path != "" and ResourceLoader.exists(tex_path):
		m.albedo_texture = load(tex_path)
	if zdef.get("emissive", false):
		m.emission_enabled = true
		m.emission = base
		m.emission_energy_multiplier = 0.4
	_mat_cache[key] = m
	return m
