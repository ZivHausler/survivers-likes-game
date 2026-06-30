shader_type spatial;
render_mode cull_disabled;

// Dissolve-death shader: noise-driven alpha clip with emissive edge band.
// progress 0 = fully visible, 1 = fully dissolved.
// edge_color is the glowing fringe at the dissolve boundary (source_color = sRGB-corrected).

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec4 edge_color : source_color = vec4(1.0, 0.2, 0.6, 1.0);

// ── Procedural noise (no texture required) ───────────────────────────────────

// Fast 2-D hash: maps a vec2 grid cell to a pseudo-random float in [0, 1).
float hash2(vec2 p) {
	p = fract(p * vec2(443.897, 441.423));
	p += dot(p, p.yx + 19.19);
	return fract((p.x + p.y) * p.x);
}

// Smooth value noise in [0, 1] — bilinearly interpolated hash lattice.
float noise2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);  // cubic hermite smoothstep
	float a = hash2(i);
	float b = hash2(i + vec2(1.0, 0.0));
	float c = hash2(i + vec2(0.0, 1.0));
	float d = hash2(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// ── Fragment ─────────────────────────────────────────────────────────────────

void fragment() {
	// Two octaves of noise for a more organic dissolve pattern.
	float n = noise2(UV * 7.0) * 0.6 + noise2(UV * 15.0) * 0.4;

	// Dissolve clip: discard pixels whose noise value falls below the progress threshold.
	// At progress=0 nothing is clipped (fully visible); at progress=1 all pixels are gone.
	if (n < progress) {
		discard;
	}

	// Emissive edge band: pixels just above the dissolve boundary glow with edge_color.
	const float EDGE_WIDTH = 0.09;
	float edge_t = 1.0 - smoothstep(0.0, EDGE_WIDTH, n - progress);

	ALBEDO = vec3(0.15);
	EMISSION = edge_color.rgb * edge_t * 5.0;
	ALPHA = 1.0;
}
