extends GutTest
## Verifies player + enemy bodies collide with the Obstacles layer (bit 16),
## so trees/rocks/walls block them. Instantiates without entering _ready by
## reading collision_mask straight off the freshly instantiated root node.

const OBSTACLE_BIT := 16

func _root_mask(scene_path: String) -> int:
	var scene: PackedScene = load(scene_path)
	assert_not_null(scene, "%s must load" % scene_path)
	var node: Node = scene.instantiate()
	var mask: int = (node as CollisionObject3D).collision_mask
	node.free()
	return mask

func test_player_body_masks_obstacles() -> void:
	var mask := _root_mask("res://player/player_3d.tscn")
	assert_true((mask & OBSTACLE_BIT) == OBSTACLE_BIT,
		"player body collision_mask must include the Obstacles bit (16)")

func test_enemy_body_masks_obstacles() -> void:
	var mask := _root_mask("res://enemies/enemy_3d.tscn")
	assert_true((mask & OBSTACLE_BIT) == OBSTACLE_BIT,
		"enemy body collision_mask must include the Obstacles bit (16)")
