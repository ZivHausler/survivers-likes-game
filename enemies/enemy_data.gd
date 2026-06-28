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
