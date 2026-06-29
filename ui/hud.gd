# See docs/notes/hud.md
class_name HUD extends CanvasLayer
## In-run heads-up display: timer, HP bar, XP bar + level, kill counter.
## process_mode = PROCESS_MODE_ALWAYS so _process runs BOTH during normal play
## (live timer/kills/XP) and while the level-up overlay pauses the tree.

@onready var _timer_label:   Label       = $VBox/TimerLabel
@onready var _kills_label:   Label       = $VBox/KillsLabel
@onready var _level_label:   Label       = $VBox/LevelLabel
@onready var _hp_bar:        ProgressBar = $VBox/HPBar
@onready var _xp_bar:        ProgressBar = $VBox/XPBar
@onready var _evolve_banner: Label       = $EvolveBanner
@onready var _boss_bar:      Control     = $BossBar
@onready var _boss_name:     Label       = $BossBar/BossNameLabel
@onready var _boss_hp_bar:   ProgressBar = $BossBar/BossHPBar
@onready var _boss_hp_text:  Label       = $BossBar/BossHPBar/BossHPText

var _game_manager: Node = null  # duck-typed: GameManager (2D) or GameManager3D
var _player: Node = null        # duck-typed: Player (2D) or Player3D
var _evolve_tween: Tween = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameEvents.player_hp_changed.connect(_on_hp_changed)
	GameEvents.player_leveled_up.connect(_on_leveled_up)
	GameEvents.evolution_unlocked.connect(_on_evolution_unlocked)
	GameEvents.boss_spawned.connect(_on_boss_spawned)
	GameEvents.boss_hp_changed.connect(_on_boss_hp_changed)
	GameEvents.boss_died.connect(_on_boss_died)

	# Defer finding siblings so the full scene tree is ready
	call_deferred("_find_siblings")

func _find_siblings() -> void:
	var parent := get_parent()
	if parent == null:
		return
	# GameManager: try 2D name, then 3D name, then any sibling with get_elapsed().
	_game_manager = parent.get_node_or_null("GameManager")
	if _game_manager == null:
		_game_manager = parent.get_node_or_null("GameManager3D")
	if _game_manager == null:
		for child in parent.get_children():
			if child.has_method("get_elapsed"):
				_game_manager = child
				break
	# Player: prefer the "player" group (both Player and Player3D are in it),
	# fall back to a sibling named "Player".
	_player = get_tree().get_first_node_in_group("player")
	if _player == null:
		_player = parent.get_node_or_null("Player")

func _process(_dt: float) -> void:
	if _game_manager and is_instance_valid(_game_manager):
		if _game_manager.has_method("get_elapsed"):
			var secs := int(_game_manager.get_elapsed())
			_timer_label.text = "%d:%02d" % [secs / 60, secs % 60]
		if _game_manager.has_method("get_kills"):
			_kills_label.text = "Kills: %d" % _game_manager.get_kills()
	if _player and is_instance_valid(_player):
		if _player.has_method("xp_to_next") and "level" in _player:
			_xp_bar.max_value = _player.xp_to_next(_player.get("level"))
		if "xp" in _player:
			_xp_bar.value = _player.get("xp")

func _on_hp_changed(current: float, max_hp: float) -> void:
	_hp_bar.max_value = max_hp
	_hp_bar.value     = current

func _on_leveled_up(level: int) -> void:
	_level_label.text = "Lv %d" % level

func _on_evolution_unlocked(_weapon_id: StringName) -> void:
	# Kill any in-flight fade so a rapid second evolution doesn't leave the old
	# tween's hide-callback to blink the banner off mid-fade.
	if _evolve_tween and _evolve_tween.is_valid():
		_evolve_tween.kill()
	_evolve_banner.modulate = Color.WHITE
	_evolve_banner.visible = true
	_evolve_tween = create_tween()
	_evolve_tween.tween_property(_evolve_banner, "modulate:a", 0.0, 2.0).set_delay(0.5)
	_evolve_tween.tween_callback(func(): _evolve_banner.visible = false)

func _on_boss_spawned(boss_name: String, max_hp: float) -> void:
	_boss_name.text = boss_name
	_boss_hp_bar.max_value = max_hp
	_boss_hp_bar.value = max_hp
	_boss_hp_text.text = "%d / %d" % [int(max_hp), int(max_hp)]
	_boss_bar.visible = true

func _on_boss_hp_changed(current: float, max_hp: float) -> void:
	_boss_hp_bar.max_value = max_hp
	_boss_hp_bar.value = current
	_boss_hp_text.text = "%d / %d" % [int(max(current, 0.0)), int(max_hp)]

func _on_boss_died() -> void:
	_boss_bar.visible = false
