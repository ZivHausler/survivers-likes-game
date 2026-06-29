# See docs/notes/xp-gem-3d.md
extends GutTest
## Unit tests for XPGem3D.tier_color, Spawner3D.xp_time_mult, and the
## material color applied by XPGem3D.setup().

# ── tier_color — value 1 (lowest tier) ───────────────────────────────────────

func test_tier_color_value_1_is_blue() -> void:
	var c := XPGem3D.tier_color(1)
	assert_eq(c, Color(0.3, 0.6, 1.0), "value 1 must map to lowest tier (blue)")

func test_tier_color_value_2_is_blue() -> void:
	var c := XPGem3D.tier_color(2)
	assert_eq(c, Color(0.3, 0.6, 1.0), "value 2 must still be lowest tier (blue)")

# ── tier_color — green tier (3–5) ─────────────────────────────────────────────

func test_tier_color_value_3_is_green() -> void:
	var c := XPGem3D.tier_color(3)
	assert_eq(c, Color(0.3, 1.0, 0.4), "value 3 must map to green tier")

func test_tier_color_value_5_is_green() -> void:
	var c := XPGem3D.tier_color(5)
	assert_eq(c, Color(0.3, 1.0, 0.4), "value 5 must map to green tier")

# ── tier_color — yellow tier (6–15) ──────────────────────────────────────────

func test_tier_color_value_6_is_yellow() -> void:
	var c := XPGem3D.tier_color(6)
	assert_eq(c, Color(1.0, 0.9, 0.2), "value 6 must map to yellow tier")

func test_tier_color_value_15_is_yellow() -> void:
	var c := XPGem3D.tier_color(15)
	assert_eq(c, Color(1.0, 0.9, 0.2), "value 15 must map to yellow tier")

# ── tier_color — orange tier (16–49) ─────────────────────────────────────────

func test_tier_color_value_16_is_orange() -> void:
	var c := XPGem3D.tier_color(16)
	assert_eq(c, Color(1.0, 0.55, 0.1), "value 16 must map to orange tier")

func test_tier_color_value_49_is_orange() -> void:
	var c := XPGem3D.tier_color(49)
	assert_eq(c, Color(1.0, 0.55, 0.1), "value 49 must map to orange tier")

# ── tier_color — magenta tier (50+) ──────────────────────────────────────────

func test_tier_color_value_50_is_magenta() -> void:
	var c := XPGem3D.tier_color(50)
	assert_eq(c, Color(1.0, 0.2, 0.6), "value 50 (boss) must map to magenta top tier")

func test_tier_color_value_200_is_magenta() -> void:
	var c := XPGem3D.tier_color(200)
	assert_eq(c, Color(1.0, 0.2, 0.6), "value 200 (big-boss) must map to magenta top tier")

# ── tier_color — boundary transitions ────────────────────────────────────────

func test_tier_color_boundary_2_vs_3_differ() -> void:
	assert_true(XPGem3D.tier_color(2) != XPGem3D.tier_color(3),
			"tier_color(2) and tier_color(3) must be different colors (blue→green boundary)")

func test_tier_color_boundary_5_vs_6_differ() -> void:
	assert_true(XPGem3D.tier_color(5) != XPGem3D.tier_color(6),
			"tier_color(5) and tier_color(6) must be different colors (green→yellow boundary)")

func test_tier_color_boundary_15_vs_16_differ() -> void:
	assert_true(XPGem3D.tier_color(15) != XPGem3D.tier_color(16),
			"tier_color(15) and tier_color(16) must be different colors (yellow→orange boundary)")

func test_tier_color_boundary_49_vs_50_differ() -> void:
	assert_true(XPGem3D.tier_color(49) != XPGem3D.tier_color(50),
			"tier_color(49) and tier_color(50) must be different colors (orange→magenta boundary)")

# ── xp_time_mult — basic contract ────────────────────────────────────────────

func test_xp_time_mult_at_zero_is_1() -> void:
	assert_almost_eq(Spawner3D.xp_time_mult(0.0), 1.0, 0.0001,
			"xp_time_mult(0) must be exactly 1.0")

func test_xp_time_mult_at_120_is_2() -> void:
	assert_almost_eq(Spawner3D.xp_time_mult(120.0), 2.0, 0.0001,
			"xp_time_mult(120) must be 2.0 (+1× per 2 min)")

