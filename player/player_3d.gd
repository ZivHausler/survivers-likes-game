# See docs/notes/player-3d.md
class_name Player3D extends CharacterBody3D
## 3D player actor (CharacterBody3D). Gameplay on XZ plane (Y up).
## Owns WASD movement and all HP/XP/level/stat logic — ported verbatim from Player (2D).
## Weapons and enemies are wired in later tasks; weapon stays null until then.

var stats: StatBlock
var weapon: Weapon
var level: int = 1
var xp: int = 0
var hp: float = 0.0

func setup(data: CharacterData) -> void:
	stats = data.base_stats.duplicate_stats()
	hp = stats.max_hp
	# Only attach 3D weapons — all current Weapon subclasses extend Node2D and will be
	# skipped here. Guard prevents crashing when weapon_scene is null OR a 2D scene.
	if data.weapon_scene:
		var inst := data.weapon_scene.instantiate()
		if inst is Node3D:
			weapon = inst as Weapon
			add_child(weapon)
			weapon.setup(self, stats)
		else:
			inst.free()
	GameEvents.player_hp_changed.emit(hp, stats.max_hp)

func _physics_process(_dt: float) -> void:
	if not stats:
		return
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = move_to_velocity(dir, stats.move_speed)
	move_and_slide()

## Pure XZ mapping helper — unit-testable without Input or scene tree.
## "up" on screen (move_up action, dir.y = -1) maps to -Z (away from camera).
static func move_to_velocity(dir: Vector2, speed: float) -> Vector3:
	return Vector3(dir.x, 0.0, dir.y) * speed

func xp_to_next(lvl: int) -> int:
	# Superlinear (quadratic) curve — same formula as 2D Player.
	# 5 + lvl*3 + lvl²*2  →  lvl1=10, lvl2=19, lvl3=32, lvl5=70, lvl10=235
	return 5 + lvl * 3 + lvl * lvl * 2

func add_xp(amount: int) -> void:
	xp += amount
	while xp >= xp_to_next(level):
		xp -= xp_to_next(level)
		level += 1
		GameEvents.player_leveled_up.emit(level)

func take_damage(amount: float) -> void:
	var dealt: float = max(0.0, amount - stats.armor)
	hp -= dealt
	GameEvents.player_hp_changed.emit(hp, stats.max_hp)
	if hp <= 0.0:
		GameEvents.player_died.emit()

func get_pickup_range() -> float:
	return stats.pickup_range

## Apply a per-level stat delta from a GENERIC upgrade.
## Mirrors Player.apply_stat_upgrade exactly; weapon.refresh_cooldown() guard preserved.
func apply_stat_upgrade(kind: StringName, value: float) -> void:
	match kind:
		&"move_speed":
			stats.move_speed += value
		&"max_hp":
			stats.max_hp += value
			hp += value
			GameEvents.player_hp_changed.emit(hp, stats.max_hp)
		&"pickup_range":
			stats.pickup_range += value
		&"fire_rate":
			stats.fire_rate_mult += value
			if weapon:
				weapon.refresh_cooldown()
		&"damage":
			stats.damage_mult += value
		&"armor":
			stats.armor += value
