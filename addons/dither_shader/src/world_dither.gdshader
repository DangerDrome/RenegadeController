/*
World-space dither shader for Godot 4.3+
Uses spatial shader on fullscreen quad to access depth buffer.
Reconstructs world position and projects dither pattern onto geometry.

Supports proper triplanar projection with blending for seamless
coverage across all surface orientations.
*/

shader_type spatial;
render_mode unshaded, fog_disabled, depth_draw_never, depth_test_disabled, cull_disabled;

uniform sampler2D screen_texture : source_color, hint_screen_texture, filter_nearest;
uniform sampler2D depth_texture : hint_depth_texture, filter_nearest;
// Keep nearest for crisp sampling, we do manual filtering when needed
uniform sampler2D dither_texture : filter_nearest_mipmap, repeat_enable;
uniform sampler2D palette_texture : filter_nearest;

// Dither parameters
uniform int bit_depth : hint_range(2, 64) = 32;
uniform float contrast : hint_range(0.0, 5.0) = 1.0;
uniform float lum_offset : hint_range(-1.0, 1.0) = 0.0;
uniform int dither_size : hint_range(1, 8) = 2;
uniform float color_mix : hint_range(0.0, 1.0) = 1.0;

// Triplanar projection
uniform float world_scale : hint_range(0.01, 50.0) = 5.0;
// 0=XZ_FLOORS, 1=XY_Z_WALLS, 2=YZ_X_WALLS, 3=AUTO_HARD, 4=TRIPLANAR_BLEND
uniform int projection_mode : hint_range(0, 4) = 4;
uniform float triplanar_sharpness : hint_range(0.1, 32.0) = 4.0;
uniform vec3 triplanar_offset;

// Moiré reduction - samples lower mip levels to reduce aliasing at small scales
uniform float moire_reduction : hint_range(0.0, 8.0) = 0.0;
// Edge softening - uses smoothstep instead of hard step (0 = hard, higher = softer)
uniform float edge_softness : hint_range(0.0, 0.5) = 0.0;
// Enable bilinear filtering on dither pattern (smoother but less crisp)
uniform bool pattern_filtering = true;

// Blend mode (0=normal, 1=add, 2=subtract, 3=multiply, 4=screen, 5=overlay,
// 6=soft_light, 7=hard_light, 8=color_dodge, 9=color_burn, 10=difference)
uniform int blend_mode : hint_range(0, 10) = 0;

// Masking - controls where dither is applied
// Luminance masking: apply dither based on brightness
uniform bool mask_shadows_enabled = false;
uniform float mask_shadows_threshold : hint_range(0.0, 1.0) = 0.5;  // Below this = shadow
uniform float mask_shadows_softness : hint_range(0.0, 0.5) = 0.1;
uniform bool mask_highlights_enabled = false;
uniform float mask_highlights_threshold : hint_range(0.0, 1.0) = 0.5;  // Above this = highlight
uniform float mask_highlights_softness : hint_range(0.0, 0.5) = 0.1;
// Edge masking: apply dither to edges (depth/normal discontinuities)
uniform bool mask_edges_enabled = false;
uniform float mask_edges_strength : hint_range(0.0, 1.0) = 1.0;
uniform float mask_edges_threshold : hint_range(0.0, 0.1) = 0.01;  // Depth difference threshold
uniform float mask_edges_normal_threshold : hint_range(0.0, 1.0) = 0.5;  // Normal difference threshold
// Depth masking: apply dither based on distance
uniform bool mask_depth_enabled = false;
uniform float mask_depth_near : hint_range(0.0, 100.0) = 0.0;  // Full effect starts here
uniform float mask_depth_far : hint_range(0.0, 500.0) = 50.0;   // Effect fades to zero here
uniform bool mask_depth_invert = false;  // Invert so far = full effect

