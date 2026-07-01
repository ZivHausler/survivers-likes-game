class_name SplatField extends RefCounted
## Pure generator of ground control images from a ZoneGrid: an RGBA splatmap (per-pixel
## zone-blend weights) and a grayscale edge-shadow / AO map (faux elevation). CPU-only
## (Image), no scene nodes, so it is unit-testable headless. See
## docs/superpowers/specs/2026-07-01-splatmap-ground-blending-design.md.

const ZoneGrid := preload("res://arena/floor/zone_grid.gd")

# Fixed RGBA channel assignment. Grass is the implicit base (weight = 1 - R - G - B - A).
const CHANNEL := { &"stone_plaza": 0, &"stone_path": 1, &"dirt_path": 2, &"flowerbed": 3 }

# pond/void render as the grass base (ground is drawn under the pond; map edge = grass).
static func _field_zone(z: StringName) -> StringName:
	if z == &"pond" or z == &"void":
		return &"grass"
	return z

# Field zone of the cell a texel falls in; out-of-grid clamps to grass (no map-edge seam).
static func _texel_zone(grid, tx: int, ty: int, k: int) -> StringName:
	var cx := tx / k
	var cy := ty / k
	if not grid.in_bounds(cx, cy):
		return &"grass"
	return _field_zone(grid.zone_at(cx, cy))

# smoothstep(0,width,d) with a hard-step fallback at width<=0 (d is always > 0 here).
static func _ramp(d: float, width: float) -> float:
	if width <= 0.0:
		return 1.0
	return smoothstep(0.0, width, d)

static func _tier_at(grid, tx: int, ty: int, k: int, tier: Dictionary) -> int:
	var cx := tx / k
	var cy := ty / k
	if not grid.in_bounds(cx, cy):
		return 0
	return int(tier.get(_field_zone(grid.zone_at(cx, cy)), 0))

# Edge-shadow map: darkens the LOW side of a tier drop within `band` world units, up to
# `strength`. High side and same-tier areas stay white (v=1). Reads as a low plateau.
static func build_ao(grid, tier: Dictionary, k: int, band: float, strength: float) -> Image:
	var w: int = grid.width * k
	var h: int = grid.height * k
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	var wpt: float = grid.cell_size / float(k)
	var r := int(ceil(band / wpt)) + 1
	for ty in h:
		for tx in w:
			var own_t := _tier_at(grid, tx, ty, k, tier)
			var best := INF
			for sy in range(-r, r + 1):
				for sx in range(-r, r + 1):
					if _tier_at(grid, tx + sx, ty + sy, k, tier) > own_t:
						var d: float = sqrt(float(sx * sx + sy * sy)) * wpt
						best = minf(best, d)
			var shade := 0.0
			if best < INF:
				shade = (1.0 - smoothstep(0.0, band, best)) * strength
			var v := 1.0 - shade
			img.set_pixel(tx, ty, Color(v, v, v))
	return img

static func build_splatmap(grid, blend: Dictionary, k: int) -> Image:
	var w: int = grid.width * k
	var h: int = grid.height * k
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var wpt: float = grid.cell_size / float(k)  # world units per texel
	var max_blend := 0.0
	for z in blend:
		max_blend = maxf(max_blend, float(blend[z]))
	# Search radius covers the widest half-transition plus a texel of slack.
	var r := int(ceil(max_blend / wpt)) + 1
	for ty in h:
		for tx in w:
			var own: StringName = _texel_zone(grid, tx, ty, k)
			# Nearest texel of a DIFFERENT field zone within the window.
			var best := INF
			var other: StringName = own
			for sy in range(-r, r + 1):
				for sx in range(-r, r + 1):
					var oz: StringName = _texel_zone(grid, tx + sx, ty + sy, k)
					if oz != own:
						var d: float = sqrt(float(sx * sx + sy * sy)) * wpt
						if d < best:
							best = d
							other = oz
			# Two-zone local blend: width = min of the pair (0 on either side => sharp).
			var wgt := { own: 1.0 }
			if best < INF:
				var width: float = minf(float(blend.get(own, 0.0)), float(blend.get(other, 0.0)))
				var ow := _ramp(best, width)
				wgt = { own: ow, other: 1.0 - ow }
			img.set_pixel(tx, ty, Color(
				float(wgt.get(&"stone_plaza", 0.0)),
				float(wgt.get(&"stone_path", 0.0)),
				float(wgt.get(&"dirt_path", 0.0)),
				float(wgt.get(&"flowerbed", 0.0))))
	return img
