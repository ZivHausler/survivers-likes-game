# Splatmap Ground Blending Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the per-tile floor + failed alpha-feather seams with one flat splatmapped ground surface whose zone textures blend per-pixel, with per-zone blend width (0 = sharp) and a faux-height plaza via an edge-shadow (AO) map.

**Architecture:** A pure `SplatField` helper turns the existing `ZoneGrid` into two control `Image`s (an RGBA splatmap and a grayscale edge-shadow/AO map). `FloorBuilder` builds one merged flat ground `ArrayMesh` (all non-`void` cells, y=0) and drives it with `splat_ground.gdshader`, which blends five zone albedos by the splat weights, biases the blend by texture luminance (depth blend), and multiplies by the AO map. The pond water keeps its disc but gains a soft alpha rim so it fades into the grass rendered beneath it.

**Tech Stack:** Godot 4.7, GDScript, `SurfaceTool`/`ArrayMesh`, `ShaderMaterial` + `.gdshader` (spatial), GUT test framework (headless).

## Global Constraints

- **Walkable floor stays flat at y=0.** All relief is faked via shading (AO map, depth blend) and props — never by raising the combat floor (raised walkable geometry swallows the character).
- **Splatmap channel order is fixed:** `R = stone_plaza, G = stone_path, B = dirt_path, A = flowerbed`; **grass is the implicit base** (weight = `1 − R − G − B − A`). `SplatField.CHANNEL` and the shader must agree on this order.
- **`blend = 0` for a zone ⇒ razor-sharp edges** at every boundary that zone touches (the "clear road" case). Non-zero `blend` (world units) ⇒ soft transition.
- **Do not restyle existing mobs/characters.** This work only touches the ground/floor.
- **Do not touch** `arena/floor/autotile.gd` or the recipe `priority` map (no live callers; out of scope) and do not touch the unrelated uncommitted `avihay_chat_spam` weapon files or `project.godot`.
- Tests run headless: `godot47 --headless -s addons/gut/gut_cmdln.gd -gtest=res://test/<file>.gd -gexit`. `godot47` resolves to `/c/Users/avino/bin/godot47`.
- Pure logic (no engine nodes beyond `Image`) lives in testable `.gd` files; shader correctness is verified by material-parameter assertions + a rendered screenshot, not unit tests.

---

## File Structure

- `arena/floor/splat_field.gd` — **new.** Pure generator: `ZoneGrid` → splatmap `Image` + AO `Image`. `class_name SplatField`.
- `arena/floor/splat_ground.gdshader` — **new.** Spatial shader blending 5 zone albedos by splat weights + depth blend + AO.
- `arena/floor/floor_builder.gd` — **rewrite** the floor build: one merged ground mesh + splat material; remove per-tile tiles, feather seams, and elevation curbs.
- `arena/maps/garden_map.gd` — **modify:** flatten walkable `y` to 0; add per-zone `blend`, `tier`; add `splat_res`, `ao_band`, `ao_strength`.
- `test/test_splat_field.gd` — **new.** Pure tests for splatmap + AO.
- `test/test_arena_regions.gd` — **modify:** replace obsolete `BaseTiles`/`TransitionTrims` assertions.
- `test/test_arena_3d_map.gd` — **modify:** replace obsolete `BaseTiles` assertion.
- `obstacles/prop_flowers_3d.tscn` — **commit** the already-good working-tree version (green box removed).

---

### Task 1: Baseline hygiene — clean starting point

Commit the one good pending working-tree change and drop the abandoned feather experiment so the splatmap is built on committed, clean code. `floor_builder.gd`/`garden_map.gd` are rewritten in later tasks; reverting them now keeps their diffs readable.

**Files:**
- Commit: `obstacles/prop_flowers_3d.tscn` (working-tree version — `LeafMound`, no `BoxMesh`)
- Revert to HEAD: `arena/floor/floor_builder.gd`, `arena/maps/garden_map.gd`

- [ ] **Step 1: Confirm the flower prop is the good version**

Run: `grep -c "BoxMesh" obstacles/prop_flowers_3d.tscn`
Expected: `0` (the green box mound is gone).

- [ ] **Step 2: Commit the flower prop fix**

