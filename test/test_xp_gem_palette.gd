# See docs/notes/xp-gem-3d.md
extends GutTest
## Palette-driving tests for XPGem3D tier colors and weapon archetype VFX colors
## (Task 1.7). Verifies that all color values are sourced from VisualPalette.role()
## rather than hardcoded Color literals.
##
## NOTE — XP gem tier RGB values happen to match palette values exactly, so
## the gem tests below are GREEN before and after the refactor (behavior is
## byte-identical). The TRUE TDD red→green cycle is demonstrated by
## test_nova_vfx_color_matches_palette_primary (nova Color(0.5,0.8,1.0) ≠
## player_primary Color(0.3,0.8,1.0), so it is RED before the fix).

# ── XPGem3D tier_color → palette ─────────────────────────────────────────────

func test_tier_color_low_matches_palette_pickup_low() -> void:
	assert_eq(XPGem3D.tier_color(1), VisualPalette.role(&"pickup_low"),
		"tier_color(1) must equal VisualPalette.role('pickup_low')")

func test_tier_color_mid_matches_palette_pickup_mid() -> void:
	assert_eq(XPGem3D.tier_color(3), VisualPalette.role(&"pickup_mid"),
		"tier_color(3) must equal VisualPalette.role('pickup_mid')")

func test_tier_color_high_matches_palette_pickup_high() -> void:
	assert_eq(XPGem3D.tier_color(6), VisualPalette.role(&"pickup_high"),
		"tier_color(6) must equal VisualPalette.role('pickup_high')")

func test_tier_color_higher_matches_palette_pickup_higher() -> void:
	assert_eq(XPGem3D.tier_color(16), VisualPalette.role(&"pickup_higher"),
		"tier_color(16) must equal VisualPalette.role('pickup_higher')")

func test_tier_color_top_matches_palette_pickup_top() -> void:
	assert_eq(XPGem3D.tier_color(50), VisualPalette.role(&"pickup_top"),
		"tier_color(50) must equal VisualPalette.role('pickup_top')")

# ── XPGem3D setup() emissive material ────────────────────────────────────────

func test_setup_low_tier_emissive_matches_palette_pickup_low() -> void:
	var scene := preload("res://pickups/xp_gem_3d.tscn") as PackedScene
	var gem: XPGem3D = add_child_autofree(scene.instantiate() as XPGem3D)
	gem.setup(1, null)
	var mesh := gem.get_node_or_null("MeshInstance3D") as MeshInstance3D
	assert_not_null(mesh, "MeshInstance3D must exist in xp_gem_3d scene")
	var mat := mesh.material_override as StandardMaterial3D
	assert_not_null(mat, "material_override must be set after setup()")
	assert_eq(mat.emission, VisualPalette.role(&"pickup_low"),
		"low-tier gem emission must match VisualPalette.role('pickup_low')")

# ── Archetype VFX colors → palette (TDD RED before fix, GREEN after) ─────────

func test_nova_vfx_color_matches_palette_player_primary() -> void:
	# RED before fix: NovaWeapon3D had Color(0.5,0.8,1.0) ≠ player_primary Color(0.3,0.8,1.0)
	# GREEN after:    vfx_color = VisualPalette.role(&"player_primary")
	var w: NovaWeapon3D = add_child_autofree(NovaWeapon3D.new())
	assert_eq(w.vfx_color, VisualPalette.role(&"player_primary"),
		"NovaWeapon3D.vfx_color must equal VisualPalette.role('player_primary')")

func test_orbit_vfx_color_matches_palette_player_secondary() -> void:
	# Values are already equal (Color(1.0,0.8,0.2) == player_secondary), so GREEN before fix too.
	var w: OrbitWeapon3D = add_child_autofree(OrbitWeapon3D.new())
	assert_eq(w.vfx_color, VisualPalette.role(&"player_secondary"),
		"OrbitWeapon3D.vfx_color must equal VisualPalette.role('player_secondary')")
