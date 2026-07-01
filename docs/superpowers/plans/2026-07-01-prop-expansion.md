# Prop Expansion (Final City Arena) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create 13 visual-only Godot 4.7 `.tscn` prop scenes (nature + urban/sci-fi + arena decor) and a GUT test file that validates all of them.

**Architecture:** Each prop is a standalone `.tscn` under `obstacles/` — root `Node3D` (PascalCase), `MeshInstance3D` children with primitive mesh sub-resources (`BoxMesh`/`CylinderMesh`/`SphereMesh`/`PrismMesh`) and `StandardMaterial3D` sub-resources. Brazier and Fountain also include an `OmniLight3D` child. The test file extends `GutTest` and runs structural assertions (load, Node3D root, ≥1 MeshInstance3D; lights where required).

**Tech Stack:** Godot 4.7, GUT (Godot Unit Testing), `.tscn` text format v3.

## Global Constraints

- All `.tscn` files: `format=3`, `uid="uid://..."` (unique per file)
- Root node: `Node3D`, name PascalCase matching file stem (e.g. `PropRock3D`)
- Children: `MeshInstance3D` with `surface_material_override/0 = SubResource(...)` — NO collision shapes, NO scripts
- Lights ONLY in `prop_brazier_3d.tscn` (OmniLight3D, warm orange) and `prop_fountain_3d.tscn` (OmniLight3D, cyan)
- No co-planar decorative layers — offset ≥0.02u or scale overlay slightly larger
- No cross-sections thinner than 0.1u
- Emissive: `emission_enabled = true`, `emission = Color(...)`, `emission_energy_multiplier = N`
- Palette: cyan `Color(0.3,0.8,1.0)`, gold `Color(1.0,0.8,0.2)`, magenta `Color(1.0,0.2,0.6)`, flame `Color(1.0,0.5,0.1)`
- Test file: `test/test_prop_expansion.gd`, extends `GutTest`, guards every scene with null-check + early return
- Baseline: 1040/1040 tests passing — add on top, no regressions

---

### Task 1: Nature Props — Rock, Tree, Bush, Tall Grass, Mushroom

**Files:**
- Create: `obstacles/prop_rock_3d.tscn`
- Create: `obstacles/prop_tree_3d.tscn`
- Create: `obstacles/prop_bush_3d.tscn`
- Create: `obstacles/prop_tall_grass_3d.tscn`
- Create: `obstacles/prop_mushroom_3d.tscn`

**Interfaces:**
- Produces: 5 loadable `PackedScene`s, each with a `Node3D` root and ≥1 `MeshInstance3D`

- [ ] **Step 1: Write prop_rock_3d.tscn**

Boulder cluster: 3 grey rocks (2x SphereMesh, 1x BoxMesh) varied sizes, slightly rotated, ~1.4u wide total. All offset upward so they sit on the ground (y ≥ radius). Rocks slightly overlap but no co-planar faces.

```
[gd_scene load_steps=4 format=3 uid="uid://proprock3d00001"]

[sub_resource type="StandardMaterial3D" id="mat_stone"]
albedo_color = Color(0.55, 0.52, 0.5, 1)
roughness = 0.9

[sub_resource type="SphereMesh" id="mesh_rock_large"]
radius = 0.5
height = 0.9

[sub_resource type="SphereMesh" id="mesh_rock_mid"]
radius = 0.32
height = 0.6

[sub_resource type="BoxMesh" id="mesh_rock_flat"]
size = Vector3(0.55, 0.28, 0.45)

[node name="PropRock3D" type="Node3D"]

[node name="RockA" type="MeshInstance3D" parent="."]
position = Vector3(0, 0.45, 0)
rotation = Vector3(0, 0.4, 0)
mesh = SubResource("mesh_rock_large")
surface_material_override/0 = SubResource("mat_stone")

[node name="RockB" type="MeshInstance3D" parent="."]
position = Vector3(0.52, 0.28, 0.15)
rotation = Vector3(0.15, 1.1, 0)
mesh = SubResource("mesh_rock_mid")
surface_material_override/0 = SubResource("mat_stone")

[node name="RockC" type="MeshInstance3D" parent="."]
position = Vector3(-0.42, 0.14, 0.22)
rotation = Vector3(0, -0.7, 0.15)
mesh = SubResource("mesh_rock_flat")
surface_material_override/0 = SubResource("mat_stone")
```

- [ ] **Step 2: Write prop_tree_3d.tscn**

Stylized tree ~4u tall. Brown `CylinderMesh` trunk (slightly tapered). Two overlapping green `SphereMesh` canopy blobs at different heights/sizes — offset vertically so upper blob is not co-planar with lower. Canopy blobs slightly larger than 0.1u cross-section.

