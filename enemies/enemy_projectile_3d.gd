# See docs/notes/enemy-projectile-3d.md
class_name EnemyProjectile3D extends Area3D
## A travelling enemy attack. Moves along a fixed XZ direction, damages the player
## (group "player") on contact with their hurtbox, and is destroyed by terrain
## (layer 16) so trees/rocks/walls act as cover. Never hits other enemies (mask
## excludes layer 8). Despawns after MAX_LIFETIME so strays don't accumulate.

const MAX_LIFETIME := 6.0

var _direction: Vector3 = Vector3.ZERO
var _speed: float = 0.0
var _damage: float = 0.0
var _age: float = 0.0
## Glow/albedo color of the orb — set per firing enemy so each caster's shots read distinctly.
var _color: Color = Color(1.0, 0.5, 0.1)

func setup(direction: Vector3, speed: float, damage: float, color: Color = Color(1.0, 0.5, 0.1)) -> void:
	var flat := Vector3(direction.x, 0.0, direction.z)
	_direction = flat.normalized() if flat.length() > 0.001 else Vector3.FORWARD
	_speed = speed
	_damage = damage
	_color = color
	_apply_color()

func _ready() -> void:
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)
	_apply_color()

## Give the orb a self-lit, enemy-tinted material so the projectile is clearly visible
## in flight. No-op if the mesh node is missing (e.g. a stripped test scene).
func _apply_color() -> void:
	var mi := get_node_or_null("MeshInstance3D") as MeshInstance3D
	if mi == null or mi.mesh == null:
		return
	var mat := StandardMaterial3D.new()
	mat.albedo_color = _color
	mat.emission_enabled = true
	mat.emission = _color
	mat.emission_energy_multiplier = 3.0
	mi.material_override = mat

func _physics_process(dt: float) -> void:
	_age += dt
	if _age >= MAX_LIFETIME:
		queue_free()
		return
	_advance(dt)

## Pure travel step (testable without signals).
func _advance(dt: float) -> void:
	global_position += _direction * _speed * dt

## Player hurtbox (Area3D, layer 2) → damage + despawn.
func _on_area_entered(area: Area3D) -> void:
	var owner_node := area.get_parent()
	if area.is_in_group("player") and area.has_method("take_damage"):
		area.take_damage(_damage)
		queue_free()
	elif owner_node and owner_node.is_in_group("player") and owner_node.has_method("take_damage"):
		owner_node.take_damage(_damage)
		queue_free()

## Terrain (StaticBody3D, layer 16) → despawn (cover). Player body also possible.
func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(_damage)
	queue_free()
