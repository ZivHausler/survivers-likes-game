# See docs/notes/enemy-3d.md
extends GutTest
## Unit tests for Enemy3D — mirrors test_enemy.gd coverage against CharacterBody3D.
## Physics-process helpers are called directly (headless); move_and_slide() is a no-op
## without a live physics world, so we inspect velocity before it would be consumed.
## Phase 2 additions: model loading path (model_scene), face_angle() static helper.

## Stub target with a recordable take_damage method.
class StubTarget extends Node3D:
	var damage_log: Array = []
	func take_damage(amount: float) -> void:
		damage_log.append(amount)

var Enemy3DScene = null

func before_all() -> void:
	Enemy3DScene = load("res://enemies/enemy_3d.tscn")

func _make_data(max_hp: float = 20.0, xp: int = 3, is_ranged: bool = false) -> EnemyData:
	var d := EnemyData.new()
	d.id = &"test_enemy_3d"
	d.color = Color.RED
	d.max_hp = max_hp
	d.move_speed = 5.0
	d.contact_damage = 4.0
	d.xp_value = xp
	d.is_ranged = is_ranged
	d.radius = 0.5
	return d

func _make_enemy(max_hp: float = 20.0, xp: int = 3, is_ranged: bool = false) -> Enemy3D:
	assert_not_null(Enemy3DScene, "enemy_3d.tscn must exist")
	var e: Enemy3D = add_child_autofree(Enemy3DScene.instantiate()) as Enemy3D
	var target: Node3D = add_child_autofree(Node3D.new()) as Node3D
	e.setup(_make_data(max_hp, xp, is_ranged), target)
	return e

# ── setup sets hp ────────────────────────────────────────────────────────────

func test_setup_sets_hp_to_max_hp() -> void:
	var e: Enemy3D = _make_enemy(30.0)
	assert_almost_eq(e.hp, 30.0, 0.001, "hp should equal data.max_hp after setup")

# ── knockback (hop-back) ──────────────────────────────────────────────────────

func test_apply_knockback_sets_window_and_velocity() -> void:
	var e: Enemy3D = _make_enemy()
	e.apply_knockback(Vector3(1.0, 0.0, 0.0), 2.5)
	assert_almost_eq(e._knockback_timer, Enemy3D.KNOCKBACK_DURATION, 0.001,
		"apply_knockback must start the hop window")
	# Speed carries `distance` over the window: |vel| == distance / duration.
	assert_almost_eq(e._knockback_vel.length(), 2.5 / Enemy3D.KNOCKBACK_DURATION, 0.01,
		"knockback speed must deliver the requested distance across the window")
	assert_almost_eq(e._knockback_vel.y, 0.0, 0.001, "knockback velocity stays on XZ")

func test_apply_knockback_moves_enemy_outward() -> void:
	var e: Enemy3D = _make_enemy()
	e.global_position = Vector3.ZERO
	e.apply_knockback(Vector3(1.0, 0.0, 0.0), 2.5)
	for i in range(20):
		await get_tree().physics_frame
	assert_gt(e.global_position.x, 0.5, "enemy must travel outward along the knockback direction")

func test_knockback_does_not_weaken_existing_stronger_hop() -> void:
	var e: Enemy3D = _make_enemy()
	e.apply_knockback(Vector3(1.0, 0.0, 0.0), 4.0)
	var strong := e._knockback_vel.length()
	e.apply_knockback(Vector3(1.0, 0.0, 0.0), 1.0)  # weaker, mid-hop
	assert_almost_eq(e._knockback_vel.length(), strong, 0.001,
		"a weaker overlapping knockback must not reduce an active stronger one")

func test_knockback_settles_model_on_ground_after_window() -> void:
	var e: Enemy3D = _make_enemy()
	e.apply_knockback(Vector3(1.0, 0.0, 0.0), 2.5)
	for i in range(20):
		await get_tree().physics_frame
	assert_almost_eq(e._knockback_timer, 0.0, 0.001, "hop window must elapse")
	assert_almost_eq(e._model.position.y, 0.0, 0.001, "model must settle flush with the ground")

