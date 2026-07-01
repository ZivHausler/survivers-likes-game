class_name FloorBuilder extends Node
## Builds the Garden floor as ONE flat splatmapped ground surface (y=_GROUND_Y, a hair above the
## arena's base surround plane to avoid z-fighting): a merged quad mesh
## over every non-void cell, driven by splat_ground.gdshader, which blends the zone textures
## per-pixel from a ZoneGrid-derived control map (SplatField). Pond water, authored decals and
## the plaza centerpiece are added on top. Replaces the old per-tile + alpha-feather approach.
## See docs/superpowers/specs/2026-07-01-splatmap-ground-blending-design.md.

const ZoneGrid := preload("res://arena/floor/zone_grid.gd")
const SplatField := preload("res://arena/floor/splat_field.gd")

# Draw-order lift above the arena's base surround plane (arena_3d.tscn Ground/GroundMesh sits at
# y=0). The splat ground must render ABOVE it or the two coplanar surfaces z-fight (extreme
# flicker). 0.02 is the same tiny offset the old per-tile floor used — draw order only, far too
# small to swallow the character; the walkable floor is still effectively flat.
const _GROUND_Y := 0.02

@export var recipe_path: String = "res://arena/maps/garden_map.gd"

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

	var decals := Node3D.new(); decals.name = "Decals"
	var pond := Node3D.new(); pond.name = "Pond"
	var centre := Node3D.new(); centre.name = "Centerpiece"

	_build_ground(root, grid, zones, recipe)
	root.add_child(decals)
	root.add_child(pond)
	root.add_child(centre)

	_build_decals(decals, recipe.get("decals", []))
	_build_pond(pond, recipe.get("pond", {}))

	# Plaza centerpiece: centered on the stone_plaza cells.
	var plaza_sum := Vector3.ZERO
	var plaza_n := 0
	for y in grid.height:
		for x in grid.width:
			if grid.zone_at(x, y) == &"stone_plaza":
				plaza_sum += grid.cell_center_world(x, y)
				plaza_n += 1
	if plaza_n > 0:
		var pc := plaza_sum / float(plaza_n)
		_build_centerpiece(centre, pc.x, pc.z, _GROUND_Y)

## One merged flat ground mesh (y=0) over every non-void cell (pond cells included, so the
## pond's soft-edged water reveals grass at the shore). UV = world XZ mapped to [0,1] across
## the whole map, so the splat shader can sample the control maps and tile the zone textures.
func _build_ground(root: Node3D, grid: ZoneGrid, zones: Dictionary, recipe: Dictionary) -> void:
	var cs: float = grid.cell_size
	var map_w := grid.width * cs
	var map_h := grid.height * cs
	var minx := -map_w * 0.5
	var minz := -map_h * 0.5
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	var half := cs * 0.5
	for y in grid.height:
		for x in grid.width:
			if grid.zone_at(x, y) == &"void":
				continue
			var wc := grid.cell_center_world(x, y)
			var corners := [
				Vector3(wc.x - half, 0.0, wc.z - half),
				Vector3(wc.x + half, 0.0, wc.z - half),
				Vector3(wc.x + half, 0.0, wc.z + half),
				Vector3(wc.x - half, 0.0, wc.z + half),
			]
			for tri in [[0, 1, 2], [0, 2, 3]]:
				for i in tri:
					var p: Vector3 = corners[i]
					st.set_uv(Vector2((p.x - minx) / map_w, (p.z - minz) / map_h))
					st.add_vertex(p)
	var mesh := st.commit()
	mesh.surface_set_material(0, _splat_material(grid, zones, recipe))
	var mi := MeshInstance3D.new()
	mi.name = "Ground"
	mi.mesh = mesh
	mi.position = Vector3(0.0, _GROUND_Y, 0.0)  # lift above the base surround plane (kills z-fight)
	root.add_child(mi, true)

