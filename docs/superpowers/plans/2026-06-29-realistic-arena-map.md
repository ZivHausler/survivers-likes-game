# Realistic Arena Map Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the flat brown arena with a realistic outdoor map (PBR grass, HDRI sky with distant mountains, trees, rocks, water) whose trees/rocks/water are obstacles that block — and route enemies around — the player and swarm, inside walled arena borders.

**Architecture:** Visual layer = PBR ground material + HDRI sky on the existing `arena_3d.tscn` (no gameplay impact). Gameplay layer = a reusable `Obstacle3D` static body (collision + `NavigationObstacle3D`) scattered by a seeded, unit-tested placement function, plus four border walls, all on a dedicated **Obstacles** physics layer that the player and enemy bodies (currently `collision_mask=0`) newly collide with but skills do not. Enemies gain a `NavigationAgent3D` with RVO avoidance so they flow around props and each other; `velocity` is still set synchronously in `_physics_process` (the actual move is routed through the avoidance callback) to preserve existing tests.

**Tech Stack:** Godot 4.7 (Forward+), GDScript, GUT 9.7.0, Poly Haven / ambientCG CC0 assets, Godot NavigationServer3D RVO avoidance.

## Global Constraints

- Godot **4.7**, Forward+ renderer. GDScript only.
- GUT 9.7.0 **silently skips** any test file using `assert_le`/`assert_ge` — always use `assert_true(x <= y)`. Watch the test count rise as expected.
- World scale: **1 unit ≈ 16 px**. Gameplay is on the **XZ plane** (Y up); camera is fixed at −55° tilt and must not be touched.
- Visuals stay **decoupled** from logic (the `Juice3D` / `SkillVFX` pattern). Logic/tests must stay green regardless of visuals. Baseline suite: **879/879 green** — never let it regress; each task that adds logic adds tests so the count rises.
- Every new `.gd` file's **first line** is `# See docs/notes/<id>.md`; add the matching note and update `docs/notes/INDEX.md`.
- All sourced assets must be **CC0**; record each in `docs/notes/asset-licenses.md`.
- **Obstacles physics layer = layer 5 (bit value `16`).** Trees/rocks/water/walls live on it; player body and enemy body `collision_mask` gain bit `16`; **skills/projectiles never mask `16`.**
- Run tests with: `godot --headless --import && godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://test -gexit`
- Commit after every task with a `feat:`/`test:`/`docs:` message ending with the Co-Authored-By trailer used in this repo.

---

## File Structure

- `project.godot` — **Modify:** add `[layer_names]` for `3d_physics/layer_5="obstacle"` (cosmetic clarity).
- `arena/arena_3d.tscn` — **Modify:** PBR ground material, HDRI sky environment, 4 border walls, water, scatter script attached to root.
- `arena/arena_scatter.gd` — **Create:** seeded obstacle placement (pure static logic + node instantiation wrapper).
- `obstacles/obstacle_3d.tscn` + `obstacles/obstacle_3d.gd` — **Create:** reusable collidable prop (StaticBody3D + mesh + CollisionShape3D + NavigationObstacle3D).
- `obstacles/water_3d.tscn` + `obstacles/water_3d.gd` — **Create:** decorative + blocking water body.
- `enemies/enemy_3d.tscn` — **Modify:** add `NavigationAgent3D` child; body `collision_mask=16`.
- `enemies/enemy_3d.gd` — **Modify:** RVO avoidance wiring (synchronous `velocity`, async move).
- `player/player_3d.tscn` — **Modify:** body `collision_mask=16`.
- `art/textures/` , `art/hdri/` , `art/models/nature/` — **Create:** downloaded CC0 assets + `.import` files.
- `test/test_obstacle_3d.gd`, `test/test_arena_scatter.gd`, `test/test_arena_3d_map.gd`, `test/test_water_3d.gd`, `test/test_enemy_3d_avoidance.gd`, `test/test_world_layers.gd` — **Create.**
- `docs/notes/` — **Create:** `obstacle-3d.md`, `arena-scatter.md`, `water-3d.md`, `arena-map.md`; update `INDEX.md`, `asset-licenses.md`.

Recommended task order: 1 (layers) → 2 (Obstacle3D) → 3 (scatter) → 4 (ground+sky) → 5 (walls) → 6 (water) → 7 (enemy avoidance) → 8 (integration + docs). Tasks 1–7 each end in an independently testable deliverable.

---

### Task 1: Obstacles physics layer + player/enemy collide with it

**Files:**
- Modify: `project.godot` (add `[layer_names]` section)
- Modify: `player/player_3d.tscn:19` (`collision_mask = 0` → `16`)
- Modify: `enemies/enemy_3d.tscn` (body `collision_mask = 0` → `16`)
- Test: `test/test_world_layers.gd`

**Interfaces:**
- Produces: the **Obstacles layer = bit value `16`** convention used by every later task. Player body and enemy body now collide with anything on layer 16.

- [ ] **Step 1: Write the failing test**