func test_mini_boss_is_immune_to_knockback() -> void:
	var e: Enemy3D = _make_enemy()
	e.configure_boss(Enemy3D.BossKind.MINI)
	e.apply_knockback(Vector3(1.0, 0.0, 0.0), 2.5)
	assert_almost_eq(e._knockback_timer, 0.0, 0.001, "mini-boss must not enter the knockback window")
	assert_almost_eq(e._knockback_vel.length(), 0.0, 0.001, "mini-boss must get no knockback velocity")

func test_big_boss_is_immune_to_knockback() -> void:
	var e: Enemy3D = _make_enemy()
	e.configure_boss(Enemy3D.BossKind.BIG)
	e.apply_knockback(Vector3(1.0, 0.0, 0.0), 2.5)
	assert_almost_eq(e._knockback_timer, 0.0, 0.001, "big boss must not enter the knockback window")

func test_normal_enemy_still_knocked_back() -> void:
	# Guard: the boss immunity must not accidentally block regular monsters.
	var e: Enemy3D = _make_enemy()
	assert_eq(e.boss_kind, Enemy3D.BossKind.NONE, "regular enemy defaults to non-boss")
	e.apply_knockback(Vector3(1.0, 0.0, 0.0), 2.5)
	assert_gt(e._knockback_timer, 0.0, "regular monster must still be knocked back")

# ── steer_velocity static helper ──────────────────────────────────────────────

func test_steer_velocity_toward_positive_x() -> void:
	var v := Enemy3D.steer_velocity(Vector3.ZERO, Vector3(10.0, 0.0, 0.0), 5.0)
	assert_almost_eq(v.x, 5.0, 0.001, "x velocity should be speed")
	assert_almost_eq(v.y, 0.0, 0.001, "y must stay 0 (XZ plane)")
	assert_almost_eq(v.z, 0.0, 0.001, "z should be 0")

func test_steer_velocity_toward_positive_z() -> void:
	var v := Enemy3D.steer_velocity(Vector3.ZERO, Vector3(0.0, 0.0, 10.0), 5.0)
	assert_almost_eq(v.x, 0.0, 0.001, "x should be 0")
	assert_almost_eq(v.y, 0.0, 0.001, "y must stay 0")
	assert_almost_eq(v.z, 5.0, 0.001, "z velocity should be speed")

func test_steer_velocity_y_always_zero_even_with_height_difference() -> void:
	var v := Enemy3D.steer_velocity(Vector3(0.0, 0.0, 0.0), Vector3(0.0, 10.0, 5.0), 5.0)
	assert_almost_eq(v.y, 0.0, 0.001, "y must always be 0 regardless of height difference")

func test_steer_velocity_diagonal_is_normalized_times_speed() -> void:
	var v := Enemy3D.steer_velocity(Vector3.ZERO, Vector3(10.0, 0.0, 10.0), 5.0)
	var expected_component := 5.0 / sqrt(2.0)
	assert_almost_eq(v.x, expected_component, 0.01, "diagonal x normalized × speed")
	assert_almost_eq(v.z, expected_component, 0.01, "diagonal z normalized × speed")
	assert_almost_eq(v.y, 0.0, 0.001, "y must stay 0")

func test_steer_velocity_same_position_returns_zero() -> void:
	var v := Enemy3D.steer_velocity(Vector3(1.0, 0.0, 1.0), Vector3(1.0, 0.0, 1.0), 5.0)
	assert_eq(v, Vector3.ZERO, "zero distance → zero velocity")

func test_steer_velocity_zero_speed_returns_zero() -> void:
	var v := Enemy3D.steer_velocity(Vector3.ZERO, Vector3(5.0, 0.0, 0.0), 0.0)
	assert_eq(v, Vector3.ZERO, "zero speed → zero velocity")

