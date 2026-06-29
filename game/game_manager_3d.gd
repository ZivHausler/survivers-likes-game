# See docs/notes/game-manager-3d.md
class_name GameManager3D extends Node
## Owns the 3D run loop: XP gem spawning, kill counter, and run setup.
## Lives inside main_3d.tscn as a Node child of the scene root.
## Task 1.5 will add the upgrade UI, game-over routing, and level-up pause flow.

const GEM_SCENE_PATH := "res://pickups/xp_gem_3d.tscn"

var _player: Player3D = null
var _spawner = null  # Spawner3D at runtime; duck-typed so test stubs work
var _gem_scene: PackedScene = null

var elapsed: float = 0.0
var kills: int = 0


func _ready() -> void:
	_gem_scene = load(GEM_SCENE_PATH) as PackedScene
	start()


func start() -> void:
	var parent := get_parent()
	if parent == null:
		return

	_player  = parent.get_node_or_null("Player") as Player3D
	_spawner = parent.get_node_or_null("Spawner3D")  # duck-typed; no cast needed

	# Build world-scale CharacterData (1 unit ≈ 16 px).
	var sb := StatBlock.new()
	sb.move_speed    = 7.5    # 120 px / 16
	sb.pickup_range  = 5.0    # 80 px / 16
	sb.max_hp        = 100.0
	sb.damage_mult   = 1.0
	sb.fire_rate_mult = 1.0
	sb.armor         = 0.0

	var cd := CharacterData.new()
	cd.base_stats   = sb
	cd.weapon_scene = load("res://weapons/ziv_stunning_looks_3d.tscn") as PackedScene

	if _player:
		_player.setup(cd)

	if _spawner != null and _player != null:
		_spawner.setup(_player)

	GameEvents.enemy_killed_3d.connect(_on_enemy_killed)


func _process(dt: float) -> void:
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
	gem.position = pos
	gem.setup(xp, _player)
	var parent := get_parent()
	if parent:
		# Defer insertion: enemy_killed_3d can fire from inside a physics callback.
		# Adding an Area3D during physics query flush prevents monitoring setup,
		# so body_entered never fires. Deferring moves insertion to a safe point.
		parent.add_child.call_deferred(gem)
