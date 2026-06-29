# See docs/notes/player-3d.md
extends GutTest
## Unit tests for Player3D logic (leveling, damage, armor, stat upgrades, velocity mapping).
## Mirrors test_player.gd coverage against the CharacterBody3D implementation.

var Player3DScene = null

func before_all() -> void:
	Player3DScene = load("res://player/player_3d.tscn")

func _make_char_data(max_hp: float = 100.0, armor: float = 0.0, pickup_range: float = 48.0) -> CharacterData:
	var sb := StatBlock.new()
	sb.max_hp = max_hp
	sb.armor = armor
	sb.pickup_range = pickup_range
	sb.move_speed = 120.0
	var cd := CharacterData.new()
	cd.base_stats = sb
	# weapon_scene intentionally null — Player3D.setup() guards with: if data.weapon_scene
	return cd

func _make_player(max_hp: float = 100.0, armor: float = 0.0) -> Player3D:
	assert_not_null(Player3DScene, "player_3d.tscn must exist before running tests")
	var player: Player3D = add_child_autofree(Player3DScene.instantiate())
	player.setup(_make_char_data(max_hp, armor))
	return player

# ── move_to_velocity (pure static, no Input/tree needed) ─────────────────────

func test_move_to_velocity_up_maps_to_negative_z() -> void:
	var v := Player3D.move_to_velocity(Vector2(0.0, -1.0), 100.0)
	assert_almost_eq(v.x, 0.0, 0.001, "x should be 0")
	assert_almost_eq(v.y, 0.0, 0.001, "y must stay 0 (XZ plane)")
	assert_almost_eq(v.z, -100.0, 0.001, "'up' action maps to -Z")

func test_move_to_velocity_right_maps_to_positive_x() -> void:
	var v := Player3D.move_to_velocity(Vector2(1.0, 0.0), 120.0)
	assert_almost_eq(v.x, 120.0, 0.001, "'right' action maps to +X")
	assert_almost_eq(v.y, 0.0, 0.001, "y must stay 0")
	assert_almost_eq(v.z, 0.0, 0.001, "z should be 0")

func test_move_to_velocity_diagonal() -> void:
	var v := Player3D.move_to_velocity(Vector2(1.0, 1.0), 10.0)
	assert_almost_eq(v.x, 10.0, 0.001)
	assert_almost_eq(v.y, 0.0, 0.001, "y must stay 0")
	assert_almost_eq(v.z, 10.0, 0.001)

func test_move_to_velocity_zero_dir_gives_zero_vector() -> void:
	assert_eq(Player3D.move_to_velocity(Vector2.ZERO, 120.0), Vector3.ZERO)

# ── xp_to_next formula ──────────────────────────────────────────────────────

func test_xp_to_next_level1() -> void:
	var p := _make_player()
	assert_eq(p.xp_to_next(1), 4, "2 + 1 + 1*1 = 4")

func test_xp_to_next_level2() -> void:
	var p := _make_player()
	assert_eq(p.xp_to_next(2), 8, "2 + 2 + 2*2 = 8")

func test_xp_to_next_level3() -> void:
	var p := _make_player()
	assert_eq(p.xp_to_next(3), 14, "2 + 3 + 3*3 = 14")

func test_xp_to_next_level5() -> void:
	var p := _make_player()
	assert_eq(p.xp_to_next(5), 32, "2 + 5 + 5*5 = 32")

# ── add_xp leveling ──────────────────────────────────────────────────────────

func test_add_xp_exact_single_level_up() -> void:
	var p := _make_player()
	p.add_xp(4)  # xp_to_next(1) = 4 exactly
	assert_eq(p.level, 2, "Should advance to level 2")
	assert_eq(p.xp, 0, "No remainder after exact threshold")

func test_add_xp_multi_level_up_with_remainder() -> void:
	var p := _make_player()
	# level 1→2 costs 4, level 2→3 costs 8; total = 12; give 13 → 1 remainder
	p.add_xp(13)
	assert_eq(p.level, 3, "Should advance two levels")
	assert_eq(p.xp, 1, "Remainder 1 should carry over")

func test_add_xp_partial_no_level_up() -> void:
	var p := _make_player()
	p.add_xp(3)  # less than xp_to_next(1) = 4
	assert_eq(p.level, 1, "Should still be level 1")
	assert_eq(p.xp, 3, "XP should accumulate")

