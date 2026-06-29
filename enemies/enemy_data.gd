# See docs/notes/enemy.md
class_name EnemyData extends Resource

@export var id: StringName
@export var color: Color = Color.WHITE
@export var max_hp: float = 10.0
@export var move_speed: float = 80.0
@export var contact_damage: float = 4.0
@export var xp_value: int = 1
@export var is_ranged: bool = false
@export var radius: float = 8.0
@export var texture: Texture2D  ## Optional sprite texture; null → use color circle placeholder

## 3D model scene (GLB PackedScene). Null → keep placeholder sphere in 3D.
## Set per-variant in the .tres; 2D enemy ignores this field.
@export var model_scene: PackedScene
## Uniform scale applied to the Model Node3D when model_scene is set.
## FBX→GLB conversions may need tuning per-monster (playtest-tunable).
@export var model_scale: float = 1.0
## Y position offset (local Model space) to seat model feet at y≈0.
## Positive lifts the mesh up; adjust until feet contact the arena floor.
@export var model_y_offset: float = 0.0
