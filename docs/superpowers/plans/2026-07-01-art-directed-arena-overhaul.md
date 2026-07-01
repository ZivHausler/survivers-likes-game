# Art-Directed Arena Overhaul (Garden Vertical Slice) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the MapBuilder blob floor + current HUD with a data-driven modular 3D tile
floor (pure autotile resolver + authored trims/decals), clustered art-directed Garden props, and a
freshly-rebuilt visual-only HUD — the hub + Garden vertical slice, iterated to ≥85/100 on the
screenshot QA rubric.

**Architecture:** A per-district **recipe** (`arena/maps/garden_map.gd`) holds an ASCII zone grid,
zone priorities, per-zone material defs, a pond inset, authored decals, and prop clusters. Pure,
unit-tested logic (`ZoneGrid`, `Autotile`, `TileVariants`, `PropLayout`) turns that data into
piece/rotation/variant/position decisions. Two scene builders (`FloorBuilder`, `GardenScatter`)
consume the recipe + pure logic to assemble `GardenFloor` and `Props` node trees at `_ready`. The
arena scene is rewired to use them; the HUD is rebuilt from scratch. All visual quality is gated by
the screenshot QA loop (`docs/notes/visual-qa-loop.md`), not unit tests.

**Tech Stack:** Godot 4.7 (GDScript, 3D), `Camera3D` (existing `GameCamera3D`), `Decal` nodes,
`StandardMaterial3D` (painterly/matte), GUT tests, SDXL art pipeline (`artkit/generation/*`).

## Global Constraints

- **3D, angled top-down.** No 2D TileMap; "tiles" are flat 3D meshes on a grid under the existing
  MOBA-style `GameCamera3D`. Combat readability at gameplay-cam distance is mandatory.
- **Visual-only HUD.** Bind ONLY existing data (timer, kills, level, HP, XP, weapons+cooldowns,
  ultimate, passives, boss). Do NOT build coins/wave/dash systems — omit them (no empty placeholder panels).
- **No auto-fail conditions** from `docs/notes/visual-qa-loop.md` in a passing slice (no flat blobs,
  no harsh borders, no sparse/random props, no debug-looking HUD, no undetailed floor).
- **Deterministic pure logic.** The autotile resolver, variant hash, and placement math are pure and
  unit-tested; byte-stable for a fixed seed (pattern: `ArenaScatter.compute_positions`).
- **Keep the suite green.** Baseline is 1067 passing. Migrate MapBuilder-tied and HUD-tied tests when
  their targets are replaced; never leave the suite red.
- **Authored, not dumped.** Zone layout and prop clusters are hand-authored recipe data, not noise.
- **North-star identity (binding).** Obey `2026-06-30-lol-swarm-visual-identity-design.md`: stylized
  3D cyber-anime, painterly League materials (baked-AO look, color-blocked, low noise, matte + select
  glowing accents), environment lower-saturation than VFX, neon cyan/magenta reserved for accents.
- **Garden identity (spec §0.1 #3):** neon cyber-park — soft organic nature + hard sci-fi structure +
  controlled neon; ≥5 ground materials; chunky stylized vegetation; VFX-poppable muted palette.
- **Technical/quality standards (binding).** `docs/notes/visual-technical-standards.md` governs all
  rendering/asset/camera/style rules: stylized 3D only (no pixel art / low-res / blurry AI textures);
  1024–2048px textures for hero assets; MSAA + mipmaps + anisotropic filtering enabled; controlled
  bloom on emissive only; AO/contact shadows; AI meshes cleaned in Blender before import; shared
  material families/bevel/glow across zones; **judge every asset from the actual gameplay-camera
  distance**, never close-up only.

**Toolset notes for the engineer (read once):**
- Godot binary: `C:\Users\avino\tools\godot47\godot47.exe`. Shell is PowerShell (use `& "..."`).
- Run ONE test file:
  `& "C:\Users\avino\tools\godot47\godot47.exe" -s --path . addons/gut/gut_cmdln.gd -gtest=res://test/<file>.gd -gexit`
- Run the FULL suite:
  `& "C:\Users\avino\tools\godot47\godot47.exe" -s --path . addons/gut/gut_cmdln.gd -gdir=res://test -gexit`
- Import new assets (textures/scenes) before referencing at runtime:
  `& "C:\Users\avino\tools\godot47\godot47.exe" --headless --import` (generates gitignored `.import`).
- `.uid` files are auto-generated on import; add them when git status shows them, do not hand-edit.
- Existing reused prop scenes live at `res://obstacles/<key>.tscn`; colliders wrap in `Obstacle3D`
  (`obstacles/obstacle_3d.gd`) via `obs.set_model(model, footprint_radius, height)`.

---

## File Structure

**New — pure logic (unit-tested, no engine calls beyond RNG/data):**
- `arena/floor/zone_grid.gd` — `ZoneGrid`: parse ASCII rows + legend → 2D zone-id grid; accessors.
- `arena/floor/autotile.gd` — `Autotile`: static resolver `resolve(grid, cx, cy, priority)`.
- `arena/floor/tile_variants.gd` — `TileVariants`: static deterministic `variant_for(cx, cy, count)`.
- `arena/floor/prop_layout.gd` — `PropLayout`: static `resolve(clusters, clear_radius)` (reuses
  `ArenaScatter.compute_positions`).

**New — recipe data:**
- `arena/maps/garden_map.gd` — `const RECIPE` (cell_size, rows, legend, priority, zones, pond,
  decals, prop_clusters). One recipe = one district (replicable).

**New — scene builders (structural tests + QA):**
- `arena/floor/floor_builder.gd` — `FloorBuilder extends Node`: builds `GardenFloor`
  (`BaseTiles`/`TransitionTrims`/`Decals`/`Pond`).
- `arena/floor/prop_scatter.gd` — `GardenScatter extends Node`: nav activation + builds `Props`
  (`Landmarks`/`MediumProps`/`SmallDetails`) + contact-shadow decals.

**New — prop scenes (authored, QA):**
- `obstacles/garden_hero_tree_3d.tscn`, `garden_bench_3d.tscn`, `garden_planter_3d.tscn`,
  `garden_trellis_3d.tscn`, `garden_bollard_3d.tscn` (+ their `.gd`/no-script as needed).

**Modified:**
- `arena/arena_3d.tscn` — swap `GroundBuilder`(MapBuilder)→`FloorBuilder`; `ObstacleSpawner`
  (ArenaScatter clusters)→`GardenScatter`; keep `Ground` collision, `Borders`, lighting/env; retune
  lighting.
- `ui/hud.tscn`, `ui/hud.gd` — full fresh rewrite (visual-only).
- `tools/screenshot.gd` — add a gameplay-cam shot.
- `tools/hud_preview.gd` — update to the new HUD node tree.

**Deleted (retired with the blob floor — user-authorized "fresh rebuild"):**
- `arena/map_builder.gd` (+ `.uid`), `arena/maps/final_city_map.gd` (+ `.uid`).

**Migrated tests:** `test/test_arena_regions.gd`, `test/test_arena_3d_map.gd` (MapBuilder→new floor);
`test/test_hud.gd`, `test/test_hud_zones.gd`, `test/test_hud_visual.gd`, `test/test_hud_theme.gd`,
`test/test_hud_3d_compat.gd`, `test/test_cooldown_hud.gd` (old HUD→new HUD). **Kept as-is:**
`test/test_arena_scatter.gd` (compute_positions is reused), `test/test_arena_environment.gd`
(glow/ambient still hold).

**New tests:** `test/test_zone_grid.gd`, `test/test_autotile.gd`, `test/test_tile_variants.gd`,
`test/test_prop_layout.gd`, `test/test_floor_builder.gd`, `test/test_garden_scatter.gd`,
`test/test_garden_props_load.gd`.

---

## Task 1: ZoneGrid — ASCII zone-map parser (pure)

**Files:**
- Create: `arena/floor/zone_grid.gd`
- Test: `test/test_zone_grid.gd`

**Interfaces:**
- Produces: `class_name ZoneGrid extends RefCounted`
  - `func _init(rows: PackedStringArray, legend: Dictionary, cell_size_: float) -> void`
  - `var width: int`, `var height: int`, `var cell_size: float`
  - `func zone_at(cx: int, cy: int) -> StringName` (out of bounds → `&"void"`)
  - `func in_bounds(cx: int, cy: int) -> bool`
  - `func cell_center_world(cx: int, cy: int) -> Vector3` (grid centered on origin, y = 0)

- [ ] **Step 1: Write the failing test**

Create `test/test_zone_grid.gd`:

```gdscript
extends GutTest
## Pure tests for the ASCII zone-map parser.

const LEGEND := { ".": &"grass", "#": &"stone_plaza", "=": &"stone_path" }

func _grid() -> ZoneGrid:
	var rows := PackedStringArray([
		"...",
		".#=",
		"...",
	])
	return ZoneGrid.new(rows, LEGEND, 4.0)

func test_dimensions() -> void:
	var g := _grid()
	assert_eq(g.width, 3, "width = longest row length")
	assert_eq(g.height, 3, "height = row count")
	assert_almost_eq(g.cell_size, 4.0, 0.001, "cell size stored")

func test_zone_lookup_by_legend() -> void:
	var g := _grid()
	assert_eq(g.zone_at(0, 0), &"grass", "'.' → grass")
	assert_eq(g.zone_at(1, 1), &"stone_plaza", "'#' → stone_plaza")
	assert_eq(g.zone_at(2, 1), &"stone_path", "'=' → stone_path")

func test_out_of_bounds_is_void() -> void:
	var g := _grid()
	assert_eq(g.zone_at(-1, 0), &"void", "negative → void")
	assert_eq(g.zone_at(3, 0), &"void", "past width → void")
	assert_eq(g.zone_at(0, 3), &"void", "past height → void")
	assert_false(g.in_bounds(3, 0), "in_bounds false past edge")
	assert_true(g.in_bounds(2, 2), "in_bounds true inside")

func test_unknown_char_is_void() -> void:
	var g := ZoneGrid.new(PackedStringArray(["?"]), LEGEND, 4.0)
	assert_eq(g.zone_at(0, 0), &"void", "char not in legend → void")

func test_short_rows_padded_with_void() -> void:
	var g := ZoneGrid.new(PackedStringArray(["##", "#"]), LEGEND, 4.0)
	assert_eq(g.width, 2, "width is longest row")
	assert_eq(g.zone_at(1, 1), &"void", "missing cell in short row → void")

func test_cell_center_world_is_centered_on_origin() -> void:
	# 3x3 grid, cell 4 → centers span [-4,0,4]; middle cell at origin.
	var g := _grid()
	var mid := g.cell_center_world(1, 1)
	assert_almost_eq(mid.x, 0.0, 0.001, "middle cell centered on x")
	assert_almost_eq(mid.z, 0.0, 0.001, "middle cell centered on z")
	assert_almost_eq(mid.y, 0.0, 0.001, "tiles live on y=0 plane")
	var corner := g.cell_center_world(0, 0)
	assert_almost_eq(corner.x, -4.0, 0.001, "cell 0 is one cell left of center")
	assert_almost_eq(corner.z, -4.0, 0.001, "cell 0 is one cell up of center")
```

- [ ] **Step 2: Run it — verify it fails**

Run: `& "C:\Users\avino\tools\godot47\godot47.exe" -s --path . addons/gut/gut_cmdln.gd -gtest=res://test/test_zone_grid.gd -gexit`
Expected: FAIL — `ZoneGrid` not found / cannot instantiate.

- [ ] **Step 3: Implement `arena/floor/zone_grid.gd`**

```gdscript
class_name ZoneGrid extends RefCounted
## Parses a hand-authored ASCII zone map (one char per cell) into a 2D grid of
## zone ids. Pure/data-only — no engine nodes. Grid is centered on the world
## origin so the arena straddles (0,0). See arena/maps/garden_map.gd for a recipe.

var width: int = 0
var height: int = 0
var cell_size: float = 4.0
var _cells: Array = []  # row-major: _cells[y][x] -> StringName

func _init(rows: PackedStringArray, legend: Dictionary, cell_size_: float) -> void:
	cell_size = cell_size_
	height = rows.size()
	for r in rows:
		width = maxi(width, r.length())
	for y in height:
		var row: Array = []
		var s: String = rows[y]
		for x in width:
			if x < s.length():
				var ch := s.substr(x, 1)
				row.append(legend.get(ch, &"void"))
			else:
				row.append(&"void")
		_cells.append(row)

func in_bounds(cx: int, cy: int) -> bool:
	return cx >= 0 and cy >= 0 and cx < width and cy < height

func zone_at(cx: int, cy: int) -> StringName:
	if not in_bounds(cx, cy):
		return &"void"
	return _cells[cy][cx]

func cell_center_world(cx: int, cy: int) -> Vector3:
	var ox := (float(width) - 1.0) * 0.5
	var oy := (float(height) - 1.0) * 0.5
	return Vector3((float(cx) - ox) * cell_size, 0.0, (float(cy) - oy) * cell_size)
```

- [ ] **Step 4: Run the test — verify it passes**

Run the same `-gtest` command. Expected: PASS (6/6).

- [ ] **Step 5: Commit**

```powershell
git add arena/floor/zone_grid.gd arena/floor/zone_grid.gd.uid test/test_zone_grid.gd
git commit -m "feat(floor): ZoneGrid ASCII zone-map parser (pure)"
```

---

## Task 2: Autotile resolver — bitmask → piece + rotation (pure)

**Files:**
- Create: `arena/floor/autotile.gd`
- Test: `test/test_autotile.gd`

**Interfaces:**
- Consumes: `ZoneGrid` (Task 1).
- Produces: `class_name Autotile`
  - `const PIECE_BASE := &"base"`, `PIECE_EDGE := &"edge"`, `PIECE_OUTER := &"outer_corner"`,
    `PIECE_INNER := &"inner_corner"`
  - `static func resolve(grid: ZoneGrid, cx: int, cy: int, priority: Dictionary) -> Dictionary`
    → `{ "piece": StringName, "rotation": int }`, rotation ∈ {0,1,2,3}.

**Rotation convention (fixed by tests):** a piece's canonical seam faces **North** (−Z, toward
`cy-1`) at rotation 0; each +1 rotates the seam one quarter clockwise: N=0, E=1, S=2, W=3.
`outer_corner` at rotation 0 has its two seams facing N+E; +1 → E+S, etc. `inner_corner` at rotation
0 is a concave pocket whose lower diagonal is NE; +1 → SE, etc. A neighbour is a **seam** (lower)
when it appears in `priority` with a strictly smaller value than this cell's zone. Neighbours absent
from `priority` (e.g. `pond`, `void`) are **not** seams (pond gets its own rim; arena edge has walls).

