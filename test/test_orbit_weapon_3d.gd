# See docs/notes/weapon-orbit-3d.md
extends GutTest
## Unit tests for OrbitWeapon3D archetype and its per-skill subclasses.
##
## Physics-overlap (real Area3D hits) is manual-only.
## Everything here tests pure/scalar logic:
##   orbiter_offsets geometry, level_up/evolve state, apply_passive, per-skill defaults.

# ─────────────────────────────────────────────────────────────────────────────
# Stub enemy
# ─────────────────────────────────────────────────────────────────────────────
class StubEnemy extends Node3D:
	var damage_received: float = 0.0
	var hit_count: int = 0

	func _init() -> void:
		add_to_group("enemies")

	func take_damage(amount: float) -> void:
		damage_received += amount
		hit_count += 1

# ─────────────────────────────────────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────────────────────────────────────

func _make_stats(dmg: float = 1.0, rate: float = 1.0) -> StatBlock:
	var s := StatBlock.new()
	s.damage_mult    = dmg
	s.fire_rate_mult = rate
	return s

func _make_orbit_weapon() -> OrbitWeapon3D:
	var w: OrbitWeapon3D = add_child_autofree(OrbitWeapon3D.new()) as OrbitWeapon3D
	var player := add_child_autofree(Node3D.new()) as Node3D
	w.setup(player, _make_stats())
	return w

func _make_mirror_shards() -> ZivMirrorShards3D:
	var scene := load("res://weapons/ziv_mirror_shards_3d.tscn")
	assert_not_null(scene, "ziv_mirror_shards_3d.tscn must exist")
	var w: ZivMirrorShards3D = add_child_autofree(scene.instantiate()) as ZivMirrorShards3D
	var player := add_child_autofree(Node3D.new()) as Node3D
	w.setup(player, _make_stats())
	return w

func _make_group_call() -> AvihayGroupCall3D:
	var scene := load("res://weapons/avihay_group_call_3d.tscn")
	assert_not_null(scene, "avihay_group_call_3d.tscn must exist")
	var w: AvihayGroupCall3D = add_child_autofree(scene.instantiate()) as AvihayGroupCall3D
	var player := add_child_autofree(Node3D.new()) as Node3D
	w.setup(player, _make_stats())
	return w

func _make_mass_dm() -> AvihayMassDM3D:
	var scene := load("res://weapons/avihay_mass_dm_3d.tscn")
	assert_not_null(scene, "avihay_mass_dm_3d.tscn must exist")
	var w: AvihayMassDM3D = add_child_autofree(scene.instantiate()) as AvihayMassDM3D
	var player := add_child_autofree(Node3D.new()) as Node3D
	w.setup(player, _make_stats())
	return w

# ═════════════════════════════════════════════════════════════════════════════
# orbiter_offsets — pure geometry, no scene required
# ═════════════════════════════════════════════════════════════════════════════

func test_orbiter_offsets_returns_correct_count() -> void:
	var offsets: Array = OrbitWeapon3D.orbiter_offsets(5, 3.0, 0.0)
	assert_eq(offsets.size(), 5, "orbiter_offsets must return exactly count items")

func test_orbiter_offsets_zero_count_empty() -> void:
	var offsets: Array = OrbitWeapon3D.orbiter_offsets(0, 3.0, 0.0)
	assert_eq(offsets.size(), 0, "count=0 must return empty array")

func test_orbiter_offsets_all_at_correct_radius() -> void:
	var radius: float = 4.5
	var offsets: Array = OrbitWeapon3D.orbiter_offsets(6, radius, 0.0)
	for v in offsets:
		var pos: Vector3 = v as Vector3
		var dist: float = sqrt(pos.x * pos.x + pos.z * pos.z)
		assert_almost_eq(dist, radius, 0.001,
			"each orbiter must be exactly at orbit_radius from origin")

func test_orbiter_offsets_y_is_zero() -> void:
	var offsets: Array = OrbitWeapon3D.orbiter_offsets(4, 3.0, 0.0)
	for v in offsets:
		var pos: Vector3 = v as Vector3
		assert_almost_eq(pos.y, 0.0, 0.001, "orbiter Y must always be 0 (XZ plane)")

