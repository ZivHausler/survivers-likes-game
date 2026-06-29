class_name SkillPool extends RefCounted
## Shared weapon pool + the pure type-filter that gates which weapons a character
## may be offered. The registry (`all()`) is populated by content plans via the
## explicit preload list below; the foundation ships it empty.

## Order-preserving filter: keep entries whose type is &"natural" OR is in `types`.
static func filter(pool: Array, types: Array) -> Array:
	var out: Array = []
	for sd in pool:
		if sd.type == &"natural" or types.has(sd.type):
			out.append(sd)
	return out

## All shared-pool weapons (10 natural + 10 typed once content lands). Empty for now.
static func all() -> Array:
	# Content plans add: const W_PEW_PEW := preload("res://characters/skills/pew_pew.tres")
	# and list them here. Foundation registry is intentionally empty.
	return []

## Weapons a character with `types` may be offered: natural ∪ matching types.
static func for_types(types: Array) -> Array:
	return filter(all(), types)