```bash
git add obstacles/prop_flowers_3d.tscn
git commit -m "fix(props): replace flower prop's green box mound with a flat leaf mound"
```

- [ ] **Step 3: Revert the abandoned feather experiment**

```bash
git checkout -- arena/floor/floor_builder.gd arena/maps/garden_map.gd
git status --short arena/floor/floor_builder.gd arena/maps/garden_map.gd
```
Expected: neither file appears as modified (clean, at HEAD).

---

### Task 2: `SplatField.build_splatmap` — RGBA control image (pure, TDD)

**Files:**
- Create: `arena/floor/splat_field.gd`
- Test: `test/test_splat_field.gd`

**Interfaces:**
- Consumes: `ZoneGrid` (`res://arena/floor/zone_grid.gd`): `.width`, `.height`, `.cell_size`, `.zone_at(cx,cy)->StringName`, `.in_bounds(cx,cy)->bool`.
- Produces:
  - `const SplatField.CHANNEL := { &"stone_plaza": 0, &"stone_path": 1, &"dirt_path": 2, &"flowerbed": 3 }`
  - `static SplatField.build_splatmap(grid, blend: Dictionary, k: int) -> Image` — RGBA8 image of size `grid.width*k` × `grid.height*k`. `blend` maps zone `StringName` → transition half-width in world units (0 = sharp). Pixel RGBA = normalized weights of the four channel zones (grass = remainder).

- [ ] **Step 1: Write the failing test**

Create `test/test_splat_field.gd`:

```gdscript
extends GutTest
## Pure tests for the ground splatmap / AO generator.

const SplatField := preload("res://arena/floor/splat_field.gd")
const ZoneGrid := preload("res://arena/floor/zone_grid.gd")

# 6x6: a 2x2 stone_plaza block in the middle of grass, and a full column of
# stone_path on the right so we can test a sharp (blend=0) boundary.
const LEGEND := { ".": &"grass", "#": &"stone_plaza", "=": &"stone_path" }
func _grid() -> ZoneGrid:
	var rows := PackedStringArray([
		"....=.",
		"....=.",
		".##.=.",
		".##.=.",
		"....=.",
		"....=.",
	])
	return ZoneGrid.new(rows, LEGEND, 8.0)

const K := 8  # texels per cell

func test_interior_grass_is_pure_base() -> void:
	# Top-left cell (0,0) is grass surrounded by grass -> all channels ~0.
	var img := SplatField.build_splatmap(_grid(), { &"grass": 3.0, &"stone_plaza": 3.0, &"stone_path": 0.0 }, K)
	var c := img.get_pixel(K / 2, K / 2)  # center of cell (0,0)
	assert_lt(c.r + c.g + c.b + c.a, 0.05, "interior grass has ~zero channel weight (grass base)")

func test_interior_plaza_is_pure_plaza() -> void:
	# Plaza block is cells (1,2)-(2,3); sample the center of cell (1,2).
	var img := SplatField.build_splatmap(_grid(), { &"grass": 3.0, &"stone_plaza": 3.0, &"stone_path": 0.0 }, K)
	var c := img.get_pixel(1 * K + K / 2, 2 * K + K / 2)
	assert_gt(c.r, 0.95, "interior plaza texel is ~pure plaza (R channel)")

func test_soft_boundary_is_intermediate() -> void:
	# The seam between grass and the plaza block, with a soft plaza blend.
	var img := SplatField.build_splatmap(_grid(), { &"grass": 4.0, &"stone_plaza": 4.0, &"stone_path": 0.0 }, K)
	# Texel right at the top edge of the plaza block (cell row 2 starts at ty=2*K).
	var c := img.get_pixel(1 * K + K / 2, 2 * K)
	assert_between(c.r, 0.1, 0.9, "soft plaza/grass seam blends (intermediate R)")

func test_zero_blend_is_sharp() -> void:
	# stone_path column has blend 0 -> its grass boundary must be hard (no intermediate).
	var img := SplatField.build_splatmap(_grid(), { &"grass": 4.0, &"stone_plaza": 4.0, &"stone_path": 0.0 }, K)
	# Walk texels straddling the grass|stone_path seam (between cell x=3 grass and x=4 path).
	var seam_tx := 4 * K  # first texel of the path column
	var ty := 0 * K + K / 2
	for tx in range(seam_tx - 2, seam_tx + 2):
		var g := img.get_pixel(tx, ty).g
		assert_true(g < 0.05 or g > 0.95, "sharp seam texel is fully grass or fully path, got g=%f" % g)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot47 --headless -s addons/gut/gut_cmdln.gd -gtest=res://test/test_splat_field.gd -gexit`
