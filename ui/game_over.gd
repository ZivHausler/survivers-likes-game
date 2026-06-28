# See docs/notes/game-over.md
class_name GameOver extends Control
## End-of-run screen: shows time survived and kills from RunState.last_run.
## Buttons: Retry → arena, Character Select → character select.

const ARENA_SCENE    := "res://game/arena.tscn"
const SELECT_SCENE   := "res://ui/character_select.tscn"

@onready var _time_label:   Label  = $VBox/TimeLabel
@onready var _kills_label:  Label  = $VBox/KillsLabel
@onready var _retry_btn:    Button = $VBox/RetryButton
@onready var _select_btn:   Button = $VBox/SelectButton

func _ready() -> void:
	var run: Dictionary = RunState.last_run
	var secs: int = int(run.get("time", 0.0))
	_time_label.text  = "Survived: %d:%02d" % [secs / 60, secs % 60]
	_kills_label.text = "Kills: %d"         % int(run.get("kills", 0))

	_retry_btn.pressed.connect(func(): get_tree().change_scene_to_file(ARENA_SCENE))
	_select_btn.pressed.connect(func(): get_tree().change_scene_to_file(SELECT_SCENE))
