shader_type spatial;

// ── Albedo ────────────────────────────────────────────────────────────────────
uniform vec4 albedo_tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform sampler2D albedo : source_color, hint_default_white;

// ── Rim (Fresnel) ─────────────────────────────────────────────────────────────
uniform vec4 rim_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float rim_power = 2.0;

// ── Emissive mask ─────────────────────────────────────────────────────────────
uniform sampler2D emissive_mask : hint_default_black;
uniform vec4 emissive_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float emissive_energy = 1.0;

void fragment() {
	// Albedo: tinted texture (or flat tint when no texture bound).
	ALBEDO = albedo_tint.rgb * texture(albedo, UV).rgb;
	ALPHA  = albedo_tint.a;

	// Rim (Fresnel): bright silhouette edge, added to EMISSION.
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), rim_power);
	EMISSION = rim * rim_color.rgb;

	// Emissive mask: optional painted glow areas.
	EMISSION += texture(emissive_mask, UV).r * emissive_color.rgb * emissive_energy;
}

void light() {
	// 2-band cel ramp on NdotL, modulated by ATTENUATION and LIGHT_COLOR.
	float NdotL = dot(NORMAL, LIGHT);
	float cel = step(0.0, NdotL) * 0.5 + step(0.5, NdotL) * 0.5;
	DIFFUSE_LIGHT += cel * ATTENUATION * LIGHT_COLOR;
}