```
[gd_scene load_steps=5 format=3 uid="uid://proptree3d000001"]

[sub_resource type="StandardMaterial3D" id="mat_trunk"]
albedo_color = Color(0.38, 0.22, 0.1, 1)
roughness = 0.9

[sub_resource type="StandardMaterial3D" id="mat_canopy"]
albedo_color = Color(0.2, 0.62, 0.18, 1)
roughness = 0.85

[sub_resource type="CylinderMesh" id="mesh_trunk"]
top_radius = 0.15
bottom_radius = 0.22
height = 2.4

[sub_resource type="SphereMesh" id="mesh_canopy_low"]
radius = 0.85
height = 1.6

[sub_resource type="SphereMesh" id="mesh_canopy_top"]
radius = 0.65
height = 1.2

[node name="PropTree3D" type="Node3D"]

[node name="Trunk" type="MeshInstance3D" parent="."]
position = Vector3(0, 1.2, 0)
mesh = SubResource("mesh_trunk")
surface_material_override/0 = SubResource("mat_trunk")

[node name="CanopyLow" type="MeshInstance3D" parent="."]
position = Vector3(0, 2.8, 0)
mesh = SubResource("mesh_canopy_low")
surface_material_override/0 = SubResource("mat_canopy")

[node name="CanopyTop" type="MeshInstance3D" parent="."]
position = Vector3(0.2, 3.7, -0.1)
mesh = SubResource("mesh_canopy_top")
surface_material_override/0 = SubResource("mat_canopy")
```

- [ ] **Step 3: Write prop_bush_3d.tscn**

Round green shrub ~1u. 3 overlapping SphereMesh blobs — different positions and slight rotations. The blobs must not be at identical Y (co-planar risk). Center blob largest, side blobs slightly smaller.

```
[gd_scene load_steps=3 format=3 uid="uid://propbush3d000001"]

[sub_resource type="StandardMaterial3D" id="mat_bush"]
albedo_color = Color(0.22, 0.58, 0.18, 1)
roughness = 0.85

[sub_resource type="SphereMesh" id="mesh_blob_large"]
radius = 0.45
height = 0.85

[sub_resource type="SphereMesh" id="mesh_blob_small"]
radius = 0.32
height = 0.6

[node name="PropBush3D" type="Node3D"]

[node name="BlobCenter" type="MeshInstance3D" parent="."]
position = Vector3(0, 0.42, 0)
mesh = SubResource("mesh_blob_large")
surface_material_override/0 = SubResource("mat_bush")

[node name="BlobLeft" type="MeshInstance3D" parent="."]
position = Vector3(-0.35, 0.3, 0.1)
mesh = SubResource("mesh_blob_small")
surface_material_override/0 = SubResource("mat_bush")

[node name="BlobRight" type="MeshInstance3D" parent="."]
position = Vector3(0.35, 0.28, -0.1)
mesh = SubResource("mesh_blob_small")
surface_material_override/0 = SubResource("mat_bush")
```

- [ ] **Step 4: Write prop_tall_grass_3d.tscn**

Clump of grass blades ~0.8u tall. 5 thin upright green blades using `BoxMesh` (width/depth ≥ 0.1u, height ~0.75u), fanned out with different X-rotations so they splay outward. No blade shares the same position.

```
[gd_scene load_steps=3 format=3 uid="uid://proptallgrass3d001"]

[sub_resource type="StandardMaterial3D" id="mat_grass"]
albedo_color = Color(0.28, 0.68, 0.22, 1)
roughness = 0.85

[sub_resource type="BoxMesh" id="mesh_blade"]
size = Vector3(0.1, 0.75, 0.1)

[sub_resource type="BoxMesh" id="mesh_blade_short"]
size = Vector3(0.1, 0.55, 0.1)

[node name="PropTallGrass3D" type="Node3D"]

[node name="BladeA" type="MeshInstance3D" parent="."]
position = Vector3(0, 0.375, 0)
rotation = Vector3(0.0, 0.0, 0.0)
mesh = SubResource("mesh_blade")
surface_material_override/0 = SubResource("mat_grass")

[node name="BladeB" type="MeshInstance3D" parent="."]
position = Vector3(0.15, 0.35, 0.1)
rotation = Vector3(0.25, 0.8, 0.1)
mesh = SubResource("mesh_blade")
surface_material_override/0 = SubResource("mat_grass")

[node name="BladeC" type="MeshInstance3D" parent="."]
position = Vector3(-0.15, 0.33, -0.1)
rotation = Vector3(-0.2, -0.6, -0.12)
mesh = SubResource("mesh_blade")
surface_material_override/0 = SubResource("mat_grass")

[node name="BladeD" type="MeshInstance3D" parent="."]
position = Vector3(0.1, 0.28, -0.15)
rotation = Vector3(0.15, 1.4, 0.2)
mesh = SubResource("mesh_blade_short")
surface_material_override/0 = SubResource("mat_grass")

[node name="BladeE" type="MeshInstance3D" parent="."]
position = Vector3(-0.12, 0.275, 0.18)
rotation = Vector3(-0.3, 2.2, -0.15)
mesh = SubResource("mesh_blade_short")
surface_material_override/0 = SubResource("mat_grass")
```

- [ ] **Step 5: Write prop_mushroom_3d.tscn**