```gdscript
# test/test_world_layers.gd
extends GutTest
## Verifies player + enemy bodies collide with the Obstacles layer (bit 16),
## so trees/rocks/walls block them. Instantiates without entering _ready by
## reading collision_mask straight off the freshly instantiated root node.

const OBSTACLE_BIT := 16

func _root_mask(scene_path: String) -> int:
	var scene: PackedScene = load(scene_path)
	assert_not_null(scene, "%s must load" % scene_path)
	var node: Node = scene.instantiate()
	var mask: int = (node as CollisionObject3D).collision_mask
	node.free()
	return mask

func test_player_body_masks_obstacles() -> void:
	var mask := _root_mask("res://player/player_3d.tscn")
	assert_true((mask & OBSTACLE_BIT) == OBSTACLE_BIT,
		"player body collision_mask must include the Obstacles bit (16)")

func test_enemy_body_masks_obstacles() -> void:
	var mask := _root_mask("res://enemies/enemy_3d.tscn")
	assert_true((mask & OBSTACLE_BIT) == OBSTACLE_BIT,
		"enemy body collision_mask must include the Obstacles bit (16)")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot --headless --import && godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://test/test_world_layers.gd -gexit`
Expected: FAIL — both masks are currently `0`.

- [ ] **Step 3: Make the changes**

In `player/player_3d.tscn`, change the `Player3D` node's `collision_mask = 0` to `collision_mask = 16`.
In `enemies/enemy_3d.tscn`, change the `Enemy3D` body's `collision_mask = 0` to `collision_mask = 16`.
In `project.godot`, add (alphabetical section placement is fine):

```ini
[layer_names]

3d_physics/layer_1="player_body"
3d_physics/layer_2="player_hurtbox"
3d_physics/layer_3="bubble"
3d_physics/layer_4="enemy"
3d_physics/layer_5="obstacle"
```

- [ ] **Step 4: Run test to verify it passes**

Run: `godot --headless --import && godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://test/test_world_layers.gd -gexit`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add project.godot player/player_3d.tscn enemies/enemy_3d.tscn test/test_world_layers.gd
git commit -m "feat(arena): add Obstacles physics layer; player+enemy collide with it"
```

---

### Task 2: Reusable `Obstacle3D` prop scene

**Files:**
- Create: `obstacles/obstacle_3d.gd`
- Create: `obstacles/obstacle_3d.tscn`
- Create: `docs/notes/obstacle-3d.md` (and add a line to `docs/notes/INDEX.md`)
- Test: `test/test_obstacle_3d.gd`

**Interfaces:**
- Produces: `class_name Obstacle3D extends StaticBody3D` with
  `func configure(mesh: Mesh, footprint_radius: float, height: float) -> void` —
  assigns the visual mesh, resizes the `CylinderShape3D` collision (radius/height),
  and sets the `NavigationObstacle3D.radius = footprint_radius`. Used by Task 3's scatter.

- [ ] **Step 1: Write the failing test**

```gdscript
# test/test_obstacle_3d.gd
extends GutTest
## Structural + configure() tests for the reusable collidable map prop.

const OBSTACLE_BIT := 16
var Scene: PackedScene = null

func before_all() -> void:
	Scene = load("res://obstacles/obstacle_3d.tscn")

func test_scene_loads() -> void:
	assert_not_null(Scene, "obstacle_3d.tscn must load")

func test_is_staticbody_on_obstacle_layer() -> void:
	var o: Obstacle3D = Scene.instantiate()
	assert_true(o is StaticBody3D, "Obstacle3D must be a StaticBody3D")
	assert_true((o.collision_layer & OBSTACLE_BIT) == OBSTACLE_BIT,
		"Obstacle3D must be ON the Obstacles layer (16)")
	o.free()

func test_has_required_children() -> void:
	var o: Obstacle3D = Scene.instantiate()
	assert_not_null(o.get_node_or_null("MeshInstance3D"), "needs a MeshInstance3D")
	assert_not_null(o.get_node_or_null("CollisionShape3D"), "needs a CollisionShape3D")
	assert_not_null(o.get_node_or_null("NavigationObstacle3D"), "needs a NavigationObstacle3D")
	o.free()

func test_configure_sets_footprint_and_nav_radius() -> void:
	var o: Obstacle3D = add_child_autofree(Scene.instantiate())
	var mesh := BoxMesh.new()
	o.configure(mesh, 2.5, 6.0)
	var mi: MeshInstance3D = o.get_node("MeshInstance3D")
	assert_eq(mi.mesh, mesh, "configure must assign the visual mesh")
	var shape: CylinderShape3D = (o.get_node("CollisionShape3D") as CollisionShape3D).shape
	assert_almost_eq(shape.radius, 2.5, 0.001, "collision radius must match footprint")
	assert_almost_eq(shape.height, 6.0, 0.001, "collision height must match")
	var nav: NavigationObstacle3D = o.get_node("NavigationObstacle3D")
	assert_almost_eq(nav.radius, 2.5, 0.001, "nav obstacle radius must match footprint")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot --headless --import && godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://test/test_obstacle_3d.gd -gexit`
Expected: FAIL — scene/script do not exist.

- [ ] **Step 3: Create the script**