- [ ] **Step 1: Write the failing test**

Create `test/test_autotile.gd`:

```gdscript
extends GutTest
## Pure tests for the floor autotile resolver.

const PRIORITY := { &"stone_plaza": 5, &"stone_path": 4, &"grass": 1 }

# Build a 3x3 grid where the center is HIGH priority and selected neighbours are LOW,
# to exercise each piece/rotation. 'H' = stone_plaza (high), 'L' = grass (low).
func _grid(rows: Array) -> ZoneGrid:
	var legend := { "H": &"stone_plaza", "L": &"grass" }
	return ZoneGrid.new(PackedStringArray(rows), legend, 4.0)

func _resolve(rows: Array) -> Dictionary:
	return Autotile.resolve(_grid(rows), 1, 1, PRIORITY)

func test_interior_is_base() -> void:
	var r := _resolve(["HHH", "HHH", "HHH"])
	assert_eq(r["piece"], Autotile.PIECE_BASE, "all-same neighbourhood → base")

func test_equal_priority_neighbour_is_not_a_seam() -> void:
	# center stone_plaza, north neighbour also stone_plaza-priority via '=' path? use H everywhere
	# but make north a same-priority DIFFERENT zone is out of scope; equal id = base already covered.
	var r := _resolve(["HHH", "HHH", "HHH"])
	assert_eq(r["piece"], Autotile.PIECE_BASE)

func test_edge_north() -> void:
	var r := _resolve(["LLL", "HHH", "HHH"])  # only north row is low
	assert_eq(r["piece"], Autotile.PIECE_EDGE, "one lower orthogonal → edge")
	assert_eq(r["rotation"], 0, "north seam → rotation 0")

func test_edge_east() -> void:
	var r := _resolve(["HHL", "HHL", "HHL"])  # east column low
	assert_eq(r["piece"], Autotile.PIECE_EDGE)
	assert_eq(r["rotation"], 1, "east seam → rotation 1")

func test_edge_south() -> void:
	var r := _resolve(["HHH", "HHH", "LLL"])
	assert_eq(r["piece"], Autotile.PIECE_EDGE)
	assert_eq(r["rotation"], 2, "south seam → rotation 2")

func test_edge_west() -> void:
	var r := _resolve(["LHH", "LHH", "LHH"])
	assert_eq(r["piece"], Autotile.PIECE_EDGE)
	assert_eq(r["rotation"], 3, "west seam → rotation 3")

func test_outer_corner_ne() -> void:
	# north AND east low → convex corner facing NE
	var r := _resolve(["LLL", "HHL", "HHL"])
	assert_eq(r["piece"], Autotile.PIECE_OUTER, "two adjacent lower sides → outer corner")
	assert_eq(r["rotation"], 0, "N+E → rotation 0")

func test_outer_corner_sw() -> void:
	var r := _resolve(["LHH", "LHH", "LLL"])  # west AND south low
	assert_eq(r["piece"], Autotile.PIECE_OUTER)
	assert_eq(r["rotation"], 2, "S+W → rotation 2")

func test_inner_corner_ne() -> void:
	# N, E orthogonals HIGH; NE diagonal LOW → concave pocket at NE
	var r := _resolve(["HHL", "HHH", "HHH"])
	assert_eq(r["piece"], Autotile.PIECE_INNER, "concave diagonal → inner corner")
	assert_eq(r["rotation"], 0, "NE pocket → rotation 0")

func test_determinism() -> void:
	var a := _resolve(["LLL", "HHH", "HHH"])
	var b := _resolve(["LLL", "HHH", "HHH"])
	assert_eq(a, b, "same input → identical output")
```

- [ ] **Step 2: Run it — verify it fails**

Run: `... -gtest=res://test/test_autotile.gd -gexit`
Expected: FAIL — `Autotile` not found.

- [ ] **Step 3: Implement `arena/floor/autotile.gd`**

```gdscript
class_name Autotile
## Pure autotile resolver. Given a ZoneGrid, a cell, and a zone-priority map,
## decides which floor piece (base/edge/outer_corner/inner_corner) the cell needs
## and its quarter-turn rotation, so the HIGHER-priority zone owns clean seams.
## No engine calls — deterministic and unit-tested. See docs/.../overhaul spec §1.2.

const PIECE_BASE  := &"base"
const PIECE_EDGE  := &"edge"
const PIECE_OUTER := &"outer_corner"
const PIECE_INNER := &"inner_corner"

# Orthogonal offsets in N,E,S,W order → rotation index equals array index.
const _ORTHO := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
# Diagonal offsets in NE,SE,SW,NW order → rotation index equals array index.
const _DIAG := [Vector2i(1, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(-1, -1)]

static func _is_lower(grid: ZoneGrid, cx: int, cy: int, dx: int, dy: int,
		self_pri: int, priority: Dictionary) -> bool:
	var z := grid.zone_at(cx + dx, cy + dy)
	if not priority.has(z):
		return false  # pond/void/unknown never form a trim seam
	return int(priority[z]) < self_pri

static func resolve(grid: ZoneGrid, cx: int, cy: int, priority: Dictionary) -> Dictionary:
	var self_zone := grid.zone_at(cx, cy)
	var self_pri: int = int(priority.get(self_zone, -9999))

	# Orthogonal seam bitmask (bit i set = _ORTHO[i] is lower).
	var ortho := []
	for o in _ORTHO:
		ortho.append(_is_lower(grid, cx, cy, o.x, o.y, self_pri, priority))
	var n: bool = ortho[0]; var e: bool = ortho[1]; var s: bool = ortho[2]; var w: bool = ortho[3]
	var count := int(n) + int(e) + int(s) + int(w)

	if count >= 2:
		# Adjacent pair → convex outer corner (N+E=0, E+S=1, S+W=2, W+N=3).
		if n and e: return { "piece": PIECE_OUTER, "rotation": 0 }
		if e and s: return { "piece": PIECE_OUTER, "rotation": 1 }
		if s and w: return { "piece": PIECE_OUTER, "rotation": 2 }
		if w and n: return { "piece": PIECE_OUTER, "rotation": 3 }
		# Opposite pair (N+S or E+W): treat as an edge on the first set side (1-wide
		# strips are avoided by authoring; this keeps the resolver total).
		for i in 4:
			if ortho[i]:
				return { "piece": PIECE_EDGE, "rotation": i }

	if count == 1:
		for i in 4:
			if ortho[i]:
				return { "piece": PIECE_EDGE, "rotation": i }

	# No orthogonal seam: a lower DIAGONAL with both its adjacent orthogonals NOT lower
	# is a concave inner corner (NE=0, SE=1, SW=2, NW=3).
	for i in 4:
		var d: Vector2i = _DIAG[i]
		if _is_lower(grid, cx, cy, d.x, d.y, self_pri, priority):
			# adjacent orthogonals of diagonal i are ortho[i] and ortho[(i+1)%4]
			if not ortho[i] and not ortho[(i + 1) % 4]:
				return { "piece": PIECE_INNER, "rotation": i }

	return { "piece": PIECE_BASE, "rotation": 0 }
```

- [ ] **Step 4: Run the test — verify it passes**

Run: `... -gtest=res://test/test_autotile.gd -gexit`. Expected: PASS (all).

- [ ] **Step 5: Commit**

```powershell
git add arena/floor/autotile.gd arena/floor/autotile.gd.uid test/test_autotile.gd
git commit -m "feat(floor): pure Autotile resolver (bitmask -> piece + rotation)"
```

---

## Task 3: TileVariants — deterministic per-cell variant hash (pure)

**Files:**
- Create: `arena/floor/tile_variants.gd`
- Test: `test/test_tile_variants.gd`

**Interfaces:**
- Produces: `class_name TileVariants`
  - `static func variant_for(cx: int, cy: int, count: int) -> int` → index in `[0, count)`.

- [ ] **Step 1: Write the failing test**

Create `test/test_tile_variants.gd`:

