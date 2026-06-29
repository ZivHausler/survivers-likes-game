# See docs/notes/game-manager-3d.md
class_name GameManager3D extends Node
## Owns the 3D run: timer, kill counter, XP gem spawning, level-up flow, death routing.
## Lives inside main_3d.tscn as a Node child of the scene root.

const GEM_SCENE_PATH := "res://pickups/xp_gem_3d.tscn"
const GAME_OVER_SCENE := "res://ui/game_over.tscn"
const ZIV_3D_PATH := "res://characters/ziv_3d.tres"
const GENERIC_UPGRADE_PATHS := [
	"res://upgrades/generic/move_speed.tres",
	"res://upgrades/generic/max_hp.tres",
	"res://upgrades/generic/pickup_range.tres",
	"res://upgrades/generic/fire_rate.tres",
	"res://upgrades/generic/armor.tres",
]

## Public — testable externally.
var upgrade_system: UpgradeSystem = null

var elapsed: float = 0.0
var kills: int = 0

var _player: Player3D = null
var _spawner = null  # Spawner3D at runtime; duck-typed so test stubs work
var _gem_scene: PackedScene = null
var _upgrade_ui: Node = null  # UpgradeUI CanvasLayer

# Level-up queue — mirrors 2D GameManager exactly.
# player.add_xp() can cross several thresholds in one call, emitting
# player_leveled_up synchronously multiple times. We serialise these so each
# level-up gets its own (freshly evaluated) choice set and the tree only
# unpauses once every queued level-up has been resolved.
var _choosing: bool = false
var _pending_levelups: int = 0


func _ready() -> void:
	_gem_scene = load(GEM_SCENE_PATH) as PackedScene
	start()


func start() -> void:
	var parent := get_parent()
	if parent == null:
		return

	_player = parent.get_node_or_null("Player") as Player3D
	_spawner = parent.get_node_or_null("Spawner3D")  # duck-typed; no cast needed
	_upgrade_ui = parent.get_node_or_null("UpgradeUI")

	# Character data: use RunState if set, else default to ziv_3d.tres.
	var char_data: CharacterData = RunState.selected_character as CharacterData
	if char_data == null:
		char_data = load(ZIV_3D_PATH) as CharacterData

	if _player and char_data:
		_player.setup(char_data)

	if _spawner != null and _player != null:
		_spawner.setup(_player)

	# Build UpgradeSystem from character data.
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

	# Connect UpgradeUI chosen signal.
	if _upgrade_ui and _upgrade_ui.has_signal("chosen"):
		_upgrade_ui.chosen.connect(_on_upgrade_chosen)

	# Connect GameEvents.
	GameEvents.enemy_killed_3d.connect(_on_enemy_killed)
	GameEvents.player_leveled_up.connect(_on_player_leveled_up)
	GameEvents.player_died.connect(_on_player_died)

	# Register Player3D and GameCamera3D with the Juice3D autoload so it can
	# spawn effects and forward camera shake. Both are siblings of this node.
	if _player:
		Juice3D.register_player(_player)
	var cam: GameCamera3D = parent.get_node_or_null("GameCamera3D") as GameCamera3D
	if cam:
		Juice3D.register_camera(cam)


func _process(dt: float) -> void:
	if get_tree().paused:
		return
	elapsed += dt


func get_elapsed() -> float:
	return elapsed


func get_kills() -> int:
	return kills


# ── GameEvents handlers ───────────────────────────────────────────────────────

func _on_enemy_killed(pos: Vector3, xp: int) -> void:
	kills += 1
	if _gem_scene == null or _player == null:
		return
	var gem: XPGem3D = _gem_scene.instantiate() as XPGem3D
	gem.setup(xp, _player)
	var parent := get_parent()
	if parent:
		# Defer insertion: enemy_killed_3d can fire from inside a physics callback.
		# Adding an Area3D during physics query flush prevents monitoring setup,
		# so body_entered never fires. Deferring moves insertion to a safe point.
		#
		# pos is a WORLD coordinate. global_position is only valid once the node is
		# in the scene tree, so we set it via tree_entered rather than using the
		# local .position property.
		gem.tree_entered.connect(func(): gem.global_position = pos, CONNECT_ONE_SHOT)
		parent.add_child.call_deferred(gem)


func _on_player_leveled_up(_level: int) -> void:
	if upgrade_system == null or _upgrade_ui == null:
		return
	# If a level-up is already being presented, queue this one and return —
	# it will be presented after the current choice resolves.
	if _choosing:
		_pending_levelups += 1
		return
	# If everything is already maxed there is nothing to pick — never pause on an
	# empty picker (that softlocks the game). Grant a small bonus and move on.
	if not upgrade_system.has_available_choices():
		_grant_max_bonus()
		return
	_choosing = true
	get_tree().paused = true
	_present_next()


## Present a fresh choice set. build_choices is re-evaluated each call so an
## evolution that becomes available across stacked level-ups is offered.
func _present_next() -> void:
	# A pick earlier in this chain may have exhausted every upgrade; never show an
	# empty picker (softlock). Grant the maxed bonus and resolve the queue instead.
	if not upgrade_system.has_available_choices():
		_grant_max_bonus()
		_resolve_next_or_unpause()
		return
	_upgrade_ui.present(upgrade_system, _player)


func _on_player_died() -> void:
	RunState.last_run = {"time": elapsed, "kills": kills}
	if is_inside_tree():
		get_tree().paused = false
		get_tree().change_scene_to_file(GAME_OVER_SCENE)


# ── Upgrade routing ───────────────────────────────────────────────────────────

## Called AFTER upgrade_system.apply(u) — routes the effect to player/weapon.
## Separated so it can be unit-tested without a full scene.
func _apply_upgrade(u: Upgrade) -> void:
	if _player == null:
		return
	match u.kind:
		Upgrade.Kind.SIGNATURE:
			if _player.weapon:
				_player.weapon.level_up()
		Upgrade.Kind.EVOLUTION:
			if _player.weapon:
				_player.weapon.evolve()
		Upgrade.Kind.PASSIVE:
			if _player.weapon:
				_player.weapon.apply_passive(u.effect_value)
		Upgrade.Kind.GENERIC:
			_player.apply_stat_upgrade(u.effect_kind, u.effect_value)


func _on_upgrade_chosen(u: Upgrade) -> void:
	if upgrade_system:
		upgrade_system.apply(u)
	_apply_upgrade(u)
	_resolve_next_or_unpause()


## Resolve the next queued level-up (if any) before unpausing, so no level-up
## loses its reward and the tree only resumes once all are done.
func _resolve_next_or_unpause() -> void:
	if _pending_levelups > 0:
		_pending_levelups -= 1
		_present_next()  # stay paused, _choosing stays true
	else:
		_choosing = false
		get_tree().paused = false


## Courtesy bonus for a level-up gained when every upgrade is already maxed:
## a small permanent HP boost (also heals), so leveling still rewards and the
## picker is never shown empty.
func _grant_max_bonus() -> void:
	if _player and _player.has_method("apply_stat_upgrade"):
		_player.apply_stat_upgrade(&"max_hp", 5.0)
