# See docs/notes/weapon-nova-3d.md
extends GutTest
## Unit tests for NovaWeapon3D archetype and its per-skill subclasses.
##
## Physics is not required — affected_enemies() is a pure Array filter.
## Tests cover: radius filtering, Y-ignored, level_up/evolve/apply_passive,
## charm variant, and per-skill defaults.

# ─────────────────────────────────────────────────────────────────────────────
# Stub enemy — position-aware, records damage + charm calls
# ─────────────────────────────────────────────────────────────────────────────
class StubEnemy extends Node3D:
	var damage_received: float = 0.0
	var charm_calls: int = 0
	var last_charm_duration: float = 0.0

	func _init() -> void:
		add_to_group("enemies")

	func take_damage(amount: float) -> void:
		damage_received += amount

	func charm(duration: float) -> void:
		charm_calls += 1
		last_charm_duration = duration

# ─────────────────────────────────────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────────────────────────────────────

func _make_stats(dmg: float = 1.0, rate: float = 1.0) -> StatBlock:
	var s := StatBlock.new()
	s.damage_mult    = dmg
	s.fire_rate_mult = rate
	return s

func _make_nova_weapon() -> NovaWeapon3D:
	var w: NovaWeapon3D = add_child_autofree(NovaWeapon3D.new()) as NovaWeapon3D
	var player := add_child_autofree(Node3D.new()) as Node3D
	w.setup(player, _make_stats())
	return w

func _make_selfie_flash() -> ZivSelfieFlash3D:
	var scene := load("res://weapons/ziv_selfie_flash_3d.tscn")
	assert_not_null(scene, "ziv_selfie_flash_3d.tscn must exist")
	var w: ZivSelfieFlash3D = add_child_autofree(scene.instantiate()) as ZivSelfieFlash3D
	var player := add_child_autofree(Node3D.new()) as Node3D
	w.setup(player, _make_stats())
	return w

func _make_adoring_aura() -> ZivAdoringAura3D:
	var scene := load("res://weapons/ziv_adoring_aura_3d.tscn")
	assert_not_null(scene, "ziv_adoring_aura_3d.tscn must exist")
	var w: ZivAdoringAura3D = add_child_autofree(scene.instantiate()) as ZivAdoringAura3D
	var player := add_child_autofree(Node3D.new()) as Node3D
	w.setup(player, _make_stats())
	return w

func _make_voice_blast() -> AvihayVoiceBlast3D:
	var scene := load("res://weapons/avihay_voice_blast_3d.tscn")
	assert_not_null(scene, "avihay_voice_blast_3d.tscn must exist")
	var w: AvihayVoiceBlast3D = add_child_autofree(scene.instantiate()) as AvihayVoiceBlast3D
	var player := add_child_autofree(Node3D.new()) as Node3D
	w.setup(player, _make_stats())
	return w

func _make_enemy_at(xpos: float, zpos: float, ypos: float = 0.0) -> StubEnemy:
	var e := StubEnemy.new()
	add_child_autofree(e)
	e.global_position = Vector3(xpos, ypos, zpos)
	return e

# ═════════════════════════════════════════════════════════════════════════════
# affected_enemies — pure filter
# ═════════════════════════════════════════════════════════════════════════════

func test_affected_enemies_includes_within_radius() -> void:
	var w := _make_nova_weapon()
	w.radius = 5.0
	var e1 := _make_enemy_at(2.0, 0.0)
	var e2 := _make_enemy_at(0.0, 4.0)
	var result: Array = w.affected_enemies([e1, e2], Vector3.ZERO)
	assert_true(result.has(e1), "enemy at dist 2 must be within radius 5")
	assert_true(result.has(e2), "enemy at dist 4 must be within radius 5")

func test_affected_enemies_excludes_beyond_radius() -> void:
	var w := _make_nova_weapon()
	w.radius = 3.0
	var far := _make_enemy_at(10.0, 0.0)
	var result: Array = w.affected_enemies([far], Vector3.ZERO)
	assert_false(result.has(far), "enemy at dist 10 must be outside radius 3")