```gdscript
# obstacles/obstacle_3d.gd
# See docs/notes/obstacle-3d.md
class_name Obstacle3D extends StaticBody3D
## Static, collidable map prop (tree / rock). Sits on the Obstacles layer (16) so it
## blocks the player and enemies, and carries a NavigationObstacle3D so enemy RVO
## avoidance routes the swarm around it. Skills never mask layer 16, so projectiles
## pass over props unchanged.

@onready var _mesh: MeshInstance3D = $MeshInstance3D
@onready var _shape: CollisionShape3D = $CollisionShape3D
@onready var _nav: NavigationObstacle3D = $NavigationObstacle3D

## Assign the visual mesh and resize collision + avoidance footprint to match.
func configure(mesh: Mesh, footprint_radius: float, height: float) -> void:
	if _mesh == null:  # not yet in tree — resolve @onready targets eagerly
		_mesh = $MeshInstance3D
		_shape = $CollisionShape3D
		_nav = $NavigationObstacle3D
	_mesh.mesh = mesh
	var cyl := CylinderShape3D.new()
	cyl.radius = footprint_radius
	cyl.height = height
	_shape.shape = cyl
	_nav.radius = footprint_radius
```

- [ ] **Step 4: Create the scene**

Create `obstacles/obstacle_3d.tscn` with this exact content:

```
[gd_scene load_steps=3 format=3 uid="uid://b0obst3d0prop1"]

[ext_resource type="Script" path="res://obstacles/obstacle_3d.gd" id="1_obst"]

[sub_resource type="CylinderShape3D" id="CylinderShape3D_footprint"]
radius = 1.0
height = 4.0

[node name="Obstacle3D" type="StaticBody3D"]
collision_layer = 16
collision_mask = 0
script = ExtResource("1_obst")

[node name="MeshInstance3D" type="MeshInstance3D" parent="."]

[node name="CollisionShape3D" type="CollisionShape3D" parent="."]
shape = SubResource("CylinderShape3D_footprint")

[node name="NavigationObstacle3D" type="NavigationObstacle3D" parent="."]
radius = 1.0
```

- [ ] **Step 5: Write the docs note**

Create `docs/notes/obstacle-3d.md` describing the prop (layer 16, blocks player+enemy, nav obstacle for RVO, `configure()` API). Add `- obstacle-3d — reusable collidable map prop` to `docs/notes/INDEX.md`.

- [ ] **Step 6: Run test to verify it passes**

Run: `godot --headless --import && godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://test/test_obstacle_3d.gd -gexit`
Expected: PASS (4 tests).

- [ ] **Step 7: Commit**

```bash
git add obstacles/ test/test_obstacle_3d.gd docs/notes/obstacle-3d.md docs/notes/INDEX.md
git commit -m "feat(arena): add reusable Obstacle3D collidable prop"
```

---

### Task 3: Seeded obstacle scatter placement

**Files:**
- Create: `arena/arena_scatter.gd`
- Create: `docs/notes/arena-scatter.md` (+ INDEX line)
- Test: `test/test_arena_scatter.gd`

**Interfaces:**
- Consumes: nothing (pure logic).
- Produces:
  `static func compute_positions(rng_seed: int, count: int, extent: float, clear_radius: float, min_separation: float, attempts_per: int = 30) -> Array` — returns an `Array[Vector3]` of XZ positions (`y == 0`). Deterministic for a given seed. Guarantees: every position within `[-extent, extent]` on X and Z; none within `clear_radius` of origin; pairwise distance ≥ `min_separation`; length ≤ `count`. Used by Task 8 to instantiate `Obstacle3D`s.

- [ ] **Step 1: Write the failing test**

```gdscript
# test/test_arena_scatter.gd
extends GutTest
## Pure-logic tests for seeded obstacle placement.

const SEED := 12345
const COUNT := 40
const EXTENT := 90.0
const CLEAR := 12.0
const MIN_SEP := 6.0

func _positions() -> Array:
	return ArenaScatter.compute_positions(SEED, COUNT, EXTENT, CLEAR, MIN_SEP)

func test_deterministic_for_same_seed() -> void:
	var a := _positions()
	var b := ArenaScatter.compute_positions(SEED, COUNT, EXTENT, CLEAR, MIN_SEP)
	assert_eq(a.size(), b.size(), "same seed → same count")
	for i in a.size():
		assert_true(a[i].is_equal_approx(b[i]), "same seed → identical position %d" % i)

func test_count_is_capped() -> void:
	assert_true(_positions().size() <= COUNT, "never returns more than requested count")

func test_all_within_extent_and_on_xz() -> void:
	for p in _positions():
		assert_almost_eq(p.y, 0.0, 0.001, "positions live on the XZ plane")
		assert_true(abs(p.x) <= EXTENT, "x within extent")
		assert_true(abs(p.z) <= EXTENT, "z within extent")

func test_center_kept_clear() -> void:
	for p in _positions():
		assert_true(p.length() >= CLEAR, "no obstacle inside the spawn clear radius")

func test_min_separation_respected() -> void:
	var ps := _positions()
	for i in ps.size():
		for j in range(i + 1, ps.size()):
			assert_true(ps[i].distance_to(ps[j]) >= MIN_SEP - 0.001,
				"props must be at least min_separation apart")

func test_overdense_request_terminates_and_caps() -> void:
	# Impossible to fit 1000 props with this separation — must return fewer, not hang.
	var ps := ArenaScatter.compute_positions(SEED, 1000, 20.0, 5.0, 8.0)
	assert_true(ps.size() < 1000, "over-dense request places fewer than requested")
	assert_true(ps.size() > 0, "still places some")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot --headless --import && godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://test/test_arena_scatter.gd -gexit`