```gdscript
extends GutTest
## Pure tests for deterministic per-cell tile-variant selection.

func test_single_variant_is_zero() -> void:
	assert_eq(TileVariants.variant_for(3, 7, 1), 0, "count 1 → always variant 0")
	assert_eq(TileVariants.variant_for(0, 0, 0), 0, "count 0 → 0 (guard, no div-by-zero)")

func test_in_range() -> void:
	for x in range(-20, 20):
		for y in range(-20, 20):
			var v := TileVariants.variant_for(x, y, 3)
			assert_true(v >= 0 and v < 3, "variant in [0,3) for (%d,%d) got %d" % [x, y, v])

func test_deterministic() -> void:
	assert_eq(TileVariants.variant_for(5, 9, 4), TileVariants.variant_for(5, 9, 4),
		"same cell+count → same variant")

func test_varies_across_cells() -> void:
	# Not all equal — the hash must spread values across a small neighbourhood.
	var seen := {}
	for x in 6:
		for y in 6:
			seen[TileVariants.variant_for(x, y, 3)] = true
	assert_true(seen.size() >= 2, "variants must differ across cells (got %d distinct)" % seen.size())
```

- [ ] **Step 2: Run it — verify it fails**

Run: `... -gtest=res://test/test_tile_variants.gd -gexit`. Expected: FAIL — `TileVariants` not found.

- [ ] **Step 3: Implement `arena/floor/tile_variants.gd`**

```gdscript
class_name TileVariants
## Deterministic per-cell variant picker so repeated floor areas never look flat.
## Pure integer hash of cell coords → index in [0, count). No RNG state.

static func variant_for(cx: int, cy: int, count: int) -> int:
	if count <= 1:
		return 0
	var h := (cx * 73856093) ^ (cy * 19349663)
	return absi(h) % count
```

- [ ] **Step 4: Run the test — verify it passes**

Run the `-gtest` command. Expected: PASS.

- [ ] **Step 5: Commit**

```powershell
git add arena/floor/tile_variants.gd arena/floor/tile_variants.gd.uid test/test_tile_variants.gd
git commit -m "feat(floor): deterministic TileVariants per-cell hash (pure)"
```

---

## Task 4: Garden recipe data (`garden_map.gd`)

**Files:**
- Create: `arena/maps/garden_map.gd`
- Test: `test/test_garden_recipe.gd`

**Interfaces:**
- Consumes: `ZoneGrid` (Task 1) for the validation test only.
- Produces: `const RECIPE: Dictionary` with keys: `cell_size: float`, `rows: PackedStringArray`,
  `legend: Dictionary` (char→StringName), `priority: Dictionary` (zone→int), `zones: Dictionary`
  (zone→`{color: Color, tex: String, variants: int, y: float, emissive: bool}`), `pond:
  {center: Vector2, radius: float, y: float, rim_color: Color, water_color: Color}`, `decals: Array`
  (`{type, pos: Vector2, size, rot}`), `prop_clusters: Array` (see Task 5 shape).

**Zone ids & palette (north-star + §0.1 Garden):** `grass` emerald matte; `stone_plaza` warm gray
hub; `stone_path` pale stone; `dirt_path` brown; `flowerbed` dark soil (flowers are props on top);
`pond` handled as an inset (not base-tiled). `void` = outside the authored area.

- [ ] **Step 1: Write the failing validation test**

Create `test/test_garden_recipe.gd`:

```gdscript
extends GutTest
## Validates the Garden recipe is well-formed and drives ZoneGrid correctly.

var RECIPE: Dictionary

func before_all() -> void:
	RECIPE = load("res://arena/maps/garden_map.gd").RECIPE

func test_has_required_keys() -> void:
	for k in ["cell_size", "rows", "legend", "priority", "zones", "pond", "decals", "prop_clusters"]:
		assert_true(RECIPE.has(k), "recipe must define '%s'" % k)

func test_rows_are_rectangular_and_sized() -> void:
	var rows: PackedStringArray = RECIPE["rows"]
	assert_true(rows.size() >= 16, "garden grid must be at least 16 rows")
	var w := rows[0].length()
	for r in rows:
		assert_eq(r.length(), w, "every row must be the same width (rectangular grid)")

func test_every_char_is_in_legend() -> void:
	var legend: Dictionary = RECIPE["legend"]
	for r in RECIPE["rows"]:
		for i in r.length():
			assert_true(legend.has(r.substr(i, 1)), "char '%s' must be in legend" % r.substr(i, 1))

func test_priority_covers_tiled_zones() -> void:
	# Every legend zone except pond/void must have a priority for seam resolution.
	var priority: Dictionary = RECIPE["priority"]
	for ch in RECIPE["legend"]:
		var z: StringName = RECIPE["legend"][ch]
		if z == &"pond" or z == &"void":
			continue
		assert_true(priority.has(z), "zone '%s' needs a priority" % z)

func test_zones_have_material_defs() -> void:
	var zones: Dictionary = RECIPE["zones"]
	for ch in RECIPE["legend"]:
		var z: StringName = RECIPE["legend"][ch]
		if z == &"void" or z == &"pond":
			continue  # pond is an inset (its own water/rim colors in recipe.pond), not a base tile
		assert_true(zones.has(z), "zone '%s' needs a material def" % z)
		assert_true(zones[z].has("color"), "zone '%s' needs a color" % z)

func test_grid_builds_and_has_a_hub() -> void:
	var g := ZoneGrid.new(RECIPE["rows"], RECIPE["legend"], RECIPE["cell_size"])
	var hub := 0
	for y in g.height:
		for x in g.width:
			if g.zone_at(x, y) == &"stone_plaza":
				hub += 1
	assert_true(hub >= 16, "recipe must contain a central stone_plaza hub (got %d cells)" % hub)
```

- [ ] **Step 2: Run it — verify it fails**

Run: `... -gtest=res://test/test_garden_recipe.gd -gexit`. Expected: FAIL — file/`RECIPE` missing.

- [ ] **Step 3: Implement `arena/maps/garden_map.gd`**

The ASCII grid is the authored Garden layout (24×24, 8-unit cells → 192×192 world, centered).
Legend: `.`=grass, `#`=stone_plaza hub, `=`=stone_path, `-`=dirt_path, `*`=flowerbed, `~`=pond.

> **Cell-size note:** spec §1.1 targets 4-unit/48×48 cells; this slice authors 8-unit/24×24 for a
> hand-editable grid. The resolver is cell-size-agnostic, so halving `cell_size` and re-authoring at
> 48×48 is a pure QA-loop refinement if 8-unit seams read blocky.

```gdscript
extends Node
## Garden district recipe: ASCII zone map + per-zone materials + pond inset + authored
## decals + prop clusters. One recipe = one district (replicable). Read by FloorBuilder
## and GardenScatter. Pure data — no logic.

# static var (NOT const): a PackedStringArray literal is not a constant expression in GDScript,
# so `const RECIPE` fails to parse. `static var` accepts it and is accessed identically via
# `load("res://arena/maps/garden_map.gd").RECIPE`.
static var RECIPE := {
	"cell_size": 8.0,
	"rows": PackedStringArray([
		"...........==...........",
		"...........==...........",
		"...........==...~~~~~...",
		"...**......==...~~~~~...",
		"...**......==...~~~~~...",
		"...........==...~~~~~...",
		"...........==...~~~~~...",
		"...........==...........",
		"........########........",
		"........########........",
		"........########........",
		"========########========",
		"========########========",
		"........########........",
		"........########........",
		"......-.########........",
		"......-....==...........",
		"......-....==....***....",
		"....***....==....***....",
		"....***....==....***....",
		"....***----==...........",
		"...........==...........",
		"...........==...........",
		"...........==...........",
	]),
	"legend": {
		".": &"grass", "#": &"stone_plaza", "=": &"stone_path",
		"-": &"dirt_path", "*": &"flowerbed", "~": &"pond",
	},
	# Higher owns the seam. pond/void intentionally absent (handled as insets / walls).
	"priority": {
		&"stone_plaza": 5, &"stone_path": 4, &"dirt_path": 3, &"flowerbed": 2, &"grass": 1,
	},
	# Painterly matte StandardMaterial3D defs. tex filled in Task 10 (SDXL); color is the
	# fallback/tint. y is the base-layer height (tiny steps avoid z-fighting).
	"zones": {
		&"grass":       { "color": Color(0.27, 0.47, 0.28), "tex": "", "variants": 3, "y": 0.02, "emissive": false },
		&"stone_plaza": { "color": Color(0.60, 0.61, 0.66), "tex": "", "variants": 2, "y": 0.03, "emissive": false },
		&"stone_path":  { "color": Color(0.70, 0.68, 0.62), "tex": "", "variants": 3, "y": 0.03, "emissive": false },
		&"dirt_path":   { "color": Color(0.42, 0.34, 0.25), "tex": "", "variants": 2, "y": 0.025, "emissive": false },
		&"flowerbed":   { "color": Color(0.30, 0.24, 0.20), "tex": "", "variants": 2, "y": 0.025, "emissive": false },
	},
	# Pond inset (world coords). Aligned with the '~' cells (upper-right).
	"pond": {
		"center": Vector2(30.0, -60.0), "radius": 20.0, "y": 0.0,
		"water_color": Color(0.14, 0.52, 0.68, 0.85), "rim_color": Color(0.55, 0.9, 1.0),
	},
	# Authored floor decals (Task 8). type maps to a texture in Task 10; size in world units.
	"decals": [
		{ "type": "plaza_medallion", "pos": Vector2(0, 0),   "size": 40.0, "rot": 0.0 },
		{ "type": "path_wear",       "pos": Vector2(0, 40),  "size": 10.0, "rot": 0.0 },
		{ "type": "path_wear",       "pos": Vector2(0, -40), "size": 10.0, "rot": 0.0 },
		{ "type": "leaves",          "pos": Vector2(-40, 40), "size": 8.0, "rot": 0.7 },
		{ "type": "moss",            "pos": Vector2(-44, 24), "size": 7.0, "rot": 0.0 },
		{ "type": "crack",           "pos": Vector2(24, 8),  "size": 6.0, "rot": 1.2 },
	],
	# Prop clusters (Task 5 PropLayout shape). role ∈ landmark|medium|small.
	# item = [scene_key, count, collide, scale].
	"prop_clusters": [
		{ "role": &"landmark", "center": Vector2(0, 40), "ext": 1.0, "seed": 1, "sep": 1.0,
			"items": [["garden_hero_tree_3d", 1, true, 1.0]] },
		{ "role": &"medium", "center": Vector2(-30, 20), "ext": 10.0, "seed": 10, "sep": 6.0,
			"items": [["garden_bench_3d", 2, true, 1.0], ["garden_planter_3d", 2, true, 1.0]] },
		{ "role": &"medium", "center": Vector2(34, 30), "ext": 10.0, "seed": 11, "sep": 6.0,
			"items": [["garden_trellis_3d", 1, true, 1.0], ["prop_lamp_3d", 1, false, 1.0]] },
		{ "role": &"small", "center": Vector2(-40, 40), "ext": 10.0, "seed": 20, "sep": 3.0,
			"items": [["prop_bush_3d", 3, false, 1.0], ["prop_flowers_3d", 4, false, 1.0]] },
		{ "role": &"small", "center": Vector2(40, -20), "ext": 10.0, "seed": 21, "sep": 3.0,
			"items": [["prop_tall_grass_3d", 5, false, 1.0], ["prop_mushroom_3d", 2, false, 1.0]] },
		{ "role": &"small", "center": Vector2(-44, -20), "ext": 8.0, "seed": 22, "sep": 3.0,
			"items": [["garden_bollard_3d", 3, true, 1.0], ["prop_flowers_3d", 3, false, 1.0]] },
	],
}
```

