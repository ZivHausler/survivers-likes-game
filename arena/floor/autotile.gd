class_name Autotile
## Pure autotile resolver. Given a ZoneGrid, a cell, and a zone-priority map,
## decides which floor piece (base/edge/outer_corner/inner_corner) the cell needs
## and its quarter-turn rotation, so the HIGHER-priority zone owns clean seams.
## No engine calls — deterministic and unit-tested. See docs/.../overhaul spec §1.2.

const ZoneGrid = preload("res://arena/floor/zone_grid.gd")

const PIECE_BASE  := &"base"
const PIECE_EDGE  := &"edge"
const PIECE_OUTER := &"outer_corner"
const PIECE_INNER := &"inner_corner"

# Orthogonal offsets in N,E,S,W order → rotation index equals array index.
const _ORTHO := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
# Diagonal offsets in NE,SE,SW,NW order → rotation index equals array index.
const _DIAG := [Vector2i(1, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(-1, -1)]

static func _is_lower(grid: ZoneGrid, cx: int, cy: int, dx: int, dy: int,
		self_pri: int, priority: Dictionary) -> bool:
	var z := grid.zone_at(cx + dx, cy + dy)
	if not priority.has(z):
		return false  # pond/void/unknown never form a trim seam
	return int(priority[z]) < self_pri

static func resolve(grid: ZoneGrid, cx: int, cy: int, priority: Dictionary) -> Dictionary:
	var self_zone := grid.zone_at(cx, cy)
	var self_pri: int = int(priority.get(self_zone, -9999))

	# Orthogonal seam bitmask (bit i set = _ORTHO[i] is lower).
	var ortho := []
	for o in _ORTHO:
		ortho.append(_is_lower(grid, cx, cy, o.x, o.y, self_pri, priority))
	var n: bool = ortho[0]; var e: bool = ortho[1]; var s: bool = ortho[2]; var w: bool = ortho[3]
	var count := int(n) + int(e) + int(s) + int(w)

	if count >= 2:
		# Adjacent pair → convex outer corner (N+E=0, E+S=1, S+W=2, W+N=3).
		if n and e: return { "piece": PIECE_OUTER, "rotation": 0 }
		if e and s: return { "piece": PIECE_OUTER, "rotation": 1 }
		if s and w: return { "piece": PIECE_OUTER, "rotation": 2 }
		if w and n: return { "piece": PIECE_OUTER, "rotation": 3 }
		# Opposite pair (N+S or E+W): treat as an edge on the first set side (1-wide
		# strips are avoided by authoring; this keeps the resolver total).
		for i in 4:
			if ortho[i]:
				return { "piece": PIECE_EDGE, "rotation": i }

	if count == 1:
		for i in 4:
			if ortho[i]:
				return { "piece": PIECE_EDGE, "rotation": i }

	# No orthogonal seam: a lower DIAGONAL with both its adjacent orthogonals NOT lower
	# is a concave inner corner (NE=0, SE=1, SW=2, NW=3).
	for i in 4:
		var d: Vector2i = _DIAG[i]
		if _is_lower(grid, cx, cy, d.x, d.y, self_pri, priority):
			# adjacent orthogonals of diagonal i are ortho[i] and ortho[(i+1)%4]
			if not ortho[i] and not ortho[(i + 1) % 4]:
				return { "piece": PIECE_INNER, "rotation": i }

	return { "piece": PIECE_BASE, "rotation": 0 }
