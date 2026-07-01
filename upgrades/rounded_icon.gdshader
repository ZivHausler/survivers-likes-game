shader_type canvas_item;
// Rounds the corners of a TextureRect via a rounded-rect SDF alpha mask, so the icon image
// itself gets a border radius (not just its plate). `aspect` = rect width / height (set from
// code so the radius stays circular on non-square plates); `radius` is in short-side units.

uniform float radius : hint_range(0.0, 0.5) = 0.10;
uniform float aspect = 1.0;

void fragment() {
	// Work in a space measured in height units so the corner radius is uniform on both axes.
	vec2 p = vec2(UV.x * aspect, UV.y);
	vec2 s = vec2(aspect, 1.0);
	vec2 half_s = s * 0.5;
	vec2 d = abs(p - half_s) - (half_s - vec2(radius));
	float dist = length(max(d, vec2(0.0))) + min(max(d.x, d.y), 0.0) - radius;
	float aa = fwidth(dist);
	COLOR.a *= 1.0 - smoothstep(-aa, aa, dist);
}
