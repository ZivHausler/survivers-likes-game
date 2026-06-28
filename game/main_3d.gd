# See docs/notes/game-camera-3d.md
extends Node3D
## 3D main scene root for the vertical slice.
## Provides minimal WASD movement on the PlayerPlaceholder so the tilted
## camera follow can be verified interactively. Full player logic is Task 1.2.

const MOVE_SPEED := 8.0

@onready var _placeholder: CharacterBody3D = $PlayerPlaceholder

func _physics_process(_delta: float) -> void:
	if not _placeholder:
		return
	var dir := Vector3.ZERO
	if Input.is_action_pressed("move_left"):  dir.x -= 1.0
	if Input.is_action_pressed("move_right"): dir.x += 1.0
	if Input.is_action_pressed("move_up"):    dir.z -= 1.0
	if Input.is_action_pressed("move_down"):  dir.z += 1.0
	if dir.length_squared() > 0.0:
		dir = dir.normalized()
	_placeholder.velocity = dir * MOVE_SPEED
	_placeholder.move_and_slide()
