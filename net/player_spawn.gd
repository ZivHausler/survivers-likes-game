# See docs/superpowers/plans/2026-07-01-coop-foundation.md (Task D2)
class_name PlayerSpawn
extends RefCounted
## Pure spawn-position helper for runtime party spawning.
## Single player spawns at the arena centre (identical to authored solo today);
## a party spreads evenly around a ring of `radius` on the XZ plane (y = 0).

static func spawn_point(index: int, count: int, radius: float) -> Vector3:
	if count <= 1:
		return Vector3.ZERO
	var ang := TAU * float(index) / float(count)
	return Vector3(cos(ang) * radius, 0.0, sin(ang) * radius)
