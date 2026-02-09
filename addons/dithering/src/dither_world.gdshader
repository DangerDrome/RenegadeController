/*
World-space dither shader for Godot 4.x
Surface-stable dithering - pattern locked to geometry (Obra Dinn style).

Uses spatial shader on fullscreen quad to access depth buffer.
Reconstructs world position and projects dither pattern via triplanar mapping.

Algorithms:
0 = Texture-based ordered (Bayer/Blue Noise from texture)
1 = Procedural Bayer (no texture needed)
2 = Blue Noise Error Diffusion Approximation
3 = White Noise
4 = Interleaved Gradient Noise (Jimenez 2014)

Palette Modes:
0 = Luminance (classic 1D palette lookup)
1 = Multi-color nearest (perceptual palette matching + dither)

References:
- Lucas Pope TIGSource: https://forums.tigsource.com/index.php?topic=40832.msg1363742
- Surma Ditherpunk: https://surma.dev/things/ditherpunk/
*/

shader_type spatial;
render_mode unshaded, fog_disabled, depth_draw_never, depth_test_disabled, cull_disabled;

#include "res://addons/dithering/src/dither_functions.gdshaderinc"

uniform sampler2D screen_texture : source_color, hint_screen_texture, filter_nearest;
uniform sampler2D depth_texture : hint_depth_texture, filter_nearest;
uniform sampler2D dither_texture : filter_nearest_mipmap, repeat_enable;
uniform sampler2D palette_texture : filter_nearest;

// Algorithm selection (0-4)
uniform int algorithm : hint_range(0, 4) = 0;

// Palette mode: 0=luminance, 1=multi-color
uniform int palette_mode : hint_range(0, 1) = 0;

// Color distance: 0=RGB, 1=Weighted RGB, 2=Oklab
uniform int color_distance_mode : hint_range(0, 2) = 2;

// Procedural Bayer level (for algorithm 1)
uniform int bayer_level : hint_range(1, 4) = 3;

// Core dither parameters
uniform int bit_depth : hint_range(2, 64) = 32;
uniform float contrast : hint_range(0.0, 5.0) = 1.0;
uniform float lum_offset : hint_range(-1.0, 1.0) = 0.0;
uniform int dither_size : hint_range(1, 8) = 2;
uniform float color_mix : hint_range(0.0, 1.0) = 1.0;

// Error diffusion approximation strength (algorithm 2)
uniform float error_strength : hint_range(0.0, 2.0) = 1.0;

// Operate in linear color space
uniform bool linear_space = false;

// Triplanar projection
uniform float world_scale : hint_range(0.01, 50.0) = 5.0;
// 0=XZ_FLOORS, 1=XY_Z_WALLS, 2=YZ_X_WALLS, 3=AUTO_HARD, 4=TRIPLANAR_BLEND
uniform int projection_mode : hint_range(0, 4) = 4;
uniform float triplanar_sharpness : hint_range(0.1, 32.0) = 4.0;
uniform vec3 triplanar_offset;

// Anti-aliasing
uniform float moire_reduction : hint_range(0.0, 8.0) = 0.0;
uniform float edge_softness : hint_range(0.0, 0.5) = 0.0;
uniform bool pattern_filtering = true;

// Blend mode (0-10)
uniform int blend_mode : hint_range(0, 10) = 0;

// === MASKING ===
// Luminance masking
uniform bool mask_shadows_enabled = false;
uniform float mask_shadows_threshold : hint_range(0.0, 1.0) = 0.5;
uniform float mask_shadows_softness : hint_range(0.0, 0.5) = 0.1;
uniform bool mask_highlights_enabled = false;
uniform float mask_highlights_threshold : hint_range(0.0, 1.0) = 0.5;
uniform float mask_highlights_softness : hint_range(0.0, 0.5) = 0.1;
// Edge masking
uniform bool mask_edges_enabled = false;
uniform float mask_edges_strength : hint_range(0.0, 1.0) = 1.0;
uniform float mask_edges_threshold : hint_range(0.0, 0.1) = 0.01;
uniform float mask_edges_normal_threshold : hint_range(0.0, 1.0) = 0.5;
// Depth masking
uniform bool mask_depth_enabled = false;
uniform float mask_depth_near : hint_range(0.0, 100.0) = 0.0;
uniform float mask_depth_far : hint_range(0.0, 500.0) = 50.0;
uniform bool mask_depth_invert = false;

