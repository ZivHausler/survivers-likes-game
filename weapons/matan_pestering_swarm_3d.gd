# See docs/notes/char-matan.md
class_name MatanPesteringSwarm3D extends OrbitWeapon3D
## Matan skill: "Pestering Swarm" — five fast-moving irritants swarming around the player,
## relentlessly harassing any enemy that gets close.
## OrbitWeapon3D with 5 orbs, fast orbit speed, light but frequent damage.

func _ready() -> void:
	orbit_count  = 5
	orbit_radius = 3.5
	orbit_speed  = TAU / 1.5   # fast — swarm feels frantic
	damage       = 9.0
	base_cooldown = 2.0
	super()