Expected: FAIL — `ArenaScatter` does not exist.

- [ ] **Step 3: Write the implementation**

```gdscript
# arena/arena_scatter.gd
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `godot --headless --import && godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://test/test_arena_scatter.gd -gexit`
Expected: PASS (6 tests).

- [ ] **Step 5: Docs + commit**

Create `docs/notes/arena-scatter.md`; add its INDEX line.

```bash
git add arena/arena_scatter.gd test/test_arena_scatter.gd docs/notes/arena-scatter.md docs/notes/INDEX.md
git commit -m "feat(arena): add seeded obstacle scatter placement logic"
```

---

### Task 4: Realistic PBR ground + HDRI sky (visual)

**Files:**
- Create: `art/textures/` (grass albedo/normal/roughness), `art/hdri/` (panorama)
- Modify: `arena/arena_3d.tscn` (ground material → PBR; environment background → Sky)
- Create: `docs/notes/arena-map.md` (+ INDEX line); append entries to `docs/notes/asset-licenses.md`
- Test: `test/test_arena_3d_map.gd` (ground + sky portion)

**Interfaces:**
- Consumes: nothing.
- Produces: an `arena_3d.tscn` whose ground uses a textured `StandardMaterial3D` (albedo texture present) and whose `WorldEnvironment` uses `background_mode = 2` (Sky).

- [ ] **Step 1: Download CC0 assets (grass texture + HDRI sky)**

Use the Poly Haven public API (CC0, no auth). List candidates, then fetch file URLs. Verify the chosen id exists before downloading (do not assume slugs):

```bash
mkdir -p art/textures art/hdri
# Browse grass textures, pick an id (e.g. inspect the JSON keys):
curl -s "https://api.polyhaven.com/assets?type=textures&categories=grass" | head -c 2000
# For the chosen <TEX_ID>, get file URLs (Diffuse / nor_gl / Rough at 2k jpg):
curl -s "https://api.polyhaven.com/files/<TEX_ID>" > /tmp/tex.json
# Download the three maps (paths shown by the JSON: .Diffuse["2k"]["jpg"]["url"], etc.)
curl -sL "<diffuse_url>"  -o art/textures/grass_diff_2k.jpg
curl -sL "<normal_url>"   -o art/textures/grass_nor_2k.jpg
curl -sL "<rough_url>"    -o art/textures/grass_rough_2k.jpg
# Browse skies / mountain HDRIs, pick an id, download a 2k .hdr:
curl -s "https://api.polyhaven.com/assets?type=hdris&categories=mountain" | head -c 2000
curl -s "https://api.polyhaven.com/files/<HDRI_ID>" > /tmp/hdri.json
curl -sL "<hdri_2k_hdr_url>" -o art/hdri/sky_mountain_2k.hdr
```

If the API is unreachable, fall back to ambientCG (`https://ambientcg.com/`) grass + a Poly Haven mirror; any CC0 grass + sky is acceptable. Record exact source URLs in `docs/notes/asset-licenses.md`.

- [ ] **Step 2: Import + write the failing test**

```gdscript
# test/test_arena_3d_map.gd
extends GutTest
## Structural tests for the realistic arena map (ground material + sky + props root).

var Scene: PackedScene = null

func before_all() -> void:
	Scene = load("res://arena/arena_3d.tscn")

func _instantiate() -> Node:
	return Scene.instantiate()

func test_scene_loads() -> void:
	assert_not_null(Scene, "arena_3d.tscn must load")

func test_ground_has_albedo_texture() -> void:
	var root := _instantiate()
	var mesh: MeshInstance3D = root.get_node("Ground/GroundMesh")
	var mat: StandardMaterial3D = mesh.get_surface_override_material(0)
	assert_not_null(mat, "ground must have a material")
	assert_not_null(mat.albedo_texture, "ground material must use a PBR albedo texture")
	root.free()

func test_environment_uses_sky_background() -> void:
	var root := _instantiate()
	var we: WorldEnvironment = root.get_node("WorldEnvironment")
	# Environment.BG_SKY == 2
	assert_eq(we.environment.background_mode, 2,
		"WorldEnvironment must use Sky background, not solid color")
	root.free()
```

- [ ] **Step 3: Run import + test to verify it fails**

Run: `godot --headless --import && godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://test/test_arena_3d_map.gd -gexit`
Expected: FAIL — ground material has no albedo texture; background_mode is `1`.

- [ ] **Step 4: Edit `arena_3d.tscn` — ground material + sky**

