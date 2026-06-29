# See docs/notes/pause-menu.md
class_name PauseMenu extends CanvasLayer
## Escape-key pause overlay for the 3D run.
## process_mode must be PROCESS_MODE_WHEN_PAUSED so the buttons respond while
## the scene tree is paused. Hidden by default; open()/close() toggle visibility
## and the tree's paused flag together so the two never drift apart.

const ARENA_SCENE  := "res://game/main_3d.tscn"
const SELECT_SCENE := "res://ui/character_select_3d.tscn"

@onready var _continue_btn: Button = $Panel/VBox/ContinueButton
@onready var _retry_btn:    Button = $Panel/VBox/RetryButton
@onready var _select_btn:   Button = $Panel/VBox/CharacterSelectButton
@onready var _quit_btn:     Button = $Panel/VBox/QuitButton


func _ready() -> void:
	hide()
	if _continue_btn:
		_continue_btn.pressed.connect(_on_continue)
	if _retry_btn:
		_retry_btn.pressed.connect(_on_retry)
	if _select_btn:
		_select_btn.pressed.connect(_on_character_select)
	if _quit_btn:
		_quit_btn.pressed.connect(_on_quit)


## Show the overlay and pause the scene tree.
func open() -> void:
	show()
	get_tree().paused = true


## Hide the overlay and unpause the scene tree.
func close() -> void:
	hide()
	get_tree().paused = false


## Returns true while the overlay is visible (i.e., the menu is open).
func is_open() -> bool:
	return visible


# ── Button handlers ───────────────────────────────────────────────────────────

func _on_continue() -> void:
	close()


func _on_retry() -> void:
	# selected_character persists in RunState; just reload the run scene.
	get_tree().paused = false
	get_tree().change_scene_to_file(ARENA_SCENE)


func _on_character_select() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(SELECT_SCENE)


func _on_quit() -> void:
	get_tree().quit()
