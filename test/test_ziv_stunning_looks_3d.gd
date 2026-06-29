# See docs/notes/weapon-ziv-3d.md
extends GutTest
## Unit tests for ZivStunningLooks3D — mirrors test_ziv_stunning_looks.gd coverage.
##
## Physics-overlap (beam physically hitting enemies via get_overlapping_bodies) is
## manual-only because it requires live physics frames.
## Everything tested here is pure state / scalar logic:
##   level_up deltas, evolve flag + CharmField state, charm sorting/radius,
##   apply_passive, beam Y-rotation flag.

# ─────────────────────────────────────────────────────────────────────────────
# Stub enemy — no scene file needed.  Added to group "enemies", exposes
# take_damage() and charm() with call recording.
# ─────────────────────────────────────────────────────────────────────────────
class StubEnemy3D extends Node3D:
	var damage_received: float = 0.0
	var hit_count: int = 0
	var charm_calls: int = 0
	var last_charm_duration: float = 0.0

	func take_damage(amount: float) -> void:
		damage_received += amount
		hit_count += 1

	func charm(duration: float) -> void:
		last_charm_duration = max(last_charm_duration, duration)
		charm_calls += 1

# ─────────────────────────────────────────────────────────────────────────────
# Scene cache
# ─────────────────────────────────────────────────────────────────────────────
var WeaponScene = null

func before_all() -> void:
	WeaponScene = load("res://weapons/ziv_stunning_looks_3d.tscn")

# ─────────────────────────────────────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────────────────────────────────────

func _make_stats(dmg: float = 1.0, rate: float = 1.0) -> StatBlock:
	var s := StatBlock.new()
	s.damage_mult    = dmg
	s.fire_rate_mult = rate
	return s

func _make_weapon() -> ZivStunningLooks3D:
	assert_not_null(WeaponScene, "ziv_stunning_looks_3d.tscn must exist")
	var w: ZivStunningLooks3D = add_child_autofree(WeaponScene.instantiate()) as ZivStunningLooks3D
	var player: Node3D = add_child_autofree(Node3D.new()) as Node3D
	w.setup(player, _make_stats())
	return w

func _make_stub_enemy(xpos: float = 0.0, zpos: float = 0.0) -> StubEnemy3D:
	var e := StubEnemy3D.new()
	add_child_autofree(e)
	e.add_to_group("enemies")
	e.global_position = Vector3(xpos, 0.0, zpos)
	return e

# ═════════════════════════════════════════════════════════════════════════════
# level_up() scaling
# ═════════════════════════════════════════════════════════════════════════════

func test_level_up_increases_beam_damage() -> void:
	var w := _make_weapon()
	var before := w.beam_damage
	w.level_up()
	assert_gt(w.beam_damage, before, "beam_damage must grow after level_up")

func test_level_up_beam_damage_delta_is_10() -> void:
	var w := _make_weapon()
	var before := w.beam_damage
	w.level_up()
	assert_almost_eq(w.beam_damage - before, 10.0, 0.001,
		"beam_damage must increase by exactly 10 per level")

func test_level_up_increases_charm_count() -> void:
	var w := _make_weapon()
	var before := w.charm_count
	w.level_up()
	assert_gt(w.charm_count, before, "charm_count must grow after level_up")

func test_level_up_charm_count_delta_is_1() -> void:
	var w := _make_weapon()
	var before := w.charm_count
	w.level_up()
	assert_eq(w.charm_count - before, 1,
		"charm_count must increase by 1 per level")

func test_level_up_increases_charm_duration() -> void:
	var w := _make_weapon()
	var before := w.charm_duration
	w.level_up()
	assert_gt(w.charm_duration, before, "charm_duration must grow after level_up")

func test_level_up_charm_duration_delta_is_half_second() -> void:
	var w := _make_weapon()
	var before := w.charm_duration
	w.level_up()
	assert_almost_eq(w.charm_duration - before, 0.5, 0.001,
		"charm_duration must increase by 0.5 per level")

func test_level_up_increases_charm_radius() -> void:
	var w := _make_weapon()
	var before := w.charm_radius
	w.level_up()
	assert_gt(w.charm_radius, before, "charm_radius must grow after level_up")

func test_level_up_charm_radius_delta_is_1_25() -> void:
	var w := _make_weapon()
	var before := w.charm_radius
	w.level_up()
	assert_almost_eq(w.charm_radius - before, 1.25, 0.001,
		"charm_radius must increase by 1.25 world units per level")