Mushroom cluster (Temtem vibe). 3 mushrooms: off-white `CylinderMesh` stems, squashed red/purple `SphereMesh` caps. Each mushroom has its own stem + cap — use separate sub-resources per size to avoid co-planar issue. Caps are at a slightly different y than the stem top.

```
[gd_scene load_steps=7 format=3 uid="uid://propmushroom3d001"]

[sub_resource type="StandardMaterial3D" id="mat_stem"]
albedo_color = Color(0.9, 0.88, 0.82, 1)
roughness = 0.8

[sub_resource type="StandardMaterial3D" id="mat_cap_red"]
albedo_color = Color(0.85, 0.15, 0.12, 1)
roughness = 0.6

[sub_resource type="StandardMaterial3D" id="mat_cap_purple"]
albedo_color = Color(0.55, 0.12, 0.78, 1)
roughness = 0.6

[sub_resource type="CylinderMesh" id="mesh_stem_tall"]
top_radius = 0.1
bottom_radius = 0.13
height = 0.55

[sub_resource type="CylinderMesh" id="mesh_stem_short"]
top_radius = 0.08
bottom_radius = 0.1
height = 0.35

[sub_resource type="SphereMesh" id="mesh_cap_large"]
radius = 0.28
height = 0.22

[sub_resource type="SphereMesh" id="mesh_cap_small"]
radius = 0.18
height = 0.15

[node name="PropMushroom3D" type="Node3D"]

[node name="StemA" type="MeshInstance3D" parent="."]
position = Vector3(0, 0.275, 0)
mesh = SubResource("mesh_stem_tall")
surface_material_override/0 = SubResource("mat_stem")

[node name="CapA" type="MeshInstance3D" parent="."]
position = Vector3(0, 0.58, 0)
mesh = SubResource("mesh_cap_large")
surface_material_override/0 = SubResource("mat_cap_red")

[node name="StemB" type="MeshInstance3D" parent="."]
position = Vector3(0.38, 0.175, 0.15)
rotation = Vector3(0, 0, 0.12)
mesh = SubResource("mesh_stem_short")
surface_material_override/0 = SubResource("mat_stem")

[node name="CapB" type="MeshInstance3D" parent="."]
position = Vector3(0.38, 0.37, 0.15)
mesh = SubResource("mesh_cap_small")
surface_material_override/0 = SubResource("mat_cap_purple")

[node name="StemC" type="MeshInstance3D" parent="."]
position = Vector3(-0.3, 0.175, -0.2)
rotation = Vector3(0, 0, -0.1)
mesh = SubResource("mesh_stem_short")
surface_material_override/0 = SubResource("mat_stem")

[node name="CapC" type="MeshInstance3D" parent="."]
position = Vector3(-0.3, 0.37, -0.2)
mesh = SubResource("mesh_cap_small")
surface_material_override/0 = SubResource("mat_cap_red")
```

---

### Task 2: Urban / Sci-Fi Props — Cone, Dumpster, Holo Sign, Generator, Concrete Barrier

**Files:**
- Create: `obstacles/prop_cone_3d.tscn`
- Create: `obstacles/prop_dumpster_3d.tscn`
- Create: `obstacles/prop_holo_sign_3d.tscn`
- Create: `obstacles/prop_generator_3d.tscn`
- Create: `obstacles/prop_concrete_barrier_3d.tscn`

**Interfaces:**
- Produces: 5 loadable `PackedScene`s, each with a `Node3D` root and ≥1 `MeshInstance3D`. `prop_holo_sign_3d` and `prop_generator_3d` have emissive materials.

- [ ] **Step 1: Write prop_cone_3d.tscn**

Traffic safety cone ~0.8u tall. Orange `CylinderMesh` cone (top_radius small ~0.05, bottom_radius ~0.3, height ~0.75) on a flat dark-grey base box. White band: a flat `CylinderMesh` ring around the cone mid-section, slightly larger radius to avoid z-fighting (+0.02u).

```
[gd_scene load_steps=5 format=3 uid="uid://propcone3d000001"]

[sub_resource type="StandardMaterial3D" id="mat_orange"]
albedo_color = Color(0.95, 0.42, 0.05, 1)
roughness = 0.7

[sub_resource type="StandardMaterial3D" id="mat_base"]
albedo_color = Color(0.18, 0.18, 0.18, 1)
roughness = 0.8

[sub_resource type="StandardMaterial3D" id="mat_band"]
albedo_color = Color(0.95, 0.95, 0.92, 1)
roughness = 0.5

[sub_resource type="CylinderMesh" id="mesh_cone"]
top_radius = 0.05
bottom_radius = 0.28
height = 0.72

[sub_resource type="BoxMesh" id="mesh_base"]
size = Vector3(0.62, 0.1, 0.62)

[sub_resource type="CylinderMesh" id="mesh_band"]
top_radius = 0.22
bottom_radius = 0.22
height = 0.1

[node name="PropCone3D" type="Node3D"]

[node name="Base" type="MeshInstance3D" parent="."]
position = Vector3(0, 0.05, 0)
mesh = SubResource("mesh_base")
surface_material_override/0 = SubResource("mat_base")

[node name="Cone" type="MeshInstance3D" parent="."]
position = Vector3(0, 0.46, 0)
mesh = SubResource("mesh_cone")
surface_material_override/0 = SubResource("mat_orange")

[node name="Band" type="MeshInstance3D" parent="."]
position = Vector3(0, 0.3, 0)
mesh = SubResource("mesh_band")
surface_material_override/0 = SubResource("mat_band")
```

