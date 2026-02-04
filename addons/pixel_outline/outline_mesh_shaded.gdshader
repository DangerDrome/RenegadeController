// Toon-shaded mesh shader for outline rendering
// Use with OutlineMaterial.toon() - pair with outline_data_pass as next_pass
shader_type spatial;

uniform vec4 albedo_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform sampler2D albedo_texture : source_color, filter_nearest;
uniform bool use_texture = false;

// Toon shading parameters
uniform int shade_levels : hint_range(2, 8) = 3;
uniform float shade_softness : hint_range(0.0, 1.0) = 0.1;

void fragment() {
	vec4 color = albedo_color;
	if (use_texture) {
		color *= texture(albedo_texture, UV);
	}
	ALBEDO = color.rgb;
	ALPHA = color.a;
}

void light() {
	// Toon shading - quantize the lighting
	float NdotL = dot(NORMAL, LIGHT);
	float intensity = (NdotL + 1.0) * 0.5; // Remap to 0-1

	// Quantize to shade_levels
	float levels = float(shade_levels);
	float quantized = floor(intensity * levels + shade_softness) / levels;
	quantized = clamp(quantized, 0.0, 1.0);

	DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR * ATTENUATION * quantized;
}
