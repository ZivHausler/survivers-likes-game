class_name MapBuilder extends Node
## Procedural, data-driven ground builder. Reads a map RECIPE (see arena/maps/*)
## and constructs organic biome blobs, winding path ribbons, water bodies with a
## bright shoreline rim, and decorative floor features (concentric rings/medallions)
## as flat meshes on the XZ plane. The goal is a vibrant, non-grid floor that reads
## like the reference maps — the floor itself is the density, not blocking props.
##
## Replicable: a new map = a new recipe script. This engine never hard-codes layout.
##
## Recipe shape (all positions are Vector2 in world XZ; y is the small stacking height
## used to avoid z-fighting between coplanar layers):
##   {
##     "textures": { "<name>": "res://...albedo.png", ... },
##     "biomes":  [ { "tex","uv","color","y","blobs":[[Vector2,radius],...] }, ... ],
##     "paths":   [ { "tex","uv","color","y","width","points":[Vector2,...] }, ... ],
##     "water":   [ { "color","rim_color","y","rim_y","rim_grow","blobs":[[Vector2,r],...] }, ... ],
##     "features":[ { "type":"disc"|"ring", ... }, ... ],
##   }

## Path to the recipe script (a GDScript exposing `const RECIPE`).
@export var recipe_path: String = "res://arena/maps/final_city_map.gd"

const _CIRCLE_SEGS := 28

func _ready() -> void:
	var parent := get_parent()
	if parent == null:
		return
	var recipe_gd := load(recipe_path) as GDScript
	if recipe_gd == null:
		push_warning("MapBuilder: could not load recipe '%s'" % recipe_path)
		return
	var recipe: Dictionary = recipe_gd.RECIPE
	var root := Node3D.new()
	root.name = "GeneratedGround"
	_build(root, recipe)
	parent.add_child.call_deferred(root)

func _build(root: Node3D, recipe: Dictionary) -> void:
	var textures: Dictionary = recipe.get("textures", {})

	for biome in recipe.get("biomes", []):
		var circles: Array = biome["blobs"]
		var mesh := _blob_mesh(circles, biome["y"], biome.get("uv", 0.08))
		_add_mesh(root, mesh, _material(textures, biome), "Biome")

	for water in recipe.get("water", []):
		# Bright shoreline rim: a larger blob of the rim color sitting just below the water.
		var rim_circles: Array = []
		for c in water["blobs"]:
			rim_circles.append([c[0], c[1] + water.get("rim_grow", 2.5)])
		var rim_mesh := _blob_mesh(rim_circles, water["rim_y"], 0.0)
		_add_mesh(root, rim_mesh, _flat_material(water["rim_color"], false), "WaterRim")
		var water_mesh := _blob_mesh(water["blobs"], water["y"], 0.0)
		_add_mesh(root, water_mesh, _flat_material(water["color"], false), "Water")

	for path in recipe.get("paths", []):
		var mesh := _ribbon_mesh(path["points"], path["width"], path["y"], path.get("uv", 0.1))
		_add_mesh(root, mesh, _material(textures, path), "Path")

	for feat in recipe.get("features", []):
		_build_feature(root, textures, feat)

func _build_feature(root: Node3D, textures: Dictionary, feat: Dictionary) -> void:
	match feat["type"]:
		"disc":
			var mesh := _blob_mesh([[feat["pos"], feat["r"]]], feat["y"], feat.get("uv", 0.08))
			_add_mesh(root, mesh, _material(textures, feat), "FeatureDisc")
		"ring":
			var mesh := _ring_mesh(feat["pos"], feat["inner"], feat["outer"], feat["y"])
			_add_mesh(root, mesh, _flat_material(feat["color"], feat.get("emissive", false)), "FeatureRing")

# --- Mesh helpers ----------------------------------------------------------