func test_level_increments_with_level_up() -> void:
	var w := _make_weapon()
	assert_eq(w.level, 1, "weapon starts at level 1")
	w.level_up()
	assert_eq(w.level, 2, "level should be 2 after one level_up")

# ═════════════════════════════════════════════════════════════════════════════
# is_max_level / evolve()
# ═════════════════════════════════════════════════════════════════════════════

func test_is_not_max_at_start() -> void:
	var w := _make_weapon()
	assert_false(w.is_max_level(ZivStunningLooks3D.MAX_LEVEL),
		"should not be max level at level 1")

func test_is_max_after_enough_level_ups() -> void:
	var w := _make_weapon()
	for _i in range(ZivStunningLooks3D.MAX_LEVEL - 1):
		w.level_up()
	assert_true(w.is_max_level(ZivStunningLooks3D.MAX_LEVEL),
		"should be max level after MAX_LEVEL-1 level_ups from level 1")

func test_evolved_is_false_initially() -> void:
	var w := _make_weapon()
	assert_false(w.evolved, "evolved must start false")

func test_evolve_sets_evolved_flag() -> void:
	var w := _make_weapon()
	w.evolve()
	assert_true(w.evolved, "evolved must be true after evolve()")

func test_evolve_enables_charm_field_monitoring() -> void:
	var w := _make_weapon()
	assert_false(w._charm_field.monitoring,
		"CharmField monitoring should be off before evolve")
	w.evolve()
	assert_true(w._charm_field.monitoring,
		"CharmField must be monitoring after evolve")

func test_evolve_beam_remains_monitoring() -> void:
	var w := _make_weapon()
	w.evolve()
	assert_true(w._beam.monitoring,
		"Beam must still be monitoring after evolve")

func test_beam_monitoring_on_from_start() -> void:
	var w := _make_weapon()
	assert_true(w._beam.monitoring,
		"Beam must have monitoring on from _ready")

func test_charm_field_monitoring_off_before_evolve() -> void:
	var w := _make_weapon()
	assert_false(w._charm_field.monitoring,
		"CharmField monitoring must be off before evolve")

# ═════════════════════════════════════════════════════════════════════════════
# _charm_nearby_enemies() — pure state logic, no physics required
# Uses get_tree().get_nodes_in_group(), which works with plain Node3D stubs.
# ═════════════════════════════════════════════════════════════════════════════

func test_charm_charms_nearest_within_radius() -> void:
	var w := _make_weapon()
	# weapon at (0,0,0), charm_count=2, charm_radius=9.0
	var e1 := _make_stub_enemy(1.0, 0.0)   # distance 1 — within radius, nearest
	var e2 := _make_stub_enemy(3.0, 0.0)   # distance 3 — within radius
	var _e3 := _make_stub_enemy(50.0, 0.0)  # distance 50 — outside radius
	w._charm_nearby_enemies()
	assert_gt(e1.charm_calls, 0, "nearest enemy should be charmed")
	assert_gt(e2.charm_calls, 0, "second enemy within radius should be charmed")

func test_charm_skips_enemy_outside_radius() -> void:
	var w := _make_weapon()
	var far := _make_stub_enemy(50.0, 0.0)   # outside charm_radius=9.0
	w._charm_nearby_enemies()
	assert_eq(far.charm_calls, 0, "enemy outside charm_radius must not be charmed")

func test_charm_respects_charm_count() -> void:
	var w := _make_weapon()
	# charm_count=2, place 3 enemies within radius; only nearest 2 get charmed
	var e1 := _make_stub_enemy(1.0, 0.0)
	var e2 := _make_stub_enemy(2.0, 0.0)
	var e3 := _make_stub_enemy(3.0, 0.0)
	w._charm_nearby_enemies()
	assert_gt(e1.charm_calls, 0, "enemy 1 (nearest) must be charmed")
	assert_gt(e2.charm_calls, 0, "enemy 2 (second nearest) must be charmed")
	assert_eq(e3.charm_calls, 0, "enemy 3 (third, exceeds charm_count=2) must not be charmed")

func test_charm_passes_correct_duration() -> void:
	var w := _make_weapon()
	var e := _make_stub_enemy(1.0, 0.0)
	w._charm_nearby_enemies()
	assert_almost_eq(e.last_charm_duration, w.charm_duration, 0.001,
		"charm must use weapon's charm_duration value")

