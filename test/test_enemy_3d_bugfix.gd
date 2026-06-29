## Tests for playtest bug fixes: BUG A (white rendering) and BUG B (slide/no-animation).
## BUG A: Enemy3D.setup() now applies data.color as an albedo tint to all MeshInstance3D
##        surfaces of the real model, mirroring the boss-tint approach in Spawner3D.
## BUG B: A procedural alive-bob is always applied while moving (guaranteed fallback);
##        compute_bob_offset() is a pure static helper tested independently.
extends GutTest

var Enemy3DScene: PackedScene = null

func before_all() -> void:
	Enemy3DScene = load("res://enemies/enemy_3d.tscn")

# ── Helpers ───────────────────────────────────────────────────────────────────

func _make_data_no_model(col: Color = Color.WHITE) -> EnemyData:
	var d := EnemyData.new()
	d.id = &"test_bugfix"
	d.color = col
	d.max_hp = 10.0
	d.move_speed = 5.0
	d.contact_damage = 2.0
	d.xp_value = 1
	d.is_ranged = false
	d.radius = 0.5
	return d

func _make_data_with_model(col: Color = Color(0.2, 0.8, 0.2, 1.0)) -> EnemyData:
	var d := _make_data_no_model(col)
	d.model_scene = load("res://art/enemies_3d/bug/bug_mesh.glb") as PackedScene
	d.model_scale = 1.0
	d.model_y_offset = 0.0
	return d

## Recursively collect all MeshInstance3D nodes under `root` (including root itself).
static func _collect_mesh_instances(root: Node, out: Array) -> void:
	if root is MeshInstance3D:
		out.append(root as MeshInstance3D)
	for child in root.get_children():
		_collect_mesh_instances(child, out)

# ── BUG A: albedo tint applied to real model surfaces ─────────────────────────

func test_model_scene_applies_albedo_tint_at_least_one_surface() -> void:
	assert_not_null(Enemy3DScene, "enemy_3d.tscn must exist")
	var e: Enemy3D = add_child_autofree(Enemy3DScene.instantiate()) as Enemy3D
	var tgt: Node3D = add_child_autofree(Node3D.new()) as Node3D
	var tint := Color(0.2, 0.8, 0.2, 1.0)
	var d := _make_data_with_model(tint)
	e.setup(d, tgt)

	# Walk the model subtree to find at least one tinted surface.
	var model_node := e.get_node_or_null("Model") as Node3D
	assert_not_null(model_node, "Model node must exist")
	var mesh_instances: Array = []
	_collect_mesh_instances(model_node, mesh_instances)
	# Filter to visible meshes with an override material (tint was applied).
	var tinted: Array = []
	for mi: MeshInstance3D in mesh_instances:
		if not mi.visible:
			continue
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var mat: Material = mi.get_surface_override_material(i)
			if mat is BaseMaterial3D:
				tinted.append(mat)
	assert_true(tinted.size() > 0,
			"At least one surface must have an override BaseMaterial3D after tint")

func test_model_scene_tint_matches_data_color() -> void:
	assert_not_null(Enemy3DScene, "enemy_3d.tscn must exist")
	var e: Enemy3D = add_child_autofree(Enemy3DScene.instantiate()) as Enemy3D
	var tgt: Node3D = add_child_autofree(Node3D.new()) as Node3D
	var tint := Color(0.15, 0.4, 0.9, 1.0)
	var d := _make_data_with_model(tint)
	e.setup(d, tgt)

	var model_node := e.get_node_or_null("Model") as Node3D
	assert_not_null(model_node, "Model node must exist")
	var mesh_instances: Array = []
	_collect_mesh_instances(model_node, mesh_instances)
	var found_match := false
	for mi: MeshInstance3D in mesh_instances:
		if not mi.visible or mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var mat: Material = mi.get_surface_override_material(i)
			if mat is BaseMaterial3D:
				var bm := mat as BaseMaterial3D
				if bm.albedo_color.is_equal_approx(tint):
					found_match = true
	assert_true(found_match,
			"At least one surface override material must have albedo_color matching data.color")

