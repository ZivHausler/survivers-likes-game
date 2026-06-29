# See docs/notes/game-camera-3d.md
extends Node3D
## 3D main scene root for the vertical slice.
## Builds a minimal CharacterData (null weapon_scene) and hands it to Player3D so
## WASD movement works immediately. Camera follow is wired via the scene's NodePath.

@onready var _player: Player3D = $Player

func _ready() -> void:
	var sb := StatBlock.new()
	var cd := CharacterData.new()
	cd.base_stats = sb
	# weapon_scene is intentionally null — no 3D weapons exist yet
	_player.setup(cd)