func test_add_xp_emits_player_leveled_up() -> void:
	var p := _make_player()
	watch_signals(GameEvents)
	p.add_xp(4)
	assert_signal_emitted(GameEvents, "player_leveled_up")

# ── take_damage ──────────────────────────────────────────────────────────────

func test_take_damage_subtracts_armor() -> void:
	var p := _make_player(100.0, 5.0)
	p.take_damage(20.0)  # dealt = max(0, 20 - 5) = 15
	assert_almost_eq(p.hp, 85.0, 0.001, "hp should be 85 after 15 dealt damage")

func test_take_damage_blocked_entirely_by_armor() -> void:
	var p := _make_player(100.0, 10.0)
	p.take_damage(5.0)  # dealt = max(0, 5 - 10) = 0
	assert_almost_eq(p.hp, 100.0, 0.001, "Armor fully blocks damage below armor value")

func test_take_damage_emits_player_hp_changed_with_values() -> void:
	var p := _make_player(100.0, 0.0)
	watch_signals(GameEvents)
	p.take_damage(30.0)  # hp: 100 → 70
	assert_signal_emitted_with_parameters(GameEvents, "player_hp_changed", [70.0, 100.0])

func test_take_damage_emits_player_died_at_zero() -> void:
	var p := _make_player(100.0, 0.0)
	watch_signals(GameEvents)
	p.take_damage(100.0)
	assert_signal_emitted(GameEvents, "player_died")

func test_take_damage_emits_player_died_on_overkill() -> void:
	var p := _make_player(100.0, 0.0)
	watch_signals(GameEvents)
	p.take_damage(999.0)
	assert_signal_emitted(GameEvents, "player_died")

# ── hp_regen ─────────────────────────────────────────────────────────────────

func test_hp_regen_heals_over_time() -> void:
	var p := _make_player(100.0, 0.0)
	p.stats.hp_regen = 10.0
	p.take_damage(50.0)               # hp 100 → 50
	p._physics_process(1.0)           # +10/s × 1s → 60
	assert_almost_eq(p.hp, 60.0, 0.001)

func test_hp_regen_does_not_overheal_past_max() -> void:
	var p := _make_player(100.0, 0.0)
	p.stats.hp_regen = 10.0
	p.take_damage(5.0)                # hp 100 → 95
	p._physics_process(2.0)           # +20 would overshoot; clamps to 100
	assert_almost_eq(p.hp, 100.0, 0.001)

func test_hp_regen_zero_is_a_noop() -> void:
	var p := _make_player(100.0, 0.0)
	p.stats.hp_regen = 0.0
	p.take_damage(30.0)              # hp 100 → 70
	p._physics_process(5.0)
	assert_almost_eq(p.hp, 70.0, 0.001)

func test_hp_regen_does_not_revive_dead_player() -> void:
	var p := _make_player(100.0, 0.0)
	p.stats.hp_regen = 10.0
	p.take_damage(100.0)             # hp → 0
	p._physics_process(1.0)
	assert_true(p.hp <= 0.0, "regen must not heal a player at/below 0 hp")

func test_all_characters_define_positive_hp_regen() -> void:
	for id in ["ziv", "avihay", "avinoam", "barak", "ido", "matan", "natali", "yinon", "yoav", "yuval"]:
		var cd: CharacterData = load("res://characters/%s_3d.tres" % id)
		assert_not_null(cd, "%s_3d.tres must load" % id)
		assert_true(cd.base_stats.hp_regen > 0.0, "%s must define a base hp_regen > 0" % id)

# ── get_pickup_range ─────────────────────────────────────────────────────────

func test_get_pickup_range_matches_stat() -> void:
	var p := _make_player()
	assert_almost_eq(p.get_pickup_range(), 48.0, 0.001)

# ── setup() ──────────────────────────────────────────────────────────────────

func test_setup_emits_initial_player_hp_changed() -> void:
	var player: Player3D = add_child_autofree(Player3DScene.instantiate())
	watch_signals(GameEvents)
	player.setup(_make_char_data(80.0, 0.0))
	assert_signal_emitted_with_parameters(GameEvents, "player_hp_changed", [80.0, 80.0])

func test_setup_null_weapon_scene_leaves_weapon_null() -> void:
	var p := _make_player()
	assert_null(p.weapon, "weapon must remain null when weapon_scene is null")

# ── apply_stat_upgrade ───────────────────────────────────────────────────────