- [ ] **Step 4: Run the test — verify it passes**

Run: `... -gtest=res://test/test_garden_recipe.gd -gexit`. Expected: PASS.

- [ ] **Step 5: Commit**

```powershell
git add arena/maps/garden_map.gd arena/maps/garden_map.gd.uid test/test_garden_recipe.gd
git commit -m "feat(floor): Garden district recipe (ASCII grid + zones + clusters)"
```

---

## Task 5: PropLayout — cluster placement resolver (pure)

**Files:**
- Create: `arena/floor/prop_layout.gd`
- Test: `test/test_prop_layout.gd`

**Interfaces:**
- Consumes: `ArenaScatter.compute_positions(rng_seed, count, extent, clear_radius, min_separation)`
  (existing, `arena/arena_scatter.gd`).
- Produces: `class_name PropLayout`
  - `static func resolve(clusters: Array, clear_radius: float) -> Array` → each element:
    `{ "key": String, "pos": Vector3, "collide": bool, "scale": float, "role": StringName }`.
  - Cluster shape: `{ role, center: Vector2, ext: float, seed: int, sep: float, items: Array }`,
    `items` = `[[key: String, count: int, collide: bool, scale: float], ...]`.
  - Placements within `clear_radius` of world origin are dropped (keeps the spawn disc open).

- [ ] **Step 1: Write the failing test**

Create `test/test_prop_layout.gd`:

```gdscript
extends GutTest
## Pure tests for cluster prop placement (reuses ArenaScatter.compute_positions).

func _clusters() -> Array:
	return [
		{ "role": &"landmark", "center": Vector2(0, 40), "ext": 1.0, "seed": 1, "sep": 1.0,
			"items": [["hero", 1, true, 1.0]] },
		{ "role": &"medium", "center": Vector2(-30, 20), "ext": 10.0, "seed": 10, "sep": 6.0,
			"items": [["bench", 3, true, 1.0]] },
		{ "role": &"small", "center": Vector2(20, -20), "ext": 10.0, "seed": 20, "sep": 3.0,
			"items": [["bush", 8, false, 1.0], ["flower", 6, false, 1.0]] },
	]

func test_deterministic() -> void:
	var a := PropLayout.resolve(_clusters(), 10.0)
	var b := PropLayout.resolve(_clusters(), 10.0)
	assert_eq(a.size(), b.size(), "same input → same count")
	for i in a.size():
		assert_true(a[i]["pos"].is_equal_approx(b[i]["pos"]), "placement %d identical" % i)

func test_entries_carry_key_role_collide_scale_and_xz_pos() -> void:
	var out := PropLayout.resolve(_clusters(), 10.0)
	assert_true(out.size() > 0)
	for e in out:
		assert_true(e.has("key") and e.has("pos") and e.has("collide") and e.has("scale") and e.has("role"))
		assert_almost_eq(e["pos"].y, 0.0, 0.001, "props sit on the y=0 plane")

func test_spawn_disc_kept_clear() -> void:
	# Force a cluster over the origin; nothing should be placed inside clear_radius.
	var clusters := [{ "role": &"small", "center": Vector2(0, 0), "ext": 30.0, "seed": 5, "sep": 4.0,
		"items": [["bush", 20, false, 1.0]] }]
	for e in PropLayout.resolve(clusters, 12.0):
		var d := Vector2(e["pos"].x, e["pos"].z).length()
		assert_true(d >= 12.0, "prop at radius %.1f violates the 12u spawn disc" % d)

func test_role_counts_match_budget_ranges() -> void:
	# Using the real Garden recipe, the resolved counts must hit the spec's budget.
	var recipe: Dictionary = load("res://arena/maps/garden_map.gd").RECIPE
	var out := PropLayout.resolve(recipe["prop_clusters"], 12.0)
	var by_role := { &"landmark": 0, &"medium": 0, &"small": 0 }
	for e in out:
		by_role[e["role"]] += 1
	assert_eq(by_role[&"landmark"], 1, "exactly 1 landmark")
	assert_true(by_role[&"medium"] >= 3 and by_role[&"medium"] <= 6, "3–6 medium, got %d" % by_role[&"medium"])
	assert_true(by_role[&"small"] >= 10 and by_role[&"small"] <= 25, "10–25 small, got %d" % by_role[&"small"])
```

- [ ] **Step 2: Run it — verify it fails**

Run: `... -gtest=res://test/test_prop_layout.gd -gexit`. Expected: FAIL — `PropLayout` not found.

- [ ] **Step 3: Implement `arena/floor/prop_layout.gd`**

```gdscript
class_name PropLayout
## Pure resolver: turns authored prop clusters into concrete world placements,
## reusing ArenaScatter.compute_positions for deterministic in-cluster jitter.
## Drops anything inside the spawn disc so the combat center stays open.

static func resolve(clusters: Array, clear_radius: float) -> Array:
	var out: Array = []
	var clear_sq := clear_radius * clear_radius
	for cluster in clusters:
		var center: Vector2 = cluster["center"]
		var ext: float = cluster["ext"]
		var sep: float = cluster["sep"]
		var seed_off: int = cluster["seed"]
		var role: StringName = cluster["role"]
		# Flatten items into a key/collide/scale list preserving order.
		var keys: Array = []
		for entry in cluster["items"]:
			for _i in entry[1]:
				keys.append({ "key": entry[0], "collide": entry[2], "scale": entry[3] })
		if keys.is_empty():
			continue
		var positions := ArenaScatter.compute_positions(seed_off, keys.size(), ext, 0.0, sep)
		for i in positions.size():
			var world := Vector3(center.x + positions[i].x, 0.0, center.y + positions[i].z)
			if world.x * world.x + world.z * world.z < clear_sq:
				continue
			out.append({
				"key": keys[i]["key"], "pos": world, "collide": keys[i]["collide"],
				"scale": keys[i]["scale"], "role": role,
			})
	return out
```

- [ ] **Step 4: Run the test — verify it passes**

Run: `... -gtest=res://test/test_prop_layout.gd -gexit`. Expected: PASS. If `medium`/`small` counts
fall outside the budget because rejection sampling dropped some, tune the recipe `ext`/`sep`/`count`
in `garden_map.gd` (Task 4) until the ranges hold, then re-run.

- [ ] **Step 5: Commit**

```powershell
git add arena/floor/prop_layout.gd arena/floor/prop_layout.gd.uid test/test_prop_layout.gd
git commit -m "feat(props): pure PropLayout cluster placement resolver"
```

---

## Task 6: FloorBuilder — base tiles + variation

**Files:**
- Create: `arena/floor/floor_builder.gd`
- Test: `test/test_floor_builder.gd`

**Interfaces:**
- Consumes: `ZoneGrid`, `Autotile`, `TileVariants` (Tasks 1–3), `garden_map.RECIPE` (Task 4).
- Produces: `class_name FloorBuilder extends Node`
  - `@export var recipe_path: String = "res://arena/maps/garden_map.gd"`
  - At `_ready`, deferred-adds a `Node3D` named `GardenFloor` to its parent with children
    `BaseTiles`, `TransitionTrims`, `Decals`, `Pond`.
  - `func build_into(root: Node3D) -> void` — testable synchronous builder (no deferral).
  - This task fills `BaseTiles` only (one flat quad MeshInstance3D per non-void, non-pond cell, with
    a shared per-`(zone,variant)` painterly material). Trims/decals/pond come in Tasks 7–8 (empty
    containers created now).

- [ ] **Step 1: Write the failing test**

Create `test/test_floor_builder.gd`:

```gdscript
extends GutTest
## Structural tests for the tiled floor builder. Runs headless (meshes, no display).

func _build() -> Node3D:
	var root := Node3D.new()
	add_child_autofree(root)
	var fb := FloorBuilder.new()
	fb.recipe_path = "res://arena/maps/garden_map.gd"
	root.add_child(fb)
	fb.build_into(root)  # synchronous path for tests
	return root

func _count_non_floor_cells() -> int:
	var recipe: Dictionary = load("res://arena/maps/garden_map.gd").RECIPE
	var g := ZoneGrid.new(recipe["rows"], recipe["legend"], recipe["cell_size"])
	var n := 0
	for y in g.height:
		for x in g.width:
			var z := g.zone_at(x, y)
			if z != &"void" and z != &"pond":
				n += 1
	return n

func test_garden_floor_root_and_containers() -> void:
	var root := _build()
	var floor := root.get_node_or_null("GardenFloor")
	assert_not_null(floor, "FloorBuilder must build a GardenFloor node")
	for c in ["BaseTiles", "TransitionTrims", "Decals", "Pond"]:
		assert_not_null(floor.get_node_or_null(c), "GardenFloor must contain %s" % c)

func test_one_base_tile_per_floor_cell() -> void:
	var root := _build()
	var tiles := root.get_node("GardenFloor/BaseTiles")
	assert_eq(tiles.get_child_count(), _count_non_floor_cells(),
		"one base tile per non-void, non-pond cell")

func test_base_tiles_have_surface_material() -> void:
	var root := _build()
	var tiles := root.get_node("GardenFloor/BaseTiles")
	var checked := 0
	for t in tiles.get_children():
		if t is MeshInstance3D:
			var mesh: Mesh = (t as MeshInstance3D).mesh
			assert_not_null(mesh, "tile has a mesh")
			assert_not_null(mesh.surface_get_material(0),
				"tile mesh surface 0 must have a material (avoids null-material render spam)")
			checked += 1
			if checked >= 5:
				break
	assert_true(checked > 0, "at least one base tile inspected")
```

- [ ] **Step 2: Run it — verify it fails**

Run: `... -gtest=res://test/test_floor_builder.gd -gexit`. Expected: FAIL — `FloorBuilder` not found.

- [ ] **Step 3: Implement `arena/floor/floor_builder.gd` (base tiles only)**

```gdscript
class_name FloorBuilder extends Node
## Builds a modular tiled floor from a district recipe: one flat quad per cell with a
## painterly per-zone material + deterministic variation. Transition trims, authored
## decals, and the pond inset are added by later steps (containers created here).
## Assigning materials to the MESH SURFACE (not just material_override) avoids the
## per-frame "Parameter material is null" render spam. Replicable: new district = new recipe.

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

## Test/҂direct entry: build the floor under `parent` synchronously.
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
```

> Fix the placeholder identifier in the comment above (`into_root`) — no non-ASCII; the method is
> `build_into_root`. (Ensure the file contains only ASCII identifiers.)

- [ ] **Step 4: Run the test — verify it passes**

Run: `... -gtest=res://test/test_floor_builder.gd -gexit`. Expected: PASS (3/3).

- [ ] **Step 5: Commit**

```powershell
git add arena/floor/floor_builder.gd arena/floor/floor_builder.gd.uid test/test_floor_builder.gd
git commit -m "feat(floor): FloorBuilder base tiles + per-cell variation"
```

---

## Task 7: FloorBuilder — transitions (trim strips + edge bleed)

**Files:**
- Modify: `arena/floor/floor_builder.gd`
- Modify: `test/test_floor_builder.gd`

**Interfaces:**
- Consumes: `Autotile.resolve(grid, x, y, priority)` (Task 2).
- Produces: after base tiles, for every non-void/non-pond cell the builder resolves its autotile
  piece; if it is not `base`, it lays a beveled **trim strip** MeshInstance3D into `TransitionTrims`
  along the seam edge(s), oriented by the returned rotation. This removes harsh material borders.

