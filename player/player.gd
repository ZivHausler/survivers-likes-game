# See docs/notes/player.md
class_name Player extends CharacterBody2D

var stats: StatBlock
var weapon: Weapon
var level: int = 1
var xp: int = 0
var hp: float = 0.0

func setup(data: CharacterData) -> void:
	stats = data.base_stats.duplicate_stats()
	hp = stats.max_hp
	($ColorRect as ColorRect).color = data.color
	if data.weapon_scene:
		weapon = data.weapon_scene.instantiate()
		add_child(weapon)
		weapon.setup(self, stats)
	GameEvents.player_hp_changed.emit(hp, stats.max_hp)

func _physics_process(_dt: float) -> void:
	if not stats:
		return
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = dir * stats.move_speed
	move_and_slide()

func xp_to_next(lvl: int) -> int:
	return 5 + lvl * 5

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
## Called by GameManager._apply_upgrade when kind == GENERIC.
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