func test_no_model_scene_placeholder_still_tinted() -> void:
	## Regression guard: the no-model-scene placeholder path must still work.
	assert_not_null(Enemy3DScene, "enemy_3d.tscn must exist")
	var e: Enemy3D = add_child_autofree(Enemy3DScene.instantiate()) as Enemy3D
	var tgt: Node3D = add_child_autofree(Node3D.new()) as Node3D
	var tint := Color(0.55, 0.15, 0.1, 1.0)
	var d := _make_data_no_model(tint)
	e.setup(d, tgt)
	var placeholder := e.get_node_or_null("Model/MeshInstance3D") as MeshInstance3D
	assert_not_null(placeholder, "placeholder must exist when no model_scene")
	assert_not_null(placeholder.material_override, "placeholder must have a material_override")
	var mat := placeholder.material_override as StandardMaterial3D
	assert_not_null(mat, "material_override must be a StandardMaterial3D")
	assert_eq(mat.albedo_color, tint, "placeholder albedo_color must match data.color")

# ── BUG B: compute_bob_offset static helper ────────────────────────────────────

func test_compute_bob_offset_zero_when_speed_ratio_zero() -> void:
	var result := Enemy3D.compute_bob_offset(0.0, PI / 2.0, 0.04)
	assert_almost_eq(result, 0.0, 0.0001,
			"bob offset must be 0 when speed_ratio is 0 (enemy stopped)")

func test_compute_bob_offset_zero_when_amplitude_zero() -> void:
	var result := Enemy3D.compute_bob_offset(1.0, PI / 2.0, 0.0)
	assert_almost_eq(result, 0.0, 0.0001,
			"bob offset must be 0 when amplitude is 0")

func test_compute_bob_offset_positive_at_quarter_cycle() -> void:
	## sin(PI/2) = 1.0; full speed + positive phase → positive offset.
	var result := Enemy3D.compute_bob_offset(1.0, PI / 2.0, 0.04)
	assert_almost_eq(result, 0.04, 0.0001,
			"bob offset at peak phase (PI/2) with full speed must equal amplitude")

func test_compute_bob_offset_negative_at_three_quarter_cycle() -> void:
	## sin(3*PI/2) = -1.0; full speed → negative offset (downward bob).
	var result := Enemy3D.compute_bob_offset(1.0, 3.0 * PI / 2.0, 0.04)
	assert_almost_eq(result, -0.04, 0.0001,
			"bob offset at trough phase (3PI/2) with full speed must equal -amplitude")

func test_compute_bob_offset_half_speed_halves_amplitude() -> void:
	## Half speed_ratio → half amplitude at peak.
	var result := Enemy3D.compute_bob_offset(0.5, PI / 2.0, 0.04)
	assert_almost_eq(result, 0.02, 0.0001,
			"bob offset at half speed_ratio must be half of amplitude")

func test_compute_bob_offset_at_zero_phase_is_zero() -> void:
	## sin(0) = 0 regardless of speed or amplitude.
	var result := Enemy3D.compute_bob_offset(1.0, 0.0, 0.04)
	assert_almost_eq(result, 0.0, 0.0001,
			"bob offset at phase=0 must be 0 (sin(0)=0)")

func test_compute_bob_offset_full_cycle_returns_near_zero() -> void:
	## sin(2*PI) ≈ 0; full cycle brings the model back to rest.
	var result := Enemy3D.compute_bob_offset(1.0, TAU, 0.04)
	assert_almost_eq(result, 0.0, 0.0001,
			"bob offset after a full cycle (phase=TAU) must be near 0")

# ── BUG B: _model_inst cached after model setup ────────────────────────────────

func test_model_inst_is_cached_after_setup_with_model() -> void:
	assert_not_null(Enemy3DScene, "enemy_3d.tscn must exist")
	var e: Enemy3D = add_child_autofree(Enemy3DScene.instantiate()) as Enemy3D
	var tgt: Node3D = add_child_autofree(Node3D.new()) as Node3D
	e.setup(_make_data_with_model(), tgt)
	assert_not_null(e._model_inst, "_model_inst must be set after setup with a model_scene")

func test_model_inst_null_when_no_model_scene() -> void:
	assert_not_null(Enemy3DScene, "enemy_3d.tscn must exist")
	var e: Enemy3D = add_child_autofree(Enemy3DScene.instantiate()) as Enemy3D
	var tgt: Node3D = add_child_autofree(Node3D.new()) as Node3D
	e.setup(_make_data_no_model(), tgt)
	assert_null(e._model_inst, "_model_inst must remain null when no model_scene is set")