Replace the ground `StandardMaterial3D_ground` sub-resource so it loads the textures, and replace the environment background with a Sky. Concretely:
- Add `ext_resource` entries for the three texture files and the HDRI.
- Set on the ground material: `albedo_texture = ExtResource(grass_diff)`, `normal_enabled = true`, `normal_texture = ExtResource(grass_nor)`, `roughness_texture = ExtResource(grass_rough)`, `uv1_scale = Vector3(40, 40, 40)` (tiles grass across the 200×200 plane), keep `roughness = 1.0`.
- Add a `PanoramaSkyMaterial` (with `panorama = ExtResource(hdri)`) and a `Sky` sub-resource referencing it.
- On `Environment_main`: set `background_mode = 2`, `sky = SubResource(Sky_...)`, `ambient_light_source = 3` (Sky), and remove `background_color`.
- Re-aim `DirectionalLight3D` to roughly match the HDRI sun (tune later in playtest).

(Edit the `.tscn` as text following the existing structure in `arena/arena_3d.tscn`.)

- [ ] **Step 5: Run import + test to verify it passes**

Run: `godot --headless --import && godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://test/test_arena_3d_map.gd -gexit`
Expected: PASS (3 tests so far; more added in Tasks 5–6).

- [ ] **Step 6: Docs + commit**

Create `docs/notes/arena-map.md`; append the grass + HDRI sources to `docs/notes/asset-licenses.md`.

```bash
git add art/textures art/hdri arena/arena_3d.tscn test/test_arena_3d_map.gd docs/notes/
git commit -m "feat(arena): realistic PBR grass ground + HDRI mountain sky"
```

---

### Task 5: Arena border walls

**Files:**
- Modify: `arena/arena_3d.tscn` (add a `Borders` node with four wall `StaticBody3D`s)
- Modify: `test/test_arena_3d_map.gd` (add border assertions)

**Interfaces:**
- Consumes: the Obstacles layer (16) from Task 1.
- Produces: a `Borders` node under the arena root containing 4 `StaticBody3D` walls on layer 16, positioned just inside the ±100 plane edge, enclosing the play area.

- [ ] **Step 1: Add the failing test (append to `test/test_arena_3d_map.gd`)**

```gdscript
const OBSTACLE_BIT := 16

func test_has_four_border_walls_on_obstacle_layer() -> void:
	var root := _instantiate()
	var borders := root.get_node_or_null("Borders")
	assert_not_null(borders, "arena must have a Borders node")
	var walls := 0
	for child in borders.get_children():
		if child is StaticBody3D and ((child as StaticBody3D).collision_layer & OBSTACLE_BIT) == OBSTACLE_BIT:
			walls += 1
	assert_eq(walls, 4, "must have 4 border walls on the Obstacles layer")
	root.free()
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot --headless --import && godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://test/test_arena_3d_map.gd::test_has_four_border_walls_on_obstacle_layer -gexit`
Expected: FAIL — no `Borders` node.

- [ ] **Step 3: Add the walls to `arena_3d.tscn`**

Add a `Borders` `Node3D` under the root with four `StaticBody3D` children (`collision_layer = 16, collision_mask = 0`), each with a `CollisionShape3D` using a thin tall `BoxShape3D`. Place them at the four edges of the playfield (e.g. extent ±95, wall thickness ~2, height ~10): North/South walls span X at `z = ±95`, East/West walls span Z at `x = ±95`. Leave the walls invisible (no mesh) — the HDRI horizon reads as the visual boundary. Example for one wall sub-resource + node:

```
[sub_resource type="BoxShape3D" id="BoxShape3D_wall_ns"]
size = Vector3(200, 10, 2)

[node name="Borders" type="Node3D" parent="."]

[node name="WallNorth" type="StaticBody3D" parent="Borders"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 5, -95)
collision_layer = 16
collision_mask = 0

[node name="CollisionShape3D" type="CollisionShape3D" parent="Borders/WallNorth"]
shape = SubResource("BoxShape3D_wall_ns")
```

Repeat for `WallSouth` (z=+95), `WallEast` (x=+95, size `Vector3(2,10,200)`), `WallWest` (x=−95).

- [ ] **Step 4: Run test to verify it passes**

Run: `godot --headless --import && godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://test/test_arena_3d_map.gd -gexit`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add arena/arena_3d.tscn test/test_arena_3d_map.gd
git commit -m "feat(arena): add walled arena borders on Obstacles layer"
```

---

### Task 6: Water body (decorative + blocking)

**Files:**
- Create: `obstacles/water_3d.gd`, `obstacles/water_3d.tscn`
- Modify: `arena/arena_3d.tscn` (place 1–2 water bodies)
- Create: `docs/notes/water-3d.md` (+ INDEX line)
- Test: `test/test_water_3d.gd`

**Interfaces:**
- Consumes: Obstacles layer (16); `NavigationObstacle3D` avoidance.
- Produces: `class_name Water3D extends StaticBody3D` — a flat water mesh (visual) + ring/disc `CollisionShape3D` on layer 16 + `NavigationObstacle3D` so player/enemies path around the pond.

- [ ] **Step 1: Write the failing test**

```gdscript
# test/test_water_3d.gd
extends GutTest
## Water body must be visible AND block movement (Obstacles layer + nav obstacle).

const OBSTACLE_BIT := 16
var Scene: PackedScene = null

