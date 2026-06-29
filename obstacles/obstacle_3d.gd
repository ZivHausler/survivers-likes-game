# See docs/notes/obstacle-3d.md
class_name Obstacle3D extends StaticBody3D
## Static, collidable map prop (tree / rock). Sits on the Obstacles layer (16) so it
## blocks the player and enemies, and carries a NavigationObstacle3D so enemy RVO
## avoidance routes the swarm around it. Skills never mask layer 16, so projectiles
## pass over props unchanged.

@onready var _mesh: MeshInstance3D = $MeshInstance3D
@onready var _shape: CollisionShape3D = $CollisionShape3D
@onready var _nav: NavigationObstacle3D = $NavigationObstacle3D

## Assign the visual mesh and resize collision + avoidance footprint to match.
func configure(mesh: Mesh, footprint_radius: float, height: float) -> void:
	if _mesh == null:  # not yet in tree — resolve @onready targets eagerly
		_mesh = $MeshInstance3D
		_shape = $CollisionShape3D
		_nav = $NavigationObstacle3D
	_mesh.mesh = mesh
	var cyl := CylinderShape3D.new()
	cyl.radius = footprint_radius
	cyl.height = height
	_shape.shape = cyl
	_nav.radius = footprint_radius
