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
var _skirt_m: StandardMaterial3D = null
var _curb_m: StandardMaterial3D = null
var _tuft_m: ArrayMesh = null
var _tuft_material: StandardMaterial3D = null

## Seam offsets/rotations: N,E,S,W -> edge strip along that side of the cell.
const _EDGE_DIR := [Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(-1, 0, 0)]

func _ready() -> void:
	var parent := get_parent()
	if parent == null:
		return
	var root := Node3D.new()
	root.name = "GardenFloor"
	_build_into_root(root)
	parent.add_child.call_deferred(root)

## Test/direct entry: build the floor under `parent` synchronously.
func build_into(parent: Node3D) -> void:
	var root := Node3D.new()
	root.name = "GardenFloor"
	_build_into_root(root)
	parent.add_child(root)

func _build_into_root(root: Node3D) -> void:
	var recipe: Dictionary = load(recipe_path).RECIPE
	var grid := ZoneGrid.new(recipe["rows"], recipe["legend"], recipe["cell_size"])
	var zones: Dictionary = recipe["zones"]
	# Elevation lookup drives curb/skirt geometry at seams (void/pond default to ground).
	var zone_y := {}
	for zn in zones:
		zone_y[zn] = float(zones[zn].get("y", 0.02))

	var base_tiles := Node3D.new(); base_tiles.name = "BaseTiles"
	var trims := Node3D.new(); trims.name = "TransitionTrims"
	var decals := Node3D.new(); decals.name = "Decals"
	var pond := Node3D.new(); pond.name = "Pond"
	var centre := Node3D.new(); centre.name = "Centerpiece"
	var seams := Node3D.new(); seams.name = "SeamScatter"
	root.add_child(base_tiles)
	root.add_child(trims)
	root.add_child(decals)
	root.add_child(pond)
	root.add_child(centre)
	root.add_child(seams)

	var cs: float = recipe["cell_size"]
	var plaza_sum := Vector3.ZERO
	var plaza_n := 0
	for y in grid.height:
		for x in grid.width:
			var z := grid.zone_at(x, y)
			if z == &"void" or z == &"pond":
				continue
			var zdef: Dictionary = zones[z]
			var variant := TileVariants.variant_for(x, y, int(zdef.get("variants", 1)))
			var mi := MeshInstance3D.new()
			# Organic zones get a per-tile UV rotation so the tiling doesn't line up into a grid.
			var uv_rot := 0
			if z == &"grass" or z == &"flowerbed":
				uv_rot = int(_hash01(x * 7 + y * 13 + 3) * 4.0) % 4
			var mesh := _tile_mesh(cs, uv_rot)
			mesh.surface_set_material(0, _material_for(z, variant, zdef))
			mi.mesh = mesh
			var wc := grid.cell_center_world(x, y)
			mi.position = Vector3(wc.x, zdef.get("y", 0.02), wc.z)
			base_tiles.add_child(mi, true)
			_lay_curbs(trims, grid, zone_y, z, x, y, wc, cs)
			_scatter_seam(seams, grid, zone_y, z, x, y, wc, cs)
			if z == &"stone_plaza":
				plaza_sum += wc
				plaza_n += 1
	_build_decals(decals, recipe.get("decals", []))
	_build_pond(pond, recipe.get("pond", {}))
	if plaza_n > 0:
		var pc := plaza_sum / float(plaza_n)
		_build_centerpiece(centre, pc.x, pc.z, float(zone_y.get(&"stone_plaza", 0.45)))

## A flat, upward-facing quad of side `size` centered on its origin (XZ plane).
## `uv_rot` (0-3) rotates the texture 90°·uv_rot on the quad. Used to break obvious tiling
## repetition on organic zones (grass) without adding textures — rotated tiles don't line up
## into a visible grid. Left 0 for stone (rotating grout lines would break seam continuity).
func _tile_mesh(size: float, uv_rot: int = 0) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	var h := size * 0.5
	var p := [Vector3(-h, 0, -h), Vector3(h, 0, -h), Vector3(h, 0, h), Vector3(-h, 0, h)]
	var uv := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
	for tri in [[0, 1, 2], [0, 2, 3]]:
		for i in tri:
			st.set_uv(uv[(i + uv_rot) % 4]); st.add_vertex(p[i])
	return st.commit()