- [ ] **Step 2: Write prop_dumpster_3d.tscn**

Large container ~2u wide ~1.2u tall. Dark-teal-green `BoxMesh` body. `BoxMesh` lid slightly wider/deeper (+0.04u each axis) placed at top, offset forward by 0.1u (open-lid look) — not co-planar with body top. Two dark `BoxMesh` side reinforcement strips (thin, offset 0.02u proud of body face).

```
[gd_scene load_steps=4 format=3 uid="uid://propdumpster3d001"]

[sub_resource type="StandardMaterial3D" id="mat_body"]
albedo_color = Color(0.1, 0.28, 0.22, 1)
roughness = 0.8
metallic = 0.1

[sub_resource type="StandardMaterial3D" id="mat_lid"]
albedo_color = Color(0.12, 0.32, 0.25, 1)
roughness = 0.75

[sub_resource type="StandardMaterial3D" id="mat_metal"]
albedo_color = Color(0.22, 0.22, 0.22, 1)
roughness = 0.55
metallic = 0.35

[sub_resource type="BoxMesh" id="mesh_body"]
size = Vector3(2.0, 1.1, 0.9)

[sub_resource type="BoxMesh" id="mesh_lid"]
size = Vector3(2.04, 0.12, 0.94)

[sub_resource type="BoxMesh" id="mesh_strip"]
size = Vector3(0.12, 1.12, 0.94)

[node name="PropDumpster3D" type="Node3D"]

[node name="Body" type="MeshInstance3D" parent="."]
position = Vector3(0, 0.55, 0)
mesh = SubResource("mesh_body")
surface_material_override/0 = SubResource("mat_body")

[node name="Lid" type="MeshInstance3D" parent="."]
position = Vector3(0, 1.16, -0.1)
rotation = Vector3(-0.22, 0, 0)
mesh = SubResource("mesh_lid")
surface_material_override/0 = SubResource("mat_lid")

[node name="StripLeft" type="MeshInstance3D" parent="."]
position = Vector3(-0.82, 0.55, 0)
mesh = SubResource("mesh_strip")
surface_material_override/0 = SubResource("mat_metal")

[node name="StripRight" type="MeshInstance3D" parent="."]
position = Vector3(0.82, 0.55, 0)
mesh = SubResource("mesh_strip")
surface_material_override/0 = SubResource("mat_metal")
```

- [ ] **Step 3: Write prop_holo_sign_3d.tscn**

Holographic sign on a post ~3u tall. Dark thin `CylinderMesh` post. Flat `BoxMesh` panel (emissive cyan, `emission_energy_multiplier=3.0`) floated near top of post. A thin dark `BoxMesh` frame slightly larger than the panel (+0.04u each side) — placed at same Z but offset by +0.02u in Z to avoid z-fighting.

```
[gd_scene load_steps=5 format=3 uid="uid://propholosign3d001"]

[sub_resource type="StandardMaterial3D" id="mat_post"]
albedo_color = Color(0.12, 0.12, 0.14, 1)
roughness = 0.6
metallic = 0.35

[sub_resource type="StandardMaterial3D" id="mat_frame"]
albedo_color = Color(0.18, 0.18, 0.2, 1)
roughness = 0.55
metallic = 0.4

[sub_resource type="StandardMaterial3D" id="mat_panel"]
albedo_color = Color(0.3, 0.8, 1.0, 1)
emission_enabled = true
emission = Color(0.3, 0.8, 1.0, 1)
emission_energy_multiplier = 3.0
roughness = 0.2

[sub_resource type="CylinderMesh" id="mesh_post"]
top_radius = 0.07
bottom_radius = 0.09
height = 3.0

[sub_resource type="BoxMesh" id="mesh_frame"]
size = Vector3(1.24, 0.74, 0.1)

[sub_resource type="BoxMesh" id="mesh_panel"]
size = Vector3(1.16, 0.66, 0.1)

[node name="PropHoloSign3D" type="Node3D"]

[node name="Post" type="MeshInstance3D" parent="."]
position = Vector3(0, 1.5, 0)
mesh = SubResource("mesh_post")
surface_material_override/0 = SubResource("mat_post")

[node name="Frame" type="MeshInstance3D" parent="."]
position = Vector3(0, 2.55, 0)
mesh = SubResource("mesh_frame")
surface_material_override/0 = SubResource("mat_frame")

[node name="Panel" type="MeshInstance3D" parent="."]
position = Vector3(0, 2.55, 0.02)
mesh = SubResource("mesh_panel")
surface_material_override/0 = SubResource("mat_panel")
```

- [ ] **Step 4: Write prop_generator_3d.tscn**

