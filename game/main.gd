# See docs/notes/game-manager.md
extends Node
## Entry point: immediately routes to the character selection screen.
## main.tscn is the project's main scene (set in project.godot).

const SELECT_SCENE := "res://ui/character_select.tscn"

func _ready() -> void:
	get_tree().change_scene_to_file.call_deferred(SELECT_SCENE)
