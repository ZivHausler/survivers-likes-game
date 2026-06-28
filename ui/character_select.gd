# See docs/notes/how-to-add-a-character.md
class_name CharacterSelect extends Control
## Character selection screen: two buttons, one per playable character.
## Sets RunState.selected_character then transitions to the arena.

const ARENA_SCENE   := "res://game/arena.tscn"
const ZIV_PATH      := "res://characters/ziv.tres"
const AVIHAY_PATH   := "res://characters/avihay.tres"

@onready var _ziv_btn:    Button = $VBox/ZivButton
@onready var _avihay_btn: Button = $VBox/AvihayButton

func _ready() -> void:
	# Tint buttons by character colour
	var ziv_data: CharacterData    = load(ZIV_PATH)    as CharacterData
	var avihay_data: CharacterData = load(AVIHAY_PATH) as CharacterData

	if ziv_data:
		_ziv_btn.text      = ziv_data.display_name
		_ziv_btn.modulate  = ziv_data.color
	if avihay_data:
		_avihay_btn.text     = avihay_data.display_name
		_avihay_btn.modulate = avihay_data.color

	_ziv_btn.pressed.connect(func():    _pick(ZIV_PATH))
	_avihay_btn.pressed.connect(func(): _pick(AVIHAY_PATH))

func _pick(path: String) -> void:
	RunState.selected_character = load(path) as CharacterData
	get_tree().change_scene_to_file(ARENA_SCENE)