func test_affected_enemies_at_exact_radius_included() -> void:
	var w := _make_nova_weapon()
	w.radius = 4.0
	var e := _make_enemy_at(4.0, 0.0)   # dist = 4.0 exactly
	var result: Array = w.affected_enemies([e], Vector3.ZERO)
	assert_true(result.has(e), "enemy at exactly radius distance must be included")

func test_affected_enemies_ignores_y_component() -> void:
	# Enemy is at XZ dist 2 but high Y — should still be included.
	var w := _make_nova_weapon()
	w.radius = 5.0
	var e := _make_enemy_at(2.0, 0.0, 100.0)   # y=100
	var result: Array = w.affected_enemies([e], Vector3.ZERO)
	assert_true(result.has(e), "Y component must be ignored in distance calculation")

func test_affected_enemies_empty_array() -> void:
	var w := _make_nova_weapon()
	var result: Array = w.affected_enemies([], Vector3.ZERO)
	assert_eq(result.size(), 0, "empty input must return empty result")

func test_affected_enemies_non_zero_origin() -> void:
	var w := _make_nova_weapon()
	w.radius = 3.0
	var origin := Vector3(5.0, 0.0, 5.0)
	var near := _make_enemy_at(6.0, 5.0)   # XZ dist from origin = 1
	var far := _make_enemy_at(0.0, 0.0)    # XZ dist from origin ≈ 7
	var result: Array = w.affected_enemies([near, far], origin)
	assert_true(result.has(near),  "enemy 1 unit from non-zero origin must be included")
	assert_false(result.has(far), "enemy 7 units from non-zero origin must be excluded")

# ═════════════════════════════════════════════════════════════════════════════
# level_up / evolve / apply_passive
# ═════════════════════════════════════════════════════════════════════════════

func test_level_up_increments_level() -> void:
	var w := _make_nova_weapon()
	assert_eq(w.level, 1)
	w.level_up()
	assert_eq(w.level, 2)

func test_level_up_increases_radius_by_1() -> void:
	var w := _make_nova_weapon()
	var before: float = w.radius
	w.level_up()
	assert_almost_eq(w.radius - before, 1.0, 0.001, "level_up must add 1.0 to radius")

func test_level_up_increases_damage_by_6() -> void:
	var w := _make_nova_weapon()
	var before: float = w.damage
	w.level_up()
	assert_almost_eq(w.damage - before, 6.0, 0.001, "level_up must add 6 to damage")

func test_level_up_no_charm_delta_when_no_charm() -> void:
	var w := _make_nova_weapon()
	w.charm_duration = 0.0
	w.level_up()
	assert_almost_eq(w.charm_duration, 0.0, 0.001,
		"level_up must not change charm_duration when it is 0")

func test_level_up_charm_variant_increases_charm_duration() -> void:
	var w := _make_nova_weapon()
	w.charm_duration = 1.0   # make it a charming variant
	w.level_up()
	assert_almost_eq(w.charm_duration, 1.3, 0.001,
		"level_up must add 0.3 to charm_duration when it is > 0")

func test_evolve_sets_evolved_flag() -> void:
	var w := _make_nova_weapon()
	w.evolve()
	assert_true(w.evolved, "evolve must set evolved=true")

func test_evolve_increases_radius() -> void:
	var w := _make_nova_weapon()
	var before: float = w.radius
	w.evolve()
	assert_gt(w.radius, before, "evolve must increase radius")

func test_apply_passive_increases_radius() -> void:
	var w := _make_nova_weapon()
	var before: float = w.radius
	w.apply_passive(2.5)
	assert_almost_eq(w.radius, before + 2.5, 0.001, "apply_passive must add value to radius")

func test_apply_passive_stacks() -> void:
	var w := _make_nova_weapon()
	var before: float = w.radius
	w.apply_passive(1.0)
	w.apply_passive(1.5)
	assert_almost_eq(w.radius, before + 2.5, 0.001, "apply_passive must stack additively")