func test_orbiter_offsets_evenly_spaced() -> void:
	# Verify even spacing by checking that the dot product between consecutive
	# unit vectors is the same (cos of the expected angular gap = cos(TAU/count)).
	# This avoids the atan2 wrap-around issue at ±PI.
	var count: int = 4
	var offsets: Array = OrbitWeapon3D.orbiter_offsets(count, 3.0, 0.0)
	assert_eq(offsets.size(), count)
	var expected_cos: float = cos(TAU / float(count))
	for i: int in range(count):
		var a: Vector3 = (offsets[i] as Vector3).normalized()
		var b: Vector3 = (offsets[(i + 1) % count] as Vector3).normalized()
		var dot: float = a.dot(b)
		assert_almost_eq(dot, expected_cos, 0.001,
			"adjacent orbiters must subtend equal TAU/count angles")

func test_orbiter_offsets_phase_shifts_angles() -> void:
	var no_phase: Array = OrbitWeapon3D.orbiter_offsets(1, 3.0, 0.0)
	var with_phase: Array = OrbitWeapon3D.orbiter_offsets(1, 3.0, TAU / 4.0)
	var a: Vector3 = no_phase[0] as Vector3
	var b: Vector3 = with_phase[0] as Vector3
	# Expect rotation by 90°: x→z, z→-x (approximately)
	assert_almost_eq(b.x, -a.z, 0.001, "phase=PI/2 should rotate x by 90 degrees")
	assert_almost_eq(b.z,  a.x, 0.001, "phase=PI/2 should rotate z by 90 degrees")

func test_orbiter_offsets_single_orbiter_at_radius_along_x() -> void:
	# count=1, phase=0 → angle=0 → position = (radius, 0, 0)
	var offsets: Array = OrbitWeapon3D.orbiter_offsets(1, 5.0, 0.0)
	var pos: Vector3 = offsets[0] as Vector3
	assert_almost_eq(pos.x, 5.0, 0.001, "count=1 phase=0: x must equal radius")
	assert_almost_eq(pos.z, 0.0, 0.001, "count=1 phase=0: z must be 0")

# ═════════════════════════════════════════════════════════════════════════════
# OrbitWeapon3D base — level_up / evolve / apply_passive
# ═════════════════════════════════════════════════════════════════════════════

func test_level_up_increments_level() -> void:
	var w := _make_orbit_weapon()
	assert_eq(w.level, 1)
	w.level_up()
	assert_eq(w.level, 2)

func test_level_up_increases_orbit_count() -> void:
	var w := _make_orbit_weapon()
	var before: int = w.orbit_count
	w.level_up()
	assert_eq(w.orbit_count, before + 1, "level_up must add 1 orbiter")

func test_level_up_increases_damage_by_4() -> void:
	var w := _make_orbit_weapon()
	var before: float = w.damage
	w.level_up()
	assert_almost_eq(w.damage - before, 4.0, 0.001, "level_up must add 4 damage")

func test_level_up_rebuilds_orbiters() -> void:
	var w := _make_orbit_weapon()
	var before: int = w._orbiters.size()
	w.level_up()
	assert_eq(w._orbiters.size(), before + 1, "level_up must rebuild orbiters to match new count")

func test_evolve_sets_evolved_flag() -> void:
	var w := _make_orbit_weapon()
	w.evolve()
	assert_true(w.evolved, "evolve must set evolved=true")

func test_evolve_doubles_orbit_count() -> void:
	var w := _make_orbit_weapon()
	var before: int = w.orbit_count
	w.evolve()
	assert_eq(w.orbit_count, before * 2, "evolve must double orbit_count")

func test_evolve_increases_orbit_speed() -> void:
	var w := _make_orbit_weapon()
	var before: float = w.orbit_speed
	w.evolve()
	assert_gt(w.orbit_speed, before, "evolve must increase orbit_speed")

func test_apply_passive_increases_damage() -> void:
	var w := _make_orbit_weapon()
	var before: float = w.damage
	w.apply_passive(8.0)
	assert_almost_eq(w.damage, before + 8.0, 0.001, "apply_passive must add value to damage")

func test_apply_passive_stacks() -> void:
	var w := _make_orbit_weapon()
	var before: float = w.damage
	w.apply_passive(3.0)
	w.apply_passive(2.0)
	assert_almost_eq(w.damage, before + 5.0, 0.001, "apply_passive must stack additively")

func test_initial_orbiters_match_count() -> void:
	var w := _make_orbit_weapon()
	assert_eq(w._orbiters.size(), w.orbit_count,
		"_orbiters must be built to match orbit_count after setup")

# ═════════════════════════════════════════════════════════════════════════════
# Per-skill subclass defaults
# ═════════════════════════════════════════════════════════════════════════════