- [ ] **Step 1: Add the failing test**

Append to `test/test_floor_builder.gd`:

```gdscript
func test_transition_trims_present_at_seams() -> void:
	var root := _build()
	var trims := root.get_node("GardenFloor/TransitionTrims")
	assert_true(trims.get_child_count() > 0,
		"seams between zones must produce trim strips (no harsh borders)")

func test_trims_have_surface_material() -> void:
	var root := _build()
	var trims := root.get_node("GardenFloor/TransitionTrims")
	if trims.get_child_count() == 0:
		return
	var first := trims.get_child(0) as MeshInstance3D
	assert_not_null(first, "trim is a MeshInstance3D")
	assert_not_null(first.mesh.surface_get_material(0), "trim mesh surface has a material")
```

- [ ] **Step 2: Run it — verify the new tests fail**

Run: `... -gtest=res://test/test_floor_builder.gd -gexit`. Expected: the two new tests FAIL
(TransitionTrims empty).

- [ ] **Step 3: Implement transitions in `floor_builder.gd`**

Add a trim material + strip mesh, and lay strips during the cell loop. Insert the trim call inside
`build_into_root`'s inner loop right after `base_tiles.add_child(mi, true)`:

```gdscript
			_lay_trims(trims, grid, recipe["priority"], x, y, wc, cs)
```

Add these methods and a cached trim material:

```gdscript
var _trim_mat: StandardMaterial3D = null

## Seam offsets/rotations: N,E,S,W → edge strip along that side of the cell.
const _EDGE_DIR := [Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(-1, 0, 0)]

func _lay_trims(trims: Node3D, grid: ZoneGrid, priority: Dictionary,
		x: int, y: int, wc: Vector3, cs: float) -> void:
	var res := Autotile.resolve(grid, x, y, priority)
	if res["piece"] == Autotile.PIECE_BASE:
		return
	# For edge/outer/inner we lay a beveled strip on each orthogonal side that borders a
	# lower zone. Re-derive the lower sides directly (robust for all piece types).
	for i in 4:
		var d: Vector3 = _EDGE_DIR[i]
		var nz := grid.zone_at(x + int(d.x), y + int(d.z))
		if not priority.has(nz):
			continue
		if int(priority[nz]) >= int(priority.get(grid.zone_at(x, y), -9999)):
			continue
		var strip := MeshInstance3D.new()
		var mesh := _trim_mesh(cs)
		mesh.surface_set_material(0, _get_trim_mat())
		strip.mesh = mesh
		# Position at the cell's seam edge, slightly raised so it caps the border.
		strip.position = Vector3(wc.x + d.x * cs * 0.5, 0.06, wc.z + d.z * cs * 0.5)
		strip.rotation.y = atan2(d.x, d.z)  # face the seam direction
		trims.add_child(strip, true)

## A thin beveled curb strip spanning one cell edge (length cs, small width/height).
func _trim_mesh(cs: float) -> ArrayMesh:
	var box := BoxMesh.new()
	box.size = Vector3(cs, 0.14, 0.5)
	return box.get_mesh_arrays() if false else _box_to_array(box)

func _box_to_array(box: BoxMesh) -> ArrayMesh:
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, box.get_mesh_arrays())
	return am

func _get_trim_mat() -> StandardMaterial3D:
	if _trim_mat == null:
		_trim_mat = StandardMaterial3D.new()
		_trim_mat.albedo_color = Color(0.74, 0.75, 0.78)
		_trim_mat.roughness = 0.85
	return _trim_mat
```

> Note: `BoxMesh.get_mesh_arrays()` returns the surface arrays; `_box_to_array` wraps them in an
> `ArrayMesh` so `surface_set_material(0, ...)` works uniformly with the base-tile path. Remove the
> dead `if false else` and keep only `return _box_to_array(box)` in `_trim_mesh`.

- [ ] **Step 4: Run the test — verify it passes**

Run: `... -gtest=res://test/test_floor_builder.gd -gexit`. Expected: PASS (5/5).

- [ ] **Step 5: Commit**

```powershell
git add arena/floor/floor_builder.gd test/test_floor_builder.gd
git commit -m "feat(floor): autotile-driven transition trim strips at zone seams"
```

---

## Task 8: FloorBuilder — authored decals + pond inset

**Files:**
- Modify: `arena/floor/floor_builder.gd`
- Modify: `test/test_floor_builder.gd`

**Interfaces:**
- Consumes: `recipe["decals"]`, `recipe["pond"]` (Task 4).
- Produces: `Decals` filled with `Decal` nodes (one per authored entry; textures wired in Task 10 —
  until then a `Decal` with a null texture is still a valid node and a visible-later placeholder),
  and `Pond` filled with a water-surface MeshInstance3D + a slightly larger bright shoreline rim.

- [ ] **Step 1: Add the failing test**

Append to `test/test_floor_builder.gd`:

```gdscript
func test_authored_decals_placed() -> void:
	var root := _build()
	var decals := root.get_node("GardenFloor/Decals")
	var recipe: Dictionary = load("res://arena/maps/garden_map.gd").RECIPE
	assert_eq(decals.get_child_count(), (recipe["decals"] as Array).size(),
		"one Decal node per authored decal entry")

func test_pond_surface_and_rim_built() -> void:
	var root := _build()
	var pond := root.get_node("GardenFloor/Pond")
	assert_true(pond.get_child_count() >= 2, "pond must have a water surface + a shoreline rim")
```

- [ ] **Step 2: Run it — verify the new tests fail**

Run: `... -gtest=res://test/test_floor_builder.gd -gexit`. Expected: the two new tests FAIL.

- [ ] **Step 3: Implement decals + pond in `floor_builder.gd`**

At the end of `build_into_root`, after the cell loop, add:

```gdscript
	_build_decals(decals, recipe.get("decals", []))
	_build_pond(pond, recipe.get("pond", {}))
```

Add:

```gdscript
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
	water.mesh = _disc_mesh(r, pond.get("water_color", Color(0.14, 0.52, 0.68, 0.85)), true)
	water.position = Vector3(c.x, pond.get("y", 0.0) + 0.05, c.y)
	water.name = "PondWater"
	container.add_child(water, true)

## A flat filled disc of `radius` with a painterly material; emissive rim if `glow`.
func _disc_mesh(radius: float, color: Color, glow: bool) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	var segs := 40
	for i in segs:
		var a0 := TAU * float(i) / segs
		var a1 := TAU * float(i + 1) / segs
		st.set_uv(Vector2(0.5, 0.5)); st.add_vertex(Vector3.ZERO)
		st.set_uv(Vector2(0, 0)); st.add_vertex(Vector3(cos(a0) * radius, 0, sin(a0) * radius))
		st.set_uv(Vector2(1, 0)); st.add_vertex(Vector3(cos(a1) * radius, 0, sin(a1) * radius))
	var mesh := st.commit()
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.3
	if color.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if glow:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = 0.5
	mesh.surface_set_material(0, m)
	return mesh
```

- [ ] **Step 4: Run the test — verify it passes**

Run: `... -gtest=res://test/test_floor_builder.gd -gexit`. Expected: PASS (7/7).

- [ ] **Step 5: Commit**

```powershell
git add arena/floor/floor_builder.gd test/test_floor_builder.gd
git commit -m "feat(floor): authored floor decals + pond inset with bright rim"
```

---

## Task 9: Authored Garden prop scenes

**Files:**
- Create: `obstacles/garden_hero_tree_3d.tscn`, `obstacles/garden_bench_3d.tscn`,
  `obstacles/garden_planter_3d.tscn`, `obstacles/garden_trellis_3d.tscn`,
  `obstacles/garden_bollard_3d.tscn`
- Test: `test/test_garden_props_load.gd`

**Interfaces:**
- Produces: five `Node3D`-rooted scenes, each composed of primitive `MeshInstance3D`s with painterly
  `StandardMaterial3D`s (matte + **select** cyan emissive accents per north-star). These are the new
  keys referenced by `garden_map.RECIPE.prop_clusters` (Task 4). Follow the existing
  `res://obstacles/*.tscn` convention (root `Node3D`, child meshes) so `GardenScatter` (Task 10) and
  `Obstacle3D.set_model` consume them unchanged.

**Design (§0.1 Garden — chunky, readable, muted + select neon):**
- `garden_hero_tree_3d` — LANDMARK: thick trunk (cylinder) + 2–3 large rounded canopy blobs
  (spheres, emerald), a few cyan-emissive vein lines (thin emissive cylinders). ~6 u tall.
- `garden_bench_3d` — low sleek bench: a flat seat box + 2 leg boxes, gray metal, thin cyan seam.
- `garden_planter_3d` — hex/round planter rim (short cylinder, metal) + soil top + a small
  cyan-emissive lip; a couple of magenta flower spheres.
- `garden_trellis_3d` — an arch: 2 uprights + a curved/segmented top bar (boxes), gray metal, faint
  cyan glow; ~4 u tall.
- `garden_bollard_3d` — short capped post (cylinder) with a cyan-emissive top band; ~1.2 u.

- [ ] **Step 1: Write the failing test**

Create `test/test_garden_props_load.gd`:

```gdscript
extends GutTest
## Every new Garden prop scene must load and contain a visible mesh (no empty props).

const KEYS := [
	"garden_hero_tree_3d", "garden_bench_3d", "garden_planter_3d",
	"garden_trellis_3d", "garden_bollard_3d",
]

func _count_visible_meshes(node: Node) -> int:
	var n := 0
	for c in node.get_children():
		if c is MeshInstance3D and (c as MeshInstance3D).visible:
			n += 1
		n += _count_visible_meshes(c)
	return n

func test_all_garden_props_load_with_a_visible_mesh() -> void:
	for k in KEYS:
		var path := "res://obstacles/%s.tscn" % k
		assert_true(ResourceLoader.exists(path), "%s must exist" % path)
		var scene: PackedScene = load(path)
		assert_not_null(scene, "%s must load" % path)
		var inst := scene.instantiate()
		assert_true(inst is Node3D, "%s root must be Node3D" % k)
		assert_true(_count_visible_meshes(inst) >= 1, "%s must have >=1 visible MeshInstance3D" % k)
		inst.free()
```

- [ ] **Step 2: Run it — verify it fails**

Run: `... -gtest=res://test/test_garden_props_load.gd -gexit`. Expected: FAIL — scenes missing.

- [ ] **Step 3: Author the five `.tscn` scenes**

Open an existing prop (e.g. `obstacles/prop_lamp_3d.tscn`) as a text reference for the format, then
create each new scene. Example — `obstacles/garden_bollard_3d.tscn`:

```
[gd_scene load_steps=3 format=3]

[sub_resource type="CylinderMesh" id="Cyl_post"]
top_radius = 0.22
bottom_radius = 0.26
height = 1.1

[sub_resource type="StandardMaterial3D" id="Mat_post"]
albedo_color = Color(0.32, 0.36, 0.42, 1)
roughness = 0.7

[sub_resource type="StandardMaterial3D" id="Mat_band"]
albedo_color = Color(0.3, 0.85, 1.0, 1)
emission_enabled = true
emission = Color(0.3, 0.85, 1.0, 1)
emission_energy_multiplier = 1.4

[node name="GardenBollard" type="Node3D"]

[node name="Post" type="MeshInstance3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0.55, 0)
mesh = SubResource("Cyl_post")
surface_material_override/0 = SubResource("Mat_post")

[node name="Band" type="MeshInstance3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 0.12, 0, 0, 0, 1, 0, 1.05, 0)
mesh = SubResource("Cyl_post")
surface_material_override/0 = SubResource("Mat_band")
```