# ═════════════════════════════════════════════════════════════════════════════
# Charm variant (ZivAdoringAura3D) — stub without physics
# ═════════════════════════════════════════════════════════════════════════════

func test_adoring_aura_has_charm_duration() -> void:
	var w := _make_adoring_aura()
	assert_gt(w.charm_duration, 0.0, "AdoringAura must have charm_duration > 0")

func test_adoring_aura_affected_enemies_filters_correctly() -> void:
	var w := _make_adoring_aura()
	var near := _make_enemy_at(2.0, 0.0)
	var far  := _make_enemy_at(100.0, 0.0)
	var result: Array = w.affected_enemies([near, far], Vector3.ZERO)
	assert_true(result.has(near),  "near enemy must be in affected list")
	assert_false(result.has(far), "far enemy must not be in affected list")

func test_adoring_aura_level_up_increases_charm_duration() -> void:
	var w := _make_adoring_aura()
	var before: float = w.charm_duration
	w.level_up()
	assert_gt(w.charm_duration, before, "AdoringAura level_up must increase charm_duration")

# ═════════════════════════════════════════════════════════════════════════════
# Per-skill defaults
# ═════════════════════════════════════════════════════════════════════════════

func test_selfie_flash_initial_damage() -> void:
	var w := _make_selfie_flash()
	assert_almost_eq(w.damage, 22.0, 0.001, "SelfieFlash damage must start at 22")

func test_selfie_flash_initial_radius() -> void:
	var w := _make_selfie_flash()
	assert_almost_eq(w.radius, 5.5, 0.001, "SelfieFlash radius must start at 5.5")

func test_selfie_flash_no_charm() -> void:
	var w := _make_selfie_flash()
	assert_almost_eq(w.charm_duration, 0.0, 0.001, "SelfieFlash must have charm_duration=0")

func test_adoring_aura_initial_radius() -> void:
	var w := _make_adoring_aura()
	assert_almost_eq(w.radius, 7.0, 0.001, "AdoringAura radius must start at 7.0")

func test_adoring_aura_initial_charm_duration() -> void:
	var w := _make_adoring_aura()
	assert_almost_eq(w.charm_duration, 2.5, 0.001, "AdoringAura charm_duration must start at 2.5")

func test_voice_blast_initial_damage() -> void:
	var w := _make_voice_blast()
	assert_almost_eq(w.damage, 25.0, 0.001, "VoiceBlast damage must start at 25")

func test_voice_blast_initial_radius() -> void:
	var w := _make_voice_blast()
	assert_almost_eq(w.radius, 6.0, 0.001, "VoiceBlast radius must start at 6.0")

# ═════════════════════════════════════════════════════════════════════════════
# Scenes load and are Weapon3D
# ═════════════════════════════════════════════════════════════════════════════

func test_nova_archetype_scene_loads() -> void:
	var scene := load("res://weapons/nova_weapon_3d.tscn")
	assert_not_null(scene, "nova_weapon_3d.tscn must load")

func test_nova_archetype_instantiates_as_weapon3d() -> void:
	var scene := load("res://weapons/nova_weapon_3d.tscn")
	var w = add_child_autofree(scene.instantiate())
	assert_true(w is Weapon3D, "NovaWeapon3D must be a Weapon3D")

func test_selfie_flash_scene_loads() -> void:
	var scene := load("res://weapons/ziv_selfie_flash_3d.tscn")
	assert_not_null(scene, "ziv_selfie_flash_3d.tscn must load")

func test_adoring_aura_scene_loads() -> void:
	var scene := load("res://weapons/ziv_adoring_aura_3d.tscn")
	assert_not_null(scene, "ziv_adoring_aura_3d.tscn must load")

func test_voice_blast_scene_loads() -> void:
	var scene := load("res://weapons/avihay_voice_blast_3d.tscn")
	assert_not_null(scene, "avihay_voice_blast_3d.tscn must load")
