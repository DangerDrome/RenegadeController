/*
Obra Dinn-style dither shader for Godot 4.x (Screen-Space Version)
Original by Sam Bigos (MIT license) - https://github.com/samuelbigos/godot_dither_shader

This is the SCREEN-SPACE dither shader using canvas_item.
For WORLD-SPACE dithering, use dither_world.gdshader with a fullscreen quad instead.
*/

shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
uniform sampler2D u_dither_tex : filter_nearest, repeat_enable;
uniform sampler2D u_color_tex : filter_nearest;

uniform int u_bit_depth : hint_range(2, 64) = 32;
uniform float u_contrast : hint_range(0.0, 5.0) = 1.0;
uniform float u_offset : hint_range(-1.0, 1.0) = 0.0;
uniform int u_dither_size : hint_range(1, 8) = 2;
uniform float u_mix : hint_range(0.0, 1.0) = 1.0;
uniform int u_blend_mode : hint_range(0, 10) = 0;

// Masking - luminance-based (screen-space only has access to color)
uniform bool u_mask_shadows_enabled = false;
uniform float u_mask_shadows_threshold : hint_range(0.0, 1.0) = 0.5;
uniform float u_mask_shadows_softness : hint_range(0.0, 0.5) = 0.1;
uniform bool u_mask_highlights_enabled = false;
uniform float u_mask_highlights_threshold : hint_range(0.0, 1.0) = 0.5;
uniform float u_mask_highlights_softness : hint_range(0.0, 0.5) = 0.1;

// Blend mode functions
vec3 blend_normal(vec3 base, vec3 blend) { return blend; }
vec3 blend_add(vec3 base, vec3 blend) { return min(base + blend, vec3(1.0)); }
vec3 blend_subtract(vec3 base, vec3 blend) { return max(base - blend, vec3(0.0)); }
vec3 blend_multiply(vec3 base, vec3 blend) { return base * blend; }
vec3 blend_screen(vec3 base, vec3 blend) { return 1.0 - (1.0 - base) * (1.0 - blend); }
vec3 blend_overlay(vec3 base, vec3 blend) {
	return mix(
		2.0 * base * blend,
		1.0 - 2.0 * (1.0 - base) * (1.0 - blend),
		step(0.5, base)
	);
}
vec3 blend_soft_light(vec3 base, vec3 blend) {
	return mix(
		2.0 * base * blend + base * base * (1.0 - 2.0 * blend),
		sqrt(base) * (2.0 * blend - 1.0) + 2.0 * base * (1.0 - blend),
		step(0.5, blend)
	);
}
vec3 blend_hard_light(vec3 base, vec3 blend) {
	return mix(
		2.0 * base * blend,
		1.0 - 2.0 * (1.0 - base) * (1.0 - blend),
		step(0.5, blend)
	);
}
vec3 blend_color_dodge(vec3 base, vec3 blend) { return min(base / max(1.0 - blend, 0.001), vec3(1.0)); }
vec3 blend_color_burn(vec3 base, vec3 blend) { return 1.0 - min((1.0 - base) / max(blend, 0.001), vec3(1.0)); }
vec3 blend_difference(vec3 base, vec3 blend) { return abs(base - blend); }

void fragment() {
	// Sample the screen texture at the desired output resolution (according to u_dither_size)
	vec2 screen_size = vec2(textureSize(screen_texture, 0)) / float(u_dither_size);
	vec2 screen_sample_uv = floor(SCREEN_UV * screen_size) / screen_size;
	vec3 screen_col = texture(screen_texture, screen_sample_uv).rgb;

	// Calculate pixel luminosity
	float lum = (screen_col.r * 0.299) + (screen_col.g * 0.587) + (screen_col.b * 0.114);

	// Adjust with contrast and offset parameters
	lum = (lum - 0.5 + u_offset) * u_contrast + 0.5;
	lum = clamp(lum, 0.0, 1.0);

	// Reduce luminosity bit depth to give a more banded visual if desired
	float bits = float(u_bit_depth);
	lum = floor(lum * bits) / bits;

	// Get the palette texture size mapped so it is 1px high
	ivec2 col_size = textureSize(u_color_tex, 0);
	col_size /= col_size.y;

	float col_x = float(col_size.x) - 1.0;
	float col_texel_size = 1.0 / col_x;

	lum = max(lum - 0.00001, 0.0);
	float lum_lower = floor(lum * col_x) * col_texel_size;
	float lum_upper = (floor(lum * col_x) + 1.0) * col_texel_size;
	float lum_scaled = lum * col_x - floor(lum * col_x);

	// Screen-space dithering
	ivec2 noise_size = textureSize(u_dither_tex, 0);
	vec2 inv_noise_size = vec2(1.0 / float(noise_size.x), 1.0 / float(noise_size.y));
	vec2 noise_uv = SCREEN_UV * inv_noise_size * vec2(float(screen_size.x), float(screen_size.y));

	float threshold = texture(u_dither_tex, noise_uv).r;

	// Adjust the dither slightly so min and max aren't quite at 0.0 and 1.0
	threshold = threshold * 0.99 + 0.005;

	// Pick color based on threshold
	float ramp_val = lum_scaled < threshold ? 0.0 : 1.0;
	float col_sample = mix(lum_lower, lum_upper, ramp_val);
	vec3 dither_col = texture(u_color_tex, vec2(col_sample, 0.5)).rgb;

	// Get original scene color
	vec3 original_col = texture(screen_texture, SCREEN_UV).rgb;

	// Apply blend mode
	vec3 blended_col;
	switch (u_blend_mode) {
		case 0: blended_col = blend_normal(original_col, dither_col); break;
		case 1: blended_col = blend_add(original_col, dither_col); break;
		case 2: blended_col = blend_subtract(original_col, dither_col); break;
		case 3: blended_col = blend_multiply(original_col, dither_col); break;
		case 4: blended_col = blend_screen(original_col, dither_col); break;
		case 5: blended_col = blend_overlay(original_col, dither_col); break;
		case 6: blended_col = blend_soft_light(original_col, dither_col); break;
		case 7: blended_col = blend_hard_light(original_col, dither_col); break;
		case 8: blended_col = blend_color_dodge(original_col, dither_col); break;
		case 9: blended_col = blend_color_burn(original_col, dither_col); break;
		case 10: blended_col = blend_difference(original_col, dither_col); break;
		default: blended_col = dither_col; break;
	}

	// === MASKING ===
	float mask = 1.0;
	float raw_lum = dot(original_col, vec3(0.299, 0.587, 0.114));

	// Luminance masking - shadows
	if (u_mask_shadows_enabled) {
		float shadow_mask = smoothstep(
			u_mask_shadows_threshold + u_mask_shadows_softness,
			u_mask_shadows_threshold - u_mask_shadows_softness,
			raw_lum
		);
		mask *= shadow_mask;
	}

	// Luminance masking - highlights
	if (u_mask_highlights_enabled) {
		float highlight_mask = smoothstep(
			u_mask_highlights_threshold - u_mask_highlights_softness,
			u_mask_highlights_threshold + u_mask_highlights_softness,
			raw_lum
		);
		mask *= highlight_mask;
	}

	// Mix between original and blended result with mask
	vec3 final_col = mix(original_col, blended_col, u_mix * mask);

	COLOR.rgb = final_col;
}