## Build real curb geometry at every seam where this cell sits HIGHER than a neighbour:
## a vertical skirt filling the step (cut-stone side) + a beveled curb cap on the lip.
## Driven by actual elevation difference, so raised zones (plaza dais, path walkway) read
## as tiered platforms and there is no flat "white piping" or floating raised slab.
func _lay_curbs(curbs: Node3D, grid: ZoneGrid, zone_y: Dictionary,
		this_zone: StringName, x: int, y: int, wc: Vector3, cs: float) -> void:
	var this_y: float = zone_y.get(this_zone, 0.02)
	for i in 4:
		var d: Vector3 = _EDGE_DIR[i]
		var nz := grid.zone_at(x + int(d.x), y + int(d.z))
		var nbr_y: float = zone_y.get(nz, 0.02)  # void/pond -> ground level
		var step := this_y - nbr_y
		if step <= 0.03:
			continue
		var ex := wc.x + d.x * cs * 0.5
		var ez := wc.z + d.z * cs * 0.5
		var rot := atan2(d.x, d.z)
		# Vertical skirt filling the step face (dark cut stone).
		var skirt := MeshInstance3D.new()
		skirt.mesh = _box_mesh(Vector3(cs, step, 0.16), _skirt_mat())
		skirt.position = Vector3(ex, nbr_y + step * 0.5, ez)
		skirt.rotation.y = rot
		curbs.add_child(skirt, true)
		# Beveled curb cap sitting proud on the lip (warm stone), slight overhang.
		var cap := MeshInstance3D.new()
		cap.mesh = _box_mesh(Vector3(cs, 0.12, 0.4), _curb_mat())
		cap.position = Vector3(ex, this_y + 0.02, ez)
		cap.rotation.y = rot
		curbs.add_child(cap, true)

func _box_mesh(size: Vector3, mat: StandardMaterial3D) -> ArrayMesh:
	var box := BoxMesh.new()
	box.size = size
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, box.get_mesh_arrays())
	am.surface_set_material(0, mat)
	return am

func _skirt_mat() -> StandardMaterial3D:
	if _skirt_m == null:
		_skirt_m = StandardMaterial3D.new()
		_skirt_m.albedo_color = Color(0.42, 0.41, 0.44)
		_skirt_m.roughness = 0.95
	return _skirt_m

func _curb_mat() -> StandardMaterial3D:
	if _curb_m == null:
		_curb_m = StandardMaterial3D.new()
		# Darker cool stone so the lip reads as intentional edging, not cream piping (the light
		# warm cap was the harsh straight "line" at every plaza border).
		_curb_m.albedo_color = Color(0.48, 0.48, 0.52)
		_curb_m.roughness = 0.85
	return _curb_m

## Hero centerpiece = a FLAT glowing emissive medallion inlay on the plaza floor (like the
## LoL-Swarm plaza floor-decal reference). It must NOT be raised: the player spawns/fights
## on the plaza center, and raised geometry there swallows the character (flat entity plane).
func _build_centerpiece(container: Node3D, cx: float, cz: float, top_y: float) -> void:
	# Concentric inlaid bands: stack filled discs largest-first, each smaller one a hair higher,
	# so the outer colours survive as rings (teal field / gold rim / teal field). All within
	# ~0.1u of the plaza top -> reads as a flush floor inlay, never a raised dais that swallows
	# the player. Matches the LoL-Swarm teal+gold plaza medallion.
	var bands := [
		[6.4, Color(0.09, 0.29, 0.35), false],  # outer teal field
		[5.6, Color(0.74, 0.57, 0.24), true],   # gold rim ring (subtle glow)
		[4.9, Color(0.07, 0.24, 0.30), false],  # inner teal field
	]
	var yy := top_y + 0.02
	for b in bands:
		var r: float = b[0]
		var col: Color = b[1]
		var gl: bool = b[2]
		var d := MeshInstance3D.new()
		d.mesh = _disc_mesh(r, col, gl)
		d.position = Vector3(cx, yy, cz)
		container.add_child(d, true)
		yy += 0.012
	# Glowing seal ring (authored decal) nested inside the gold rim.
	if ResourceLoader.exists("res://art/decals/plaza_medallion.png"):
		var med := MeshInstance3D.new()
		var mesh := _tile_mesh(11.0)
		mesh.surface_set_material(0, _medallion_mat())
		med.mesh = mesh
		med.position = Vector3(cx, yy + 0.02, cz)
		container.add_child(med, true)
		yy += 0.02
	# Center emblem dot.
	var dot := MeshInstance3D.new()
	dot.mesh = _disc_mesh(1.3, Color(0.78, 0.62, 0.30), true)
	dot.position = Vector3(cx, yy + 0.02, cz)
	container.add_child(dot, true)

