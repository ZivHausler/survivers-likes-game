# See docs/notes/juice-3d.md
extends Node
## Juice3D — decoupled visual-effects layer for the 3D game.
## Listens to GameEvents signals and spawns 3D feedback: death bursts, floating
## XP numbers, hit-flash, camera shake, and evolution/level-up fanfare.
## Register the Player3D and GameCamera3D from GameManager3D at run start.
## Disabling or removing this autoload leaves all game logic unaffected.

var _camera = null   ## GameCamera3D registered by GameManager3D; duck-typed for tests
var _player: Node3D = null
var _last_hp: float = -1.0  ## Tracks previous HP to detect a decrease

## Screen-shake trauma applied when a boss dies. Big boss jolts harder than a mini-boss.
const MINI_BOSS_SHAKE: float = 0.45
const BIG_BOSS_SHAKE: float = 0.85

const _DeathPop3DScene: PackedScene = preload("res://vfx/death_pop_3d.tscn")
const _DamageNumber3DScene: PackedScene = preload("res://vfx/damage_number_3d.tscn")
const _EvolutionFlashScene: PackedScene = preload("res://vfx/evolution_flash.tscn")

func _ready() -> void:
	GameEvents.enemy_killed_3d.connect(_on_enemy_killed_3d)
	GameEvents.xp_collected.connect(_on_xp_collected)
	GameEvents.player_leveled_up.connect(_on_player_leveled_up)
	GameEvents.player_hp_changed.connect(_on_player_hp_changed)
	GameEvents.player_died.connect(_on_player_died)
	GameEvents.evolution_unlocked.connect(_on_evolution_unlocked)
	GameEvents.boss_killed_3d.connect(_on_boss_killed_3d)

# ── Public API ────────────────────────────────────────────────────────────────

func register_player(p: Node3D) -> void:
	_player = p

## Register the camera that receives add_trauma() calls. Duck-typed so test stubs work.
func register_camera(cam) -> void:
	_camera = cam

# ── Private helpers ───────────────────────────────────────────────────────────

## Returns a safe scene parent for effect nodes, or null if unavailable.
func _safe_parent() -> Node:
	if not is_instance_valid(_player):
		return null
	var tree: SceneTree = _player.get_tree()
	return tree.current_scene if tree.current_scene != null else tree.root

## Forward trauma to the registered GameCamera3D's add_trauma method, if available.
func _add_trauma(amount: float) -> void:
	if not is_instance_valid(_camera):
		return
	if _camera.has_method("add_trauma"):
		_camera.add_trauma(amount)

# ── Signal handlers ───────────────────────────────────────────────────────────

func _on_enemy_killed_3d(pos: Vector3, xp: int) -> void:
	var parent := _safe_parent()
	if parent == null:
		return
	# Death particle burst
	var pop: DeathPop3D = _DeathPop3DScene.instantiate()
	parent.add_child(pop)
	pop.play_at(pos)
	# Floating XP number
	var num: DamageNumber3D = _DamageNumber3DScene.instantiate()
	parent.add_child(num)
	num.setup(xp, pos)
	# No camera shake on normal enemy deaths — only bosses shake (see _on_boss_killed_3d).

func _on_xp_collected(_amount: int) -> void:
	if not is_instance_valid(_player):
		return
	var parent := _safe_parent()
	if parent == null:
		return
	# Reuse death_pop_3d as a small gold sparkle burst at the player.
	var pop: DeathPop3D = _DeathPop3DScene.instantiate()
	parent.add_child(pop)
	pop.play_at(_player.global_position)

func _on_player_leveled_up(_level: int) -> void:
	var parent := _safe_parent()
	if parent == null:
		return
	var flash: EvolutionFlash = _EvolutionFlashScene.instantiate()
	# add_child FIRST so _ready() creates the internal rect; set_intensity after.
	parent.add_child(flash)
	flash.set_intensity(0.4)

func _on_player_hp_changed(current: float, _max_hp: float) -> void:
	# Flash player and shake camera only on HP decrease
	if _last_hp >= 0.0 and current < _last_hp:
		if is_instance_valid(_player):
			HitFlash3D.flash(_player, 0.15)
		_add_trauma(0.3)
	_last_hp = current

func _on_player_died() -> void:
	pass  # Death-screen transition handled by GameManager3D

## Boss-only screen shake: mini-boss gives a solid jolt, big boss a bigger one.
func _on_boss_killed_3d(boss_kind: int) -> void:
	var amount := BIG_BOSS_SHAKE if boss_kind == Enemy3D.BossKind.BIG else MINI_BOSS_SHAKE
	_add_trauma(amount)

func _on_evolution_unlocked(_weapon_id: StringName) -> void:
	var parent := _safe_parent()
	if parent == null:
		return
	var flash: EvolutionFlash = _EvolutionFlashScene.instantiate()
	parent.add_child(flash)
	# Full intensity (default ~0.85 alpha) for evolution