Expected: FAIL — `SplatField` has no `build_splatmap` (parse/nil error).

- [ ] **Step 3: Implement `SplatField.build_splatmap`**

Create `arena/floor/splat_field.gd`:

```gdscript
class_name SplatField extends RefCounted
## Pure generator of ground control images from a ZoneGrid: an RGBA splatmap (per-pixel
## zone-blend weights) and a grayscale edge-shadow / AO map (faux elevation). CPU-only
## (Image), no scene nodes, so it is unit-testable headless. See
## docs/superpowers/specs/2026-07-01-splatmap-ground-blending-design.md.

const ZoneGrid := preload("res://arena/floor/zone_grid.gd")

# Fixed RGBA channel assignment. Grass is the implicit base (weight = 1 - R - G - B - A).
const CHANNEL := { &"stone_plaza": 0, &"stone_path": 1, &"dirt_path": 2, &"flowerbed": 3 }

# pond/void render as the grass base (ground is drawn under the pond; map edge = grass).
static func _field_zone(z: StringName) -> StringName:
	if z == &"pond" or z == &"void":
		return &"grass"
	return z

# Field zone of the cell a texel falls in; out-of-grid clamps to grass (no map-edge seam).
static func _texel_zone(grid, tx: int, ty: int, k: int) -> StringName:
	var cx := tx / k
	var cy := ty / k
	if not grid.in_bounds(cx, cy):
		return &"grass"
	return _field_zone(grid.zone_at(cx, cy))

# smoothstep(0,width,d) with a hard-step fallback at width<=0 (d is always > 0 here).
static func _ramp(d: float, width: float) -> float:
	if width <= 0.0:
		return 1.0
	return smoothstep(0.0, width, d)

static func build_splatmap(grid, blend: Dictionary, k: int) -> Image:
	var w := grid.width * k
	var h := grid.height * k
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var wpt := grid.cell_size / float(k)  # world units per texel
	var max_blend := 0.0
	for z in blend:
		max_blend = maxf(max_blend, float(blend[z]))
	# Search radius covers the widest half-transition plus a texel of slack.
	var r := int(ceil(max_blend / wpt)) + 1
	for ty in h:
		for tx in w:
			var own := _texel_zone(grid, tx, ty, k)
			# Nearest texel of a DIFFERENT field zone within the window.
			var best := INF
			var other: StringName = own
			for sy in range(-r, r + 1):
				for sx in range(-r, r + 1):
					var oz := _texel_zone(grid, tx + sx, ty + sy, k)
					if oz != own:
						var d := sqrt(float(sx * sx + sy * sy)) * wpt
						if d < best:
							best = d
							other = oz
			# Two-zone local blend: width = min of the pair (0 on either side => sharp).
			var wgt := { own: 1.0 }
			if best < INF:
				var width: float = minf(float(blend.get(own, 0.0)), float(blend.get(other, 0.0)))
				var ow := _ramp(best, width)
				wgt = { own: ow, other: 1.0 - ow }
			img.set_pixel(tx, ty, Color(
				float(wgt.get(&"stone_plaza", 0.0)),
				float(wgt.get(&"stone_path", 0.0)),
				float(wgt.get(&"dirt_path", 0.0)),
				float(wgt.get(&"flowerbed", 0.0))))
	return img
```

- [ ] **Step 4: Run test to verify it passes**

Run: `godot47 --headless -s addons/gut/gut_cmdln.gd -gtest=res://test/test_splat_field.gd -gexit`
Expected: PASS — 4/4 (interior grass, interior plaza, soft seam, sharp seam).

- [ ] **Step 5: Commit**

```bash
git add arena/floor/splat_field.gd arena/floor/splat_field.gd.uid test/test_splat_field.gd
git commit -m "feat(floor): SplatField.build_splatmap — per-pixel zone blend weights"
```

---

