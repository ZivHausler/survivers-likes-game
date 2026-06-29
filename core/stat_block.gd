# See docs/notes/stat-block.md
class_name StatBlock extends Resource

@export var max_hp: float = 100.0
@export var move_speed: float = 120.0
@export var pickup_range: float = 80.0
@export var damage_mult: float = 1.0
@export var fire_rate_mult: float = 1.0
@export var armor: float = 0.0
## Base passive health regenerated per second (0 = none). Varies per character.
@export var hp_regen: float = 0.0

func duplicate_stats() -> StatBlock:
	return duplicate(true) as StatBlock