Build the other four analogously (compose `BoxMesh`/`CylinderMesh`/`SphereMesh` primitives with
matte gray materials + a single cyan-emissive accent each; canopy/flowers use emerald/magenta). Keep
each root a `Node3D` named descriptively. Then import:

Run: `& "C:\Users\avino\tools\godot47\godot47.exe" --headless --import`

- [ ] **Step 4: Add footprints and run the test**

Add footprints for the colliding new props so `GardenScatter` (Task 10) can size their `Obstacle3D`
wrappers. (These are added in Task 10's `_FP`; note the intended values here for reference:
`garden_hero_tree_3d [1.0, 6.0]`, `garden_bench_3d [1.0, 0.6]`, `garden_planter_3d [0.8, 0.8]`,
`garden_trellis_3d [1.2, 4.0]`, `garden_bollard_3d [0.3, 1.1]`.)

Run: `... -gtest=res://test/test_garden_props_load.gd -gexit`. Expected: PASS.

- [ ] **Step 5: Commit**

```powershell
git add obstacles/garden_*.tscn obstacles/garden_*.tscn.uid obstacles/garden_*.import test/test_garden_props_load.gd
git commit -m "feat(props): authored Garden prop scenes (hero tree, bench, planter, trellis, bollard)"
```

---

## Task 10: GardenScatter — prop builder + navigation

**Files:**
- Create: `arena/floor/prop_scatter.gd`
- Test: `test/test_garden_scatter.gd`

**Interfaces:**
- Consumes: `PropLayout.resolve` (Task 5), `garden_map.RECIPE.prop_clusters` (Task 4), the new + reused
  `res://obstacles/<key>.tscn` scenes, `Obstacle3D` (`obstacles/obstacle_3d.gd`,
  `set_model(model, radius, height)`).
- Produces: `class_name GardenScatter extends Node`
  - `@export var recipe_path: String = "res://arena/maps/garden_map.gd"`
  - `@export var clear_radius: float = 12.0`
  - At `_ready`: activates navigation (flat region, RVO) and deferred-adds a `Props` `Node3D` with
    children `Landmarks`, `MediumProps`, `SmallDetails`; colliders wrap in `Obstacle3D`, non-colliders
    are plain instances; every prop gets a soft contact-shadow decal.
  - `func build_props(parent: Node3D) -> void` — synchronous testable builder (no deferral, no nav).

- [ ] **Step 1: Write the failing test**

Create `test/test_garden_scatter.gd`:

```gdscript
extends GutTest
## Structural tests for the Garden prop builder.

func _build() -> Node3D:
	var root := Node3D.new()
	add_child_autofree(root)
	var gs := GardenScatter.new()
	gs.recipe_path = "res://arena/maps/garden_map.gd"
	gs.clear_radius = 12.0
	root.add_child(gs)
	gs.build_props(root)
	return root

func test_props_tree_structure() -> void:
	var root := _build()
	var props := root.get_node_or_null("Props")
	assert_not_null(props, "GardenScatter must build a Props node")
	for c in ["Landmarks", "MediumProps", "SmallDetails"]:
		assert_not_null(props.get_node_or_null(c), "Props must contain %s" % c)

func test_budget_counts() -> void:
	var root := _build()
	var props := root.get_node("Props")
	assert_eq(props.get_node("Landmarks").get_child_count(), 1, "exactly 1 landmark")
	var med := props.get_node("MediumProps").get_child_count()
	var small := props.get_node("SmallDetails").get_child_count()
	assert_true(med >= 3 and med <= 6, "3–6 medium props, got %d" % med)
	assert_true(small >= 10 and small <= 25, "10–25 small props, got %d" % small)

func test_spawn_disc_clear() -> void:
	var root := _build()
	var props := root.get_node("Props")
	for group in ["Landmarks", "MediumProps", "SmallDetails"]:
		for p in props.get_node(group).get_children():
			var n := p as Node3D
			var d := Vector2(n.position.x, n.position.z).length()
			assert_true(d >= 12.0, "prop '%s' at radius %.1f violates spawn disc" % [n.name, d])

func test_collider_props_wrapped_in_obstacle3d() -> void:
	var root := _build()
	var landmark := root.get_node("Props/Landmarks").get_child(0)
	assert_true(landmark is Obstacle3D, "colliding landmark must be an Obstacle3D wrapper")
```

- [ ] **Step 2: Run it — verify it fails**

Run: `... -gtest=res://test/test_garden_scatter.gd -gexit`. Expected: FAIL — `GardenScatter` not found.

- [ ] **Step 3: Implement `arena/floor/prop_scatter.gd`**

```gdscript
class_name GardenScatter extends Node
## Builds the Garden's clustered, art-directed props from the district recipe:
## one landmark, medium props, and small details, each grouped for scene clarity.
## Colliders are wrapped in Obstacle3D (collision + nav carve); decoration is plain.
## Also activates the navigation map (flat region) so enemy RVO avoidance works.

@export var recipe_path: String = "res://arena/maps/garden_map.gd"
@export var clear_radius: float = 12.0

const _FP := {
	"garden_hero_tree_3d": [1.0, 6.0], "garden_bench_3d": [1.0, 0.6],
	"garden_planter_3d": [0.8, 0.8], "garden_trellis_3d": [1.2, 4.0],
	"garden_bollard_3d": [0.3, 1.1], "prop_lamp_3d": [0.4, 3.0],
}
const _OBSTACLE_SCENE := preload("res://obstacles/obstacle_3d.tscn")

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
		_add_contact_shadow(container, pl["pos"])

func _spawn_obstacle(container: Node3D, pl: Dictionary) -> void:
	var key: String = pl["key"]
	var fp: Array = _FP.get(key, [0.8, 2.0])
	var scale_mul: float = pl["scale"]
	var scene := load("res://obstacles/%s.tscn" % key) as PackedScene
	var obs: Obstacle3D = _OBSTACLE_SCENE.instantiate()
	if scene != null:
		var model := scene.instantiate()
		if model is Node3D:
			obs.set_model(model as Node3D, fp[0] * scale_mul, fp[1] * scale_mul)
		elif model != null:
			model.free()
	obs.position = Vector3(pl["pos"].x, 0.0, pl["pos"].z)
	if scale_mul != 1.0:
		obs.scale = Vector3.ONE * scale_mul
	container.add_child(obs, true)

func _spawn_decor(container: Node3D, pl: Dictionary) -> void:
	var scene := load("res://obstacles/%s.tscn" % pl["key"]) as PackedScene
	if scene == null:
		return
	var node := scene.instantiate()
	if node is Node3D:
		(node as Node3D).position = Vector3(pl["pos"].x, 0.0, pl["pos"].z)
		container.add_child(node, true)
	elif node != null:
		node.free()

func _add_contact_shadow(container: Node3D, pos: Vector3) -> void:
	var d := Decal.new()
	d.size = Vector3(2.2, 3.0, 2.2)
	d.position = Vector3(pos.x, 1.0, pos.z)
	var tex_path := "res://art/decals/contact_shadow.png"
	if ResourceLoader.exists(tex_path):
		d.texture_albedo = load(tex_path)
	d.modulate = Color(0, 0, 0, 0.5)
	d.name = "ContactShadow"
	container.add_child(d)

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
```

- [ ] **Step 4: Run the test — verify it passes**

Run: `... -gtest=res://test/test_garden_scatter.gd -gexit`. Expected: PASS (4/4). If budget counts
fail, tune `garden_map.RECIPE.prop_clusters` and re-run Task 5's + this test.

- [ ] **Step 5: Commit**

```powershell
git add arena/floor/prop_scatter.gd arena/floor/prop_scatter.gd.uid test/test_garden_scatter.gd
git commit -m "feat(props): GardenScatter clustered prop builder + nav activation"
```

---

## Task 11: SDXL floor textures + decals; wire into recipe

**Files:**
- Create (generated art): `art/textures/garden_grass_albedo.png` (+ `_worn`, `_cracked` variants),
  `art/textures/garden_stone_plaza_albedo.png`, `garden_stone_path_albedo.png`,
  `garden_dirt_path_albedo.png`; `art/decals/plaza_medallion.png`, `path_wear.png`, `leaves.png`,
  `moss.png`, `crack.png`, `contact_shadow.png`.
- Modify: `arena/maps/garden_map.gd` (`zones[*].tex` → texture paths).

**Interfaces:** none new. This is a QA-gated asset task (no unit test); the floor builder already
reads `zones[z].tex` and `art/decals/<type>.png` conventionally, so wiring is data-only.

- [ ] **Step 1: Generate tileable base textures + alpha decals (SDXL)**

Use the artkit pipeline (`C:\Users\avino\swarm\artkit`, WSL venv, DreamShaper XL). Generate **seamless
tileable** base albedos (matte, painterly, low-noise, color-blocked per north-star) and **alpha**
decals (transparent PNGs). Example single-line invocation pattern (adapt the manifest to these
outputs, mirroring the existing `gen_icon.py` flow):

```powershell
& wsl bash -lc "MSYS_NO_PATHCONV=1 /root/sdgen/.venv/bin/python /mnt/c/Users/avino/swarm/artkit/generation/gen_tile.py --manifest /mnt/c/Users/avino/swarm/artkit/manifests/garden_floor.json"
```

Manifest entries (subjects, tileable): emerald stylized grass (clean/worn/cracked), warm-gray plaza
stone with subtle concentric hint, pale stone path, brown dirt path; decals: circular cyan-inlay
plaza medallion, soft path-wear smudge, scattered leaves, moss patch, hairline crack, soft round
contact shadow. Copy outputs into `art/textures/` and `art/decals/`.

Per `docs/notes/visual-technical-standards.md`: generate base albedos at **1024–2048 px**, seamless/
tileable, matte + low-noise; **no blurry output** — re-author or re-pass any texture that reads soft
from the gameplay camera. Ensure the texture `.import` presets have **Mipmaps ON** (floors/props) and
**anisotropic** filtering for the angled floor materials. Judge sharpness on the Task 15 `gameplay`
and `garden` shots (gameplay-cam distance), not 1:1 close-up.

- [ ] **Step 2: Wire texture paths into `garden_map.gd`**

Set each `zones[*].tex` and confirm decal `type` names match the `art/decals/<type>.png` files:

```gdscript
	"zones": {
		&"grass":       { "color": Color(0.27,0.47,0.28), "tex": "res://art/textures/garden_grass_albedo.png", "variants": 3, "y": 0.02, "emissive": false },
		&"stone_plaza": { "color": Color(0.60,0.61,0.66), "tex": "res://art/textures/garden_stone_plaza_albedo.png", "variants": 2, "y": 0.03, "emissive": false },
		&"stone_path":  { "color": Color(0.70,0.68,0.62), "tex": "res://art/textures/garden_stone_path_albedo.png", "variants": 3, "y": 0.03, "emissive": false },
		&"dirt_path":   { "color": Color(0.42,0.34,0.25), "tex": "res://art/textures/garden_dirt_path_albedo.png", "variants": 2, "y": 0.025, "emissive": false },
		&"flowerbed":   { "color": Color(0.30,0.24,0.20), "tex": "", "variants": 2, "y": 0.025, "emissive": false },
	},
```