// Debug
// 0=off, 1=depth, 2=world_pos, 3=normal, 4=screen_uv, 5=passthrough,
// 6=dither_uv, 7=threshold, 8=luminance, 9=checker, 10=triplanar_weights, 11=mask
uniform int debug_mode : hint_range(0, 11) = 0;
uniform float debug_checker_size : hint_range(0.1, 10.0) = 1.0;

// Reconstruct world position from depth buffer
vec3 reconstruct_world_position(vec2 uv, float depth_val, mat4 inv_proj, mat4 inv_view) {
	vec3 ndc;
	ndc.xy = uv * 2.0 - 1.0;
	ndc.z = depth_val * 2.0 - 1.0;
	
	vec4 view_pos = inv_proj * vec4(ndc, 1.0);
	view_pos.xyz /= view_pos.w;
	
	vec4 wpos = inv_view * vec4(view_pos.xyz, 1.0);
	return wpos.xyz;
}

// Compute triplanar blend weights from surface normal
vec3 triplanar_weights(vec3 normal, float sharpness) {
	vec3 w = pow(abs(normal), vec3(sharpness));
	w /= (w.x + w.y + w.z + 0.0001);
	return w;
}

// Manual bilinear sampling with LOD support
float sample_bilinear(sampler2D tex, vec2 uv, float lod_bias) {
	vec2 tex_size = vec2(textureSize(tex, int(lod_bias)));
	vec2 texel = uv * tex_size - 0.5;
	vec2 f = fract(texel);
	vec2 base = (floor(texel) + 0.5) / tex_size;
	vec2 step_size = 1.0 / tex_size;

	float tl = textureLod(tex, base, lod_bias).r;
	float tr = textureLod(tex, base + vec2(step_size.x, 0.0), lod_bias).r;
	float bl = textureLod(tex, base + vec2(0.0, step_size.y), lod_bias).r;
	float br = textureLod(tex, base + step_size, lod_bias).r;

	return mix(mix(tl, tr, f.x), mix(bl, br, f.x), f.y);
}

// Sample dither texture with optional bilinear filtering
float sample_dither(sampler2D tex, vec2 uv, float lod_bias, bool use_filtering) {
	if (use_filtering) {
		return sample_bilinear(tex, uv, lod_bias);
	} else {
		return textureLod(tex, uv, lod_bias).r;
	}
}

// Sample a texture using triplanar projection with LOD bias for moiré reduction
float sample_triplanar(sampler2D tex, vec3 pos, vec3 weights, float lod_bias, bool use_filtering) {
	float sample_xz = sample_dither(tex, pos.xz, lod_bias, use_filtering);  // Y-facing
	float sample_xy = sample_dither(tex, pos.xy, lod_bias, use_filtering);  // Z-facing
	float sample_yz = sample_dither(tex, pos.yz, lod_bias, use_filtering);  // X-facing
	return sample_xz * weights.y + sample_xy * weights.z + sample_yz * weights.x;
}

// Procedural checker using triplanar projection
float checker_triplanar(vec3 pos, vec3 weights, float sz) {
	vec2 uv_xz = pos.xz / sz;
	vec2 uv_xy = pos.xy / sz;
	vec2 uv_yz = pos.yz / sz;
	
	float c_xz = mod(floor(uv_xz.x) + floor(uv_xz.y), 2.0);
	float c_xy = mod(floor(uv_xy.x) + floor(uv_xy.y), 2.0);
	float c_yz = mod(floor(uv_yz.x) + floor(uv_yz.y), 2.0);
	
	return c_xz * weights.y + c_xy * weights.z + c_yz * weights.x;
}

// Procedural checker for a single axis
float checker_single(vec2 uv, float sz) {
	vec2 cuv = uv / sz;
	return mod(floor(cuv.x) + floor(cuv.y), 2.0);
}

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