# ── charm suppresses movement ─────────────────────────────────────────────────

func test_charm_stacks_by_max() -> void:
	var e: Enemy3D = _make_enemy()
	e.charm(2.0)
	e.charm(1.0)  # shorter, should not reduce timer
	assert_almost_eq(e._charm_timer, 2.0, 0.001, "charm stacks by taking the max")

func test_charm_keeps_velocity_zero_while_active() -> void:
	var e: Enemy3D = _make_enemy()
	e.charm(1.0)
	e.target.global_position = Vector3(5.0, 0.0, 0.0)
	e._physics_process(0.1)  # 0.9 s charm remaining
	assert_eq(e.velocity, Vector3.ZERO, "velocity must be zero while charmed")

func test_charm_expires_enemy_moves_toward_target() -> void:
	var e: Enemy3D = _make_enemy()
	e.charm(0.5)
	e.target.global_position = Vector3(10.0, 0.0, 0.0)
	# Tick past charm expiry — 0.6 s > 0.5 s charm
	e._physics_process(0.6)
	assert_true(e.velocity.x > 0.0, "enemy should move toward +X after charm expires")
	assert_almost_eq(e.velocity.y, 0.0, 0.001, "y velocity must stay 0 after charm")

# ── contact damage ────────────────────────────────────────────────────────────

func test_contact_damage_called_when_in_range() -> void:
	var e: Enemy3D = add_child_autofree(Enemy3DScene.instantiate()) as Enemy3D
	var stub: StubTarget = add_child_autofree(StubTarget.new()) as StubTarget
	e.setup(_make_data(20.0, 3), stub)
	# Both at origin → dist = 0 < CONTACT_RANGE = 1.5
	e._physics_process(0.016)
	assert_eq(stub.damage_log.size(), 1, "take_damage should be called once")
	assert_almost_eq(stub.damage_log[0], 4.0, 0.001, "contact_damage value should match data")

func test_contact_damage_cooldown_prevents_immediate_repeat() -> void:
	var e: Enemy3D = add_child_autofree(Enemy3DScene.instantiate()) as Enemy3D
	var stub: StubTarget = add_child_autofree(StubTarget.new()) as StubTarget
	e.setup(_make_data(20.0, 3), stub)
	e._physics_process(0.016)  # first hit
	e._physics_process(0.016)  # cooldown not elapsed (0.5 s)
	assert_eq(stub.damage_log.size(), 1, "second tick within cooldown must not deal damage")

func test_contact_damage_fires_again_after_cooldown_elapses() -> void:
	var e: Enemy3D = add_child_autofree(Enemy3DScene.instantiate()) as Enemy3D
	var stub: StubTarget = add_child_autofree(StubTarget.new()) as StubTarget
	e.setup(_make_data(20.0, 3), stub)
	e._physics_process(0.016)   # first hit, _contact_cd = 0.5
	e._physics_process(0.5)     # advances cd to 0 exactly: max(0, 0.5 - 0.5) = 0 → second hit
	assert_eq(stub.damage_log.size(), 2, "second hit should fire after cooldown elapses")

# ── take_damage / death ───────────────────────────────────────────────────────

func test_take_damage_reduces_hp() -> void:
	var e: Enemy3D = _make_enemy(20.0)
	e.take_damage(7.0)
	assert_almost_eq(e.hp, 13.0, 0.001, "hp should be 13 after 7 damage on 20hp enemy")

func test_nonlethal_damage_does_not_emit_enemy_killed_3d() -> void:
	var e: Enemy3D = _make_enemy(20.0, 3)
	watch_signals(GameEvents)
	e.take_damage(10.0)
	assert_signal_not_emitted(GameEvents, "enemy_killed_3d")

func test_nonlethal_damage_does_not_free_node() -> void:
	var e: Enemy3D = _make_enemy(20.0)
	e.take_damage(5.0)
	assert_true(is_instance_valid(e), "enemy should still be alive after non-lethal damage")

