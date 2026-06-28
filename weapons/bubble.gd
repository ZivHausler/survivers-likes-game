# See docs/notes/weapon-avihay.md
class_name Bubble extends Area2D

const _BubblePopScene: PackedScene = preload("res://vfx/death_pop.tscn")
## Area2D projectile fired by AvihayChatSpam.
##
## Travels along `_direction` each physics frame at `SPEED` px/s.
## On body contact calls take_damage(damage) on the enemy, decrements pierce,
## and frees itself when pierce is exhausted.
## If homing, steers toward the nearest enemy each frame.
## Guards against double-hitting the same enemy (each enemy hit at most once
## per bubble instance).

const SPEED: float = 220.0
const MAX_LIFETIME: float = 4.0

var _direction: Vector2 = Vector2.RIGHT
var _damage: float = 10.0
var _pierce: int = 1
var _homing: bool = false
var _lifetime: float = 0.0
## Enemies already hit by this bubble instance — no re-hit allowed.
var _hit_enemies: Array[Node] = []
## VFX trail particles (visual-only).
var _trail: CPUParticles2D = null

## Initialise the bubble after adding to scene tree.
## Call this immediately after add_child(bubble).
func setup(direction: Vector2, damage: float, pierce: int, homing: bool) -> void:
	_direction = direction.normalized()
	_damage    = damage
	_pierce    = pierce
	_homing    = homing
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	# VFX: travel trail (visual-only).
	_trail = CPUParticles2D.new()
	_trail.amount                = 6
	_trail.lifetime              = 0.3
	_trail.one_shot              = false
	_trail.emitting              = true
	_trail.explosiveness         = 0.0
	_trail.spread                = 90.0
	_trail.initial_velocity_min  = 10.0
	_trail.initial_velocity_max  = 30.0
	_trail.color                 = Color(0.5, 0.7, 1.0, 0.5)
	add_child(_trail)
	# Denser trail for evolved (homing) bubbles.
	if _homing:
		_trail.amount = 12

func _physics_process(dt: float) -> void:
	_advance(dt)

## Advance the bubble by `dt` seconds.
## Exposed as a public method so unit tests can drive movement without
## relying on the physics engine.
func _advance(dt: float) -> void:
	_lifetime += dt
	if _lifetime >= MAX_LIFETIME:
		queue_free()
		return
	if _homing and is_inside_tree():
		var nearest := _nearest_enemy()
		if nearest and is_instance_valid(nearest):
			var to_enemy := (nearest.global_position - global_position).normalized()
			_direction = _direction.lerp(to_enemy, 5.0 * dt).normalized()
	position += _direction * SPEED * dt

## Physics body_entered handler — routes to _on_hit for testability.
func _on_body_entered(body: Node) -> void:
	_on_hit(body)

## Process a hit against `enemy`.
## Public so tests can call it directly without relying on physics overlap.
func _on_hit(enemy: Node) -> void:
	if enemy in _hit_enemies:
		return
	if not enemy.is_in_group("enemies"):
		return
	_hit_enemies.append(enemy)
	if enemy.has_method("take_damage"):
		enemy.take_damage(_damage)
	_pierce -= 1
	if _pierce <= 0:
		_spawn_hit_pop()
		queue_free()

## Spawn a DeathPop-style burst at the bubble's current position.
func _spawn_hit_pop() -> void:
	var pop_parent := get_parent()
	if not is_instance_valid(pop_parent):
		return
	var pop: DeathPop = _BubblePopScene.instantiate()
	pop_parent.add_child(pop)
	pop.play_at(global_position)

## Return the nearest enemy node in the scene tree, or null if none.
func _nearest_enemy() -> Node2D:
	if not is_inside_tree():
		return null
	var enemies := get_tree().get_nodes_in_group("enemies")
	var nearest: Node2D = null
	var best_dist := INF
	for e in enemies:
		if not is_instance_valid(e):
			continue
		var d := global_position.distance_to((e as Node2D).global_position)
		if d < best_dist:
			best_dist = d
			nearest = e as Node2D
	return nearest
