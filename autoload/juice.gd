# See docs/notes/juice.md
extends Node
## Juice — decoupled visual-effects layer.
## Listens to GameEvents signals and spawns screen feedback (particles, tweens,
## camera shake). Disabling this autoload reverts the game to pure logic.
## Wave C fills the handler bodies with effect spawning + guarded refs.

var _camera: Camera2D = null
var _player: Node2D = null
var _last_hp: float = -1.0  ## Tracks previous HP to detect a decrease

const _DamageNumberScene: PackedScene = preload("res://vfx/damage_number.tscn")
const _DeathPopScene: PackedScene = preload("res://vfx/death_pop.tscn")

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

# ── Private helpers ──────────────────────────────────────────────────────────

## Returns a safe scene parent for effect nodes, or null if unavailable.
## Prefers current_scene; falls back to root if current_scene is null
## (can happen in headless tests or during scene transitions).
func _safe_parent() -> Node:
	if not is_instance_valid(_player):
		return null
	var tree: SceneTree = _player.get_tree()
	return tree.current_scene if tree.current_scene != null else tree.root

## Forward trauma to the ScreenShake child on _camera, if available.
func _add_trauma(amount: float) -> void:
	if not is_instance_valid(_camera):
		return
	var shake := _camera.get_node_or_null("ScreenShake") as ScreenShake
	if shake:
		shake.add_trauma(amount)

# ── Signal handlers ──────────────────────────────────────────────────────────

func _on_enemy_killed(position: Vector2, xp_value: int) -> void:
	var parent := _safe_parent()
	if parent == null:
		return
	# Death particle burst
	var pop: DeathPop = _DeathPopScene.instantiate()
	parent.add_child(pop)
	pop.play_at(position)
	# Floating number showing XP earned
	var num: DamageNumber = _DamageNumberScene.instantiate()
	parent.add_child(num)
	num.setup(xp_value, position)
	# Small camera shake
	_add_trauma(0.25)

func _on_xp_collected(_amount: int) -> void:
	pass  # Wave D: flash XP counter

func _on_player_leveled_up(_level: int) -> void:
	pass  # Wave D: level-up fanfare effect

func _on_player_hp_changed(current: float, _max_hp: float) -> void:
	# Flash player and shake camera only on a HP decrease
	if _last_hp >= 0.0 and current < _last_hp:
		if is_instance_valid(_player):
			HitFlash.flash(_player, 0.15)
		_add_trauma(0.3)
	_last_hp = current

func _on_player_died() -> void:
	pass  # Wave D: death-screen transition

func _on_evolution_unlocked(_weapon_id: StringName) -> void:
	pass  # Wave D: evolution sparkle / announcement