### Task 3: `SplatField.build_ao` — edge-shadow map for faux height (pure, TDD)

**Files:**
- Modify: `arena/floor/splat_field.gd`
- Test: `test/test_splat_field.gd` (add cases)

**Interfaces:**
- Consumes: same `ZoneGrid` API; `_field_zone`, `_texel_zone` from Task 2.
- Produces: `static SplatField.build_ao(grid, tier: Dictionary, k: int, band: float, strength: float) -> Image` — RGB8 image, value `v = 1 - shade` in every channel; `shade` (up to `strength`) darkens the LOW side of a `tier` drop within `band` world units. `tier` maps zone → int elevation tier (default 0).

- [ ] **Step 1: Write the failing test**

Append to `test/test_splat_field.gd`:

```gdscript
func test_ao_darkens_low_side_of_tier_drop() -> void:
	# Plaza (tier 1) block in grass (tier 0); grass just outside the block is shadowed.
	var tier := { &"stone_plaza": 1 }  # everything else defaults to 0
	var img := SplatField.build_ao(_grid(), tier, K, 6.0, 0.4)
	# Grass texel one texel outside the top edge of the plaza block (cell (1,2) top is ty=2*K).
	var outside := img.get_pixel(1 * K + K / 2, 2 * K - 1)
	assert_lt(outside.r, 0.999, "grass just outside the plaza is darkened (AO band)")

func test_ao_high_side_and_far_are_unshadowed() -> void:
	var tier := { &"stone_plaza": 1 }
	var img := SplatField.build_ao(_grid(), tier, K, 6.0, 0.4)
	# Inside plaza (high side) -> no shadow.
	var inside := img.get_pixel(1 * K + K / 2, 2 * K + K / 2)
	assert_almost_eq(inside.r, 1.0, 0.001, "high side (plaza) is not shadowed")
	# Far corner grass -> no shadow.
	var far := img.get_pixel(K / 2, K / 2)
	assert_almost_eq(far.r, 1.0, 0.001, "grass far from any tier drop is not shadowed")

func test_ao_flat_tiers_are_all_white() -> void:
	var img := SplatField.build_ao(_grid(), {}, K, 6.0, 0.4)  # all tier 0
	assert_almost_eq(img.get_pixel(1 * K + K / 2, 2 * K - 1).r, 1.0, 0.001, "no tier drop -> no shadow")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot47 --headless -s addons/gut/gut_cmdln.gd -gtest=res://test/test_splat_field.gd -gexit`
Expected: FAIL — `build_ao` not defined.

- [ ] **Step 3: Implement `SplatField.build_ao`**

Append to `arena/floor/splat_field.gd`:

```gdscript
static func _tier_at(grid, tx: int, ty: int, k: int, tier: Dictionary) -> int:
	var cx := tx / k
	var cy := ty / k
	if not grid.in_bounds(cx, cy):
		return 0
	return int(tier.get(_field_zone(grid.zone_at(cx, cy)), 0))

# Edge-shadow map: darkens the LOW side of a tier drop within `band` world units, up to
# `strength`. High side and same-tier areas stay white (v=1). Reads as a low plateau.
static func build_ao(grid, tier: Dictionary, k: int, band: float, strength: float) -> Image:
	var w := grid.width * k
	var h := grid.height * k
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	var wpt := grid.cell_size / float(k)
	var r := int(ceil(band / wpt)) + 1
	for ty in h:
		for tx in w:
			var own_t := _tier_at(grid, tx, ty, k, tier)
			var best := INF
			for sy in range(-r, r + 1):
				for sx in range(-r, r + 1):
					if _tier_at(grid, tx + sx, ty + sy, k, tier) > own_t:
						var d := sqrt(float(sx * sx + sy * sy)) * wpt
						best = minf(best, d)
			var shade := 0.0
			if best < INF:
				shade = (1.0 - smoothstep(0.0, band, best)) * strength
			var v := 1.0 - shade
			img.set_pixel(tx, ty, Color(v, v, v))
	return img
```

- [ ] **Step 4: Run test to verify it passes**

Run: `godot47 --headless -s addons/gut/gut_cmdln.gd -gtest=res://test/test_splat_field.gd -gexit`
Expected: PASS — 7/7 (4 splatmap + 3 AO).