func test_lethal_damage_emits_enemy_killed_3d() -> void:
	var e: Enemy3D = _make_enemy(20.0, 3)
	watch_signals(GameEvents)
	e.take_damage(20.0)
	assert_signal_emitted(GameEvents, "enemy_killed_3d")

func test_lethal_damage_emits_correct_xp_value() -> void:
	var e: Enemy3D = _make_enemy(20.0, 7)
	var expected_pos: Vector3 = e.global_position
	watch_signals(GameEvents)
	e.take_damage(25.0)
	assert_signal_emitted_with_parameters(GameEvents, "enemy_killed_3d", [expected_pos, 7])

func test_overkill_emits_enemy_killed_3d() -> void:
	var e: Enemy3D = _make_enemy(20.0, 3)
	watch_signals(GameEvents)
	e.take_damage(999.0)
	assert_signal_emitted(GameEvents, "enemy_killed_3d")

func test_lethal_damage_frees_node() -> void:
	var e: Enemy3D = _make_enemy(20.0)
	e.take_damage(20.0)
	await get_tree().process_frame
	assert_false(is_instance_valid(e), "enemy should be freed after lethal damage")

# ── proxy routing → host arbitration (Task E2, M3) ────────────────────────────

## Stub manager recording client_deal_damage() calls; duck-typed for the proxy branch
## in Enemy3D.take_damage (the real GameManager3D.client_deal_damage RPCs to the host).
class StubNetManager3D extends Node:
	var calls: Array = []  # each entry: [net_id, amount]
	func client_deal_damage(net_id: int, amount: float) -> void:
		calls.append([net_id, amount])

func test_proxy_take_damage_forwards_to_net_manager_and_leaves_hp_unchanged() -> void:
	var e: Enemy3D = _make_enemy(20.0)
	e._is_proxy = true
	e.net_id = 42
	var mgr := StubNetManager3D.new()
	e._net_manager = mgr
	var hp_before := e.hp

	e.take_damage(7.0)

	assert_eq(mgr.calls.size(), 1, "proxy take_damage must forward exactly once to the net manager")
	assert_eq(mgr.calls[0][0], 42, "forwarded call must carry the proxy's net_id")
	assert_almost_eq(mgr.calls[0][1], 7.0, 0.001, "forwarded call must carry the damage amount")
	assert_almost_eq(e.hp, hp_before, 0.001, "proxy take_damage must NOT change hp locally")

func test_proxy_take_damage_does_not_emit_enemy_killed_3d() -> void:
	var e: Enemy3D = _make_enemy(5.0)  # low hp — a real enemy would die from 7.0 damage
	e._is_proxy = true
	e.net_id = 1
	e._net_manager = StubNetManager3D.new()
	watch_signals(GameEvents)

	e.take_damage(7.0)

	assert_signal_not_emitted(GameEvents, "enemy_killed_3d")

# ── null / freed-target guards ────────────────────────────────────────────────

func test_physics_process_before_setup_does_not_crash() -> void:
	var e: Enemy3D = add_child_autofree(Enemy3DScene.instantiate()) as Enemy3D
	e._physics_process(0.016)
	assert_true(true, "no crash when _physics_process runs before setup()")

func test_physics_process_with_freed_target_does_not_crash() -> void:
	var e: Enemy3D = add_child_autofree(Enemy3DScene.instantiate()) as Enemy3D
	var doomed: Node3D = Node3D.new()
	add_child(doomed)
	e.setup(_make_data(20.0, 3), doomed)
	doomed.free()
	e._physics_process(0.016)
	assert_true(true, "no crash when _physics_process runs with a freed target")

