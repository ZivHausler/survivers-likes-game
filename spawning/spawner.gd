# See docs/notes/spawner.md
class_name Spawner extends Node2D
## Wave spawner — instances enemies on a ring around the target.
## Driven by DifficultyTimeline; call setup(target) to activate.
##
## Mini-boss: a tank with ×8 HP and ×3 visual scale — spawned once per
## 300 s window as reported by DifficultyTimeline.boss_due.

const ENEMY_SCENE_PATH := "res://enemies/enemy.tscn"
const SWARMER_PATH     := "res://enemies/swarmer.tres"
const TANK_PATH        := "res://enemies/tank.tres"
const SPITTER_PATH     := "res://enemies/spitter.tres"

const SPAWN_RING_RADIUS: float = 400.0
const BOSS_HP_MULT:    float = 8.0
const BOSS_SCALE_MULT: float = 3.0
const BOSS_XP_VALUE:   int   = 50

var _target: Node2D
var _timeline: DifficultyTimeline
var _elapsed: float = 0.0
var _spawn_cd: float = 0.0
var _active: bool = false

# Pre-loaded resources
var _enemy_scene: PackedScene
var _variants: Dictionary  # StringName → EnemyData


func setup(target: Node2D) -> void:
	_target = target
	_timeline = DifficultyTimeline.new()
	_elapsed  = 0.0
	_spawn_cd = 0.0

	_enemy_scene = load(ENEMY_SCENE_PATH) as PackedScene

	var swarmer: EnemyData = load(SWARMER_PATH) as EnemyData
	var tank:    EnemyData = load(TANK_PATH)    as EnemyData
	var spitter: EnemyData = load(SPITTER_PATH) as EnemyData
	_variants = {
		&"swarmer": swarmer,
		&"tank":    tank,
		&"spitter": spitter,
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

	# ── boss ──────────────────────────────────────────────────────────────────
	if state.boss_due:
		_spawn_boss()
		_timeline.mark_boss_spawned()

	# ── normal spawn ──────────────────────────────────────────────────────────
	if _spawn_cd <= 0.0:
		_spawn_normal(state.allowed_variants)
		_spawn_cd = state.spawn_interval


func _spawn_normal(allowed: Array) -> void:
	if allowed.is_empty() or _enemy_scene == null:
		return
	var id: StringName = allowed[randi() % allowed.size()]
	var data: EnemyData = _variants.get(id)
	if data == null:
		return
	_instance_enemy(data, 1.0)


func _spawn_boss() -> void:
	var data: EnemyData = _variants.get(&"tank")
	if data == null:
		return
	# Duplicate so we can mutate HP/xp_value without touching the shared resource
	var boss_data: EnemyData = data.duplicate() as EnemyData
	boss_data.max_hp *= BOSS_HP_MULT
	boss_data.xp_value = BOSS_XP_VALUE
	var boss: Enemy = _instance_enemy(boss_data, BOSS_SCALE_MULT)
	# Boss visual: menacing red tint on the sprite (visual only — HP/scale untouched).
	if boss != null:
		var sprite := boss.get_node_or_null("Sprite") as Sprite2D
		if sprite != null and sprite.visible:
			sprite.modulate = Color(1.0, 0.15, 0.1, 1.0)


func _instance_enemy(data: EnemyData, scale_mult: float) -> Enemy:
	var enemy: Enemy = _enemy_scene.instantiate() as Enemy
	# Add to the same parent so the enemy persists beyond this node's lifetime
	var parent := get_parent()
	assert(parent != null, "Spawner must not be the scene root")
	parent.add_child(enemy)
	enemy.add_to_group("enemies")
	enemy.global_position = _random_ring_position()
	enemy.scale = Vector2.ONE * scale_mult
	enemy.setup(data, _target)
	return enemy


func _random_ring_position() -> Vector2:
	var angle: float = randf() * TAU
	var origin: Vector2 = _target.global_position if is_instance_valid(_target) else global_position
	return origin + Vector2(cos(angle), sin(angle)) * SPAWN_RING_RADIUS