func test_xp_time_mult_is_monotone_increasing() -> void:
	var t0 := Spawner3D.xp_time_mult(0.0)
	var t60 := Spawner3D.xp_time_mult(60.0)
	var t120 := Spawner3D.xp_time_mult(120.0)
	assert_true(t60 > t0,  "xp_time_mult(60) must be greater than xp_time_mult(0)")
	assert_true(t120 > t60, "xp_time_mult(120) must be greater than xp_time_mult(60)")

func test_xp_time_mult_never_below_1() -> void:
	assert_true(Spawner3D.xp_time_mult(0.0) >= 1.0,
			"xp_time_mult must never return less than 1.0 (floor at t=0)")

# ── spawner XP scaling — static helper drives value up ───────────────────────

func test_xp_scale_at_elapsed_120_is_greater_than_at_elapsed_0() -> void:
	var swarmer := load("res://enemies/swarmer.tres") as EnemyData
	var base_xp: int = swarmer.xp_value
	var xp_at_0   := maxi(base_xp, int(round(float(base_xp) * Spawner3D.xp_time_mult(0.0))))
	var xp_at_120 := maxi(base_xp, int(round(float(base_xp) * Spawner3D.xp_time_mult(120.0))))
	assert_true(xp_at_120 > xp_at_0,
			"XP scaled at t=120 must exceed XP scaled at t=0 for a positive-xp enemy")

func test_shared_swarmer_tres_xp_value_not_mutated_by_xp_scaling() -> void:
	var swarmer := load("res://enemies/swarmer.tres") as EnemyData
	var original_xp := swarmer.xp_value
	# Simulate what _spawn_normal does: duplicate then modify the copy.
	var scaled := Spawner3D.scale_enemy_data(swarmer, 1.0)
	scaled.xp_value = maxi(original_xp, int(round(float(original_xp) * Spawner3D.xp_time_mult(120.0))))
	assert_eq(swarmer.xp_value, original_xp,
			"Modifying the duplicated EnemyData xp_value must not mutate the shared swarmer.tres")

# ── setup() material color ────────────────────────────────────────────────────

func test_setup_sets_gem_material_albedo_to_tier_color() -> void:
	var scene := preload("res://pickups/xp_gem_3d.tscn") as PackedScene
	var gem := scene.instantiate() as XPGem3D
	add_child_autofree(gem)
	gem.setup(5, null)  # value 5 → green tier
	var mesh := gem.get_node_or_null("MeshInstance3D") as MeshInstance3D
	assert_not_null(mesh, "MeshInstance3D must exist in the xp_gem_3d scene")
	var mat := mesh.material_override as StandardMaterial3D
	assert_not_null(mat, "material_override must be set on MeshInstance3D after setup()")
	var expected := XPGem3D.tier_color(5)
	assert_eq(mat.albedo_color, expected,
			"material albedo_color must match tier_color(5) = green")

func test_setup_gem_material_is_fresh_not_shared_resource() -> void:
	# The scene's MeshInstance3D has no material_override in the .tscn.
	# setup() must create a fresh StandardMaterial3D, not share any existing one.
	var scene := preload("res://pickups/xp_gem_3d.tscn") as PackedScene
	var gem := scene.instantiate() as XPGem3D
	add_child_autofree(gem)
	var mesh := gem.get_node_or_null("MeshInstance3D") as MeshInstance3D
	assert_not_null(mesh, "MeshInstance3D must exist")
	var mat_before := mesh.material_override  # should be null before setup
	gem.setup(1, null)
	var mat_after := mesh.material_override
	assert_not_null(mat_after, "material_override must be non-null after setup()")
	assert_true(mat_after != mat_before,
			"setup() must assign a new material instance, not the original (null) override")

func test_setup_value_50_uses_magenta_material() -> void:
	var scene := preload("res://pickups/xp_gem_3d.tscn") as PackedScene
	var gem := scene.instantiate() as XPGem3D
	add_child_autofree(gem)
	gem.setup(50, null)  # boss value → magenta
	var mesh := gem.get_node_or_null("MeshInstance3D") as MeshInstance3D
	var mat := mesh.material_override as StandardMaterial3D
	assert_not_null(mat, "material_override must be set for boss-value gem")
	assert_eq(mat.albedo_color, XPGem3D.tier_color(50),
			"boss gem (value 50) must show magenta material")