Industrial machinery ~1.6u wide ~1.2u tall. Dark metal `BoxMesh` body. Three thin `BoxMesh` vent slats on top face (offset 0.03u above body top to avoid z-fighting, separated by gaps). Small emissive status light (`SphereMesh`, green, `emission_energy_multiplier=2.5`).

```
[gd_scene load_steps=5 format=3 uid="uid://propgenerator3d001"]

[sub_resource type="StandardMaterial3D" id="mat_metal"]
albedo_color = Color(0.18, 0.18, 0.2, 1)
roughness = 0.7
metallic = 0.4

[sub_resource type="StandardMaterial3D" id="mat_vent"]
albedo_color = Color(0.12, 0.12, 0.14, 1)
roughness = 0.65
metallic = 0.5

[sub_resource type="StandardMaterial3D" id="mat_status"]
albedo_color = Color(0.2, 0.95, 0.3, 1)
emission_enabled = true
emission = Color(0.2, 0.95, 0.3, 1)
emission_energy_multiplier = 2.5
roughness = 0.3

[sub_resource type="BoxMesh" id="mesh_body"]
size = Vector3(1.6, 1.2, 0.9)

[sub_resource type="BoxMesh" id="mesh_vent"]
size = Vector3(1.3, 0.1, 0.12)

[sub_resource type="SphereMesh" id="mesh_light"]
radius = 0.08
height = 0.16

[node name="PropGenerator3D" type="Node3D"]

[node name="Body" type="MeshInstance3D" parent="."]
position = Vector3(0, 0.6, 0)
mesh = SubResource("mesh_body")
surface_material_override/0 = SubResource("mat_metal")

[node name="VentA" type="MeshInstance3D" parent="."]
position = Vector3(0, 1.23, 0.18)
mesh = SubResource("mesh_vent")
surface_material_override/0 = SubResource("mat_vent")

[node name="VentB" type="MeshInstance3D" parent="."]
position = Vector3(0, 1.23, 0.0)
mesh = SubResource("mesh_vent")
surface_material_override/0 = SubResource("mat_vent")

[node name="VentC" type="MeshInstance3D" parent="."]
position = Vector3(0, 1.23, -0.18)
mesh = SubResource("mesh_vent")
surface_material_override/0 = SubResource("mat_vent")

[node name="StatusLight" type="MeshInstance3D" parent="."]
position = Vector3(0.72, 0.9, 0.46)
mesh = SubResource("mesh_light")
surface_material_override/0 = SubResource("mat_status")
```

- [ ] **Step 5: Write prop_concrete_barrier_3d.tscn**

Jersey barrier ~2u long ~1u tall. Use a `BoxMesh` for the main rectangular body, plus a slightly narrower `BoxMesh` for the upper section (the classic jersey barrier taper). Upper section is offset +0.02u on Z so it's not co-planar, and is shorter/narrower than the base.

```
[gd_scene load_steps=3 format=3 uid="uid://propconcrete3d0001"]

[sub_resource type="StandardMaterial3D" id="mat_concrete"]
albedo_color = Color(0.72, 0.7, 0.68, 1)
roughness = 0.92

[sub_resource type="BoxMesh" id="mesh_base"]
size = Vector3(2.0, 0.55, 0.65)

[sub_resource type="BoxMesh" id="mesh_top"]
size = Vector3(2.0, 0.48, 0.38)

[node name="PropConcreteBarrier3D" type="Node3D"]

[node name="BarrierBase" type="MeshInstance3D" parent="."]
position = Vector3(0, 0.275, 0)
mesh = SubResource("mesh_base")
surface_material_override/0 = SubResource("mat_concrete")

[node name="BarrierTop" type="MeshInstance3D" parent="."]
position = Vector3(0, 0.79, 0)
mesh = SubResource("mesh_top")
surface_material_override/0 = SubResource("mat_concrete")
```

---

### Task 3: Arena / Decor Props — Pillar, Brazier, Fountain

**Files:**
- Create: `obstacles/prop_pillar_3d.tscn`
- Create: `obstacles/prop_brazier_3d.tscn`
- Create: `obstacles/prop_fountain_3d.tscn`

**Interfaces:**
- Produces: 3 loadable `PackedScene`s. `prop_brazier_3d` and `prop_fountain_3d` each contain ≥1 `OmniLight3D` in addition to `MeshInstance3D` children.

- [ ] **Step 1: Write prop_pillar_3d.tscn**

Stone column ~4u tall. Light-grey `CylinderMesh` shaft. Wider `BoxMesh` square base (~0.1u taller than shaft bottom — no co-planar). Wider `BoxMesh` capital at top (same width as base, ~0.2u thick, offset 0.02u above shaft top). LoS-blocker silhouette.

