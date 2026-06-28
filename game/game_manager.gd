# See docs/notes/game-manager.md
class_name GameManager extends Node
## Owns the run: timer, kill counter, XP gem spawning, level-up flow, death routing.
## Lives inside arena.tscn as a Node child of the arena root.

const XP_GEM_SCENE_PATH := "res://pickups/xp_gem.tscn"
const GAME_OVER_SCENE  := "res://ui/game_over.tscn"
const GENERIC_UPGRADE_PATHS := [
	"res://upgrades/generic/move_speed.tres",
	"res://upgrades/generic/max_hp.tres",
	"res://upgrades/generic/pickup_range.tres",
	"res://upgrades/generic/fire_rate.tres",
	"res://upgrades/generic/armor.tres",
]

## Public — testable externally (set in _ready() from scene).
var player: Player = null
var upgrade_system: UpgradeSystem = null

var elapsed: float = 0.0
var kills:   int   = 0

var _rng: RandomNumberGenerator
var _xp_gem_scene: PackedScene
var _upgrade_ui: Node  # UpgradeUI CanvasLayer

func _ready() -> void:
	_rng = RandomNumberGenerator.new()
	_rng.randomize()
	_xp_gem_scene = load(XP_GEM_SCENE_PATH) as PackedScene

	# Resolve scene siblings
	var parent := get_parent()
	if parent == null:
		return

	player = parent.get_node_or_null("Player") as Player
	_upgrade_ui = parent.get_node_or_null("UpgradeUI")

	var spawner := parent.get_node_or_null("Spawner") as Spawner

	# Set up player from RunState
	var char_data: CharacterData = RunState.selected_character as CharacterData
	if player and char_data:
		player.setup(char_data)

	# Start spawner
	if spawner and player:
		spawner.setup(player)

	# Build UpgradeSystem from character data
	if char_data and char_data.signature_upgrade and char_data.passive_upgrade and char_data.evolution_upgrade:
		var generic_pool: Array = []
		for path in GENERIC_UPGRADE_PATHS:
			var u := load(path) as Upgrade
			if u:
				generic_pool.append(u)
		upgrade_system = UpgradeSystem.new(
			char_data,
			generic_pool,
			char_data.signature_upgrade,
			char_data.passive_upgrade,
			char_data.evolution_upgrade
		)

	# Connect UpgradeUI chosen signal
	if _upgrade_ui and _upgrade_ui.has_signal("chosen"):
		_upgrade_ui.chosen.connect(_on_upgrade_chosen)

	# Connect GameEvents
	GameEvents.enemy_killed.connect(_on_enemy_killed)
	GameEvents.player_leveled_up.connect(_on_player_leveled_up)
	GameEvents.player_died.connect(_on_player_died)

func _process(dt: float) -> void:
	if get_tree().paused:
		return
	elapsed += dt

func get_elapsed() -> float:
	return elapsed

func get_kills() -> int:
	return kills

# ── GameEvents handlers ───────────────────────────────────────────────────────

func _on_enemy_killed(position: Vector2, xp_value: int) -> void:
	kills += 1
	if _xp_gem_scene == null or player == null:
		return
	var gem: XPGem = _xp_gem_scene.instantiate() as XPGem
	var arena := get_parent()
	if arena:
		arena.add_child(gem)
	gem.global_position = position
	gem.setup(xp_value, player)

func _on_player_leveled_up(_level: int) -> void:
	if upgrade_system == null or _upgrade_ui == null:
		return
	get_tree().paused = true
	_upgrade_ui.present(upgrade_system, player)

func _on_player_died() -> void:
	RunState.last_run = {"time": elapsed, "kills": kills}
	get_tree().paused = false
	get_tree().change_scene_to_file(GAME_OVER_SCENE)

# ── Upgrade routing ───────────────────────────────────────────────────────────

## Called AFTER upgrade_system.apply(u) — routes the effect to player/weapon.
## Separated so it can be unit-tested without a full scene.
func _apply_upgrade(u: Upgrade) -> void:
	if player == null:
		return
	match u.kind:
		Upgrade.Kind.SIGNATURE:
			if player.weapon:
				player.weapon.level_up()
		Upgrade.Kind.EVOLUTION:
			if player.weapon:
				player.weapon.evolve()
		Upgrade.Kind.PASSIVE:
			if player.weapon:
				player.weapon.apply_passive(u.effect_value)
		Upgrade.Kind.GENERIC:
			player.apply_stat_upgrade(u.effect_kind, u.effect_value)

func _on_upgrade_chosen(u: Upgrade) -> void:
	if upgrade_system:
		upgrade_system.apply(u)
	_apply_upgrade(u)
	get_tree().paused = false