func test_apply_stat_upgrade_move_speed() -> void:
	var p := _make_player()
	var before := p.stats.move_speed
	p.apply_stat_upgrade(&"move_speed", 10.0)
	assert_almost_eq(p.stats.move_speed, before + 10.0, 0.001)

func test_apply_stat_upgrade_max_hp_raises_stat_and_current_hp() -> void:
	var p := _make_player(100.0, 0.0)
	watch_signals(GameEvents)
	p.apply_stat_upgrade(&"max_hp", 20.0)
	assert_almost_eq(p.stats.max_hp, 120.0, 0.001)
	assert_almost_eq(p.hp, 120.0, 0.001)
	assert_signal_emitted(GameEvents, "player_hp_changed")

func test_apply_stat_upgrade_pickup_range() -> void:
	var p := _make_player()
	p.apply_stat_upgrade(&"pickup_range", 5.0)
	assert_almost_eq(p.stats.pickup_range, 53.0, 0.001)

func test_apply_stat_upgrade_fire_rate() -> void:
	var p := _make_player()
	var before := p.stats.fire_rate_mult
	p.apply_stat_upgrade(&"fire_rate", 0.5)
	assert_almost_eq(p.stats.fire_rate_mult, before + 0.5, 0.001)

func test_apply_stat_upgrade_damage() -> void:
	var p := _make_player()
	var before := p.stats.damage_mult
	p.apply_stat_upgrade(&"damage", 0.2)
	assert_almost_eq(p.stats.damage_mult, before + 0.2, 0.001)

func test_apply_stat_upgrade_armor() -> void:
	var p := _make_player()
	p.apply_stat_upgrade(&"armor", 3.0)
	assert_almost_eq(p.stats.armor, 3.0, 0.001)

# ── face_angle (pure static, no Input/tree needed) ───────────────────────────

func test_face_angle_positive_x_velocity() -> void:
	var angle := Player3D.face_angle(Vector3(1.0, 0.0, 0.0))
	assert_almost_eq(angle, atan2(1.0, 0.0), 0.001, "+X velocity heading")

func test_face_angle_positive_z_velocity() -> void:
	var angle := Player3D.face_angle(Vector3(0.0, 0.0, 1.0))
	assert_almost_eq(angle, atan2(0.0, 1.0), 0.001, "+Z velocity heading")

func test_face_angle_diagonal() -> void:
	var angle := Player3D.face_angle(Vector3(1.0, 0.0, 1.0))
	assert_almost_eq(angle, atan2(1.0, 1.0), 0.001, "diagonal XZ velocity heading")

func test_face_angle_negative_x_velocity() -> void:
	var angle := Player3D.face_angle(Vector3(-1.0, 0.0, 0.0))
	assert_almost_eq(angle, atan2(-1.0, 0.0), 0.001, "-X velocity heading")

func test_face_angle_zero_velocity_returns_zero_not_nan() -> void:
	var angle := Player3D.face_angle(Vector3.ZERO)
	assert_almost_eq(angle, 0.0, 0.001, "zero velocity returns 0.0 (no NaN)")

# ── model integration tests ───────────────────────────────────────────────────

func _make_char_data_with_model(model_path: String = "res://art/characters_3d/kenney_blocky_characters/models/character-a.glb") -> CharacterData:
	var cd := _make_char_data()
	cd.model_scene = load(model_path)
	cd.model_scale = 1.0
	return cd

func test_setup_with_model_hides_capsule_placeholder() -> void:
	var player: Player3D = add_child_autofree(Player3DScene.instantiate())
	player.setup(_make_char_data_with_model())
	var placeholder := player.get_node_or_null("Model/MeshInstance3D") as MeshInstance3D
	assert_not_null(placeholder, "MeshInstance3D placeholder must still exist in scene")
	assert_false(placeholder.visible, "placeholder capsule must be hidden after model setup")

func test_setup_with_model_adds_instance_under_model_node() -> void:
	var player: Player3D = add_child_autofree(Player3DScene.instantiate())
	player.setup(_make_char_data_with_model())
	var model_node := player.get_node("Model") as Node3D
	# Model node should have: original MeshInstance3D + the instanced GLB scene
	assert_true(model_node.get_child_count() > 1, "instanced model was added under Model node")

func test_setup_with_model_finds_animation_player() -> void:
	var player: Player3D = add_child_autofree(Player3DScene.instantiate())
	player.setup(_make_char_data_with_model())
	assert_not_null(player._anim_player, "AnimationPlayer must be found inside the Kenney GLB")

