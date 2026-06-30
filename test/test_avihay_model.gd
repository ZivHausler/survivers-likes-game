# See docs/notes/character-data.md
extends GutTest
## Verifies Avihay uses the generated rigged uwu_soldier model and that it honors
## the consumer animation contract (idle + walk clips present). See docs/notes/asset-pipeline.md.

func test_avihay_model_scene_is_set():
	var data: CharacterData = load("res://characters/avihay_3d.tres")
	assert_not_null(data, "avihay_3d.tres should load")
	assert_not_null(data.model_scene, "avihay must have a model_scene")

func test_avihay_model_has_idle_and_walk_animations():
	var data: CharacterData = load("res://characters/avihay_3d.tres")
	var inst = data.model_scene.instantiate()
	var ap: AnimationPlayer = inst.find_child("AnimationPlayer", true, false)
	assert_not_null(ap, "rigged model must expose an AnimationPlayer")
	if ap:
		assert_true(ap.has_animation("idle"), "model must have an 'idle' clip (player plays it)")
		assert_true(ap.has_animation("walk"), "model must have a 'walk' clip (player plays it while moving)")
	inst.free()

func test_avihay_model_has_skeleton():
	var data: CharacterData = load("res://characters/avihay_3d.tres")
	var inst = data.model_scene.instantiate()
	var sk = inst.find_child("Skeleton3D", true, false)
	assert_not_null(sk, "rigged model must have a Skeleton3D")
	inst.free()