# ── ranged stand-off ──────────────────────────────────────────────────────────
# NOTE: Ranged movement (kite approach/retreat/hold) is fully covered by
# test/test_ranged_attack.gd (kite_velocity + _can_fire + cooldown gating).
# The old inline RANGED_STANDOFF logic no longer applies to is_ranged enemies —
# they now delegate to RangedAttack.desired_velocity() which kites by attack_range.

func test_ranged_enemy_outside_standoff_moves_toward_target() -> void:
	# A plain melee enemy beyond RANGED_STANDOFF must still chase the target.
	var e: Enemy3D = add_child_autofree(Enemy3DScene.instantiate()) as Enemy3D
	var target: Node3D = add_child_autofree(Node3D.new()) as Node3D
	e.setup(_make_data(20.0, 3, false), target)
	# Place target 10 units away — beyond RANGED_STANDOFF (6.0)
	target.global_position = Vector3(10.0, 0.0, 0.0)
	e._physics_process(0.016)
	assert_true(e.velocity.x > 0.0, "melee enemy beyond stand-off should move toward target")

# ── face_angle() static helper ────────────────────────────────────────────────

func test_face_angle_positive_x_velocity() -> void:
	var angle := Enemy3D.face_angle(Vector3(1.0, 0.0, 0.0))
	assert_almost_eq(angle, atan2(1.0, 0.0), 0.001, "facing +X → atan2(1,0)")

func test_face_angle_positive_z_velocity() -> void:
	var angle := Enemy3D.face_angle(Vector3(0.0, 0.0, 1.0))
	assert_almost_eq(angle, atan2(0.0, 1.0), 0.001, "facing +Z → atan2(0,1)")

func test_face_angle_zero_velocity_returns_zero() -> void:
	var angle := Enemy3D.face_angle(Vector3.ZERO)
	assert_almost_eq(angle, 0.0, 0.001, "zero velocity must return 0.0 (never NaN)")

func test_face_angle_negative_x_velocity() -> void:
	var angle := Enemy3D.face_angle(Vector3(-1.0, 0.0, 0.0))
	assert_almost_eq(angle, atan2(-1.0, 0.0), 0.001, "facing -X → atan2(-1,0)")

func test_face_angle_y_component_ignored() -> void:
	# Y is irrelevant; should give same as XZ-only vector.
	var a1 := Enemy3D.face_angle(Vector3(1.0, 0.0, 0.0))
	var a2 := Enemy3D.face_angle(Vector3(1.0, 999.0, 0.0))
	assert_almost_eq(a1, a2, 0.001, "Y component must not affect the heading angle")

# ── model_scene loading path ───────────────────────────────────────────────────

func _make_data_with_model() -> EnemyData:
	var d := _make_data()
	d.model_scene = load("res://art/enemies_3d/bug/bug_mesh.glb") as PackedScene
	d.model_scale = 1.0
	d.model_y_offset = 0.0
	return d

func test_model_setup_hides_placeholder() -> void:
	assert_not_null(Enemy3DScene, "enemy_3d.tscn must exist")
	var e: Enemy3D = add_child_autofree(Enemy3DScene.instantiate()) as Enemy3D
	var target: Node3D = add_child_autofree(Node3D.new()) as Node3D
	e.setup(_make_data_with_model(), target)
	var placeholder := e.get_node_or_null("Model/MeshInstance3D") as MeshInstance3D
	assert_not_null(placeholder, "Model/MeshInstance3D node must still exist in scene")
	assert_false(placeholder.visible, "placeholder MeshInstance3D must be hidden when model_scene is set")

func test_model_setup_adds_child_under_model() -> void:
	assert_not_null(Enemy3DScene, "enemy_3d.tscn must exist")
	var e: Enemy3D = add_child_autofree(Enemy3DScene.instantiate()) as Enemy3D
	var target: Node3D = add_child_autofree(Node3D.new()) as Node3D
	e.setup(_make_data_with_model(), target)
	var model_node := e.get_node_or_null("Model") as Node3D
	assert_not_null(model_node, "Model node must exist")
	# Model should have at least 2 children: the placeholder and the new model instance.
	assert_true(model_node.get_child_count() > 1,
			"Model must have the placeholder + at least one instanced model child")

