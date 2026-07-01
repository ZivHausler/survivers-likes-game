class_name TeamProgress
extends RefCounted

var level: int = 1
var xp: int = 0

static func xp_to_next(lvl: int) -> int:
	return 2 + lvl + lvl * lvl

func add_xp(amount: int) -> int:
	xp += amount
	var gained := 0
	while xp >= xp_to_next(level):
		xp -= xp_to_next(level)
		level += 1
		gained += 1
	return gained

func to_dict() -> Dictionary:
	return {"level": level, "xp": xp}

func from_dict(d: Dictionary) -> void:
	level = int(d.get("level", 1))
	xp = int(d.get("xp", 0))