- [ ] **Step 5: Commit**

```bash
git add arena/floor/splat_field.gd test/test_splat_field.gd
git commit -m "feat(floor): SplatField.build_ao — edge-shadow map for faux-height plaza"
```

---

### Task 4: Splat ground shader + FloorBuilder rewrite + recipe + test fixups

Replace the per-cell tile floor and feather seams with one merged flat ground mesh driven by the splat shader. This is the integration task: the shader can't be unit-tested alone, so it is verified by material-parameter assertions in the arena tests plus (Task 6) a rendered screenshot.

**Files:**
- Create: `arena/floor/splat_ground.gdshader`
- Modify: `arena/floor/floor_builder.gd` (rewrite the build path)
- Modify: `arena/maps/garden_map.gd` (flatten `y`, add `blend`/`tier`, add `splat_res`/`ao_band`/`ao_strength`)
- Modify: `test/test_arena_regions.gd` (replace `BaseTiles`/`TransitionTrims` assertions)
- Modify: `test/test_arena_3d_map.gd` (replace `BaseTiles` assertion)

**Interfaces:**
- Consumes: `SplatField.build_splatmap(grid, blend, k)`, `SplatField.build_ao(grid, tier, k, band, strength)`, `SplatField.CHANNEL`; `ZoneGrid`.
- Produces: at runtime, `GardenFloor/Ground` — a `MeshInstance3D` whose `mesh.surface_get_material(0)` is a `ShaderMaterial` using `splat_ground.gdshader` with a non-null `splatmap` shader parameter. Node names `BaseTiles`, `TransitionTrims`, `SeamScatter` no longer exist; `Decals`, `Pond`, `Centerpiece` remain.

- [ ] **Step 1: Create the shader**

Create `arena/floor/splat_ground.gdshader`:

```glsl
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

// Control maps are DATA (no sRGB): plain linear filtering.
uniform sampler2D splatmap : filter_linear;
uniform sampler2D ao_map : filter_linear;
// Zone albedos: sRGB, tiling.
uniform sampler2D grass_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D plaza_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D path_tex  : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dirt_tex  : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D flower_tex: source_color, filter_linear_mipmap_anisotropic, repeat_enable;

uniform vec2 tile_scale = vec2(24.0, 24.0);  // UV(0..1 over map) * tile_scale = texture repeats
uniform float roughness_val = 0.92;
uniform float height_blend = 3.0;            // 0 = plain cross-fade; >0 = taller texture wins near seams

float luma(vec3 c) { return dot(c, vec3(0.299, 0.587, 0.114)); }

void fragment() {
	vec2 map_uv = UV;
	vec4 s = texture(splatmap, map_uv);
	// grass is the implicit base (channel order must match SplatField.CHANNEL).
	float w_plaza = s.r;
	float w_path  = s.g;
	float w_dirt  = s.b;
	float w_flower= s.a;
	float w_grass = clamp(1.0 - (w_plaza + w_path + w_dirt + w_flower), 0.0, 1.0);

	vec2 tuv = map_uv * tile_scale;
	vec3 c_grass = texture(grass_tex, tuv).rgb;
	vec3 c_plaza = texture(plaza_tex, tuv).rgb;
	vec3 c_path  = texture(path_tex,  tuv).rgb;
	vec3 c_dirt  = texture(dirt_tex,  tuv).rgb;
	vec3 c_flower= texture(flower_tex,tuv).rgb;

	// Depth blend: bias each weight by its texture height (luma proxy) so cobbles sit on top
	// of grass at a seam instead of ghosting through it.
	float g  = w_grass  * (1.0 + height_blend * luma(c_grass));
	float p  = w_plaza  * (1.0 + height_blend * luma(c_plaza));
	float pa = w_path   * (1.0 + height_blend * luma(c_path));
	float d  = w_dirt   * (1.0 + height_blend * luma(c_dirt));
	float f  = w_flower * (1.0 + height_blend * luma(c_flower));
	float tot = g + p + pa + d + f + 0.00001;

	vec3 col = (c_grass * g + c_plaza * p + c_path * pa + c_dirt * d + c_flower * f) / tot;
	col *= texture(ao_map, map_uv).r;  // faux-elevation edge shadow

	ALBEDO = col;
	ROUGHNESS = roughness_val;
	METALLIC = 0.0;
}
```