func before_all() -> void:
	Scene = load("res://obstacles/water_3d.tscn")

func test_scene_loads() -> void:
	assert_not_null(Scene, "water_3d.tscn must load")

func test_is_blocking_and_has_visual_and_nav() -> void:
	var w: Water3D = Scene.instantiate()
	assert_true(w is StaticBody3D, "Water3D is a StaticBody3D")
	assert_true((w.collision_layer & OBSTACLE_BIT) == OBSTACLE_BIT, "water blocks on layer 16")
	assert_not_null(w.get_node_or_null("MeshInstance3D"), "water has a visible surface")
	assert_not_null(w.get_node_or_null("CollisionShape3D"), "water has blocking collision")
	assert_not_null(w.get_node_or_null("NavigationObstacle3D"), "water has a nav obstacle")
	w.free()
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot --headless --import && godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://test/test_water_3d.gd -gexit`
Expected: FAIL — water scene/script missing.

- [ ] **Step 3: Create script + scene**

```gdscript
# obstacles/water_3d.gd
# See docs/notes/water-3d.md
class_name Water3D extends StaticBody3D
## Decorative water pond that also blocks movement: a flat surface mesh plus a
## cylindrical collision footprint on the Obstacles layer (16) and a matching
## NavigationObstacle3D so the swarm routes around it. No fluid simulation.
```

Create `obstacles/water_3d.tscn`: `StaticBody3D` (`collision_layer = 16, collision_mask = 0`, script attached) with:
- `MeshInstance3D` using a `PlaneMesh` (e.g. `size = Vector2(24, 24)`) + a translucent blue water `StandardMaterial3D` (`albedo_color = Color(0.15, 0.35, 0.5, 0.75)`, `transparency = 1`, low `roughness`, `metallic ≈ 0.2`). A water shader can be swapped in later; a translucent material is sufficient for v1.
- `CollisionShape3D` with a `CylinderShape3D` (`radius = 12, height = 2`) so bodies can't walk into the pond.
- `NavigationObstacle3D` with `radius = 12`.

- [ ] **Step 4: Place water in the arena + extend the test**

Add 1–2 `Water3D` instances to `arena_3d.tscn` (e.g. at `(40, 0, -30)` and `(-50, 0, 45)`), clear of the center spawn. Append to `test/test_arena_3d_map.gd`:

```gdscript
func test_arena_contains_water() -> void:
	var root := _instantiate()
	var found := false
	for child in root.get_children():
		if child is Water3D:
			found = true
			break
	assert_true(found, "arena must contain at least one Water3D body")
	root.free()
```

- [ ] **Step 5: Run import + tests to verify they pass**

Run: `godot --headless --import && godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://test/test_water_3d.gd -gexit`
then `... -gtest=res://test/test_arena_3d_map.gd -gexit`
Expected: PASS.

- [ ] **Step 6: Docs + commit**

Create `docs/notes/water-3d.md`; add INDEX line.

```bash
git add obstacles/water_3d.gd obstacles/water_3d.tscn arena/arena_3d.tscn test/test_water_3d.gd test/test_arena_3d_map.gd docs/notes/
git commit -m "feat(arena): add decorative + blocking water bodies"
```

---

### Task 7: Enemy RVO avoidance

**Files:**
- Modify: `enemies/enemy_3d.tscn` (add `NavigationAgent3D` child)
- Modify: `enemies/enemy_3d.gd` (route movement through avoidance; keep `velocity` synchronous)
- Modify: `docs/notes/enemy-3d.md`
- Test: `test/test_enemy_3d_avoidance.gd`

**Interfaces:**
- Consumes: `NavigationObstacle3D`s on `Obstacle3D` / `Water3D` (Tasks 2, 6).
- Produces: enemies that locally avoid props and each other. **Critical invariant:** `_physics_process` still assigns `self.velocity` synchronously (so `test_enemy_3d.gd:89-99` keep passing); the avoidance callback only performs the actual `move_and_slide()`.

- [ ] **Step 1: Add `NavigationAgent3D` to `enemy_3d.tscn`**

Add as a child of the `Enemy3D` root:

```
[node name="NavigationAgent3D" type="NavigationAgent3D" parent="."]
avoidance_enabled = true
radius = 0.6
max_speed = 12.0
```

- [ ] **Step 2: Write the failing test**