func _splat_material(grid: ZoneGrid, zones: Dictionary, recipe: Dictionary) -> ShaderMaterial:
	var blend := {}
	var tier := {}
	for zn in zones:
		blend[zn] = float(zones[zn].get("blend", 0.0))
		tier[zn] = int(zones[zn].get("tier", 0))
	if not blend.has(&"grass"):
		blend[&"grass"] = 2.5
	var k := int(recipe.get("splat_res", 8))
	var splat_img := SplatField.build_splatmap(grid, blend, k)
	var ao_img := SplatField.build_ao(grid, tier, k,
		float(recipe.get("ao_band", 6.0)), float(recipe.get("ao_strength", 0.35)))
	var mat := ShaderMaterial.new()
	mat.shader = load("res://arena/floor/splat_ground.gdshader")
	mat.set_shader_parameter("splatmap", ImageTexture.create_from_image(splat_img))
	mat.set_shader_parameter("ao_map", ImageTexture.create_from_image(ao_img))
	mat.set_shader_parameter("grass_tex", _zone_tex(&"grass", zones))
	mat.set_shader_parameter("plaza_tex", _zone_tex(&"stone_plaza", zones))
	mat.set_shader_parameter("path_tex", _zone_tex(&"stone_path", zones))
	mat.set_shader_parameter("dirt_tex", _zone_tex(&"dirt_path", zones))
	mat.set_shader_parameter("flower_tex", _zone_tex(&"flowerbed", zones))
	# UV runs 0..1 across the whole map; repeating once per cell keeps each texture at its
	# authored ~cell scale (matches the old one-texture-per-8u-cell look).
	mat.set_shader_parameter("tile_scale", Vector2(grid.width, grid.height))
	return mat

func _zone_tex(zone: StringName, zones: Dictionary) -> Texture2D:
	var path: String = zones.get(zone, {}).get("tex", "")
	if path != "" and ResourceLoader.exists(path):
		return load(path)
	# Fallback: 1px white so the shader still blends (tinted by nothing).
	var img := Image.create(1, 1, false, Image.FORMAT_RGB8)
	img.fill(Color(1, 1, 1))
	return ImageTexture.create_from_image(img)

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
	# Depth gradient (Temtem-oasis reference): dark teal-green deep center -> saturated
	# green-turquoise shallows. Saturated + green (not pale sky-blue) to match the oasis water.
	var deep := Color(0.03, 0.28, 0.33, 1.0)
	var shallow := Color(0.13, 0.60, 0.58, 1.0)
	var foam: Color = pond.get("rim_color", Color(0.86, 0.98, 0.96))
	# Water body: saturated depth gradient, opaque until a small fade only at the very edge.
	var water := MeshInstance3D.new()
	water.name = "PondWater"
	water.mesh = _pond_water_mesh(r, r * 0.10, deep, shallow)
	water.position = Vector3(c.x, 0.05, c.y)  # just above the flat ground
	container.add_child(water, true)
	# Thin crisp foam waterline right at the shore (references show a defined foam line, not a
	# wide glowing halo).
	var foam_mi := MeshInstance3D.new()
	foam_mi.name = "PondFoam"
	foam_mi.mesh = _foam_ring_mesh(r * 0.94, r * 0.02, Color(foam.r, foam.g, foam.b, 0.9))
	foam_mi.position = Vector3(c.x, 0.065, c.y)
	container.add_child(foam_mi, true)

## Water disc: concentric-ring grid (not a fan — avoids radial transparency streaks) with a
## radial depth gradient (deep center -> shallow rim) and a wide alpha fade over the outer
## `fade` world units, so the water reveals the grass beneath at the shore. Vertex colour
## carries both the gradient and the fade alpha.
func _pond_water_mesh(r: float, fade: float, deep: Color, shallow: Color) -> ArrayMesh:
	var segs := 64
	var rings := 18
	var fade_start: float = 1.0 - clampf(fade / r, 0.05, 0.95)  # normalized radius where alpha drops
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	for j in rings:
		var t0 := float(j) / float(rings)
		var t1 := float(j + 1) / float(rings)
		for i in segs:
			var a0 := TAU * float(i) / float(segs)
			var a1 := TAU * float(i + 1) / float(segs)
			_pw_vert(st, t0, a0, r, fade_start, deep, shallow)
			_pw_vert(st, t1, a0, r, fade_start, deep, shallow)
			_pw_vert(st, t1, a1, r, fade_start, deep, shallow)
			_pw_vert(st, t0, a0, r, fade_start, deep, shallow)
			_pw_vert(st, t1, a1, r, fade_start, deep, shallow)
			_pw_vert(st, t0, a1, r, fade_start, deep, shallow)
	var mesh := st.commit()
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	# Unshaded: stylized flat water shows its authored depth gradient exactly, instead of the
	# bright sky HDRI reflecting off a flat plane at this grazing camera angle and washing it out.
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.surface_set_material(0, m)
	return mesh

