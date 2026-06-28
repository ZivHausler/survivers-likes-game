# See docs/notes/game-events.md
extends Node
## Global signal bus. Systems emit/connect here instead of referencing each other.

signal enemy_killed(position: Vector2, xp_value: int)
signal xp_collected(amount: int)
signal player_leveled_up(level: int)
signal player_hp_changed(current: float, max_hp: float)
signal player_died()
signal evolution_unlocked(weapon_id: StringName)