func test_setup_without_model_leaves_placeholder_visible() -> void:
	var player: Player3D = add_child_autofree(Player3DScene.instantiate())
	player.setup(_make_char_data())  # no model_scene
	var placeholder := player.get_node_or_null("Model/MeshInstance3D") as MeshInstance3D
	assert_not_null(placeholder)
	assert_true(placeholder.visible, "placeholder stays visible when no model_scene is set")

func test_setup_without_model_anim_player_stays_null() -> void:
	var player: Player3D = add_child_autofree(Player3DScene.instantiate())
	player.setup(_make_char_data())  # no model_scene
	assert_null(player._anim_player, "_anim_player must stay null when model_scene is unset")

func test_setup_with_model_texture_applies_albedo_texture_to_mesh_surfaces() -> void:
	## After setup() with a CharacterData that has model_texture set (Ziv = texture-a.png),
	## every MeshInstance3D surface override material inside the instanced model must have
	## albedo_texture != null. This catches the pure-white render bug where GLBs had no
	## albedo_texture and the skin atlas was never wired up.
	var cd := _make_char_data_with_model()
	cd.model_texture = load("res://art/characters_3d/kenney_blocky_characters/textures/texture-a.png")
	assert_not_null(cd.model_texture, "texture-a.png must be loadable")
	var player: Player3D = add_child_autofree(Player3DScene.instantiate())
	player.setup(cd)
	# Walk the Model subtree and verify at least one MeshInstance3D surface override material
	# has albedo_texture set — proves _apply_texture() ran.
	var model_node := player.get_node("Model") as Node3D
	var found_textured_surface := false
	var queue: Array = [model_node]
	while queue.size() > 0:
		var n: Node = queue.pop_front()
		if n is MeshInstance3D:
			var mi := n as MeshInstance3D
			if mi.mesh:
				for i in mi.mesh.get_surface_count():
					var mat: Material = mi.get_surface_override_material(i)
					if mat is StandardMaterial3D:
						if (mat as StandardMaterial3D).albedo_texture != null:
							found_textured_surface = true
		for child in n.get_children():
			queue.push_back(child)
	assert_true(found_textured_surface, "At least one MeshInstance3D surface must have albedo_texture set after setup() with model_texture")

# ── multi-weapon (SkillSystem wiring) ────────────────────────────────────────

## Stub weapon: records calls, implements Weapon3D's public interface as Node3D.
class StubWeapon3D extends Node3D:
	var level_up_called := false
	var evolve_called   := false
	var passive_val     := 0.0
	var refresh_count   := 0
	func setup(_p, _s) -> void: pass
	func level_up()            -> void: level_up_called = true
	func evolve()              -> void: evolve_called   = true
	func apply_passive(v: float) -> void: passive_val = v
	func refresh_cooldown()    -> void: refresh_count += 1


func _make_weapon_scene_from_stub() -> PackedScene:
	var stub := StubWeapon3D.new()
	var ps   := PackedScene.new()
	ps.pack(stub)
	stub.free()
	return ps


func _make_player_with_stats() -> Player3D:
	var player: Player3D = add_child_autofree(Player3DScene.instantiate())
	var cd := _make_char_data(100.0)
	# Use empty skills so setup() doesn't auto-attach a weapon (skills-based flow).
	player.setup(cd)
	return player


func test_acquire_skill_adds_weapon_to_weapons_dict() -> void:
	var player := _make_player_with_stats()
	var ps     := _make_weapon_scene_from_stub()
	player.acquire_skill(&"test_skill", ps)
	assert_true(player.weapons.has(&"test_skill"),
		"acquire_skill must add the weapon to weapons[skill_id]")


func test_acquire_skill_sets_convenience_weapon_on_first_call() -> void:
	var player := _make_player_with_stats()
	var ps     := _make_weapon_scene_from_stub()
	player.acquire_skill(&"skill_a", ps)
	assert_not_null(player.weapon,
		"weapon convenience pointer must be set after first acquire_skill")


func test_acquire_two_skills_both_in_weapons_dict() -> void:
	var player := _make_player_with_stats()
	var ps1    := _make_weapon_scene_from_stub()
	var ps2    := _make_weapon_scene_from_stub()
	player.acquire_skill(&"alpha", ps1)
	player.acquire_skill(&"beta",  ps2)
	assert_true(player.weapons.has(&"alpha"), "weapons must contain alpha")
	assert_true(player.weapons.has(&"beta"),  "weapons must contain beta")
	assert_eq(player.weapons.size(), 2, "weapons dict must have exactly 2 entries")