```
[gd_scene load_steps=5 format=3 uid="uid://proppillar3d00001"]

[sub_resource type="StandardMaterial3D" id="mat_stone"]
albedo_color = Color(0.78, 0.75, 0.72, 1)
roughness = 0.88

[sub_resource type="CylinderMesh" id="mesh_shaft"]
top_radius = 0.28
bottom_radius = 0.3
height = 3.6

[sub_resource type="BoxMesh" id="mesh_base"]
size = Vector3(0.8, 0.22, 0.8)

[sub_resource type="BoxMesh" id="mesh_capital"]
size = Vector3(0.78, 0.2, 0.78)

[sub_resource type="CylinderMesh" id="mesh_collar"]
top_radius = 0.32
bottom_radius = 0.32
height = 0.14

[node name="PropPillar3D" type="Node3D"]

[node name="Base" type="MeshInstance3D" parent="."]
position = Vector3(0, 0.11, 0)
mesh = SubResource("mesh_base")
surface_material_override/0 = SubResource("mat_stone")

[node name="Shaft" type="MeshInstance3D" parent="."]
position = Vector3(0, 2.12, 0)
mesh = SubResource("mesh_shaft")
surface_material_override/0 = SubResource("mat_stone")

[node name="Collar" type="MeshInstance3D" parent="."]
position = Vector3(0, 3.95, 0)
mesh = SubResource("mesh_collar")
surface_material_override/0 = SubResource("mat_stone")

[node name="Capital" type="MeshInstance3D" parent="."]
position = Vector3(0, 4.12, 0)
mesh = SubResource("mesh_capital")
surface_material_override/0 = SubResource("mat_stone")
```

- [ ] **Step 2: Write prop_brazier_3d.tscn**

Torch/brazier ~2u tall. Dark `CylinderMesh` stand (tapered). Bowl: slightly wider, short `CylinderMesh` at top of stand. Emissive flame: squashed `SphereMesh` (warm orange `Color(1.0,0.5,0.1)`, `emission_energy_multiplier=4.0`). `OmniLight3D`: warm orange, range=7, energy=1.5, positioned at flame location.

```
[gd_scene load_steps=5 format=3 uid="uid://propbrazier3d0001"]

[sub_resource type="StandardMaterial3D" id="mat_stand"]
albedo_color = Color(0.15, 0.13, 0.12, 1)
roughness = 0.7
metallic = 0.3

[sub_resource type="StandardMaterial3D" id="mat_bowl"]
albedo_color = Color(0.2, 0.17, 0.14, 1)
roughness = 0.65
metallic = 0.25

[sub_resource type="StandardMaterial3D" id="mat_flame"]
albedo_color = Color(1.0, 0.5, 0.1, 1)
emission_enabled = true
emission = Color(1.0, 0.5, 0.1, 1)
emission_energy_multiplier = 4.0
roughness = 0.3

[sub_resource type="CylinderMesh" id="mesh_stand"]
top_radius = 0.12
bottom_radius = 0.2
height = 1.6

[sub_resource type="CylinderMesh" id="mesh_bowl"]
top_radius = 0.28
bottom_radius = 0.14
height = 0.28

[sub_resource type="SphereMesh" id="mesh_flame"]
radius = 0.22
height = 0.35

[node name="PropBrazier3D" type="Node3D"]

[node name="Stand" type="MeshInstance3D" parent="."]
position = Vector3(0, 0.8, 0)
mesh = SubResource("mesh_stand")
surface_material_override/0 = SubResource("mat_stand")

[node name="Bowl" type="MeshInstance3D" parent="."]
position = Vector3(0, 1.74, 0)
mesh = SubResource("mesh_bowl")
surface_material_override/0 = SubResource("mat_bowl")

[node name="Flame" type="MeshInstance3D" parent="."]
position = Vector3(0, 2.03, 0)
mesh = SubResource("mesh_flame")
surface_material_override/0 = SubResource("mat_flame")

[node name="FireLight" type="OmniLight3D" parent="."]
position = Vector3(0, 2.05, 0)
light_color = Color(1.0, 0.55, 0.1, 1)
light_energy = 1.5
omni_range = 7.0
```

- [ ] **Step 3: Write prop_fountain_3d.tscn**

Final City charging-station/fountain ~4u wide ~1.2u tall. Layered `CylinderMesh` steps (wide flat base, narrower mid ring, narrow inner basin). Glowing emissive cyan `CylinderMesh` core pillar at center (`emission_energy_multiplier=3.0`). `OmniLight3D`: cyan, range=10, energy=1.2.