(The variant materials all share one albedo; per-variant value-shift already differentiates them. A
richer worn/cracked-per-variant swap is an optional QA-loop refinement.)

- [ ] **Step 3: Import + verify the recipe test still passes**

Run: `& "C:\Users\avino\tools\godot47\godot47.exe" --headless --import`
Run: `... -gtest=res://test/test_garden_recipe.gd -gexit` and `... -gtest=res://test/test_floor_builder.gd -gexit`.
Expected: PASS (textures are optional to the builder; it loads them when present).

- [ ] **Step 4: Commit**

```powershell
git add art/textures/garden_*.png art/textures/garden_*.png.import art/decals/*.png art/decals/*.png.import arena/maps/garden_map.gd
git commit -m "feat(art): SDXL Garden floor textures + decals wired into recipe"
```

---

## Task 12: Rebuild the arena scene + retune lighting + migrate arena tests

**Files:**
- Modify: `arena/arena_3d.tscn`
- Delete: `arena/map_builder.gd` (+ `.uid`), `arena/maps/final_city_map.gd` (+ `.uid`)
- Rewrite: `test/test_arena_regions.gd`, `test/test_arena_3d_map.gd`

**Interfaces:**
- Consumes: `FloorBuilder`, `GardenScatter`.
- Produces: an `arena_3d.tscn` whose floor is `GardenFloor` (built by `FloorBuilder`) and whose props
  are `Props` (built by `GardenScatter`), retaining `Ground` collision, four `Borders` walls,
  `DirectionalLight3D`, and `WorldEnvironment` (glow/ambient). No `GeneratedGround`/`Obstacles`/
  `Fountain`/`Water` nodes remain.

- [ ] **Step 1: Rewrite the arena tests to the new structure (write them first — they fail)**

Replace `test/test_arena_regions.gd` entirely:

```gdscript
extends GutTest
## Structural + runtime tests for the tiled Garden arena (FloorBuilder + GardenScatter).

var Scene: PackedScene = null

func before_all() -> void:
	Scene = load("res://arena/arena_3d.tscn")

func _build_arena() -> Node:
	var root: Node = autofree(Scene.instantiate())
	add_child(root)
	await get_tree().process_frame
	await get_tree().process_frame
	return root

func test_scene_loads() -> void:
	assert_not_null(Scene, "arena_3d.tscn must load")

func test_floor_builder_and_scatter_nodes_exist() -> void:
	var root := Scene.instantiate()
	assert_not_null(root.get_node_or_null("FloorBuilder"), "arena needs a FloorBuilder node")
	assert_not_null(root.get_node_or_null("GardenScatter"), "arena needs a GardenScatter node")
	root.free()

func test_garden_floor_is_built() -> void:
	var root := await _build_arena()
	var floor := root.get_node_or_null("GardenFloor")
	assert_not_null(floor, "FloorBuilder must build GardenFloor")
	assert_true(floor.get_node("BaseTiles").get_child_count() > 50, "many base tiles")
	assert_true(floor.get_node("TransitionTrims").get_child_count() > 0, "seams have trims")

func test_props_are_built_and_clustered() -> void:
	var root := await _build_arena()
	var props := root.get_node_or_null("Props")
	assert_not_null(props, "GardenScatter must build Props")
	assert_eq(props.get_node("Landmarks").get_child_count(), 1, "one landmark")

func test_spawn_disc_clear() -> void:
	var root := await _build_arena()
	var props := root.get_node("Props")
	for group in ["Landmarks", "MediumProps", "SmallDetails"]:
		for p in props.get_node(group).get_children():
			var n := p as Node3D
			assert_true(Vector2(n.position.x, n.position.z).length() >= 12.0,
				"prop '%s' inside spawn disc" % n.name)
```

Edit `test/test_arena_3d_map.gd`: keep `test_scene_loads`, `test_ground_has_albedo_texture`,
`test_environment_uses_sky_background`, `test_has_four_border_walls_on_obstacle_layer`. **Remove**
`test_arena_contains_water`, `test_scatter_spawns_obstacles_at_runtime`,
`test_pylon_obstacle_has_mesh_instances` (MapBuilder/old-scatter specific). Add:

```gdscript
func test_floor_tiles_built_at_runtime() -> void:
	var root: Node = autofree(_instantiate())
	add_child(root)
	await get_tree().process_frame
	await get_tree().process_frame
	var floor := root.get_node_or_null("GardenFloor")
	assert_not_null(floor, "GardenFloor must be built at runtime")
	assert_true(floor.get_node("BaseTiles").get_child_count() > 0, "base tiles built")
```

- [ ] **Step 2: Run the arena tests — verify they fail**

Run: `... -gtest=res://test/test_arena_regions.gd -gexit` and `... -gtest=res://test/test_arena_3d_map.gd -gexit`.
Expected: FAIL (scene still has old nodes).

- [ ] **Step 3: Edit `arena/arena_3d.tscn`**

- Change the `GroundBuilder` node's script from `map_builder.gd` to `floor_builder.gd` and rename it
  `FloorBuilder`; set `recipe_path = "res://arena/maps/garden_map.gd"`. (Update the `ext_resource`
  script path + `id`.)
- Change the `ObstacleSpawner` node's script from `arena_scatter.gd` to `prop_scatter.gd` and rename
  it `GardenScatter`.
- Keep `Ground` (StaticBody3D + `GroundCollision`), but recolor `GroundMesh`'s material to a neutral
  dark so any sub-tile gaps don't flash bright grass (set `albedo_color = Color(0.12,0.14,0.12)`,
  keep or drop the albedo texture — test only requires an albedo_texture on the ground mesh, so keep
  a texture assigned).
- Keep `Borders`, `DirectionalLight3D`, `WorldEnvironment`.
- **Lighting retune (§4):** on `DirectionalLight3D` keep `shadow_enabled=true`, `shadow_blur≈2.0`,
  `light_energy≈1.0`; on `Environment` keep `glow_enabled=true`, set `glow_intensity≈0.6`,
  `glow_bloom≈0.15`, `glow_hdr_threshold≈1.1`, `ambient_light_energy≈0.5` (bright soft ambient, bloom
  only on emissive accents). Do not drop below the values asserted by `test_arena_environment.gd`
  (`glow_enabled==true`, `ambient_light_energy>=0.3`).

- [ ] **Step 3b: Apply render/quality project settings** (per `docs/notes/visual-technical-standards.md`)

Edit `project.godot` `[rendering]` (add if missing):
`anti_aliasing/quality/msaa_3d=2` (2× MSAA), `anti_aliasing/quality/screen_space_aa=1` (FXAA),
`textures/default_filters/anisotropic_filtering_level=3` (8×). Confirm the arena `WorldEnvironment`
has SSAO or contact shadows enabled and the glow HDR threshold only fires on emissive accents
(set in Step 3). Import: `& "C:\Users\avino\tools\godot47\godot47.exe" --headless --import`.

- [ ] **Step 4: Delete retired MapBuilder files**

```powershell
git rm arena/map_builder.gd arena/map_builder.gd.uid arena/maps/final_city_map.gd arena/maps/final_city_map.gd.uid
```

- [ ] **Step 5: Run arena + environment tests — verify they pass**

Run: `... -gtest=res://test/test_arena_regions.gd -gexit`, `... -gtest=res://test/test_arena_3d_map.gd -gexit`,
`... -gtest=res://test/test_arena_environment.gd -gexit`. Expected: PASS.

- [ ] **Step 6: Run the FULL suite — confirm still green**

Run: `& "C:\Users\avino\tools\godot47\godot47.exe" -s --path . addons/gut/gut_cmdln.gd -gdir=res://test -gexit`
Expected: green (HUD tests still pass here — HUD is rebuilt in Tasks 13–15; the arena rebuild must not
touch the HUD). If any non-HUD test references a deleted MapBuilder symbol, migrate it now.

- [ ] **Step 7: Commit**

```powershell
git add arena/arena_3d.tscn test/test_arena_regions.gd test/test_arena_3d_map.gd
git commit -m "feat(arena): rebuild arena on tiled floor + GardenScatter; retire MapBuilder"
```

---

## Task 13: New HUD — script + pure logic (rewrite pure/duck-typed tests)

**Files:**
- Rewrite: `ui/hud.gd`
- Rewrite: `test/test_cooldown_hud.gd`, `test/test_hud_zones.gd`, `test/test_hud_3d_compat.gd`

**Interfaces:**
- Produces: `class_name HUD extends CanvasLayer` with the SAME pure/duck-typed API the game relies on
  (so binding logic is unchanged and testable):
  - `func collect_cooldowns(player) -> Array` → `[{ id, fraction, is_ultimate }]`, weapons first, ult last.
  - `func collect_passives(player) -> Array` → `[{ id, level }]`.
  - `func _find_siblings() -> void` — resolves `_game_manager` (name `GameManager`/`GameManager3D`,
    else any sibling with `get_elapsed`) and `_player` (group `player`, else sibling `Player`).
  - `process_mode = PROCESS_MODE_ALWAYS`; binds `GameEvents` boss/hp/level/evolution signals.
- The NEW `.tscn` node tree (built in Task 14) will use fresh names; `hud.gd` must reference nodes it
  owns via `@onready` matching that tree. In THIS task, write `hud.gd` to the new node contract but
  guard every `@onready`-dependent update with null checks so the pure-logic tests (which instantiate
  `hud.gd` via `.new()` without the scene) pass.

**New node contract (used by Task 14 `.tscn` and by `hud.gd` `@onready` paths):**
```
HUD (CanvasLayer)
  Top (PanelContainer)            # top status strip
    TopRow (HBoxContainer)
      Timer (Label)
      Kills (Label)
      Level (Label)
      Enemies (Label)
    XP (ProgressBar)
  Boss (PanelContainer)           # hidden until boss_spawned
    BossName (Label)
    BossHP (ProgressBar)
      BossHPText (Label)
  Command (PanelContainer)        # bottom-center cluster
    HP (ProgressBar)
      HPText (Label)
    Portrait (TextureRect)
    Weapons (HBoxContainer)       # ability icons + cooldown fills
    Ult (RadialCooldown)
    Passives (HBoxContainer)
  Minimap (Node/Control, ui/minimap.gd)   # top-right
  Settings (Button)                        # top-right
  Evolve (Label)                           # centered banner, hidden
  UltReady (Label)                         # ready popup, hidden
```

- [ ] **Step 1: Rewrite the pure/duck-typed tests to the new script**

`test/test_cooldown_hud.gd` and `test/test_hud_zones.gd` already instantiate `load("res://ui/hud.gd").new()`
and call `collect_cooldowns`/`collect_passives` — keep those bodies (the API is preserved), only
confirm they still pass against the new script. `test/test_hud_3d_compat.gd` calls `hud._find_siblings()`
after adding the HUD scene — keep it (the sibling-resolution contract is preserved). No assertion
changes are needed if the API is preserved; re-run them in Step 3 to confirm.

- [ ] **Step 2: Rewrite `ui/hud.gd`**

Write a fresh, smaller `hud.gd` preserving the pure API and signal bindings, referencing the new node
tree. Keep `collect_cooldowns`, `collect_passives`, `_find_siblings`, `_build_icon_map`,
`_register_icon`, `_load_convention` (icon convention reused per spec §3). Every `_process`/handler
access to an `@onready` node is null-guarded so `.new()`-without-scene still runs the pure methods.
(Model the structure on the current `ui/hud.gd`, but bind to the new node names above and drop the
old command-bar-specific node paths.)