func test_acquire_skill_duplicate_is_noop() -> void:
	var player := _make_player_with_stats()
	var ps     := _make_weapon_scene_from_stub()
	player.acquire_skill(&"dup", ps)
	var first_weapon = player.weapons[&"dup"]  # untyped — Dictionary returns Variant
	player.acquire_skill(&"dup", ps)
	assert_eq(player.weapons[&"dup"], first_weapon,
		"Duplicate acquire_skill must not replace existing weapon")
	assert_eq(player.weapons.size(), 1, "Duplicate must not add a second entry")


func test_has_skill_returns_true_after_acquire() -> void:
	var player := _make_player_with_stats()
	var ps     := _make_weapon_scene_from_stub()
	player.acquire_skill(&"charm", ps)
	assert_true(player.has_skill(&"charm"), "has_skill must return true after acquire")


func test_has_skill_returns_false_before_acquire() -> void:
	var player := _make_player_with_stats()
	assert_false(player.has_skill(&"charm"),
		"has_skill must return false before acquire")


func test_level_skill_calls_weapon_level_up() -> void:
	var player := _make_player_with_stats()
	var ps     := _make_weapon_scene_from_stub()
	player.acquire_skill(&"sk", ps)
	var stub := player.weapons[&"sk"] as StubWeapon3D
	player.level_skill(&"sk")
	assert_true(stub.level_up_called, "level_skill must call weapon.level_up()")


func test_level_skill_noop_when_not_owned() -> void:
	var player := _make_player_with_stats()
	# Should not crash:
	player.level_skill(&"nonexistent")
	assert_true(true, "level_skill on unknown skill_id must not crash")


func test_apply_skill_passive_calls_apply_passive() -> void:
	var player := _make_player_with_stats()
	var ps     := _make_weapon_scene_from_stub()
	player.acquire_skill(&"sk", ps)
	var stub := player.weapons[&"sk"] as StubWeapon3D
	player.apply_skill_passive(&"sk", 0.75)
	assert_almost_eq(stub.passive_val, 0.75, 0.001,
		"apply_skill_passive must forward value to weapon.apply_passive()")


func test_evolve_skill_calls_evolve() -> void:
	var player := _make_player_with_stats()
	var ps     := _make_weapon_scene_from_stub()
	player.acquire_skill(&"sk", ps)
	var stub := player.weapons[&"sk"] as StubWeapon3D
	player.evolve_skill(&"sk")
	assert_true(stub.evolve_called, "evolve_skill must call weapon.evolve()")


func test_fire_rate_stat_upgrade_refreshes_all_weapons() -> void:
	var player := _make_player_with_stats()
	var ps1    := _make_weapon_scene_from_stub()
	var ps2    := _make_weapon_scene_from_stub()
	player.acquire_skill(&"w1", ps1)
	player.acquire_skill(&"w2", ps2)
	var stub1 := player.weapons[&"w1"] as StubWeapon3D
	var stub2 := player.weapons[&"w2"] as StubWeapon3D
	player.apply_stat_upgrade(&"fire_rate", 0.5)
	assert_true(stub1.refresh_count > 0,
		"fire_rate upgrade must call refresh_cooldown on weapon w1")
	assert_true(stub2.refresh_count > 0,
		"fire_rate upgrade must call refresh_cooldown on weapon w2")


# ── invulnerability (post-levelup i-frames) ─────────────────────────────────

func test_set_invulnerable_makes_is_invulnerable_true() -> void:
	var p := _make_player()
	p.set_invulnerable(2.0)
	assert_true(p.is_invulnerable(), "is_invulnerable must return true after set_invulnerable(2.0)")

func test_is_invulnerable_false_by_default() -> void:
	var p := _make_player()
	assert_false(p.is_invulnerable(), "player must not be invulnerable at start")

func test_take_damage_ignored_while_invulnerable() -> void:
	var p := _make_player(100.0, 0.0)
	p.set_invulnerable(2.0)
	p.take_damage(50.0)
	assert_almost_eq(p.hp, 100.0, 0.001, "HP must not change while invulnerable")

func test_take_damage_does_not_emit_hp_changed_while_invulnerable() -> void:
	var p := _make_player(100.0, 0.0)
	p.set_invulnerable(2.0)
	watch_signals(GameEvents)
	p.take_damage(50.0)
	assert_signal_not_emitted(GameEvents, "player_hp_changed",
		"player_hp_changed must not emit while invulnerable")