func test_caster_model_resolves_attack_clip_and_plays_gesture() -> void:
	# Ghost (archer) is a self-contained Quaternius GLB with a Punch/Headbutt attack clip.
	assert_not_null(Enemy3DScene, "enemy_3d.tscn must exist")
	var e: Enemy3D = add_child_autofree(Enemy3DScene.instantiate()) as Enemy3D
	var target: Node3D = add_child_autofree(Node3D.new()) as Node3D
	var d := _make_data()
	d.model_scene = load("res://art/enemies_3d/ghost/ghost_mesh.glb") as PackedScene
	e.setup(d, target)
	assert_ne(e._clip_attack, "", "caster model must resolve an attack/cast gesture clip")
	e.play_attack_gesture(0.5)
	assert_true(e._attack_anim_left > 0.0, "play_attack_gesture arms the gesture lock")
	if e._anim_player:
		assert_eq(e._anim_player.current_animation, e._clip_attack,
			"AnimationPlayer is playing the attack gesture clip")

func test_play_attack_gesture_noops_without_attack_clip() -> void:
	# Bug mesh has no attack clip → gesture must safely no-op (no crash, no lock).
	var e: Enemy3D = add_child_autofree(Enemy3DScene.instantiate()) as Enemy3D
	var target: Node3D = add_child_autofree(Node3D.new()) as Node3D
	e.setup(_make_data_with_model(), target)
	e.play_attack_gesture(0.5)
	assert_eq(e._attack_anim_left, 0.0, "no attack clip → gesture lock stays unarmed")

func test_no_model_scene_keeps_placeholder_visible() -> void:
	assert_not_null(Enemy3DScene, "enemy_3d.tscn must exist")
	var e: Enemy3D = add_child_autofree(Enemy3DScene.instantiate()) as Enemy3D
	var target: Node3D = add_child_autofree(Node3D.new()) as Node3D
	# Use data without model_scene (default nil).
	e.setup(_make_data(), target)
	var placeholder := e.get_node_or_null("Model/MeshInstance3D") as MeshInstance3D
	assert_not_null(placeholder, "placeholder must exist when no model_scene")
	assert_true(placeholder.visible, "placeholder must remain visible when model_scene is null")

func test_no_model_scene_tints_placeholder_by_color() -> void:
	assert_not_null(Enemy3DScene, "enemy_3d.tscn must exist")
	var e: Enemy3D = add_child_autofree(Enemy3DScene.instantiate()) as Enemy3D
	var target: Node3D = add_child_autofree(Node3D.new()) as Node3D
	var d := _make_data()
	d.color = Color.BLUE
	e.setup(d, target)
	var placeholder := e.get_node_or_null("Model/MeshInstance3D") as MeshInstance3D
	assert_not_null(placeholder, "placeholder must exist")
	assert_not_null(placeholder.material_override, "material_override must be set for color tint")
	var mat := placeholder.material_override as StandardMaterial3D
	assert_not_null(mat, "material_override must be a StandardMaterial3D")
	assert_eq(mat.albedo_color, Color.BLUE, "albedo_color must match data.color")

# ── BUG B: skeletal "move" animation retargeting ──────────────────────────────
# The skinned mesh GLB (bug_mesh.glb) imports its rig as a Skeleton3D, but the
# separate animation GLB (bug_run.glb) keys node-path tracks (RootNode/bug_body/…).
# retarget_tracks_to_skeleton() rewrites those onto skeleton bones so the walk plays.

func test_find_skeleton_locates_skinned_skeleton_in_bug_mesh() -> void:
	var mesh_ps := load("res://art/enemies_3d/bug/bug_mesh.glb") as PackedScene
	var mesh_inst: Node = autofree(mesh_ps.instantiate())
	var skel := Enemy3D.find_skeleton(mesh_inst)
	assert_not_null(skel, "bug_mesh.glb must import a Skeleton3D")
	assert_true(skel.get_bone_count() > 0, "skeleton must expose bones")