- [ ] **Step 3: Run the three tests — verify green**

Run each: `... -gtest=res://test/test_cooldown_hud.gd -gexit`, `... -gtest=res://test/test_hud_zones.gd -gexit`,
`... -gtest=res://test/test_hud_3d_compat.gd -gexit`.
Expected: PASS. (`test_hud_3d_compat` needs the new `hud.tscn` to instantiate; if the scene isn't
rebuilt yet, temporarily point its `load` at a minimal scene OR sequence Task 14 Step 1 first. To
avoid the coupling, do Task 14's `.tscn` skeleton before running this step.)

- [ ] **Step 4: Commit**

```powershell
git add ui/hud.gd test/test_cooldown_hud.gd test/test_hud_zones.gd test/test_hud_3d_compat.gd
git commit -m "feat(hud): fresh hud.gd preserving pure cooldown/passive/sibling API"
```

---

## Task 14: New HUD scene + styling (rewrite structural/style/theme tests)

**Files:**
- Rewrite: `ui/hud.tscn`
- Rewrite: `test/test_hud.gd`, `test/test_hud_visual.gd`, `test/test_hud_theme.gd`
- Modify: `tools/hud_preview.gd`

**Interfaces:**
- Consumes: `ui/hud.gd` (Task 13), `ui/radial_cooldown.gd`, `ui/minimap.gd`, `swarm_hud_theme.tres`.
- Produces: `ui/hud.tscn` matching the new node contract; dark translucent framed panels, styled
  HP/XP bars, ability-icon frames w/ cooldown fills, ult radial, minimap + settings, evolve/ult
  popups. Boss panel hidden by default; theme applied to the first Control child.

- [ ] **Step 1: Rewrite the HUD structural/style/theme tests to the new tree**

Rewrite `test/test_hud.gd` (boss panel) to the new paths — `Boss`, `Boss/BossName`, `Boss/BossHP`,
`Boss/BossHP/BossHPText`:

```gdscript
extends GutTest
## Boss bar reacts to GameEvents boss signals (new HUD tree).

var HUDScene = null
func before_all() -> void: HUDScene = load("res://ui/hud.tscn")
func _hud() -> CanvasLayer: return add_child_autofree(HUDScene.instantiate()) as CanvasLayer

func test_boss_hidden_by_default() -> void:
	assert_false((_hud().get_node("Boss") as Control).visible, "Boss panel hidden until spawn")

func test_boss_spawned_shows_name_and_max() -> void:
	var hud := _hud()
	GameEvents.boss_spawned.emit("Undead Serpent", 2000.0)
	assert_true((hud.get_node("Boss") as Control).visible)
	assert_eq((hud.get_node("Boss/BossName") as Label).text, "Undead Serpent")
	assert_almost_eq((hud.get_node("Boss/BossHP") as ProgressBar).max_value, 2000.0, 0.001)

func test_boss_hp_changed_updates_text() -> void:
	var hud := _hud()
	GameEvents.boss_spawned.emit("Undead Serpent", 2000.0)
	GameEvents.boss_hp_changed.emit(750.0, 2000.0)
	assert_eq((hud.get_node("Boss/BossHP/BossHPText") as Label).text, "750 / 2000")

func test_boss_died_hides_bar() -> void:
	var hud := _hud()
	GameEvents.boss_spawned.emit("Undead Serpent", 2000.0)
	GameEvents.boss_died.emit()
	assert_false((hud.get_node("Boss") as Control).visible)
```

Rewrite `test/test_hud_visual.gd` to the new tree: assert `process_mode==ALWAYS`; `Command/HP` and
`Top/XP` each have `fill` + `background` stylebox overrides; `Evolve` starts hidden and shows on
`evolution_unlocked`; `Top`, `Command`, and `Command/Ult` exist.

Rewrite `test/test_hud_theme.gd`: theme resource loads; `Top` (first Control child) has a theme;
`Boss` is a `PanelContainer` with a theme; `Evolve` has gold `font_color` + positive `outline_size`.
Keep the two `upgrade_ui.tscn` assertions unchanged (that scene is untouched).

- [ ] **Step 2: Run the three tests — verify they fail**

Run each. Expected: FAIL (old `hud.tscn` still present / new one absent).

- [ ] **Step 3: Build `ui/hud.tscn`**

Author the scene to the node contract (Task 13), rooted at `CanvasLayer` with `script = ui/hud.gd`.
Apply `swarm_hud_theme.tres` to `Top` (and set `Boss` = `PanelContainer` with the theme). Give `HP`
and `XP` `fill` + `background` StyleBoxFlat overrides (HP danger-orange fill; XP cyan fill; dark
backgrounds). `Evolve` = centered Label, hidden, gold `font_color` `Color(1,0.8,0.2)`, `outline_size`
> 0, cyan outline. Add `Command/Ult` as a `RadialCooldown` (`ui/radial_cooldown.gd`), `Minimap`
(`ui/minimap.gd`), and a `Settings` `Button` (top-right). Weapons/Passives are empty `HBoxContainer`s
populated at runtime by `hud.gd`.

- [ ] **Step 4: Update `tools/hud_preview.gd`**

Its stub player/GM already drive the HUD via signals + duck-typed accessors; only the node paths it
inspects (if any) change. It currently just loads `hud.tscn` and emits signals — verify it still
renders; adjust any hard-coded node path to the new tree. Keep the arena backdrop load.

- [ ] **Step 5: Run HUD tests + full suite**

Run the three rewritten tests, plus Task 13's three, then the FULL suite.
Expected: all green (1067 baseline restored on the new HUD).

- [ ] **Step 6: Commit**

```powershell
git add ui/hud.tscn tools/hud_preview.gd test/test_hud.gd test/test_hud_visual.gd test/test_hud_theme.gd
git commit -m "feat(hud): fresh visual-only HUD scene + migrated structural/style tests"
```

---

## Task 15: Visual QA loop to ≥85/100 (arena + gameplay-cam + HUD)

**Files:**
- Modify: `tools/screenshot.gd` (add a gameplay-cam shot)
- Modify (as QA dictates): `arena/maps/garden_map.gd`, `arena/floor/floor_builder.gd`,
  `arena/floor/prop_scatter.gd`, `ui/hud.tscn`, `arena/arena_3d.tscn`
- Update: `docs/superpowers/specs/2026-07-01-graphic-ui-and-map-design-spec.md` (Change log)

**Interfaces:** none. Governed by `docs/notes/visual-qa-loop.md`. This task does NOT add unit tests;
it iterates visuals against the rubric while keeping the suite green after every change.

- [ ] **Step 1: Add a gameplay-cam shot to `tools/screenshot.gd`**

Replace the `SHOTS` array with three purpose-built shots (§6): a full-map overview, a NEW angled
gameplay-cam at player height over hub+garden (to judge combat readability), and a mid framing:

```gdscript
const SHOTS := [
	{ "name": "overview",  "pos": Vector3(0, 180, 150), "look": Vector3(0, 0, 0) },
	{ "name": "gameplay",  "pos": Vector3(0, 26, 34),   "look": Vector3(0, 0, 6) },  # ~ -65° like GameCamera3D
	{ "name": "garden",    "pos": Vector3(-20, 40, 70), "look": Vector3(-20, 0, 30) },
]
```

- [ ] **Step 2: Render arena + HUD screenshots**

```powershell
& "C:\Users\avino\tools\godot47\godot47.exe" res://tools/screenshot.tscn
& "C:\Users\avino\tools\godot47\godot47.exe" res://tools/hud_preview.tscn
```

Outputs: `res://_shots/overview.png`, `gameplay.png`, `garden.png`, `hud.png` (all gitignored).

- [ ] **Step 3: Score with the rubric and write the VISUAL QA REPORT**

Read each PNG. Write the verbatim `VISUAL QA REPORT` (format in `docs/notes/visual-qa-loop.md`):
overall score /100, top-5 failures, what works, required fixes. Check the auto-fail list explicitly
(flat blobs / harsh borders / sparse-random props / debug HUD / undetailed floor / no hierarchy /
biome-island look).

- [ ] **Step 4: Fix the top-5 in priority order, re-render, re-score. Loop until ≥85/100.**

Priority order (map/transitions → floor detail → prop clusters → HUD → lighting). Typical levers:
recipe zone layout/palette (`garden_map.gd`), trim/decal density (`floor_builder.gd`), cluster
anchors/budget (`garden_map.gd` `prop_clusters`), HUD spacing/contrast (`hud.tscn`), env
glow/ambient (`arena_3d.tscn`). **After every change, run the full suite** to stay green:
`& "C:\Users\avino\tools\godot47\godot47.exe" -s --path . addons/gut/gut_cmdln.gd -gdir=res://test -gexit`.
If a change alters a structural invariant (tile/prop counts, node names), update the owning test in
the same commit.

- [ ] **Step 5: Confirm success criteria (§8) and update the living spec**

Confirm: overview AND gameplay-cam both ≥85; no auto-fail; HUD reads HP/EXP/level/timer/kills/
abilities/boss instantly; suite green. Append a dated line to the Change log of
`docs/superpowers/specs/2026-07-01-graphic-ui-and-map-design-spec.md` recording the Garden slice
result and the final scores (per project CLAUDE.md — UI/map/art decisions update that spec).

- [ ] **Step 6: Commit**

```powershell
git add tools/screenshot.gd arena/ ui/ docs/superpowers/specs/2026-07-01-graphic-ui-and-map-design-spec.md
git commit -m "feat(arena/hud): iterate Garden slice to >=85/100 on the visual QA rubric"
```

---

## Self-Review (completed before handoff)

**Spec coverage:**
- §0/§0.1 identity → Task 4 recipe palette/zones + Task 9 prop style + Task 11 painterly textures + Task 15 QA.
- §1.1 grid/zone map → Tasks 1, 4. §1.2 resolver + priority → Task 2. §1.3 tiles/transitions → Tasks 6, 7.
  §1.4 variation + decals → Tasks 3, 8. §1.5 assets → Task 11.
- §2 props (budget 1/3–6/10–25, clusters, grounding) → Tasks 5, 9, 10.
- §3 visual-only HUD (top/bottom/side/top-right; omit coins/wave/dash; reuse RadialCooldown/minimap/
  icon convention; fresh gd/tscn) → Tasks 13, 14.
- §4 lighting → Task 12 Step 3. §5 hierarchy (Arena3D/Floor/Props/Gameplay/HUD) → Tasks 12, 14.
- §6 QA loop + gameplay-cam shot → Task 15. §7 testing (pure units + migration) → Tasks 1–3, 5, 12–14.
- §8 success criteria → Task 15 Step 5. §9 out-of-scope respected (no coins/wave/dash; other districts
  are follow-ups; ability-icon roster parked).

**Type consistency:** `ZoneGrid.zone_at`/`cell_center_world`, `Autotile.resolve → {piece, rotation}`,
`TileVariants.variant_for`, `PropLayout.resolve → {key,pos,collide,scale,role}`,
`FloorBuilder.build_into`/`build_into_root`, `GardenScatter.build_props`, and the HUD pure API
(`collect_cooldowns`/`collect_passives`/`_find_siblings`) are used identically across tasks.

**Known follow-ups (out of this slice):** finer 4-unit cells if 8-unit seams read blocky; per-variant
worn/cracked texture swaps; replicating the recipe to the other 5 districts.