# ═════════════════════════════════════════════════════════════════════════════
# apply_passive()
# ═════════════════════════════════════════════════════════════════════════════

func test_apply_passive_increases_charm_duration() -> void:
	var w := _make_weapon()
	var before := w.charm_duration
	w.apply_passive(1.5)
	assert_almost_eq(w.charm_duration, before + 1.5, 0.001,
		"apply_passive must add value to charm_duration")

func test_apply_passive_stacks() -> void:
	var w := _make_weapon()
	var before := w.charm_duration
	w.apply_passive(1.0)
	w.apply_passive(0.5)
	assert_almost_eq(w.charm_duration, before + 1.5, 0.001,
		"apply_passive must stack additively")

# ═════════════════════════════════════════════════════════════════════════════
# Initial constants
# ═════════════════════════════════════════════════════════════════════════════

func test_initial_beam_damage() -> void:
	var w := _make_weapon()
	assert_almost_eq(w.beam_damage, 25.0, 0.001, "beam_damage must start at 25.0")

func test_initial_charm_count() -> void:
	var w := _make_weapon()
	assert_eq(w.charm_count, 2, "charm_count must start at 2")

func test_initial_charm_duration() -> void:
	var w := _make_weapon()
	assert_almost_eq(w.charm_duration, 2.0, 0.001, "charm_duration must start at 2.0")

func test_initial_charm_radius() -> void:
	var w := _make_weapon()
	assert_almost_eq(w.charm_radius, 9.0, 0.001, "charm_radius must start at 9.0")

func test_base_cooldown_is_3() -> void:
	var w := _make_weapon()
	assert_almost_eq(w.base_cooldown, 3.0, 0.001, "base_cooldown must be 3.0")

# ═════════════════════════════════════════════════════════════════════════════
# aim_angle_to — pure geometry helper
# ═════════════════════════════════════════════════════════════════════════════

func test_aim_angle_to_target_directly_in_front() -> void:
	# Target at (0, 0, -5) — directly along the beam's natural -Z direction.
	# Expected rotation.y = 0 so beam already faces that way.
	var angle := ZivStunningLooks3D.aim_angle_to(Vector3.ZERO, Vector3(0.0, 0.0, -5.0))
	assert_almost_eq(angle, 0.0, 0.01,
		"target on -Z axis must require zero beam rotation")

func test_aim_angle_to_target_to_the_right() -> void:
	# Target at (+X, 0, 0) — beam must rotate -PI/2 so its -Z points toward +X.
	var angle := ZivStunningLooks3D.aim_angle_to(Vector3.ZERO, Vector3(5.0, 0.0, 0.0))
	assert_almost_eq(angle, -PI / 2.0, 0.01,
		"target on +X axis must require beam rotation of -PI/2")

func test_aim_angle_to_non_zero_origin() -> void:
	# Same relative direction from two different origins → same angle.
	var a1 := ZivStunningLooks3D.aim_angle_to(Vector3.ZERO, Vector3(0.0, 0.0, -3.0))
	var a2 := ZivStunningLooks3D.aim_angle_to(Vector3(10.0, 0.0, 10.0), Vector3(10.0, 0.0, 7.0))
	assert_almost_eq(a1, a2, 0.01,
		"aim_angle_to must depend only on relative XZ direction, not absolute position")

func test_aim_angle_to_same_position_no_crash() -> void:
	# When from == to there is no meaningful direction; the key contract is no crash
	# and a finite result (the game never places an enemy at the weapon's exact origin).
	var angle := ZivStunningLooks3D.aim_angle_to(Vector3.ZERO, Vector3.ZERO)
	assert_true(is_finite(angle),
		"aim_angle_to with identical from/to must return a finite value without crashing")

# ═════════════════════════════════════════════════════════════════════════════
# Beam mesh height — visual must sit above the ground
# ═════════════════════════════════════════════════════════════════════════════

func test_beam_mesh_local_y_is_positive() -> void:
	var w := _make_weapon()
	var beam_mi: MeshInstance3D = null
	for child in w._beam.get_children():
		if child is MeshInstance3D:
			beam_mi = child as MeshInstance3D
			break
	assert_not_null(beam_mi, "Beam Area3D must contain a MeshInstance3D child")
	assert_gt(beam_mi.position.y, 0.0,
		"Beam visual mesh must have a positive local Y offset (torso height)")
