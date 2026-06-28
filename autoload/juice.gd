# See docs/notes/juice.md
extends Node
## Juice — decoupled visual-effects layer.
## Listens to GameEvents signals and spawns screen feedback (particles, tweens,
## camera shake, etc.). Disabling this autoload reverts the game to pure logic.
## Wave C fills the handler bodies; this file is the skeleton.

var _camera: Camera2D = null
var _player: Node2D = null

func _ready() -> void:
	GameEvents.enemy_killed.connect(_on_enemy_killed)
	GameEvents.xp_collected.connect(_on_xp_collected)
	GameEvents.player_leveled_up.connect(_on_player_leveled_up)
	GameEvents.player_hp_changed.connect(_on_player_hp_changed)
	GameEvents.player_died.connect(_on_player_died)
	GameEvents.evolution_unlocked.connect(_on_evolution_unlocked)

# ── Public API ───────────────────────────────────────────────────────────────

func register_camera(cam: Camera2D) -> void:
	_camera = cam

func register_player(p: Node2D) -> void:
	_player = p

# ── Signal handlers (stubs — Wave C fills these) ─────────────────────────────

func _on_enemy_killed(_position: Vector2, _xp_value: int) -> void:
	pass  # Wave C: spawn death particles at position

func _on_xp_collected(_amount: int) -> void:
	pass  # Wave C: flash XP counter

func _on_player_leveled_up(_level: int) -> void:
	pass  # Wave C: level-up fanfare effect

func _on_player_hp_changed(_current: float, _max_hp: float) -> void:
	pass  # Wave C: HP bar flash / hit vignette

func _on_player_died() -> void:
	pass  # Wave C: death screen effect

func _on_evolution_unlocked(_weapon_id: StringName) -> void:
	pass  # Wave C: evolution sparkle / announcement