func test_take_damage_does_not_emit_player_died_while_invulnerable() -> void:
	var p := _make_player(100.0, 0.0)
	p.set_invulnerable(2.0)
	watch_signals(GameEvents)
	p.take_damage(999.0)
	assert_signal_not_emitted(GameEvents, "player_died",
		"player_died must not emit while invulnerable")

func test_take_damage_applies_after_invuln_expires() -> void:
	var p := _make_player(100.0, 0.0)
	p.set_invulnerable(0.1)
	# Drive the timer past zero via _physics_process
	p._physics_process(0.2)
	assert_false(p.is_invulnerable(), "invuln must have expired after driving timer to 0")
	p.take_damage(30.0)
	assert_almost_eq(p.hp, 70.0, 0.001, "damage must apply once invuln expires")

func test_set_invulnerable_takes_max_smaller_second_call() -> void:
	var p := _make_player()
	p.set_invulnerable(2.0)
	p.set_invulnerable(1.0)
	# Timer should remain at 2.0 (or very close, no time has passed)
	assert_true(p._invuln_timer > 1.5,
		"set_invulnerable(1.0) after 2.0 must keep 2.0 (max semantics)")

func test_set_invulnerable_takes_max_larger_second_call() -> void:
	var p := _make_player()
	p.set_invulnerable(1.0)
	p.set_invulnerable(2.0)
	assert_almost_eq(p._invuln_timer, 2.0, 0.001,
		"set_invulnerable(2.0) after 1.0 must raise timer to 2.0")

func test_model_visible_restored_when_invuln_ends() -> void:
	var p := _make_player()
	p.set_invulnerable(0.05)
	# Drive past the timer so blink logic runs and then invuln ends
	p._physics_process(0.1)
	var model := p.get_node_or_null("Model") as Node3D
	assert_not_null(model, "Model node must exist")
	assert_true(model.visible,
		"Model must be visible again after invulnerability ends")

# ── heal() ───────────────────────────────────────────────────────────────────

func test_heal_increases_hp() -> void:
	var p := _make_player(100.0, 0.0)
	p.take_damage(40.0)  # hp → 60
	var before := p.hp
	p.heal(10.0)
	assert_almost_eq(p.hp, before + 10.0, 0.001, "heal() must increase hp by the given amount")

func test_heal_clamped_to_max_hp() -> void:
	var p := _make_player(100.0, 0.0)
	p.take_damage(5.0)  # hp → 95
	p.heal(20.0)        # would be 115 without clamp
	assert_almost_eq(p.hp, 100.0, 0.001, "heal() must not push hp above max_hp")

func test_heal_at_max_hp_stays_at_max() -> void:
	var p := _make_player(100.0, 0.0)
	# hp already at max — heal should keep it there
	p.heal(10.0)
	assert_almost_eq(p.hp, 100.0, 0.001, "heal() must not overheal beyond max_hp")

func test_heal_emits_player_hp_changed() -> void:
	var p := _make_player(100.0, 0.0)
	p.take_damage(30.0)  # hp → 70
	watch_signals(GameEvents)
	p.heal(5.0)
	assert_signal_emitted(GameEvents, "player_hp_changed",
		"heal() must emit player_hp_changed so the HUD updates")

func test_heal_emits_correct_values() -> void:
	var p := _make_player(100.0, 0.0)
	p.take_damage(30.0)  # hp → 70
	watch_signals(GameEvents)
	p.heal(10.0)         # hp → 80
	assert_signal_emitted_with_parameters(GameEvents, "player_hp_changed", [80.0, 100.0])

# ── backward_single_weapon_fallback ─────────────────────────────────────────

func test_backward_single_weapon_fallback_when_skills_empty() -> void:
	# When CharacterData.skills is empty AND weapon_scene is set, the old single-weapon
	# flow must still work so pre-migration tests and legacy configs stay green.
	var player: Player3D = add_child_autofree(Player3DScene.instantiate())
	var cd     := _make_char_data()
	cd.weapon_scene = load("res://weapons/ziv_stunning_looks_3d.tscn")
	# skills defaults to [] since we use _make_char_data (no skills set).
	player.setup(cd)
	assert_not_null(player.weapon,
		"Legacy fallback: weapon must be set when skills is empty and weapon_scene is set")
	assert_true(player.weapon is Node3D,
		"Legacy fallback weapon must be a Node3D")
