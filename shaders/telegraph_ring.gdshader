// AoE telegraph ring — additive flat decal laid on the XZ ground plane.
// Drawn on a PlaneMesh (Y-up); UV (0,0)→(1,1) maps across the mesh.
// The ring position is animated by the script via the `radius` uniform (0..1).
shader_type spatial;
render_mode blend_add, cull_disabled, unshaded, depth_draw_never, depth_test_disabled;

uniform vec4 ring_color : source_color = vec4(0.3, 0.8, 1.0, 1.0);
// Normalized ring radius: 0 = center, 1 = outer edge of the mesh.
uniform float radius : hint_range(0.0, 1.2) = 0.5;
// Half-width of the soft ring edge in the same normalized space.
uniform float width : hint_range(0.01, 0.5) = 0.06;

void fragment() {
	// UV center is (0.5, 0.5); d is in [0, 1] at the mesh edge.
	vec2 centered = UV - vec2(0.5, 0.5);
	float d = length(centered) * 2.0;

	// Soft ring: fade in from inner edge, fade out past outer edge.
	float inner = smoothstep(radius - width, radius, d);
	float outer = smoothstep(radius, radius + width, d);
	float ring  = inner - outer;

	ALBEDO = ring_color.rgb;
	ALPHA  = ring * ring_color.a;
}