```
[gd_scene load_steps=6 format=3 uid="uid://propfountain3d001"]

[sub_resource type="StandardMaterial3D" id="mat_stone"]
albedo_color = Color(0.68, 0.65, 0.62, 1)
roughness = 0.88

[sub_resource type="StandardMaterial3D" id="mat_basin"]
albedo_color = Color(0.55, 0.62, 0.65, 1)
roughness = 0.8

[sub_resource type="StandardMaterial3D" id="mat_core"]
albedo_color = Color(0.3, 0.8, 1.0, 1)
emission_enabled = true
emission = Color(0.3, 0.8, 1.0, 1)
emission_energy_multiplier = 3.0
roughness = 0.2

[sub_resource type="CylinderMesh" id="mesh_platform"]
top_radius = 2.0
bottom_radius = 2.1
height = 0.3

[sub_resource type="CylinderMesh" id="mesh_mid_ring"]
top_radius = 1.3
bottom_radius = 1.4
height = 0.25

[sub_resource type="CylinderMesh" id="mesh_basin"]
top_radius = 0.75
bottom_radius = 0.8
height = 0.35

[sub_resource type="CylinderMesh" id="mesh_core"]
top_radius = 0.15
bottom_radius = 0.18
height = 0.9

[node name="PropFountain3D" type="Node3D"]

[node name="Platform" type="MeshInstance3D" parent="."]
position = Vector3(0, 0.15, 0)
mesh = SubResource("mesh_platform")
surface_material_override/0 = SubResource("mat_stone")

[node name="MidRing" type="MeshInstance3D" parent="."]
position = Vector3(0, 0.425, 0)
mesh = SubResource("mesh_mid_ring")
surface_material_override/0 = SubResource("mat_stone")

[node name="Basin" type="MeshInstance3D" parent="."]
position = Vector3(0, 0.625, 0)
mesh = SubResource("mesh_basin")
surface_material_override/0 = SubResource("mat_basin")

[node name="Core" type="MeshInstance3D" parent="."]
position = Vector3(0, 1.15, 0)
mesh = SubResource("mesh_core")
surface_material_override/0 = SubResource("mat_core")

[node name="FountainLight" type="OmniLight3D" parent="."]
position = Vector3(0, 1.2, 0)
light_color = Color(0.3, 0.8, 1.0, 1)
light_energy = 1.2
omni_range = 10.0
```

---

### Task 4: Test File

**Files:**
- Create: `test/test_prop_expansion.gd`

**Interfaces:**
- Consumes: all 13 `.tscn` files from Tasks 1–3
- Produces: GUT test suite; per-prop: load assert, Node3D root assert, ≥1 MeshInstance3D assert; brazier + fountain: additionally ≥1 OmniLight3D assert

- [ ] **Step 1: Write test/test_prop_expansion.gd**

```gdscript
extends GutTest
## Structural tests for the Final City prop expansion (13 props).
## Each scene: loads as PackedScene, roots as Node3D, has >= 1 MeshInstance3D.
## prop_brazier_3d + prop_fountain_3d additionally require >= 1 OmniLight3D.

# --- paths ---
const ROCK_PATH       := "res://obstacles/prop_rock_3d.tscn"
const TREE_PATH       := "res://obstacles/prop_tree_3d.tscn"
const BUSH_PATH       := "res://obstacles/prop_bush_3d.tscn"
const GRASS_PATH      := "res://obstacles/prop_tall_grass_3d.tscn"
const MUSHROOM_PATH   := "res://obstacles/prop_mushroom_3d.tscn"
const CONE_PATH       := "res://obstacles/prop_cone_3d.tscn"
const DUMPSTER_PATH   := "res://obstacles/prop_dumpster_3d.tscn"
const HOLO_PATH       := "res://obstacles/prop_holo_sign_3d.tscn"
const GENERATOR_PATH  := "res://obstacles/prop_generator_3d.tscn"
const BARRIER_PATH    := "res://obstacles/prop_concrete_barrier_3d.tscn"
const PILLAR_PATH     := "res://obstacles/prop_pillar_3d.tscn"
const BRAZIER_PATH    := "res://obstacles/prop_brazier_3d.tscn"
const FOUNTAIN_PATH   := "res://obstacles/prop_fountain_3d.tscn"

# --- helpers ---
func _count_of_type(node: Node, klass) -> int:
	var total := 0
	for child in node.get_children():
		if is_instance_of(child, klass):
			total += 1
		total += _count_of_type(child, klass)
	return total

func _assert_prop(path: String, label: String) -> Node:
	var scene: PackedScene = load(path)
	assert_not_null(scene, "%s must load as PackedScene" % label)
	if scene == null:
		return null
	var root := scene.instantiate()
	assert_true(root is Node3D, "%s root must be Node3D, got %s" % [label, root.get_class()])
	var meshes := _count_of_type(root, MeshInstance3D)
	assert_gt(meshes, 0, "%s must have >= 1 MeshInstance3D, got %d" % [label, meshes])
	return root

# --- Rock ---
func test_rock_loads_and_has_mesh() -> void:
	var root := _assert_prop(ROCK_PATH, "prop_rock_3d")
	if root == null: return
	root.free()

# --- Tree ---
func test_tree_loads_and_has_mesh() -> void:
	var root := _assert_prop(TREE_PATH, "prop_tree_3d")
	if root == null: return
	root.free()

# --- Bush ---
func test_bush_loads_and_has_mesh() -> void:
	var root := _assert_prop(BUSH_PATH, "prop_bush_3d")
	if root == null: return
	root.free()

# --- Tall Grass ---
func test_tall_grass_loads_and_has_mesh() -> void:
	var root := _assert_prop(GRASS_PATH, "prop_tall_grass_3d")
	if root == null: return
	root.free()

# --- Mushroom ---
func test_mushroom_loads_and_has_mesh() -> void:
	var root := _assert_prop(MUSHROOM_PATH, "prop_mushroom_3d")
	if root == null: return
	root.free()

# --- Cone ---
func test_cone_loads_and_has_mesh() -> void:
	var root := _assert_prop(CONE_PATH, "prop_cone_3d")
	if root == null: return
	root.free()

# --- Dumpster ---
func test_dumpster_loads_and_has_mesh() -> void:
	var root := _assert_prop(DUMPSTER_PATH, "prop_dumpster_3d")
	if root == null: return
	root.free()

# --- Holo Sign ---
func test_holo_sign_loads_and_has_mesh() -> void:
	var root := _assert_prop(HOLO_PATH, "prop_holo_sign_3d")
	if root == null: return
	root.free()

# --- Generator ---
func test_generator_loads_and_has_mesh() -> void:
	var root := _assert_prop(GENERATOR_PATH, "prop_generator_3d")
	if root == null: return
	root.free()

# --- Concrete Barrier ---
func test_concrete_barrier_loads_and_has_mesh() -> void:
	var root := _assert_prop(BARRIER_PATH, "prop_concrete_barrier_3d")
	if root == null: return
	root.free()

# --- Pillar ---
func test_pillar_loads_and_has_mesh() -> void:
	var root := _assert_prop(PILLAR_PATH, "prop_pillar_3d")
	if root == null: return
	root.free()

# --- Brazier (also requires OmniLight3D) ---
func test_brazier_loads_and_has_mesh() -> void:
	var root := _assert_prop(BRAZIER_PATH, "prop_brazier_3d")
	if root == null: return
	root.free()

func test_brazier_has_omni_light() -> void:
	var scene: PackedScene = load(BRAZIER_PATH)
	assert_not_null(scene, "prop_brazier_3d.tscn must load")
	if scene == null: return
	var root := scene.instantiate()
	var lights := _count_of_type(root, OmniLight3D)
	assert_gt(lights, 0, "prop_brazier_3d must have >= 1 OmniLight3D, got %d" % lights)
	root.free()

# --- Fountain (also requires OmniLight3D) ---
func test_fountain_loads_and_has_mesh() -> void:
	var root := _assert_prop(FOUNTAIN_PATH, "prop_fountain_3d")
	if root == null: return
	root.free()

func test_fountain_has_omni_light() -> void:
	var scene: PackedScene = load(FOUNTAIN_PATH)
	assert_not_null(scene, "prop_fountain_3d.tscn must load")
	if scene == null: return
	var root := scene.instantiate()
	var lights := _count_of_type(root, OmniLight3D)
	assert_gt(lights, 0, "prop_fountain_3d must have >= 1 OmniLight3D, got %d" % lights)
	root.free()
```