// Debug (0=off, 1=depth, 2=world_pos, 3=normal, 4=screen_uv, 5=passthrough,
//        6=dither_uv, 7=threshold, 8=luminance, 9=checker, 10=triplanar_weights,
//        11=mask, 12=algorithm_output)
uniform int debug_mode : hint_range(0, 12) = 0;
uniform float debug_checker_size : hint_range(0.1, 10.0) = 1.0;

// === HELPER: Get threshold based on world position and algorithm ===
float get_world_threshold(vec3 scaled_pos, vec3 tri_w, vec2 pixel_coord) {
	float threshold = 0.5;

	if (algorithm == 1) {
		// Procedural Bayer in world space
		vec2 world_pixel;
		if (projection_mode == 4) {
			// Triplanar: blend procedural Bayer from 3 axes
			float b_xz = bayer_procedural(floor(scaled_pos.xz * 16.0), bayer_level);
			float b_xy = bayer_procedural(floor(scaled_pos.xy * 16.0), bayer_level);
			float b_yz = bayer_procedural(floor(scaled_pos.yz * 16.0), bayer_level);
			threshold = b_xz * tri_w.y + b_xy * tri_w.z + b_yz * tri_w.x;
		} else if (projection_mode == 3) {
			vec3 abs_n = tri_w;  // already weighted, find dominant
			if (abs_n.y >= abs_n.x && abs_n.y >= abs_n.z) world_pixel = scaled_pos.xz;
			else if (abs_n.x >= abs_n.z) world_pixel = scaled_pos.yz;
			else world_pixel = scaled_pos.xy;
			threshold = bayer_procedural(floor(world_pixel * 16.0), bayer_level);
		} else if (projection_mode == 0) {
			threshold = bayer_procedural(floor(scaled_pos.xz * 16.0), bayer_level);
		} else if (projection_mode == 1) {
			threshold = bayer_procedural(floor(scaled_pos.xy * 16.0), bayer_level);
		} else {
			threshold = bayer_procedural(floor(scaled_pos.yz * 16.0), bayer_level);
		}
	}
	else if (algorithm == 3) {
		// White noise in world space
		vec2 wc;
		if (projection_mode == 0) wc = scaled_pos.xz;
		else if (projection_mode == 1) wc = scaled_pos.xy;
		else if (projection_mode == 2) wc = scaled_pos.yz;
		else wc = scaled_pos.xz;  // fallback
		threshold = white_noise(floor(wc * 256.0));
	}
	else if (algorithm == 4) {
		// IGN in world space
		vec2 wc;
		if (projection_mode == 0) wc = scaled_pos.xz;
		else if (projection_mode == 1) wc = scaled_pos.xy;
		else if (projection_mode == 2) wc = scaled_pos.yz;
		else wc = scaled_pos.xz;
		threshold = ign(floor(wc * 256.0));
	}
	else {
		// Algorithms 0, 2: texture-based
		if (projection_mode == 4) {
			threshold = sample_triplanar_dither(dither_texture, scaled_pos, tri_w, moire_reduction, pattern_filtering);
		} else if (projection_mode == 3) {
			vec3 abs_n = tri_w;
			vec2 single_uv;
			if (abs_n.y >= abs_n.x && abs_n.y >= abs_n.z) single_uv = scaled_pos.xz;
			else if (abs_n.x >= abs_n.z) single_uv = scaled_pos.yz;
			else single_uv = scaled_pos.xy;
			threshold = sample_dither_tex(dither_texture, single_uv, moire_reduction, pattern_filtering);
		} else if (projection_mode == 0) {
			threshold = sample_dither_tex(dither_texture, scaled_pos.xz, moire_reduction, pattern_filtering);
		} else if (projection_mode == 1) {
			threshold = sample_dither_tex(dither_texture, scaled_pos.xy, moire_reduction, pattern_filtering);
		} else {
			threshold = sample_dither_tex(dither_texture, scaled_pos.yz, moire_reduction, pattern_filtering);
		}

		// For algorithm 2 (error diffusion approx), modify the threshold
		if (algorithm == 2) {
			threshold = 0.5 + (threshold - 0.5) * error_strength;
			threshold = mix(threshold, texture(dither_texture, scaled_pos.xz).r, 0.3);
		}
	}

	return threshold;
}

