# See docs/notes/weapon-avihay-3d.md
class_name Bubble3D extends Area3D
## 3D projectile fired by AvihayChatSpam3D.
##
## Travels along `_direction` (XZ unit vector) each physics frame at SPEED world-units/s.
## On body contact calls take_damage(damage) on the enemy, decrements pierce,
## and frees itself when pierce is exhausted.
## If homing, steers toward the nearest enemy each frame.
## Guards against double-hitting the same enemy (each enemy hit at most once
## per bubble instance).
##
## SPEED = 14.0 world units/s  (220 px/s ÷ 16 ≈ 13.75, rounded to 14.0).
## Hit VFX is Phase 4.5 — queue_free() directly when pierce exhausted.

const SPEED: float = 14.0
const MAX_LIFETIME: float = 4.0

var _direction: Vector3 = Vector3(1, 0, 0)
var _damage: float = 10.0
var _pierce: int = 1
var _homing: bool = false
var _lifetime: float = 0.0
## Enemies already hit by this bubble instance — no re-hit allowed.
var _hit_enemies: Array[Node] = []
## VFX identifiers for skill_hit signal. Defaults match Avihay's color scheme.
var vfx_id: StringName = &"avihay_chat_spam"
var vfx_color: Color = Color(0.3, 0.6, 1.0)  # blue/chat

func _ready() -> void:
	_setup_visual()

## Add a clearly visible emissive sphere mesh so the bubble is easy to see.
## Called from _ready(); creates a fresh material per instance.
func _setup_visual() -> void:
	var mi := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height  = 1.0
	mi.mesh = sphere
	# Raise the visual to torso height so the bubble doesn't clip into the ground.
	# The Area3D collision and movement logic remain at Y=0.
	mi.position = Vector3(0.0, 1.0, 0.0)
	# Fresh material per bubble instance — never share a resource.
	var mat := StandardMaterial3D.new()
	mat.albedo_color = vfx_color
	mat.emission_enabled = true
	mat.emission = vfx_color
	mat.emission_energy_multiplier = 2.0
	mi.material_override = mat
	add_child(mi)

## Initialise the bubble after adding to scene tree.
## Call this immediately after add_child(bubble).
func setup(direction: Vector3, damage: float, pierce: int, homing: bool) -> void:
	_direction = direction.normalized()
	_damage    = damage
	_pierce    = pierce
	_homing    = homing
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

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
			var diff := nearest.global_position - global_position
			diff.y = 0.0
			var to_enemy := diff.normalized()
			_direction = _direction.lerp(to_enemy, 5.0 * dt).normalized()
	global_position += _direction * SPEED * dt

## Physics body_entered handler — routes to _on_hit for testability.
func _on_body_entered(body: Node3D) -> void:
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
		var e3d := enemy as Node3D
		if e3d:
			GameEvents.skill_hit.emit(vfx_id, vfx_color, e3d.global_position)
	_pierce -= 1
	if _pierce <= 0:
		queue_free()

## Return the nearest enemy node in the scene tree, or null if none.
func _nearest_enemy() -> Node3D:
	if not is_inside_tree():
		return null
	var enemies := get_tree().get_nodes_in_group("enemies")
	var nearest: Node3D = null
	var best_dist := INF
	for e in enemies:
		if not is_instance_valid(e):
			continue
		var d := global_position.distance_to((e as Node3D).global_position)
		if d < best_dist:
			best_dist = d
			nearest = e as Node3D
	return nearest