---

### Task 5: Import + Run Tests

**Files:** No new files — this task imports and validates.

- [ ] **Step 1: Run headless import**

```bash
/c/Users/avino/tools/godot47/godot47.exe --headless --import
```

Expected: exits 0, may emit benign `Parameter "material" is null` warnings — that's fine.

- [ ] **Step 2: Run focused test suite**

```bash
/c/Users/avino/tools/godot47/godot47.exe --headless -s addons/gut/gut_cmdln.gd -gdir=res://test -gselect=test_prop_expansion.gd -gexit
```

Expected: 15 tests pass (13 mesh tests + 2 light tests). Zero failures.

- [ ] **Step 3: Run full suite for regression check**

```bash
/c/Users/avino/tools/godot47/godot47.exe --headless -s addons/gut/gut_cmdln.gd -gdir=res://test -gexit
```

Expected: ≥1055 tests passing (baseline 1040 + 15 new), 0 failures.

---

### Task 6: Commit

**Files:** Stage exactly these files by explicit path.

- [ ] **Step 1: Stage new files**

```bash
git add obstacles/prop_rock_3d.tscn obstacles/prop_tree_3d.tscn obstacles/prop_bush_3d.tscn obstacles/prop_tall_grass_3d.tscn obstacles/prop_mushroom_3d.tscn obstacles/prop_cone_3d.tscn obstacles/prop_dumpster_3d.tscn obstacles/prop_holo_sign_3d.tscn obstacles/prop_generator_3d.tscn obstacles/prop_concrete_barrier_3d.tscn obstacles/prop_pillar_3d.tscn obstacles/prop_brazier_3d.tscn obstacles/prop_fountain_3d.tscn test/test_prop_expansion.gd
```

- [ ] **Step 2: Commit**

```bash
git commit -m "$(cat <<'EOF'
feat(visual): prop expansion — rocks, tree, bush, mushrooms, signs, pillar, brazier, fountain, etc.

13 visual-only primitive-mesh props for the Final City arena:
- Nature: rock cluster, stylized tree, bush, tall grass blades, mushroom cluster
- Urban/sci-fi: traffic cone, dumpster, holographic sign (emissive cyan), generator (emissive status light), jersey barrier
- Arena/decor: stone pillar, brazier (emissive flame + OmniLight3D), fountain centerpiece (emissive cyan core + OmniLight3D)
- GUT test: test_prop_expansion.gd — 15 structural assertions, 0 regressions

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
EOF
)"
```