## Break the hard straight border where soft ground (grass/dirt/flowerbed) meets a raised
## hard zone: sprinkle small grass tufts along the seam, jittered + overhanging, so the
## eye reads an organic edge instead of a ruler line. Deterministic (hash by cell+dir).
const _SOFT := { &"grass": true, &"flowerbed": true, &"dirt_path": true }

func _scatter_seam(seams: Node3D, grid: ZoneGrid, zone_y: Dictionary,
		this_zone: StringName, x: int, y: int, wc: Vector3, cs: float) -> void:
	if not _SOFT.has(this_zone):
		return  # scatter from the soft side onto the seam
	var gy: float = zone_y.get(this_zone, 0.02)
	for i in 4:
		var d: Vector3 = _EDGE_DIR[i]
		var nz := grid.zone_at(x + int(d.x), y + int(d.z))
		if not (nz == &"stone_plaza" or nz == &"stone_path"):
			continue  # creep ONLY onto raised stone edges — never pond (water), void, dirt, grass
		var tang := Vector3(d.z, 0.0, -d.x)  # along the edge
		var mid := Vector3(wc.x + d.x * cs * 0.5, gy, wc.z + d.z * cs * 0.5)
		# Dense overhanging fringe: many clumps along the edge, jittered, and pushed a little
		# ONTO the hard zone (positive d) so grass creeps over the lip and hides the ruler line.
		var n := 9
		for k in n:
			var h := _hash01(x * 91 + y * 47 + i * 13 + k * 7)
			var h2 := _hash01(x * 31 + y * 17 + i * 5 + k * 101)
			var along := (float(k) / float(n - 1) - 0.5) * cs + (h - 0.5) * cs * 0.14
			# spill from just inside the soft side to well over the seam onto the hard zone
			var over := (h2 - 0.25) * cs * 0.5
			var pos := mid + tang * along + d * over
			var tuft := MeshInstance3D.new()
			tuft.mesh = _tuft_mesh()
			var s := 1.0 + h2 * 1.1
			tuft.scale = Vector3(s, s * (0.9 + h * 0.7), s)
			tuft.rotation.y = h * TAU
			tuft.position = pos
			seams.add_child(tuft, true)

func _hash01(n: int) -> float:
	var h := (n * 73856093) ^ (n * 19349663)
	return float(absi(h) % 10000) / 10000.0

func _tuft_mesh() -> ArrayMesh:
	if _tuft_m != null:
		return _tuft_m
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# three crossed FILLED cards (grass-billboard style) -> a low green clump that reads as
	# MASS from the angled cam. Tapered spikes were sub-pixel; solid cards fill the seam.
	var cards := 4
	var hw := 0.52         # base half-width
	var tw := 0.12         # top half-width (tapered -> grass-clump silhouette, not a rectangle)
	var hgt := 0.72
	var base_c := Color(0.19, 0.40, 0.15)  # shaded root
	var tip_c := Color(0.47, 0.74, 0.33)   # sunlit tip
	for c in cards:
		var a := PI * float(c) / float(cards)
		var dx := cos(a) * hw
		var dz := sin(a) * hw
		var tdx := cos(a) * tw
		var tdz := sin(a) * tw
		var b0 := Vector3(-dx, 0.0, -dz)
		var b1 := Vector3(dx, 0.0, dz)
		var t0 := Vector3(-tdx, hgt, -tdz)
		var t1 := Vector3(tdx, hgt, tdz)
		st.set_normal(Vector3.UP)
		# per-vertex gradient (base dark -> tip bright) so cards read as grass, not flat paddles
		st.set_color(base_c); st.add_vertex(b0)
		st.set_color(base_c); st.add_vertex(b1)
		st.set_color(tip_c); st.add_vertex(t1)
		st.set_color(base_c); st.add_vertex(b0)
		st.set_color(tip_c); st.add_vertex(t1)
		st.set_color(tip_c); st.add_vertex(t0)
	_tuft_m = st.commit()
	_tuft_m.surface_set_material(0, _tuft_mat())
	return _tuft_m

