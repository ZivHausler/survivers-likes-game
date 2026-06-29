# See docs/notes/spawner-3d.md
class_name Spawner3D extends Node3D
## Wave spawner (3D) — instances enemies on a ring around the target.
## Driven by DifficultyTimeline; call setup(target) to activate.
## Mirrors Spawner (Node2D) behavior verbatim; 1 unit ≈ 16 px scale applied.
##
## Normal enemies: HP and scale grow with time; move_speed rescaled to 3D world units.
## Mini-boss: tank ×8 HP (×hp_mult) ×3 scale — every 180 s window.
## Big boss:  tank ×40 HP (×hp_mult) ×5 scale — at t=600 (once).

const ENEMY_SCENE_PATH := "res://enemies/enemy_3d.tscn"
const SWARMER_PATH     := "res://enemies/swarmer.tres"
const TANK_PATH        := "res://enemies/tank.tres"
const SPITTER_PATH     := "res://enemies/spitter.tres"

const SPAWN_RING_RADIUS: float = 25.0       # 400 px / 16
const WORLD_SCALE:       float = 1.0 / 16.0 # 1 world unit ≈ 16 px

const BOSS_HP_MULT:    float = 8.0
const BOSS_SCALE_MULT: float = 3.0
const BOSS_XP_VALUE:   int   = 50

const BIG_BOSS_HP_MULT:    float = 40.0
const BIG_BOSS_SCALE_MULT: float = 5.0
const BIG_BOSS_XP_VALUE:   int   = 200

var _target: Node3D
var _timeline: DifficultyTimeline
var _elapsed: float = 0.0
var _spawn_cd: float = 0.0
var _active: bool = false

var _enemy_scene: PackedScene
var _variants: Dictionary  # StringName → EnemyData


# ── Pure static helpers (testable without a scene tree) ───────────────────────

## Returns the point on a ring of `radius` at `angle` around `origin` on the XZ plane.
## y is always 0. Called by _random_ring_position() and unit tests.
static func ring_position(origin: Vector3, angle: float, radius: float) -> Vector3:
	return origin + Vector3(cos(angle), 0.0, sin(angle)) * radius


## Duplicates `base` and scales HP + move_speed for a normal spawn.
## Never mutates the source .tres resource.
static func scale_enemy_data(base: EnemyData, hp_mult: float) -> EnemyData:
	var d: EnemyData = base.duplicate() as EnemyData
	d.max_hp = int(d.max_hp * hp_mult)
	d.move_speed *= WORLD_SCALE
	return d


## Duplicates `base` and applies mini-boss multipliers + move_speed rescale.
## Never mutates the source .tres resource.
static func boss_enemy_data(base: EnemyData, hp_mult: float) -> EnemyData:
	var d: EnemyData = base.duplicate() as EnemyData
	d.max_hp = int(d.max_hp * BOSS_HP_MULT * hp_mult)
	d.xp_value = BOSS_XP_VALUE
	d.move_speed *= WORLD_SCALE
	return d


## Duplicates `base` and applies big-boss multipliers + move_speed rescale.
## Never mutates the source .tres resource.
static func big_boss_enemy_data(base: EnemyData, hp_mult: float) -> EnemyData:
	var d: EnemyData = base.duplicate() as EnemyData
	d.max_hp = int(d.max_hp * BIG_BOSS_HP_MULT * hp_mult)
	d.xp_value = BIG_BOSS_XP_VALUE
	d.move_speed *= WORLD_SCALE
	return d


# ── Instance methods ──────────────────────────────────────────────────────────

func setup(target: Node3D) -> void:
	_target = target
	_timeline = DifficultyTimeline.new()
	_elapsed  = 0.0
	_spawn_cd = 0.0

	_enemy_scene = load(ENEMY_SCENE_PATH) as PackedScene

	_variants = {
		&"swarmer": load(SWARMER_PATH) as EnemyData,
		&"tank":    load(TANK_PATH)    as EnemyData,
		&"spitter": load(SPITTER_PATH) as EnemyData,
	}

	_active = true


