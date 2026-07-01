class_name PropLayout
## Pure resolver: turns authored prop clusters into concrete world placements,
## reusing ArenaScatter.compute_positions for deterministic in-cluster jitter.
## Drops anything inside the spawn disc so the combat center stays open.

const ArenaScatter = preload("res://arena/arena_scatter.gd")

static func resolve(clusters: Array, clear_radius: float) -> Array:
	var out: Array = []
	var clear_sq := clear_radius * clear_radius
	for cluster in clusters:
		var center: Vector2 = cluster["center"]
		var ext: float = cluster["ext"]
		var sep: float = cluster["sep"]
		var seed_off: int = cluster["seed"]
		var role: StringName = cluster["role"]
		# Flatten items into a key/collide/scale list preserving order.
		var keys: Array = []
		for entry in cluster["items"]:
			for _i in entry[1]:
				keys.append({ "key": entry[0], "collide": entry[2], "scale": entry[3] })
		if keys.is_empty():
			continue
		var positions := ArenaScatter.compute_positions(seed_off, keys.size(), ext, 0.0, sep)
		for i in positions.size():
			var world := Vector3(center.x + positions[i].x, 0.0, center.y + positions[i].z)
			if world.x * world.x + world.z * world.z < clear_sq:
				continue
			out.append({
				"key": keys[i]["key"], "pos": world, "collide": keys[i]["collide"],
				"scale": keys[i]["scale"], "role": role,
			})
	return out