- [ ] **Step 2: Edit the recipe — flatten `y`, add blend/tier/splat params**

In `arena/maps/garden_map.gd`, replace the five `zones` entries (keep the `"tex"` paths and `"color"` values exactly as they are; set `"y": 0.0`; add `"blend"` and `"tier"`), and add the three top-level splat params. Set the `zones` block to:

```gdscript
	"zones": {
		&"grass":       { "color": Color(0.96, 0.98, 0.96), "tex": "res://art/textures/garden_grass.png", "y": 0.0, "blend": 2.5, "tier": 0, "emissive": false },
		&"stone_plaza": { "color": Color(0.64, 0.66, 0.70), "tex": "res://art/textures/garden_stone_plaza.png", "y": 0.0, "blend": 2.0, "tier": 1, "emissive": false },
		&"stone_path":  { "color": Color(0.70, 0.71, 0.73), "tex": "res://art/textures/garden_stone_path.png", "y": 0.0, "blend": 1.5, "tier": 0, "emissive": false },
		&"dirt_path":   { "color": Color(0.74, 0.67, 0.55), "tex": "res://art/textures/garden_dirt_path.png", "y": 0.0, "blend": 2.5, "tier": 0, "emissive": false },
		&"flowerbed":   { "color": Color(1.0, 1.0, 1.0), "tex": "res://art/textures/garden_flowerbed.png", "y": 0.0, "blend": 3.0, "tier": 0, "emissive": false },
	},
```

Then add these three keys to the top level of `RECIPE` (place them right after the `"cell_size": 8.0,` line):

```gdscript
	"splat_res": 8,       # splatmap texels per cell
	"ao_band": 6.0,       # edge-shadow falloff (world units) on the low side of a tier drop
	"ao_strength": 0.35,  # max darkening of the edge shadow
```

(Leave `"variants"` keys as-is if present — they are simply unused by the splat floor now. Leave `legend`, `priority`, `pond`, `decals`, `prop_clusters` unchanged.)

- [ ] **Step 3: Rewrite `floor_builder.gd`**

Replace the entire contents of `arena/floor/floor_builder.gd` with:

```gdscript
class_name FloorBuilder extends Node
## Builds the Garden floor as ONE flat splatmapped ground surface (y=0): a merged quad mesh
## over every non-void cell, driven by splat_ground.gdshader, which blends the zone textures
## per-pixel from a ZoneGrid-derived control map (SplatField). Pond water, authored decals and
## the plaza centerpiece are added on top. Replaces the old per-tile + alpha-feather approach.
## See docs/superpowers/specs/2026-07-01-splatmap-ground-blending-design.md.

const ZoneGrid := preload("res://arena/floor/zone_grid.gd")
const SplatField := preload("res://arena/floor/splat_field.gd")

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
		_build_centerpiece(centre, pc.x, pc.z, 0.0)

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
	var water := MeshInstance3D.new()
	water.name = "PondWater"
	water.mesh = _pond_water_mesh(r, 2.5, pond.get("water_color", Color(0.14, 0.48, 0.66, 1.0)))
	water.position = Vector3(c.x, 0.10, c.y)  # just above the flat ground
	container.add_child(water, true)

## Water disc with a SOFT alpha rim: opaque center, fading to transparent over the outer
## `fade` world units, so the water blends into the grass rendered beneath the pond (real
## shoreline). Vertex alpha drives the fade; albedo is the constant water colour.
func _pond_water_mesh(r: float, fade: float, color: Color) -> ArrayMesh:
	var segs := 72
	var ri := maxf(0.0, r - fade)
	var op := Color(color.r, color.g, color.b, 1.0)
	var tr := Color(color.r, color.g, color.b, 0.0)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	for i in segs:
		var a0 := TAU * float(i) / segs
		var a1 := TAU * float(i + 1) / segs
		var i0 := Vector3(cos(a0) * ri, 0.0, sin(a0) * ri)
		var i1 := Vector3(cos(a1) * ri, 0.0, sin(a1) * ri)
		var o0 := Vector3(cos(a0) * r, 0.0, sin(a0) * r)
		var o1 := Vector3(cos(a1) * r, 0.0, sin(a1) * r)
		# Inner solid fan (opaque).
		st.set_color(op); st.set_uv(Vector2(0.5, 0.5)); st.add_vertex(Vector3.ZERO)
		st.set_color(op); st.set_uv(Vector2(0, 0)); st.add_vertex(i0)
		st.set_color(op); st.set_uv(Vector2(1, 0)); st.add_vertex(i1)
		# Rim ring: opaque inner -> transparent outer.
		st.set_color(op); st.set_uv(Vector2(0, 0)); st.add_vertex(i0)
		st.set_color(op); st.set_uv(Vector2(1, 0)); st.add_vertex(i1)
		st.set_color(tr); st.set_uv(Vector2(1, 1)); st.add_vertex(o1)
		st.set_color(op); st.set_uv(Vector2(0, 0)); st.add_vertex(i0)
		st.set_color(tr); st.set_uv(Vector2(1, 1)); st.add_vertex(o1)
		st.set_color(tr); st.set_uv(Vector2(0, 1)); st.add_vertex(o0)
	var mesh := st.commit()
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true       # albedo = water colour; vertex alpha = rim fade
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.35
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
```

