# See docs/notes/character-select-3d.md
class_name CharacterSelect3D extends Control
## Character selection screen for 3D run: one Button per playable character, generated
## data-driven from CHARACTER_PATHS.  Sets RunState.selected_character (3D CharacterData)
## then transitions to main_3d.

const MAIN_3D_SCENE := "res://game/main_3d.tscn"

## All 10 playable 3D characters — Ziv and Avihay first, then the eight new friends.
const CHARACTER_PATHS: Array[String] = [
	"res://characters/ziv_3d.tres",
	"res://characters/avihay_3d.tres",
	"res://characters/avinoam_3d.tres",
	"res://characters/matan_3d.tres",
	"res://characters/ido_3d.tres",
	"res://characters/yuval_3d.tres",
	"res://characters/natali_3d.tres",
	"res://characters/barak_3d.tres",
	"res://characters/yinon_3d.tres",
	"res://characters/yoav_3d.tres",
]

@onready var _grid: GridContainer = $VBox/Scroll/Grid

func _ready() -> void:
	for path in CHARACTER_PATHS:
		var data: CharacterData = load(path) as CharacterData
		if data == null:
			push_warning("CharacterSelect3D: could not load CharacterData from %s — skipping" % path)
			continue

		var btn := Button.new()
		btn.text               = data.display_name
		btn.modulate           = data.color
		btn.custom_minimum_size = Vector2(160, 50)
		btn.pressed.connect(_pick.bind(path))
		_grid.add_child(btn)

func _pick(path: String) -> void:
	RunState.selected_character = load(path) as CharacterData
	get_tree().change_scene_to_file(MAIN_3D_SCENE)