vec3 apply_blend(vec3 base, vec3 blend, int mode) {
	switch (mode) {
		case 1: return blend_add(base, blend);
		case 2: return blend_subtract(base, blend);
		case 3: return blend_multiply(base, blend);
		case 4: return blend_screen(base, blend);
		case 5: return blend_overlay(base, blend);
		case 6: return blend_soft_light(base, blend);
		case 7: return blend_hard_light(base, blend);
		case 8: return blend_color_dodge(base, blend);
		case 9: return blend_color_burn(base, blend);
		case 10: return blend_difference(base, blend);
		default: return blend_normal(base, blend);
	}
}

// Edge detection using depth discontinuities
float detect_edges_depth(sampler2D depth_tex, vec2 uv, vec2 texel_size, float threshold) {
	float d_c = texture(depth_tex, uv).r;
	float d_l = texture(depth_tex, uv + vec2(-texel_size.x, 0.0)).r;
	float d_r = texture(depth_tex, uv + vec2(texel_size.x, 0.0)).r;
	float d_u = texture(depth_tex, uv + vec2(0.0, -texel_size.y)).r;
	float d_d = texture(depth_tex, uv + vec2(0.0, texel_size.y)).r;

	float diff = abs(d_l - d_c) + abs(d_r - d_c) + abs(d_u - d_c) + abs(d_d - d_c);
	return smoothstep(0.0, threshold, diff);
}

// Edge detection using normal discontinuities
float detect_edges_normal(vec3 normal_c, vec3 world_pos, vec2 uv, float threshold, mat4 inv_proj, mat4 inv_view, sampler2D depth_tex, vec2 texel_size) {
	// Sample neighboring depths and reconstruct normals
	float d_l = texture(depth_tex, uv + vec2(-texel_size.x, 0.0)).r;
	float d_r = texture(depth_tex, uv + vec2(texel_size.x, 0.0)).r;
	float d_u = texture(depth_tex, uv + vec2(0.0, -texel_size.y)).r;
	float d_d = texture(depth_tex, uv + vec2(0.0, texel_size.y)).r;

	vec3 pos_l = reconstruct_world_position(uv + vec2(-texel_size.x, 0.0), d_l, inv_proj, inv_view);
	vec3 pos_r = reconstruct_world_position(uv + vec2(texel_size.x, 0.0), d_r, inv_proj, inv_view);
	vec3 pos_u = reconstruct_world_position(uv + vec2(0.0, -texel_size.y), d_u, inv_proj, inv_view);
	vec3 pos_d = reconstruct_world_position(uv + vec2(0.0, texel_size.y), d_d, inv_proj, inv_view);

	vec3 normal_h = normalize(cross(pos_r - pos_l, vec3(0.0, 1.0, 0.0)));
	vec3 normal_v = normalize(cross(vec3(1.0, 0.0, 0.0), pos_d - pos_u));

	float dot_h = 1.0 - abs(dot(normal_c, normal_h));
	float dot_v = 1.0 - abs(dot(normal_c, normal_v));

	return smoothstep(0.0, threshold, max(dot_h, dot_v));
}

// Calculate linear depth from raw depth
float get_linear_depth(float depth_raw, mat4 inv_proj) {
	vec4 ndc = vec4(0.0, 0.0, depth_raw * 2.0 - 1.0, 1.0);
	vec4 view_pos = inv_proj * ndc;
	return -view_pos.z / view_pos.w;
}

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