- [ ] **Step 4: Fix the two arena tests that reference the old floor nodes**

In `test/test_arena_regions.gd`, replace the body of `test_garden_floor_is_built` (currently asserting `BaseTiles`/`TransitionTrims`) with:

```gdscript
func test_garden_floor_is_built() -> void:
	var root := await _build_arena()
	var floor := root.get_node_or_null("GardenFloor")
	assert_not_null(floor, "FloorBuilder must build GardenFloor")
	var ground := floor.get_node_or_null("Ground") as MeshInstance3D
	assert_not_null(ground, "splat Ground mesh is built")
	var mat := ground.mesh.surface_get_material(0)
	assert_true(mat is ShaderMaterial, "ground uses the splat ShaderMaterial")
	assert_not_null(mat.get_shader_parameter("splatmap"), "splatmap control texture is set")
```

In `test/test_arena_3d_map.gd`, replace the line (around line 51)
`assert_true(floor.get_node("BaseTiles").get_child_count() > 0, "base tiles built")`
with:

```gdscript
	assert_not_null(floor.get_node_or_null("Ground"), "splat Ground mesh built")
```

- [ ] **Step 5: Run the affected tests**

Run:
```bash
godot47 --headless -s addons/gut/gut_cmdln.gd -gtest=res://test/test_splat_field.gd -gexit
godot47 --headless -s addons/gut/gut_cmdln.gd -gtest=res://test/test_arena_regions.gd -gexit
godot47 --headless -s addons/gut/gut_cmdln.gd -gtest=res://test/test_arena_3d_map.gd -gexit
```
Expected: all PASS (splat_field 7/7; arena_regions incl. the rewritten floor test; arena_3d_map incl. the `Ground` assertion). No "Parameter material is null" spam and no shader compile errors in the output.

- [ ] **Step 6: Commit**

```bash
git add arena/floor/splat_ground.gdshader arena/floor/floor_builder.gd arena/maps/garden_map.gd test/test_arena_regions.gd test/test_arena_3d_map.gd
git commit -m "feat(floor): splatmap ground surface replaces per-tile floor + feather seams"
```

---

### Task 5: Full-suite regression + dead-code check

Confirm the rewrite didn't break anything else (prop scatter, garden recipe tests, floor tests that reference removed helpers) and remove any now-orphaned files/imports the rewrite created.

**Files:**
- Possibly modify: `test/test_floor_builder.gd`, `test/test_garden_recipe.gd`, `test/test_garden_scatter.gd` (only if they assert removed behavior — fix to match the splat floor)

- [ ] **Step 1: Run the whole floor/arena/garden/prop test surface**

Run:
```bash
for p in test_splat test_arena test_garden test_prop test_floor test_zone test_tile test_autotile; do
  echo "=== $p ==="; godot47 --headless -s addons/gut/gut_cmdln.gd -gdir=res://test -gprefix=$p -gexit 2>&1 | grep -iE "Passing|Failing|Failed]|error"; done
```
Expected: every suite reports `Passing` with `0` Failing. If a test asserts removed floor behavior (e.g. `TransitionTrims`, per-tile materials, `TileVariants` on the floor), update that assertion to match the splat floor (single `Ground` mesh, `ShaderMaterial`) — do not weaken unrelated assertions.