```gdscript
# test/test_enemy_3d_avoidance.gd
extends GutTest
## Verifies enemies are wired for RVO avoidance and that velocity is still set
## synchronously in _physics_process (so existing velocity assertions hold).

var Scene: PackedScene = null

class StubTarget extends Node3D:
	pass

func before_all() -> void:
	Scene = load("res://enemies/enemy_3d.tscn")

func _make_enemy() -> Enemy3D:
	var e: Enemy3D = add_child_autofree(Scene.instantiate())
	var d := EnemyData.new()
	d.max_hp = 30.0
	d.move_speed = 5.0
	d.contact_damage = 4.0
	var tgt: StubTarget = add_child_autofree(StubTarget.new())
	tgt.global_position = Vector3(10, 0, 0)
	e.global_position = Vector3.ZERO
	e.setup(d, tgt)
	return e

func test_enemy_has_avoidance_agent() -> void:
	var e := _make_enemy()
	var agent := e.get_node_or_null("NavigationAgent3D")
	assert_not_null(agent, "enemy must have a NavigationAgent3D")
	assert_true((agent as NavigationAgent3D).avoidance_enabled, "avoidance must be enabled")

func test_velocity_set_synchronously_in_physics_process() -> void:
	var e := _make_enemy()
	e._physics_process(0.016)
	assert_true(e.velocity.x > 0.0,
		"velocity must be set synchronously toward target (+X), not deferred to callback")
	assert_almost_eq(e.velocity.y, 0.0, 0.001, "velocity stays on XZ plane")

func test_velocity_computed_callback_assigns_velocity() -> void:
	var e := _make_enemy()
	e._on_velocity_computed(Vector3(3.0, 0.0, 0.0))
	assert_almost_eq(e.velocity.x, 3.0, 0.001, "callback applies the safe velocity")
```

- [ ] **Step 3: Run test to verify it fails**

Run: `godot --headless --import && godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://test/test_enemy_3d_avoidance.gd -gexit`
Expected: FAIL — `_on_velocity_computed` does not exist (and agent may be absent before Step 1 import).

- [ ] **Step 4: Refactor `enemy_3d.gd`**

Add the agent reference + connect the signal, and route movement through `_apply_movement`. Replace the movement section of `_physics_process` and add the two helpers. **Keep every existing line that sets `velocity` synchronously** — only the single `move_and_slide()` calls move into `_apply_movement`.

```gdscript
# Add near the other @onready vars:
@onready var _agent: NavigationAgent3D = $NavigationAgent3D

func _ready() -> void:
	if _agent:
		_agent.velocity_computed.connect(_on_velocity_computed)

# In _physics_process, the charm branch becomes:
#   if _charm_timer > 0.0:
#       velocity = Vector3.ZERO
#       _apply_movement(dt)
#       return
# ...and the main branch keeps `velocity = steer_velocity(...)` then calls
# `_apply_movement(dt)` IN PLACE OF the old `move_and_slide()`. The model
# rotation / _play_anim / _apply_bob / contact-damage blocks stay exactly as they
# are (they read `velocity`, which is already set).

## Route this frame's desired velocity through RVO avoidance when available; the
## actual move_and_slide() then happens in _on_velocity_computed. Falls back to a
## direct move when there is no agent or we are outside the scene tree (headless
## unit tests), preserving the original synchronous behavior.
func _apply_movement(_dt: float) -> void:
	if _agent and _agent.avoidance_enabled and is_inside_tree():
		_agent.set_velocity(velocity)
	else:
		move_and_slide()

## Avoidance result: the navigation server's collision-free velocity. Apply it and
## perform the real move. velocity_computed fires during the physics step.
func _on_velocity_computed(safe_velocity: Vector3) -> void:
	velocity = safe_velocity
	move_and_slide()
```

Note for the implementer: do **not** remove the synchronous `velocity = ...` assignments in `_physics_process`; the existing suite (`test_enemy_3d.gd`) reads `velocity` right after calling `_physics_process`, and `test_velocity_set_synchronously_in_physics_process` above locks this in.

- [ ] **Step 5: Run the avoidance test + the full enemy suites**

Run: `godot --headless --import && godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://test/test_enemy_3d_avoidance.gd -gexit`
then `... -gtest=res://test/test_enemy_3d.gd -gexit` and `... -gtest=res://test/test_enemy_3d_bugfix.gd -gexit`
Expected: ALL PASS (new avoidance tests green; existing enemy tests still green).

- [ ] **Step 6: Docs + commit**

Update `docs/notes/enemy-3d.md` (avoidance wiring + synchronous-velocity invariant).

```bash
git add enemies/enemy_3d.tscn enemies/enemy_3d.gd test/test_enemy_3d_avoidance.gd docs/notes/enemy-3d.md
git commit -m "feat(enemy): RVO avoidance routes swarm around obstacles"
```

---

### Task 8: Wire scatter into the arena + source props + full verification

**Files:**
- Modify: `arena/arena_3d.tscn` (attach `arena_scatter.gd` via a small spawner node/script that instantiates obstacles at `_ready`)
- Create: `art/models/nature/` (tree + rock CC0 models) OR a stylized fallback
- Modify: `docs/notes/arena-map.md`, `docs/notes/asset-licenses.md`, `HANDOFF.md`
- Test: `test/test_arena_3d_map.gd` (scatter-spawns-obstacles assertion)

**Interfaces:**
- Consumes: `ArenaScatter.compute_positions` (Task 3), `Obstacle3D.configure` (Task 2).
- Produces: a running arena that spawns collidable trees/rocks at play start.

- [ ] **Step 1: Source rock + tree models (CC0)**

```bash
mkdir -p art/models/nature
# Rocks/boulders from Poly Haven (good realistic CC0 coverage):
curl -s "https://api.polyhaven.com/assets?type=models&categories=rock" | head -c 2000
curl -s "https://api.polyhaven.com/files/<ROCK_ID>" > /tmp/rock.json
# download the gltf at 1k into art/models/nature/<rock>/ (gltf + bin + textures)
```

