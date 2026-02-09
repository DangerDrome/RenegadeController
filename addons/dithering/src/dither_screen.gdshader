/*
Screen-space dither shader for Godot 4.x
Uses canvas_item - pattern moves with camera (film-grain look).

Algorithms:
0 = Texture-based ordered (Bayer/Blue Noise from texture)
1 = Procedural Bayer (no texture needed)
2 = Blue Noise Error Diffusion Approximation
3 = White Noise
4 = Interleaved Gradient Noise (Jimenez 2014)

Palette Modes:
0 = Luminance (classic 1D palette lookup)
1 = Multi-color nearest (perceptual palette matching + dither)
*/

shader_type canvas_item;

#include "res://addons/dithering/src/dither_functions.gdshaderinc"

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
uniform sampler2D u_dither_tex : filter_nearest, repeat_enable;
uniform sampler2D u_color_tex : filter_nearest;

// Algorithm selection
uniform int u_algorithm : hint_range(0, 4) = 0;

// Palette mode: 0=luminance, 1=multi-color
uniform int u_palette_mode : hint_range(0, 1) = 0;

// Color distance: 0=RGB, 1=Weighted RGB, 2=Oklab
uniform int u_color_distance : hint_range(0, 2) = 2;

// Procedural Bayer level (for algorithm 1): 1=2x2, 2=4x4, 3=8x8, 4=16x16
uniform int u_bayer_level : hint_range(1, 4) = 3;

// Core parameters
uniform int u_bit_depth : hint_range(2, 64) = 32;
uniform float u_contrast : hint_range(0.0, 5.0) = 1.0;
uniform float u_offset : hint_range(-1.0, 1.0) = 0.0;
uniform int u_dither_size : hint_range(1, 8) = 2;
uniform float u_mix : hint_range(0.0, 1.0) = 1.0;
uniform int u_blend_mode : hint_range(0, 10) = 0;

// Error diffusion approximation strength (algorithm 2)
uniform float u_error_strength : hint_range(0.0, 2.0) = 1.0;

// Operate in linear color space for accuracy
uniform bool u_linear_space = false;

// Masking
uniform bool u_mask_shadows_enabled = false;
uniform float u_mask_shadows_threshold : hint_range(0.0, 1.0) = 0.5;
uniform float u_mask_shadows_softness : hint_range(0.0, 0.5) = 0.1;
uniform bool u_mask_highlights_enabled = false;
uniform float u_mask_highlights_threshold : hint_range(0.0, 1.0) = 0.5;
uniform float u_mask_highlights_softness : hint_range(0.0, 0.5) = 0.1;

void fragment() {
	// Sample at pixelated resolution
	vec2 screen_size = vec2(textureSize(screen_texture, 0)) / float(u_dither_size);
	vec2 screen_sample_uv = floor(SCREEN_UV * screen_size) / screen_size;
	vec3 screen_col = texture(screen_texture, screen_sample_uv).rgb;

	// Optionally work in linear space
	vec3 working_col = u_linear_space ? srgb_to_linear(screen_col) : screen_col;

	// Calculate luminance
	float lum = luminance_601(working_col);
	lum = clamp((lum - 0.5 + u_offset) * u_contrast + 0.5, 0.0, 1.0);

	// Reduce bit depth
	float bits = float(u_bit_depth);
	lum = floor(lum * bits) / bits;

	// Compute pixel coordinate for procedural algorithms
	vec2 pixel_coord = floor(SCREEN_UV * screen_size);

	// Get threshold based on selected algorithm
	float threshold = 0.5;

	switch (u_algorithm) {
		case 0: {
			// Texture-based ordered dithering
			ivec2 noise_size = textureSize(u_dither_tex, 0);
			vec2 inv_noise = vec2(1.0 / float(noise_size.x), 1.0 / float(noise_size.y));
			vec2 noise_uv = SCREEN_UV * inv_noise * vec2(screen_size);
			threshold = texture(u_dither_tex, noise_uv).r;
		} break;
		case 1: {
			// Procedural Bayer
			threshold = bayer_procedural(pixel_coord, u_bayer_level);
		} break;
		case 2: {
			// Blue noise error diffusion approximation
			// Add shaped noise to the color before quantizing, simulating error spread
			ivec2 noise_size = textureSize(u_dither_tex, 0);
			vec2 inv_noise = vec2(1.0 / float(noise_size.x), 1.0 / float(noise_size.y));
			vec2 noise_uv = SCREEN_UV * inv_noise * vec2(screen_size);
			float noise_val = texture(u_dither_tex, noise_uv).r;
			// Shift noise to [-0.5, 0.5] range and scale by strength
			threshold = 0.5 + (noise_val - 0.5) * u_error_strength;
			// Bias threshold with luminance for error-diffusion-like clustering
			threshold = mix(threshold, noise_val, 0.3);
		} break;
		case 3: {
			// White noise
			threshold = white_noise(pixel_coord);
		} break;
		case 4: {
			// Interleaved Gradient Noise
			threshold = ign(pixel_coord);
		} break;
	}

	// Clamp threshold slightly off extremes
	threshold = threshold * 0.99 + 0.005;

	// Apply dithering based on palette mode
	vec3 dither_col;

	if (u_palette_mode == 1) {
		// Multi-color mode: add threshold noise and snap to nearest palette color
		vec3 noised_col = working_col + (threshold - 0.5) * (1.0 / bits);
		dither_col = dither_multicolor(noised_col, threshold, u_color_tex, u_color_distance);
		if (u_linear_space) dither_col = linear_to_srgb(dither_col);
	} else {
		// Classic luminance mode
		vec3 pal = palette_lookup(u_color_tex, lum);
		float ramp = (pal.z < threshold) ? 0.0 : 1.0;
		float col_sample = mix(pal.x, pal.y, ramp);
		dither_col = texture(u_color_tex, vec2(col_sample, 0.5)).rgb;
	}

	// Get original color for blending
	vec3 original_col = texture(screen_texture, SCREEN_UV).rgb;

	// Apply blend mode
	vec3 blended_col = apply_blend(original_col, dither_col, u_blend_mode);

	// Masking
	float mask = 1.0;
	float raw_lum = luminance_601(original_col);

	if (u_mask_shadows_enabled) {
		mask *= smoothstep(
			u_mask_shadows_threshold + u_mask_shadows_softness,
			u_mask_shadows_threshold - u_mask_shadows_softness,
			raw_lum
		);
	}

	if (u_mask_highlights_enabled) {
		mask *= smoothstep(
			u_mask_highlights_threshold - u_mask_highlights_softness,
			u_mask_highlights_threshold + u_mask_highlights_softness,
			raw_lum
		);
	}

	COLOR.rgb = mix(original_col, blended_col, u_mix * mask);
}