func _tuft_mat() -> StandardMaterial3D:
	if _tuft_material == null:
		_tuft_material = StandardMaterial3D.new()
		_tuft_material.albedo_color = Color(1, 1, 1)
		_tuft_material.vertex_color_use_as_albedo = true  # let the base->tip gradient show
		_tuft_material.roughness = 0.95
		_tuft_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _tuft_material

func _medallion_mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	var t := load("res://art/decals/plaza_medallion.png")
	m.albedo_texture = t
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.emission_enabled = true
	m.emission_texture = t
	m.emission = Color(0.45, 0.9, 1.0)
	m.emission_energy_multiplier = 1.3
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m

func _build_decals(container: Node3D, entries: Array) -> void:
	for e in entries:
		var d := Decal.new()
		var s: float = e.get("size", 8.0)
		d.size = Vector3(s, 4.0, s)
		var p: Vector2 = e["pos"]
		d.position = Vector3(p.x, 1.0, p.y)  # project downward onto the floor
		d.rotation.y = e.get("rot", 0.0)
		var tex_path := "res://art/decals/%s.png" % e["type"]
		if ResourceLoader.exists(tex_path):
			d.texture_albedo = load(tex_path)
		d.name = String(e["type"]).capitalize()
		container.add_child(d, true)

func _build_pond(container: Node3D, pond: Dictionary) -> void:
	if pond.is_empty():
		return
	var c: Vector2 = pond["center"]
	var r: float = pond["radius"]
	# Shoreline rim: a slightly larger bright disc just below the water.
	var rim := MeshInstance3D.new()
	rim.mesh = _disc_mesh(r + 1.6, pond.get("rim_color", Color(0.55, 0.9, 1.0)), true)
	rim.position = Vector3(c.x, 0.0, c.y)
	rim.name = "PondRim"
	container.add_child(rim, true)
	# Water surface.
	var water := MeshInstance3D.new()
	water.mesh = _disc_mesh(r, pond.get("water_color", Color(0.14, 0.52, 0.68, 0.85)), false)
	water.position = Vector3(c.x, pond.get("y", 0.0) + 0.05, c.y)
	water.name = "PondWater"
	container.add_child(water, true)

## A flat filled disc of `radius` with a painterly material; emissive if `glow`.
func _disc_mesh(radius: float, color: Color, glow: bool) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	var segs := 72
	for i in segs:
		var a0 := TAU * float(i) / segs
		var a1 := TAU * float(i + 1) / segs
		st.set_uv(Vector2(0.5, 0.5)); st.add_vertex(Vector3.ZERO)
		st.set_uv(Vector2(0, 0)); st.add_vertex(Vector3(cos(a0) * radius, 0, sin(a0) * radius))
		st.set_uv(Vector2(1, 0)); st.add_vertex(Vector3(cos(a1) * radius, 0, sin(a1) * radius))
	var mesh := st.commit()
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.55
	if color.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if glow:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = 0.5
	mesh.surface_set_material(0, m)
	return mesh

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
		# Angled MOBA camera: anisotropic + mipmaps kill shimmer on distant tiles.
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		# Normal map (convention: <tex>_normal.png) so the key light rakes across the
		# cel outlines — grout recesses, stones bulge. Turns flat quads into surface.
		var normal_path := tex_path.replace(".png", "_normal.png")
		if ResourceLoader.exists(normal_path):
			m.normal_enabled = true
			m.normal_texture = load(normal_path)
			m.normal_scale = 1.0
	if zdef.get("emissive", false):
		m.emission_enabled = true
		m.emission = base
		m.emission_energy_multiplier = 0.4
	_mat_cache[key] = m
	return m
