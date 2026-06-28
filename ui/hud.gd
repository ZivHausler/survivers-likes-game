# See docs/notes/hud.md
class_name HUD extends CanvasLayer
## In-run heads-up display: timer, HP bar, XP bar + level, kill counter.
## process_mode = PROCESS_MODE_WHEN_PAUSED so it stays live during level-up overlay.

@onready var _timer_label:  Label      = $VBox/TimerLabel
@onready var _kills_label:  Label      = $VBox/KillsLabel
@onready var _level_label:  Label      = $VBox/LevelLabel
@onready var _hp_bar:       ProgressBar = $VBox/HPBar
@onready var _xp_bar:       ProgressBar = $VBox/XPBar

var _game_manager: GameManager = null
var _player: Player = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	GameEvents.player_hp_changed.connect(_on_hp_changed)
	GameEvents.player_leveled_up.connect(_on_leveled_up)

	# Defer finding siblings so the full scene tree is ready
	call_deferred("_find_siblings")

func _find_siblings() -> void:
	var parent := get_parent()
	if parent == null:
		return
	_game_manager = parent.get_node_or_null("GameManager") as GameManager
	_player       = parent.get_node_or_null("Player")      as Player

func _process(_dt: float) -> void:
	if _game_manager:
		var secs := int(_game_manager.get_elapsed())
		_timer_label.text = "%d:%02d" % [secs / 60, secs % 60]
		_kills_label.text = "Kills: %d" % _game_manager.get_kills()
	if _player:
		_xp_bar.max_value = _player.xp_to_next(_player.level)
		_xp_bar.value     = _player.xp

func _on_hp_changed(current: float, max_hp: float) -> void:
	_hp_bar.max_value = max_hp
	_hp_bar.value     = current

func _on_leveled_up(level: int) -> void:
	_level_label.text = "Lv %d" % level
