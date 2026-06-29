# See docs/notes/char-yinon.md
class_name YinonClusterBomb3D extends OrbitWeapon3D
## Yinon skill: "Cluster Bomb" — 4 orbiting explosive shells spinning around the player.
## OrbitWeapon3D with 4 orbiters, solid radius, military damage.

func _ready() -> void:
	orbit_count  = 4
	orbit_radius = 3.0
	orbit_speed  = TAU / 3.0
	damage       = 14.0
	base_cooldown = 2.5
	super()