void fragment() {
	// Sample screen at pixelated resolution
	vec2 screen_size = vec2(textureSize(screen_texture, 0)) / float(dither_size);
	vec2 sample_uv = floor(SCREEN_UV * screen_size) / screen_size;
	vec3 screen_col = texture(screen_texture, sample_uv).rgb;
	
	// Sample raw depth
	float depth_raw = texture(depth_texture, SCREEN_UV).r;
	
	// Reconstruct world position and surface normal
	vec3 world_pos = reconstruct_world_position(SCREEN_UV, depth_raw, INV_PROJECTION_MATRIX, INV_VIEW_MATRIX);
	vec3 surface_normal = normalize(cross(dFdy(world_pos), dFdx(world_pos)));
	
	// Calculate luminance
	float lum = dot(screen_col, vec3(0.299, 0.587, 0.114));
	lum = clamp((lum - 0.5 + lum_offset) * contrast + 0.5, 0.0, 1.0);
	
	// Scale and offset world position for pattern projection
	vec3 scaled_pos = world_pos / world_scale + triplanar_offset;
	
	// Compute triplanar blend weights
	vec3 tri_w = triplanar_weights(surface_normal, triplanar_sharpness);
	
	// Sample dither threshold based on projection mode
	float threshold = 0.5;
	vec2 single_uv = vec2(0.0);
	
	if (projection_mode == 4) {
		// TRIPLANAR_BLEND
		threshold = sample_triplanar(dither_texture, scaled_pos, tri_w, moire_reduction, pattern_filtering);
	} else if (projection_mode == 3) {
		// AUTO_HARD: dominant axis, no blending
		vec3 abs_n = abs(surface_normal);
		if (abs_n.y >= abs_n.x && abs_n.y >= abs_n.z) {
			single_uv = scaled_pos.xz;
		} else if (abs_n.x >= abs_n.z) {
			single_uv = scaled_pos.yz;
		} else {
			single_uv = scaled_pos.xy;
		}
		threshold = sample_dither(dither_texture, single_uv, moire_reduction, pattern_filtering);
	} else if (projection_mode == 0) {
		single_uv = scaled_pos.xz;
		threshold = sample_dither(dither_texture, single_uv, moire_reduction, pattern_filtering);
	} else if (projection_mode == 1) {
		single_uv = scaled_pos.xy;
		threshold = sample_dither(dither_texture, single_uv, moire_reduction, pattern_filtering);
	} else {
		single_uv = scaled_pos.yz;
		threshold = sample_dither(dither_texture, single_uv, moire_reduction, pattern_filtering);
	}
	
	threshold = threshold * 0.99 + 0.005;
	
	// === OUTPUT ===
	vec3 final_col = vec3(0.0);
	
	if (debug_mode == 1) {
		// Depth (linearized)
		vec3 ndc;
		ndc.xy = SCREEN_UV * 2.0 - 1.0;
		ndc.z = depth_raw * 2.0 - 1.0;
		vec4 vp = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
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
		// Dither UV visualization
		if (projection_mode == 4) {
			final_col = vec3(
				fract(scaled_pos.yz).x * tri_w.x,
				fract(scaled_pos.xz).x * tri_w.y,
				fract(scaled_pos.xy).x * tri_w.z
			);
		} else {
			final_col = vec3(fract(single_uv), 0.0);
		}
		
	} else if (debug_mode == 7) {
		final_col = vec3(threshold);
		
	} else if (debug_mode == 8) {
		final_col = vec3(lum);
		
	} else if (debug_mode == 9) {
		// Checker pattern - respects current projection mode
		if (projection_mode == 4) {
			final_col = vec3(checker_triplanar(world_pos, tri_w, debug_checker_size));
		} else if (projection_mode == 3) {
			vec3 abs_n = abs(surface_normal);
			if (abs_n.y >= abs_n.x && abs_n.y >= abs_n.z) {
				final_col = vec3(checker_single(world_pos.xz, debug_checker_size));
			} else if (abs_n.x >= abs_n.z) {
				final_col = vec3(checker_single(world_pos.yz, debug_checker_size));
			} else {
				final_col = vec3(checker_single(world_pos.xy, debug_checker_size));
			}
		} else if (projection_mode == 0) {
			final_col = vec3(checker_single(world_pos.xz, debug_checker_size));
		} else if (projection_mode == 1) {
			final_col = vec3(checker_single(world_pos.xy, debug_checker_size));
		} else {
			final_col = vec3(checker_single(world_pos.yz, debug_checker_size));
		}
		
	} else if (debug_mode == 10) {
		// Triplanar weights: R=X-facing, G=Y-facing, B=Z-facing
		final_col = tri_w;

	} else if (debug_mode == 11) {
		// Mask visualization
		float mask = 1.0;
		vec2 texel_size = 1.0 / vec2(textureSize(screen_texture, 0));
		float raw_lum = dot(texture(screen_texture, sample_uv).rgb, vec3(0.299, 0.587, 0.114));

		if (mask_shadows_enabled) {
			mask *= smoothstep(mask_shadows_threshold + mask_shadows_softness,
				mask_shadows_threshold - mask_shadows_softness, raw_lum);
		}
		if (mask_highlights_enabled) {
			mask *= smoothstep(mask_highlights_threshold - mask_highlights_softness,
				mask_highlights_threshold + mask_highlights_softness, raw_lum);
		}
		if (mask_edges_enabled) {
			float edge_depth = detect_edges_depth(depth_texture, SCREEN_UV, texel_size, mask_edges_threshold);
			float edge_normal = detect_edges_normal(surface_normal, world_pos, SCREEN_UV, mask_edges_normal_threshold,
				INV_PROJECTION_MATRIX, INV_VIEW_MATRIX, depth_texture, texel_size);
			mask *= max(edge_depth, edge_normal) * mask_edges_strength;
		}
		if (mask_depth_enabled) {
			float linear_depth = get_linear_depth(depth_raw, INV_PROJECTION_MATRIX);
			float depth_mask = smoothstep(mask_depth_far, mask_depth_near, linear_depth);
			if (mask_depth_invert) depth_mask = 1.0 - depth_mask;
			mask *= depth_mask;
		}
		final_col = vec3(mask);

	} else {
		// === NORMAL DITHERING (debug_mode == 0) ===
		float dithered;
		if (edge_softness > 0.0) {
			dithered = smoothstep(threshold - edge_softness, threshold + edge_softness, lum);
		} else {
			dithered = step(threshold, lum);
		}
		vec3 dither_col = texture(palette_texture, vec2(dithered * 0.999, 0.5)).rgb;

		// === MASKING ===
		float mask = 1.0;
		vec2 texel_size = 1.0 / vec2(textureSize(screen_texture, 0));
		float raw_lum = dot(texture(screen_texture, sample_uv).rgb, vec3(0.299, 0.587, 0.114));

		if (mask_shadows_enabled) {
			mask *= smoothstep(mask_shadows_threshold + mask_shadows_softness,
				mask_shadows_threshold - mask_shadows_softness, raw_lum);
		}
		if (mask_highlights_enabled) {
			mask *= smoothstep(mask_highlights_threshold - mask_highlights_softness,
				mask_highlights_threshold + mask_highlights_softness, raw_lum);
		}
		if (mask_edges_enabled) {
			float edge_depth = detect_edges_depth(depth_texture, SCREEN_UV, texel_size, mask_edges_threshold);
			float edge_normal = detect_edges_normal(surface_normal, world_pos, SCREEN_UV, mask_edges_normal_threshold,
				INV_PROJECTION_MATRIX, INV_VIEW_MATRIX, depth_texture, texel_size);
			mask *= max(edge_depth, edge_normal) * mask_edges_strength;
		}
		if (mask_depth_enabled) {
			float linear_depth = get_linear_depth(depth_raw, INV_PROJECTION_MATRIX);
			float depth_mask = smoothstep(mask_depth_far, mask_depth_near, linear_depth);
			if (mask_depth_invert) depth_mask = 1.0 - depth_mask;
			mask *= depth_mask;
		}

		// Apply blend mode with mask
		vec3 blended_col = apply_blend(screen_col, dither_col, blend_mode);
		final_col = mix(screen_col, blended_col, color_mix * mask);
	}
	
	ALBEDO = final_col;
}
