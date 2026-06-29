# See docs/notes/skills-overview-3-3.md
class_name ZivMirrorShards3D extends OrbitWeapon3D
## Ziv skill: "Mirror Shards" — orbiting glass shards that cut nearby enemies.
## OrbitWeapon3D with tuned params: 3 shards, close radius, moderate damage.

func _ready() -> void:
	orbit_count  = 3
	orbit_radius = 3.5
	orbit_speed  = TAU / 2.5   # slightly faster than base
	damage       = 20.0
	base_cooldown = 2.0
	super()
