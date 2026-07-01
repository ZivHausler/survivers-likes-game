class_name TileVariants
## Deterministic per-cell variant picker so repeated floor areas never look flat.
## Pure integer hash of cell coords → index in [0, count). No RNG state.

static func variant_for(cx: int, cy: int, count: int) -> int:
	if count <= 1:
		return 0
	var h := (cx * 73856093) ^ (cy * 19349663)
	return absi(h) % count