## A union of filled circles (overlapping fans) as one flat surface at height `y`.
## Overlapping triangles share color/height so no visible z-fighting within the mesh.
## UVs are world-space so a tiling texture stays consistent across blobs.
func _blob_mesh(circles: Array, y: float, uv: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	for c in circles:
		var center: Vector2 = c[0]
		var r: float = c[1]
		for i in _CIRCLE_SEGS:
			var a0 := TAU * float(i) / _CIRCLE_SEGS
			var a1 := TAU * float(i + 1) / _CIRCLE_SEGS
			var p0 := center + Vector2(cos(a0), sin(a0)) * r
			var p1 := center + Vector2(cos(a1), sin(a1)) * r
			_vtx(st, center, y, uv)
			_vtx(st, p0, y, uv)
			_vtx(st, p1, y, uv)
	return st.commit()

## A flat ribbon following a polyline, constant `width`, at height `y`.
func _ribbon_mesh(points: Array, width: float, y: float, uv: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	var hw := width * 0.5
	var left: Array = []
	var right: Array = []
	for i in points.size():
		var p: Vector2 = points[i]
		var dir: Vector2
		if i == 0:
			dir = (points[1] - p)
		elif i == points.size() - 1:
			dir = (p - points[i - 1])
		else:
			dir = (points[i + 1] - points[i - 1])
		dir = dir.normalized()
		var nrm := Vector2(-dir.y, dir.x)
		left.append(p + nrm * hw)
		right.append(p - nrm * hw)
	for i in points.size() - 1:
		var l0: Vector2 = left[i]
		var r0: Vector2 = right[i]
		var l1: Vector2 = left[i + 1]
		var r1: Vector2 = right[i + 1]
		_vtx(st, l0, y, uv); _vtx(st, r0, y, uv); _vtx(st, l1, y, uv)
		_vtx(st, l1, y, uv); _vtx(st, r0, y, uv); _vtx(st, r1, y, uv)
	return st.commit()

## A flat annulus (ring) centered at `pos` between inner/outer radius at height `y`.
func _ring_mesh(pos: Vector2, inner: float, outer: float, y: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	for i in _CIRCLE_SEGS:
		var a0 := TAU * float(i) / _CIRCLE_SEGS
		var a1 := TAU * float(i + 1) / _CIRCLE_SEGS
		var io0 := pos + Vector2(cos(a0), sin(a0)) * inner
		var io1 := pos + Vector2(cos(a1), sin(a1)) * inner
		var oo0 := pos + Vector2(cos(a0), sin(a0)) * outer
		var oo1 := pos + Vector2(cos(a1), sin(a1)) * outer
		_vtx(st, io0, y, 0.1); _vtx(st, oo0, y, 0.1); _vtx(st, oo1, y, 0.1)
		_vtx(st, io0, y, 0.1); _vtx(st, oo1, y, 0.1); _vtx(st, io1, y, 0.1)
	return st.commit()

func _vtx(st: SurfaceTool, p: Vector2, y: float, uv: float) -> void:
	st.set_uv(p * uv)
	st.add_vertex(Vector3(p.x, y, p.y))

# --- Materials -------------------------------------------------------------

func _material(textures: Dictionary, def: Dictionary) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.roughness = 0.85
	m.albedo_color = def.get("color", Color.WHITE)
	var tex_name: String = def.get("tex", "")
	if textures.has(tex_name):
		m.albedo_texture = load(textures[tex_name])
	return m

func _flat_material(color: Color, emissive: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.roughness = 0.5
	m.albedo_color = color
	if emissive:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = 0.6
	return m

func _add_mesh(root: Node3D, mesh: ArrayMesh, mat: Material, node_name: String) -> void:
	if mesh.get_surface_count() == 0:
		return
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	# Assign to the surface (not just material_override) so the renderer's shadow /
	# dependency pass never queries a null surface material (avoids per-frame
	# "Parameter material is null" spam). material_override kept for instance clarity.
	mesh.surface_set_material(0, mat)
	mi.material_override = mat
	mi.name = node_name
	# force_readable_name=true so duplicate names become "Biome", "Biome2", … instead
	# of generic "@MeshInstance3D@…", keeping name-prefix lookups working.
	root.add_child(mi, true)
