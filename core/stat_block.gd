# See docs/notes/stat-block.md
class_name StatBlock extends Resource

@export var max_hp: float = 100.0
@export var move_speed: float = 120.0
@export var pickup_range: float = 48.0
@export var damage_mult: float = 1.0
@export var fire_rate_mult: float = 1.0
@export var armor: float = 0.0

func duplicate_stats() -> StatBlock:
	return duplicate(true) as StatBlock