func _process(dt: float) -> void:
	if not _active:
		return
	if not is_instance_valid(_target):
		return

	_elapsed  += dt
	_spawn_cd -= dt

	var state: Dictionary = _timeline.state_at(_elapsed)

	# ── big boss (10-min, fires once) ─────────────────────────────────────────
	if state.big_boss_due:
		_spawn_big_boss(state.hp_mult)
		_timeline.mark_big_boss_spawned()

	# ── mini-boss ──────────────────────────────────────────────────────────────
	if state.boss_due:
		_spawn_boss(state.hp_mult)
		_timeline.mark_boss_spawned()

	# ── normal spawn ──────────────────────────────────────────────────────────
	if _spawn_cd <= 0.0:
		_spawn_normal(state.allowed_variants, state.hp_mult, state.enemy_scale)
		_spawn_cd = state.spawn_interval


func _spawn_normal(allowed: Array, hp_mult: float, scale_mult: float) -> void:
	if allowed.is_empty() or _enemy_scene == null:
		return
	var id: StringName = allowed[randi() % allowed.size()]
	var data: EnemyData = _variants.get(id)
	if data == null:
		return
	var scaled_data: EnemyData = scale_enemy_data(data, hp_mult)
	_instance_enemy(scaled_data, scale_mult)


func _spawn_boss(hp_mult: float) -> void:
	var data: EnemyData = _variants.get(&"tank")
	if data == null:
		return
	var boss_data: EnemyData = boss_enemy_data(data, hp_mult)
	var boss: Enemy3D = _instance_enemy(boss_data, BOSS_SCALE_MULT)
	if boss != null:
		# ORDERING DEPENDENCY: tint MUST run after _instance_enemy() (which calls
		# enemy.setup()). setup() sets material_override on "Model/MeshInstance3D";
		# we intentionally overwrite it here with the boss tint. The node path
		# "Model/MeshInstance3D" matches the structure of enemy_3d.tscn.
		var mesh_inst := boss.get_node_or_null("Model/MeshInstance3D") as MeshInstance3D
		if mesh_inst != null:
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color(1.0, 0.15, 0.1, 1.0)
			mesh_inst.material_override = mat


func _spawn_big_boss(hp_mult: float) -> void:
	var data: EnemyData = _variants.get(&"tank")
	if data == null:
		return
	var big_data: EnemyData = big_boss_enemy_data(data, hp_mult)
	var boss: Enemy3D = _instance_enemy(big_data, BIG_BOSS_SCALE_MULT)
	if boss != null:
		# ORDERING DEPENDENCY: tint MUST run after _instance_enemy() (which calls
		# enemy.setup()). setup() sets material_override on "Model/MeshInstance3D";
		# we intentionally overwrite it here with the big-boss tint. The node path
		# "Model/MeshInstance3D" matches the structure of enemy_3d.tscn.
		var mesh_inst := boss.get_node_or_null("Model/MeshInstance3D") as MeshInstance3D
		if mesh_inst != null:
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color(0.5, 0.0, 1.0, 1.0)
			mesh_inst.material_override = mat


func _instance_enemy(data: EnemyData, scale_mult: float) -> Enemy3D:
	if _enemy_scene == null:
		return null
	var enemy: Enemy3D = _enemy_scene.instantiate() as Enemy3D
	var parent := get_parent()
	assert(parent != null, "Spawner3D must not be the scene root")
	parent.add_child(enemy)
	enemy.add_to_group("enemies")
	enemy.global_position = _random_ring_position()
	enemy.scale = Vector3.ONE * scale_mult
	enemy.setup(data, _target)
	return enemy


func _random_ring_position() -> Vector3:
	var angle: float = randf() * TAU
	var origin: Vector3 = _target.global_position if is_instance_valid(_target) else global_position
	return ring_position(origin, angle, SPAWN_RING_RADIUS)
