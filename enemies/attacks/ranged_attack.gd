# See docs/notes/enemy-attacks.md
class_name RangedAttack extends EnemyAttack
## Kites to EnemyData.attack_range and fires EnemyProjectile3D at the player when it has
## line of sight (terrain on layer 16 blocks the ray → hold fire). Telegraphs each shot
## with a windup. Holds a hysteresis band around attack_range so it doesn't jitter.

const PROJECTILE := preload("res://enemies/enemy_projectile_3d.tscn")
const BAND := 2.0  ## +/- world units of "hold" tolerance around attack_range

var _cooldown_left: float = 0.0
var _windup_left: float = -1.0  ## >=0 means a shot is winding up

## Pure kite velocity: approach if beyond range+band, retreat if inside range-band, else hold.
static func kite_velocity(from: Vector3, to: Vector3, attack_range: float, speed: float) -> Vector3:
	var delta := to - from
	delta.y = 0.0
	var dist := delta.length()
	if dist < 0.001:
		return Vector3.ZERO
	var dir := delta.normalized()
	if dist > attack_range + BAND:
		return dir * speed            # approach
	if dist < attack_range - BAND:
		return -dir * speed           # retreat (kite)
	return Vector3.ZERO               # hold in band

func _ready_to_fire() -> bool:
	return _cooldown_left <= 0.0

## Pure firing gate: in range, line of sight clear, and off cooldown.
func _can_fire(dist: float, los_clear: bool, attack_range: float) -> bool:
	return dist <= attack_range and los_clear and _ready_to_fire()

func desired_velocity(enemy: Enemy3D, target: Node3D, _dt: float) -> Vector3:
	return kite_velocity(enemy.global_position, target.global_position,
			enemy.data.attack_range, enemy.data.move_speed)

func attack_tick(enemy: Enemy3D, target: Node3D, dt: float) -> void:
	_cooldown_left = max(0.0, _cooldown_left - dt)
	# Resolve an in-progress windup → launch.
	if _windup_left >= 0.0:
		_windup_left -= dt
		if _windup_left <= 0.0:
			_windup_left = -1.0
			_launch(enemy, target)
		return
	var to_t := target.global_position - enemy.global_position
	to_t.y = 0.0
	var dist := to_t.length()
	var los_clear := not _los_blocked(enemy, target)
	if _can_fire(dist, los_clear, enemy.data.attack_range):
		_windup_left = enemy.data.windup_time   # telegraph, then _launch
		GameEvents.skill_cast.emit(&"enemy_ranged_windup", Color.WHITE, enemy.global_position)

## Raycast enemy→player against terrain layer 16. True if a wall/obstacle blocks the shot.
func _los_blocked(enemy: Enemy3D, target: Node3D) -> bool:
	var world := enemy.get_world_3d()
	if world == null:
		return false
	var from := enemy.global_position + Vector3(0, 1, 0)
	var to := target.global_position + Vector3(0, 1, 0)
	var q := PhysicsRayQueryParameters3D.create(from, to, 16)  # mask = layer 16 (terrain)
	var hit := world.direct_space_state.intersect_ray(q)
	return not hit.is_empty()

func _launch(enemy: Enemy3D, target: Node3D) -> void:
	if not is_instance_valid(target):
		return
	var dir := target.global_position - enemy.global_position
	var proj: EnemyProjectile3D = PROJECTILE.instantiate()
	proj.setup(dir, enemy.data.projectile_speed, enemy.data.projectile_damage)
	var spawn_parent := enemy.get_parent()
	if spawn_parent == null:
		proj.free()
		return
	proj.global_position = enemy.global_position + Vector3(0, 1, 0)
	spawn_parent.add_child.call_deferred(proj)
	# Re-arm cooldown after the shot actually goes out.
	_cooldown_left = enemy.data.attack_cooldown
	GameEvents.skill_hit.emit(&"enemy_ranged_fire", Color.WHITE, enemy.global_position)
