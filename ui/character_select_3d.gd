# See docs/notes/character-select-3d.md
class_name CharacterSelect3D extends Control
## Character selection screen for 3D run: two buttons, one per playable character.
## Sets RunState.selected_character (3D CharacterData) then transitions to main_3d.

const MAIN_3D_SCENE  := "res://game/main_3d.tscn"
const ZIV_3D_PATH    := "res://characters/ziv_3d.tres"
const AVIHAY_3D_PATH := "res://characters/avihay_3d.tres"

@onready var _ziv_btn:    Button = $VBox/ZivButton
@onready var _avihay_btn: Button = $VBox/AvihayButton

func _ready() -> void:
	# Tint buttons by character colour
	var ziv_data: CharacterData    = load(ZIV_3D_PATH)    as CharacterData
	var avihay_data: CharacterData = load(AVIHAY_3D_PATH) as CharacterData

	if ziv_data:
		_ziv_btn.text     = ziv_data.display_name
		_ziv_btn.modulate = ziv_data.color
	if avihay_data:
		_avihay_btn.text     = avihay_data.display_name
		_avihay_btn.modulate = avihay_data.color

	_ziv_btn.pressed.connect(func():    _pick(ZIV_3D_PATH))
	_avihay_btn.pressed.connect(func(): _pick(AVIHAY_3D_PATH))

func _pick(path: String) -> void:
	RunState.selected_character = load(path) as CharacterData
	get_tree().change_scene_to_file(MAIN_3D_SCENE)