## One water vertex at normalized radius `t` (0 center, 1 edge) and angle `ang`: colour lerps
## deep->shallow with t; alpha is 1 until `fade_start` then ramps to 0 at the edge.
func _pw_vert(st: SurfaceTool, t: float, ang: float, r: float, fade_start: float,
		deep: Color, shallow: Color) -> void:
	var col := deep.lerp(shallow, t)
	var a := 1.0
	if t > fade_start:
		a = 1.0 - (t - fade_start) / (1.0 - fade_start)
	st.set_color(Color(col.r, col.g, col.b, a))
	st.add_vertex(Vector3(cos(ang) * r * t, 0.0, sin(ang) * r * t))

## Soft glowing annulus centered on radius `mid` (half-width `hw`): transparent at both edges,
## full colour in the middle, emissive — reads as a foam/shore highlight line, not a hard band.
func _foam_ring_mesh(mid: float, hw: float, color: Color) -> ArrayMesh:
	var segs := 64
	var inner := mid - hw
	var outer := mid + hw
	var op := color
	var tr := Color(color.r, color.g, color.b, 0.0)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	for i in segs:
		var a0 := TAU * float(i) / float(segs)
		var a1 := TAU * float(i + 1) / float(segs)
		var pi0 := Vector3(cos(a0) * inner, 0.0, sin(a0) * inner)
		var pi1 := Vector3(cos(a1) * inner, 0.0, sin(a1) * inner)
		var pm0 := Vector3(cos(a0) * mid, 0.0, sin(a0) * mid)
		var pm1 := Vector3(cos(a1) * mid, 0.0, sin(a1) * mid)
		var po0 := Vector3(cos(a0) * outer, 0.0, sin(a0) * outer)
		var po1 := Vector3(cos(a1) * outer, 0.0, sin(a1) * outer)
		# inner(transparent) -> mid(opaque)
		st.set_color(tr); st.add_vertex(pi0); st.set_color(op); st.add_vertex(pm0); st.set_color(op); st.add_vertex(pm1)
		st.set_color(tr); st.add_vertex(pi0); st.set_color(op); st.add_vertex(pm1); st.set_color(tr); st.add_vertex(pi1)
		# mid(opaque) -> outer(transparent)
		st.set_color(op); st.add_vertex(pm0); st.set_color(tr); st.add_vertex(po0); st.set_color(tr); st.add_vertex(po1)
		st.set_color(op); st.add_vertex(pm0); st.set_color(tr); st.add_vertex(po1); st.set_color(op); st.add_vertex(pm1)
	var mesh := st.commit()
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED  # crisp bright foam line, no sky wash
	mesh.surface_set_material(0, m)
	return mesh

## Flat glowing medallion inlay on the plaza floor (flush, never raised — the player fights
## on the plaza center). Concentric filled discs, largest first, each a hair higher.
func _build_centerpiece(container: Node3D, cx: float, cz: float, top_y: float) -> void:
	var bands := [
		[6.4, Color(0.09, 0.29, 0.35), false],
		[5.6, Color(0.74, 0.57, 0.24), true],
		[4.9, Color(0.07, 0.24, 0.30), false],
	]
	var yy := top_y + 0.02
	for b in bands:
		var d := MeshInstance3D.new()
		d.mesh = _disc_mesh(b[0], b[1], b[2])
		d.position = Vector3(cx, yy, cz)
		container.add_child(d, true)
		yy += 0.012
	if ResourceLoader.exists("res://art/decals/plaza_medallion.png"):
		var med := MeshInstance3D.new()
		var mesh := _quad_mesh(11.0)
		mesh.surface_set_material(0, _medallion_mat())
		med.mesh = mesh
		med.position = Vector3(cx, yy + 0.02, cz)
		container.add_child(med, true)
		yy += 0.02
	var dot := MeshInstance3D.new()
	dot.mesh = _disc_mesh(1.3, Color(0.78, 0.62, 0.30), true)
	dot.position = Vector3(cx, yy + 0.02, cz)
	container.add_child(dot, true)

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

## A flat, upward-facing quad of side `size` centered on origin (used by the medallion decal).
func _quad_mesh(size: float) -> ArrayMesh:
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

## A flat filled disc of `radius`; emissive if `glow`.
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
	if glow:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = 0.5
	mesh.surface_set_material(0, m)
	return mesh