// Checker patterns for debug
float checker_single(vec2 uv, float sz) {
	vec2 cuv = uv / sz;
	return mod(floor(cuv.x) + floor(cuv.y), 2.0);
}

float checker_triplanar(vec3 pos, vec3 weights, float sz) {
	float c_xz = checker_single(pos.xz, sz);
	float c_xy = checker_single(pos.xy, sz);
	float c_yz = checker_single(pos.yz, sz);
	return c_xz * weights.y + c_xy * weights.z + c_yz * weights.x;
}

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

void fragment() {
	// Sample at pixelated resolution
	vec2 screen_size = vec2(textureSize(screen_texture, 0)) / float(dither_size);
	vec2 sample_uv = floor(SCREEN_UV * screen_size) / screen_size;
	vec3 screen_col = texture(screen_texture, sample_uv).rgb;

	// Depth reconstruction
	float depth_raw = texture(depth_texture, SCREEN_UV).r;
	vec3 world_pos = reconstruct_world_pos(SCREEN_UV, depth_raw, INV_PROJECTION_MATRIX, INV_VIEW_MATRIX);
	vec3 surface_normal = normalize(cross(dFdy(world_pos), dFdx(world_pos)));

	// Working color space
	vec3 working_col = linear_space ? srgb_to_linear(screen_col) : screen_col;

	// Luminance
	float lum = luminance_601(working_col);
	lum = clamp((lum - 0.5 + lum_offset) * contrast + 0.5, 0.0, 1.0);

	// Scale world position for pattern projection
	vec3 scaled_pos = world_pos / world_scale + triplanar_offset;

	// Triplanar weights
	vec3 tri_w = triplanar_weights(surface_normal, triplanar_sharpness);

	// Pixel coordinate for procedural algorithms
	vec2 pixel_coord = floor(SCREEN_UV * screen_size);

	// Get threshold
	float threshold = get_world_threshold(scaled_pos, tri_w, pixel_coord);
	threshold = threshold * 0.99 + 0.005;

	// === OUTPUT ===
	vec3 final_col = vec3(0.0);

	if (debug_mode == 1) {
		// Depth
		vec4 vp = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth_raw * 2.0 - 1.0, 1.0);
		vp.xyz /= vp.w;
		final_col = vec3(clamp(-vp.z / 100.0, 0.0, 1.0));
	} else if (debug_mode == 2) {
		final_col = fract(world_pos * 0.1);
	} else if (debug_mode == 3) {
		final_col = surface_normal * 0.5 + 0.5;
	} else if (debug_mode == 4) {
		final_col = vec3(SCREEN_UV, 0.0);
	} else if (debug_mode == 5) {
		final_col = screen_col;
	} else if (debug_mode == 6) {
		if (projection_mode == 4) {
			final_col = vec3(fract(scaled_pos.yz).x * tri_w.x, fract(scaled_pos.xz).x * tri_w.y, fract(scaled_pos.xy).x * tri_w.z);
		} else {
			vec2 suv = (projection_mode == 0) ? scaled_pos.xz : (projection_mode == 1) ? scaled_pos.xy : scaled_pos.yz;
			final_col = vec3(fract(suv), 0.0);
		}
	} else if (debug_mode == 7) {
		final_col = vec3(threshold);
	} else if (debug_mode == 8) {
		final_col = vec3(lum);
	} else if (debug_mode == 9) {
		if (projection_mode == 4) final_col = vec3(checker_triplanar(world_pos, tri_w, debug_checker_size));
		else {
			vec2 cuv = (projection_mode == 0) ? world_pos.xz : (projection_mode == 1) ? world_pos.xy : world_pos.yz;
			final_col = vec3(checker_single(cuv, debug_checker_size));
		}
	} else if (debug_mode == 10) {
		final_col = tri_w;
	} else if (debug_mode == 11) {
		// Mask visualization
		float mask = 1.0;
		vec2 texel_size = 1.0 / vec2(textureSize(screen_texture, 0));
		float raw_lum = luminance_601(texture(screen_texture, sample_uv).rgb);

		if (mask_shadows_enabled) {
			mask *= smoothstep(mask_shadows_threshold + mask_shadows_softness, mask_shadows_threshold - mask_shadows_softness, raw_lum);
		}
		if (mask_highlights_enabled) {
			mask *= smoothstep(mask_highlights_threshold - mask_highlights_softness, mask_highlights_threshold + mask_highlights_softness, raw_lum);
		}
		if (mask_edges_enabled) {
			mask *= detect_edges_depth(depth_texture, SCREEN_UV, texel_size, mask_edges_threshold) * mask_edges_strength;
		}
		if (mask_depth_enabled) {
			float lin_d = get_linear_depth(depth_raw, INV_PROJECTION_MATRIX);
			float dm = smoothstep(mask_depth_far, mask_depth_near, lin_d);
			if (mask_depth_invert) dm = 1.0 - dm;
			mask *= dm;
		}
		final_col = vec3(mask);
	} else if (debug_mode == 12) {
		// Raw algorithm output (threshold value as grayscale)
		final_col = vec3(get_world_threshold(scaled_pos, tri_w, pixel_coord));
	} else {
		// === NORMAL DITHERING ===
		vec3 dither_col;

		if (palette_mode == 1) {
			// Multi-color palette mode
			float bits_f = float(bit_depth);
			vec3 noised_col = working_col + (threshold - 0.5) * (1.0 / bits_f);
			dither_col = dither_multicolor(noised_col, threshold, palette_texture, color_distance_mode);
			if (linear_space) dither_col = linear_to_srgb(dither_col);
		} else {
			// Classic luminance mode
			float dithered;
			if (edge_softness > 0.0) {
				dithered = smoothstep(threshold - edge_softness, threshold + edge_softness, lum);
			} else {
				dithered = step(threshold, lum);
			}
			dither_col = texture(palette_texture, vec2(dithered * 0.999, 0.5)).rgb;
		}

		// === MASKING ===
		float mask = 1.0;
		vec2 texel_size = 1.0 / vec2(textureSize(screen_texture, 0));
		float raw_lum = luminance_601(texture(screen_texture, sample_uv).rgb);

		if (mask_shadows_enabled) {
			mask *= smoothstep(mask_shadows_threshold + mask_shadows_softness, mask_shadows_threshold - mask_shadows_softness, raw_lum);
		}
		if (mask_highlights_enabled) {
			mask *= smoothstep(mask_highlights_threshold - mask_highlights_softness, mask_highlights_threshold + mask_highlights_softness, raw_lum);
		}
		if (mask_edges_enabled) {
			mask *= detect_edges_depth(depth_texture, SCREEN_UV, texel_size, mask_edges_threshold) * mask_edges_strength;
		}
		if (mask_depth_enabled) {
			float lin_d = get_linear_depth(depth_raw, INV_PROJECTION_MATRIX);
			float dm = smoothstep(mask_depth_far, mask_depth_near, lin_d);
			if (mask_depth_invert) dm = 1.0 - dm;
			mask *= dm;
		}

		// Blend
		vec3 blended_col = apply_blend(screen_col, dither_col, blend_mode);
		final_col = mix(screen_col, blended_col, color_mix * mask);
	}

	ALBEDO = final_col;
}