For **trees**: query `https://api.polyhaven.com/assets?type=models&categories=plants` (and search the asset list). **If no realistic CC0 tree exists**, fall back to a stylized CC0 tree (Kenney Nature Kit / Quaternius `.glb`) — this is the pre-approved fallback from the spec; note exactly what was used in `docs/notes/asset-licenses.md`. Do not block the task hunting for a perfect realistic tree.

- [ ] **Step 2: Add a scatter spawner to `arena_3d.tscn`**

Attach a script (extend `arena/arena_scatter.gd` with an instance-side `_ready`, or add a tiny `ObstacleSpawner` node whose script calls the static helper). The spawner, at `_ready`:
1. loads `obstacle_3d.tscn` and the prop meshes (rock/tree),
2. calls `ArenaScatter.compute_positions(seed, count, extent, clear_radius, min_separation)` with exported, tunable params (`@export var obstacle_count := 35`, `rng_seed := 1`, `extent := 88.0`, `clear_radius := 14.0`, `min_separation := 7.0`),
3. for each position, instantiates `Obstacle3D`, calls `configure(mesh, footprint, height)` picking a prop type per index, sets its `position`, and adds it under an `Obstacles` node.

Guard asset loads: if a mesh fails to load, fall back to a `BoxMesh`/`CylinderMesh` placeholder and `push_warning(...)` — never crash.

- [ ] **Step 3: Add the failing integration test (append to `test/test_arena_3d_map.gd`)**

```gdscript
func test_scatter_spawns_obstacles_at_runtime() -> void:
	var root: Node = autofree(_instantiate())
	add_child(root)   # entering the tree runs the spawner's _ready
	await get_tree().process_frame
	var obstacles := root.get_node_or_null("Obstacles")
	assert_not_null(obstacles, "arena must have an Obstacles container")
	var count := 0
	for child in obstacles.get_children():
		if child is Obstacle3D:
			count += 1
	assert_true(count > 0, "scatter must spawn at least one Obstacle3D at runtime")
```

- [ ] **Step 4: Run import + test to verify it fails, then passes after Step 2 wiring**

Run: `godot --headless --import && godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://test/test_arena_3d_map.gd::test_scatter_spawns_obstacles_at_runtime -gexit`
Expected: FAIL before wiring (no `Obstacles` container) → PASS after Step 2 is in place.

- [ ] **Step 5: Run the FULL suite — confirm no regression**

Run: `godot --headless --import && godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://test -gexit`
Expected: ALL green; total test count = 879 + the new tests (no skips — confirm the count rose by the number of new test functions; a flat count means a file was silently skipped, likely an `assert_le`/`assert_ge` slip).

- [ ] **Step 6: Update HANDOFF + asset licenses; commit**

Update `HANDOFF.md` (new arena map feature; tunable scatter params; avoidance) and finalize `docs/notes/asset-licenses.md` (every grass/HDRI/rock/tree source + CC0 confirmation).

```bash
git add arena/arena_3d.tscn art/models test/test_arena_3d_map.gd docs/notes/ HANDOFF.md
git commit -m "feat(arena): scatter collidable nature props into the arena"
```

- [ ] **Step 7: Manual playtest (user-run — visuals can't be verified headless)**

Run `godot --path ~/friends-swarm`, pick a character, and confirm: grass + sky render; trees/rocks/water look right; the player is blocked by props and walls and cannot leave the arena; enemies flow around obstacles without permanently bunching; skills still pass over props; framerate holds with a large wave. Tune `obstacle_count` / `clear_radius` / `min_separation` / sky sun angle to taste.

---

## Self-Review

**Spec coverage:**
- Realistic PBR ground → Task 4. HDRI sky + distant mountains → Task 4. Trees/rocks → Tasks 2+8. Water (decorative + blocking) → Task 6. Border walls → Task 5. Obstacles block player+enemy → Task 1 (layers) + Tasks 2/5/6 (props on layer 16). Enemies route around (RVO) → Task 7. Seeded/tunable scatter, center kept clear → Task 3 + Task 8. Skills unaffected → Task 1 constraint (skills never mask 16). Tests stay green → every task + Task 8 Step 5. Asset licenses CC0 → Tasks 4/8 docs. Trees-risk fallback → Task 8 Step 1. All spec sections map to a task.

**Placeholder scan:** Asset URLs are intentionally fetched-then-filled via the Poly Haven API (the slugs are genuinely unknown until queried — the commands show exactly how to resolve them); this is a real procedure, not a TODO. No "add error handling"/"write tests for the above" placeholders — every code/test step shows code.

**Type consistency:** `Obstacle3D.configure(mesh, footprint_radius, height)` defined in Task 2 and called identically in Task 8. `ArenaScatter.compute_positions(rng_seed, count, extent, clear_radius, min_separation, attempts_per=30)` defined in Task 3, called with matching arg order in Task 8. `Enemy3D._on_velocity_computed(safe_velocity)` defined and tested with the same name in Task 7. `Water3D` / `Obstacle3D` `class_name`s consistent across tasks. Obstacles bit `16` consistent everywhere.