func test_retarget_tracks_maps_node_paths_onto_skeleton_bones() -> void:
	var mesh_ps := load("res://art/enemies_3d/bug/bug_mesh.glb") as PackedScene
	var mesh_inst: Node = autofree(mesh_ps.instantiate())
	var skel := Enemy3D.find_skeleton(mesh_inst)
	assert_not_null(skel, "bug_mesh.glb must import a Skeleton3D")

	var run_ps := load("res://art/enemies_3d/bug/bug_run.glb") as PackedScene
	var run_inst: Node = autofree(run_ps.instantiate())
	var src_ap := run_inst.find_child("AnimationPlayer", true, false) as AnimationPlayer
	assert_not_null(src_ap, "bug_run.glb must carry an AnimationPlayer")
	var names := src_ap.get_animation_list()
	assert_false(names.is_empty(), "bug_run.glb must contain at least one animation")
	var anim: Animation = (src_ap.get_animation(names[0]) as Animation).duplicate(true)

	# Pre-condition: raw tracks are node paths with no :bone subname (the bug).
	assert_eq(anim.track_get_path(0).get_concatenated_subnames(), "",
			"raw imported track must be a node path, not a bone track")

	var kept := Enemy3D.retarget_tracks_to_skeleton(anim, skel, NodePath("RootNode/Skeleton3D"))
	assert_true(kept > 0, "at least one track must retarget onto a bone")
	# Every surviving track must address a real bone via its subname.
	for t in range(anim.get_track_count()):
		var p := anim.track_get_path(t)
		var sub := p.get_concatenated_subnames()
		assert_true(skel.find_bone(sub) != -1,
				"track %d must target a real bone, got path %s" % [t, p])

func test_bug_model_setup_loads_retargeted_move_animation() -> void:
	var e: Enemy3D = add_child_autofree(Enemy3DScene.instantiate()) as Enemy3D
	var target: Node3D = add_child_autofree(Node3D.new()) as Node3D
	e.setup(_make_data_with_model(), target)
	assert_true(e._anim_loaded, "bug model should load a 'move' animation")
	assert_not_null(e._anim_player, "anim player must be set after model load")
	assert_true(e._anim_player.has_animation("move"), "'move' animation must be present")
	var anim := e._anim_player.get_animation("move")
	var skel := Enemy3D.find_skeleton(e._model_inst)
	assert_not_null(skel, "model instance must contain a Skeleton3D")
	assert_true(anim.get_track_count() > 0, "retargeted 'move' must keep tracks")
	# Resolve each track exactly as AnimationMixer does: the node portion must resolve
	# from the player's root_node, and the subname must be a real bone. This is precisely
	# the check whose failure produced the "couldn't resolve track" warning spam.
	var anim_root: Node = e._anim_player.get_node(e._anim_player.root_node)
	assert_not_null(anim_root, "AnimationPlayer.root_node must resolve to a node")
	for t in range(anim.get_track_count()):
		var p := anim.track_get_path(t)
		var node_path := NodePath(p.get_concatenated_names())
		var resolved := anim_root.get_node_or_null(node_path)
		assert_true(resolved is Skeleton3D,
				"track %d node path %s must resolve to the Skeleton3D" % [t, p])
		assert_true(skel.find_bone(p.get_concatenated_subnames()) != -1,
				"track %d must target a real bone, got %s" % [t, p])

# ── boss tagging + HP feedback ────────────────────────────────────────────────

func test_default_enemy_boss_kind_is_none() -> void:
	var e: Enemy3D = _make_enemy()
	assert_eq(e.boss_kind, Enemy3D.BossKind.NONE, "normal enemy defaults to BossKind.NONE")