func test_mirror_shards_orbit_count() -> void:
	var w := _make_mirror_shards()
	assert_eq(w.orbit_count, 3, "MirrorShards must start with 3 shards")

func test_mirror_shards_damage() -> void:
	var w := _make_mirror_shards()
	assert_almost_eq(w.damage, 20.0, 0.001, "MirrorShards damage must be 20")

func test_group_call_orbit_count() -> void:
	var w := _make_group_call()
	assert_eq(w.orbit_count, 4, "GroupCall must start with 4 orbiters")

func test_group_call_damage() -> void:
	var w := _make_group_call()
	assert_almost_eq(w.damage, 15.0, 0.001, "GroupCall damage must be 15")

func test_mass_dm_orbit_count() -> void:
	var w := _make_mass_dm()
	assert_eq(w.orbit_count, 6, "MassDM must start with 6 orbiters")

func test_mass_dm_orbit_speed_fast() -> void:
	var w := _make_mass_dm()
	assert_almost_eq(w.orbit_speed, TAU, 0.001, "MassDM orbit_speed must be TAU (full rotation/s)")

func test_mass_dm_damage_lower() -> void:
	var w := _make_mass_dm()
	assert_almost_eq(w.damage, 9.0, 0.001, "MassDM damage must be 9")

# ═════════════════════════════════════════════════════════════════════════════
# Per-skill base_cooldown — subclass values must not be clobbered by archetype
# ═════════════════════════════════════════════════════════════════════════════

func test_mirror_shards_base_cooldown() -> void:
	var w := _make_mirror_shards()
	assert_almost_eq(w.base_cooldown, 2.0, 0.001, "MirrorShards base_cooldown must be 2.0")

func test_mass_dm_base_cooldown() -> void:
	var w := _make_mass_dm()
	assert_almost_eq(w.base_cooldown, 2.0, 0.001, "MassDM base_cooldown must be 2.0")

func test_group_call_base_cooldown() -> void:
	var w := _make_group_call()
	assert_almost_eq(w.base_cooldown, 2.5, 0.001, "GroupCall base_cooldown must be 2.5")

func test_orbit_archetype_base_cooldown_default() -> void:
	var w := _make_orbit_weapon()
	assert_almost_eq(w.base_cooldown, 2.5, 0.001, "OrbitWeapon3D direct base_cooldown must default to 2.5")

# ═════════════════════════════════════════════════════════════════════════════
# Scenes load and are Weapon3D
# ═════════════════════════════════════════════════════════════════════════════

func test_orbit_archetype_scene_loads() -> void:
	var scene := load("res://weapons/orbit_weapon_3d.tscn")
	assert_not_null(scene, "orbit_weapon_3d.tscn must load")

func test_orbit_archetype_instantiates_as_weapon3d() -> void:
	var scene := load("res://weapons/orbit_weapon_3d.tscn")
	var w = add_child_autofree(scene.instantiate())
	assert_true(w is Weapon3D, "OrbitWeapon3D must be a Weapon3D")

func test_mirror_shards_scene_loads() -> void:
	var scene := load("res://weapons/ziv_mirror_shards_3d.tscn")
	assert_not_null(scene, "ziv_mirror_shards_3d.tscn must load")

func test_group_call_scene_loads() -> void:
	var scene := load("res://weapons/avihay_group_call_3d.tscn")
	assert_not_null(scene, "avihay_group_call_3d.tscn must load")

func test_mass_dm_scene_loads() -> void:
	var scene := load("res://weapons/avihay_mass_dm_3d.tscn")
	assert_not_null(scene, "avihay_mass_dm_3d.tscn must load")

# ═════════════════════════════════════════════════════════════════════════════
# Orbiter visual height — mesh must sit above the ground
# ═════════════════════════════════════════════════════════════════════════════

func test_orbiter_visual_mesh_local_y_is_positive() -> void:
	var w := _make_orbit_weapon()
	assert_true(w._orbiters.size() > 0, "must have at least one orbiter to test")
	var orbiter: Area3D = w._orbiters[0]
	var mi: MeshInstance3D = null
	for child in orbiter.get_children():
		if child is MeshInstance3D:
			mi = child as MeshInstance3D
			break
	assert_not_null(mi, "orbiter Area3D must contain a MeshInstance3D child")
	assert_gt(mi.position.y, 0.0,
		"orbiter visual mesh must have a positive local Y offset (torso height)")
