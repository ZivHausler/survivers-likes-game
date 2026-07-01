# See docs/notes/enemy-attacks.md
class_name DashAttack extends EnemyAttack
## Gap-closer. Approaches at move_speed until within dash_trigger_range, telegraphs
## (dash_windup), locks the player's position, then lunges at dash_speed for
## dash_duration (contact deals contact_damage), then waits dash_cooldown. desired_velocity
## reflects the phase so movement and attack stay in sync.

enum Phase { APPROACH, WINDUP, DASH, COOLDOWN }
var _phase: int = Phase.APPROACH
var _timer: float = 0.0
var _locked: Vector3 = Vector3.ZERO   ## player position captured at dash start
var _hit_this_dash: bool = false

## Pure: dash velocity from `from` toward the locked target at `speed` (Y flattened).
static func dash_velocity(from: Vector3, locked_target: Vector3, speed: float) -> Vector3:
	var d: Vector3 = locked_target - from
	d.y = 0.0
	if d.length() < 0.001:
		return Vector3.ZERO
	return d.normalized() * speed

func desired_velocity(enemy, target: Node3D, _dt: float) -> Vector3:
	var d: EnemyData = enemy.data
	match _phase:
		Phase.APPROACH:
			var to: Vector3 = target.global_position - enemy.global_position
			to.y = 0.0
			return to.normalized() * d.move_speed if to.length() > 0.001 else Vector3.ZERO
		Phase.WINDUP, Phase.COOLDOWN:
			return Vector3.ZERO           # brace / recover (telegraph)
		Phase.DASH:
			return dash_velocity(enemy.global_position, _locked, d.dash_speed)
	return Vector3.ZERO

func attack_tick(enemy, target: Node3D, dt: float) -> void:
	var d: EnemyData = enemy.data
	match _phase:
		Phase.APPROACH:
			var dist: float = (target.global_position - enemy.global_position).length()
			if dist <= d.dash_trigger_range:
				_phase = Phase.WINDUP
				_timer = d.dash_windup
				# Ground telegraph circle removed as requested — the WINDUP brace is the tell.
		Phase.WINDUP:
			_timer -= dt
			if _timer <= 0.0:
				_phase = Phase.DASH
				_timer = d.dash_duration
				_locked = target.global_position   # commit to a fixed lunge point
				_hit_this_dash = false
		Phase.DASH:
			_timer -= dt
			if not _hit_this_dash:
				var dist: float = (target.global_position - enemy.global_position).length()
				if dist < (enemy as Enemy3D).CONTACT_RANGE and target.has_method("take_damage"):
					target.take_damage(d.contact_damage)
					_hit_this_dash = true
			if _timer <= 0.0:
				_phase = Phase.COOLDOWN
				_timer = d.dash_cooldown
		Phase.COOLDOWN:
			_timer -= dt
			if _timer <= 0.0:
				_phase = Phase.APPROACH