- [ ] **Step 2: Verify no dangling references to removed symbols**

Run:
```bash
grep -rnE "TransitionTrims|BaseTiles|SeamScatter|_feather|_scatter_seam|_lay_curbs|_material_for|_pond_fringe|TileVariants" --include=*.gd --include=*.tscn arena/ test/ tools/
```
Expected: no matches in `arena/floor/floor_builder.gd`, `arena/arena_3d.tscn`, `test/test_arena_regions.gd`, `test/test_arena_3d_map.gd`. (`TileVariants` may still appear in `test/test_tile_variants.gd` and `arena/floor/tile_variants.gd` — those stay. `autotile.gd`/`test_autotile.gd` stay.) Fix any stragglers pointing at the removed floor internals.

- [ ] **Step 3: Run the full suite once**

Run: `godot47 --headless -s addons/gut/gut_cmdln.gd -gdir=res://test -gexit 2>&1 | grep -iE "Tests|Passing|Failing|Asserts"`
Expected: `Failing Tests 0`.

- [ ] **Step 4: Commit any test fixups**

```bash
git add -A test/
git commit -m "test(floor): align floor/arena tests with the splatmap ground"
```
(If Steps 1–3 required no changes, skip the commit.)

---

### Task 6: Rendered verification (real player POV) + spec change-log

The splat blending is a visual feature; verify it in the actual game view and record the outcome. This task has no unit test — its deliverable is the rendered shots showing blended zones + the updated living spec.

**Files:**
- Modify: `docs/superpowers/specs/2026-07-01-splatmap-ground-blending-design.md` (Change log)

- [ ] **Step 1: Render the map tour from the real gameplay camera**

Run: `godot47 res://tools/map_tour_shot.tscn`
Expected: console prints `TOUR_SHOT` for each stop and `MAP_TOUR_DONE`, no errors. PNGs written to `res://_shots/tour_spawn.png`, `tour_north_path.png`, `tour_garden_ne.png`, `tour_pond.png`, `tour_grass_sw.png`.

- [ ] **Step 2: Inspect the shots against the four original complaints**

Open each `res://_shots/tour_*.png` and confirm:
- grass↔grass: no straight cut lines between cells (one continuous surface).
- grass↔stone_plaza / stone_path: soft blended transition (not a translucent ghost, not a ruler line); plaza reads slightly raised via the edge shadow.
- flowerbed↔grass: flowers blend into grass instead of fading to transparent.
- pond: water fades into the grass shore (no hard circle, no flicker).

If a boundary still looks wrong, tune the relevant `zones[...]["blend"]` (higher = softer, `0` = sharp), `ao_band`/`ao_strength` (plaza height feel), or the shader's `height_blend` uniform default, then re-render. Record what you changed.

- [ ] **Step 3: Append a Change log entry to the design spec**

Add one dated line to the `## Change log` section of `docs/superpowers/specs/2026-07-01-splatmap-ground-blending-design.md` summarizing the shipped result and any tuning values chosen (final `blend` per zone, `ao_band`, `ao_strength`, `height_blend`).

- [ ] **Step 4: Commit**

```bash
git add docs/superpowers/specs/2026-07-01-splatmap-ground-blending-design.md
git commit -m "docs(spec): record shipped splatmap ground blending + tuning values"
```

---

## Notes for the implementer

- **`godot47`** = `/c/Users/avino/bin/godot47`. Headless works for logic/material tests; the `map_tour_shot`/`floor_preview` render harnesses need a real GPU context (run them windowed, not `--headless`).
- **Channel order is load-bearing:** `SplatField.CHANNEL` (R=plaza,G=path,B=dirt,A=flower) and the shader's `w_plaza=s.r … w_flower=s.a` must stay in lockstep. Grass is always the remainder.
- **Do not** reintroduce per-zone `y` steps, curbs, or feather overlays — the flat single surface is the whole point.
- **Out of scope, do not touch:** `arena/floor/autotile.gd`, the recipe `priority` map, and the unrelated `avihay_chat_spam_*` / `project.godot` working-tree changes.
