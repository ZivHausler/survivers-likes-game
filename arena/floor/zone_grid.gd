class_name ZoneGrid extends RefCounted
## Parses a hand-authored ASCII zone map (one char per cell) into a 2D grid of
## zone ids. Pure/data-only — no engine nodes. Grid is centered on the world
## origin so the arena straddles (0,0). See arena/maps/garden_map.gd for a recipe.

var width: int = 0
var height: int = 0
var cell_size: float = 4.0
var _cells: Array = []  # row-major: _cells[y][x] -> StringName

func _init(rows: PackedStringArray, legend: Dictionary, cell_size_: float) -> void:
	cell_size = cell_size_
	height = rows.size()
	for r in rows:
		width = maxi(width, r.length())
	for y in height:
		var row: Array = []
		var s: String = rows[y]
		for x in width:
			if x < s.length():
				var ch := s.substr(x, 1)
				row.append(legend.get(ch, &"void"))
			else:
				row.append(&"void")
		_cells.append(row)

func in_bounds(cx: int, cy: int) -> bool:
	return cx >= 0 and cy >= 0 and cx < width and cy < height

func zone_at(cx: int, cy: int) -> StringName:
	if not in_bounds(cx, cy):
		return &"void"
	return _cells[cy][cx]

func cell_center_world(cx: int, cy: int) -> Vector3:
	var ox := (float(width) - 1.0) * 0.5
	var oy := (float(height) - 1.0) * 0.5
	return Vector3((float(cx) - ox) * cell_size, 0.0, (float(cy) - oy) * cell_size)
