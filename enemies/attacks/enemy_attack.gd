# See docs/notes/enemy-attacks.md
class_name EnemyAttack extends RefCounted
## Strategy object for non-melee enemy archetypes. Enemy3D delegates per-frame
## movement shaping (desired_velocity) and the attack action (attack_tick) to one
## of these. MELEE enemies use Enemy3D's inline default and have NO attack object.

## Returns this frame's desired XZ velocity (Y = 0). Base = stand still.
func desired_velocity(_enemy: Enemy3D, _target: Node3D, _dt: float) -> Vector3:
	return Vector3.ZERO

## Performs the archetype's attack for this frame (fire / lunge-hit). Base = nothing.
func attack_tick(_enemy: Enemy3D, _target: Node3D, _dt: float) -> void:
	pass