func test_normal_enemy_has_no_health_bar_child() -> void:
	var e: Enemy3D = _make_enemy()
	assert_null(e._health_bar, "normal enemy must not own a HealthBar3D")

func test_configure_big_boss_emits_boss_spawned_with_max_hp() -> void:
	var e: Enemy3D = _make_enemy(500.0)
	watch_signals(GameEvents)
	e.configure_boss(Enemy3D.BossKind.BIG, "Undead Serpent")
	assert_eq(e.boss_kind, Enemy3D.BossKind.BIG, "boss_kind set to BIG")
	assert_signal_emitted_with_parameters(GameEvents, "boss_spawned", ["Undead Serpent", 500.0])

func test_big_boss_nonlethal_damage_emits_boss_hp_changed() -> void:
	var e: Enemy3D = _make_enemy(500.0)
	e.configure_boss(Enemy3D.BossKind.BIG, "Undead Serpent")
	watch_signals(GameEvents)
	e.take_damage(120.0)  # 500 → 380, non-lethal
	assert_signal_emitted_with_parameters(GameEvents, "boss_hp_changed", [380.0, 500.0])

func test_big_boss_lethal_damage_emits_boss_died() -> void:
	var e: Enemy3D = _make_enemy(100.0)
	e.configure_boss(Enemy3D.BossKind.BIG, "Undead Serpent")
	watch_signals(GameEvents)
	e.take_damage(100.0)  # lethal
	assert_signal_emitted(GameEvents, "boss_died")

func test_configure_mini_boss_creates_health_bar_at_full() -> void:
	var e: Enemy3D = _make_enemy(200.0)
	e.configure_boss(Enemy3D.BossKind.MINI)
	assert_eq(e.boss_kind, Enemy3D.BossKind.MINI, "boss_kind set to MINI")
	assert_not_null(e._health_bar, "mini-boss must own a HealthBar3D child")
	assert_almost_eq(e._health_bar._fill_pivot.scale.x, 1.0, 0.001, "bar starts full")

func test_mini_boss_nonlethal_damage_updates_bar_ratio() -> void:
	var e: Enemy3D = _make_enemy(200.0)
	e.configure_boss(Enemy3D.BossKind.MINI)
	e.take_damage(50.0)  # 200 → 150 → ratio 0.75
	assert_almost_eq(e._health_bar._fill_pivot.scale.x, 0.75, 0.001, "bar fill tracks hp/max")

func test_normal_enemy_damage_emits_no_boss_signals() -> void:
	var e: Enemy3D = _make_enemy(50.0)
	watch_signals(GameEvents)
	e.take_damage(10.0)
	assert_signal_not_emitted(GameEvents, "boss_hp_changed")
	assert_signal_not_emitted(GameEvents, "boss_died")

# ── boss death → boss_killed_3d (drives boss-only screen shake) ────────────────

func test_mini_boss_death_emits_boss_killed_3d() -> void:
	var e: Enemy3D = _make_enemy(50.0)
	e.configure_boss(Enemy3D.BossKind.MINI)
	watch_signals(GameEvents)
	e.take_damage(50.0)  # lethal
	assert_signal_emitted_with_parameters(GameEvents, "boss_killed_3d", [Enemy3D.BossKind.MINI])

func test_big_boss_death_emits_boss_killed_3d() -> void:
	var e: Enemy3D = _make_enemy(50.0)
	e.configure_boss(Enemy3D.BossKind.BIG, "Undead Serpent")
	watch_signals(GameEvents)
	e.take_damage(50.0)  # lethal
	assert_signal_emitted_with_parameters(GameEvents, "boss_killed_3d", [Enemy3D.BossKind.BIG])

func test_normal_enemy_death_does_not_emit_boss_killed_3d() -> void:
	var e: Enemy3D = _make_enemy(20.0)
	watch_signals(GameEvents)
	e.take_damage(20.0)  # lethal
	assert_signal_not_emitted(GameEvents, "boss_killed_3d")
