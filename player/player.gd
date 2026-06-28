# See docs/notes/player.md
class_name Player extends CharacterBody2D

var stats: StatBlock
var weapon: Weapon
var level: int = 1
var xp: int = 0
var hp: float = 0.0

var _bob_t: float = 0.0

func setup(data: CharacterData) -> void:
	stats = data.base_stats.duplicate_stats()
	hp = stats.max_hp
	var sprite := $Sprite as AnimatedSprite2D
	if data.sprite_frames:
		sprite.sprite_frames = data.sprite_frames
		sprite.play("idle")
		sprite.show()
		($ColorRect as ColorRect).hide()
	else:
		($ColorRect as ColorRect).color = data.color
		sprite.hide()
	if data.weapon_scene:
		weapon = data.weapon_scene.instantiate()
		add_child(weapon)
		weapon.setup(self, stats)
	GameEvents.player_hp_changed.emit(hp, stats.max_hp)

func _physics_process(dt: float) -> void:
	if not stats:
		return
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = dir * stats.move_speed
	move_and_slide()
	# Procedural bob/squash — visual only, no effect on movement or collision
	var sprite := $Sprite as AnimatedSprite2D
	if sprite.visible and sprite.sprite_frames:
		if velocity.length_squared() > 1.0:
			_bob_t += dt * 10.0
			sprite.position.y = sin(_bob_t) * 2.0
			sprite.scale = Vector2(
				1.0 + abs(sin(_bob_t)) * 0.06,
				1.0 - abs(sin(_bob_t)) * 0.08
			)
			if velocity.x != 0.0:
				sprite.flip_h = velocity.x < 0.0
		else:
			_bob_t = 0.0
			sprite.position.y = 0.0
			sprite.scale = Vector2.ONE

func xp_to_next(lvl: int) -> int:
	# Superlinear (quadratic) curve: each level costs noticeably more than the last.
	# Formula: 5 + lvl*3 + lvl²*2  →  lvl1=10, lvl2=19, lvl3=32, lvl5=70, lvl10=235
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
