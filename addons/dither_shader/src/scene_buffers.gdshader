/*
Scene buffer capture shader for Godot 4.6 Compatibility Mode.
Outputs various scene buffers: depth, normals, world position, etc.
*/

shader_type spatial;
render_mode unshaded, depth_test_disabled, cull_disabled;

uniform sampler2D depth_texture : hint_depth_texture, filter_nearest;
uniform sampler2D depth_curve : filter_linear;
uniform bool use_curve = false;
uniform float max_depth : hint_range(1.0, 500.0) = 100.0;

// Buffer modes: 0=Depth, 1=Depth Inverted, 2=Normals, 3=Normals Raw, 4=World Position
uniform int buffer_mode : hint_range(0, 4) = 0;

// Get linear depth value
float get_linear_depth(vec2 uv, mat4 inv_proj) {
	float raw_depth = texture(depth_texture, uv).x;
	float ndc_depth = raw_depth * 2.0 - 1.0;
	vec4 view_pos = inv_proj * vec4(uv * 2.0 - 1.0, ndc_depth, 1.0);
	view_pos.xyz /= view_pos.w;
	return -view_pos.z;
}

// Reconstruct view position from UV and depth
vec3 get_view_pos(vec2 uv, mat4 inv_proj) {
	float raw_depth = texture(depth_texture, uv).x;
	float ndc_depth = raw_depth * 2.0 - 1.0;
	vec4 view_pos = inv_proj * vec4(uv * 2.0 - 1.0, ndc_depth, 1.0);
	return view_pos.xyz / view_pos.w;
}

// Reconstruct view-space normal from depth buffer using neighbor sampling
vec3 normal_from_depth(vec2 uv, mat4 inv_proj, vec2 texel_size) {
	// Sample center and neighbors
	vec3 P = get_view_pos(uv, inv_proj);
	vec3 P_right = get_view_pos(uv + vec2(texel_size.x, 0.0), inv_proj);
	vec3 P_up = get_view_pos(uv + vec2(0.0, texel_size.y), inv_proj);

	// Calculate normal from cross product of tangent vectors
	vec3 tangent_x = P_right - P;
	vec3 tangent_y = P_up - P;
	vec3 normal = normalize(cross(tangent_y, tangent_x));
	return normal;
}

// Reconstruct world-space position from depth buffer
vec3 world_position_from_depth(vec2 uv, mat4 inv_proj, mat4 inv_view) {
	float raw_depth = texture(depth_texture, uv).x;
	float ndc_depth = raw_depth * 2.0 - 1.0;

	vec4 view_pos = inv_proj * vec4(uv * 2.0 - 1.0, ndc_depth, 1.0);
	view_pos.xyz /= view_pos.w;

	vec4 world_pos = inv_view * vec4(view_pos.xyz, 1.0);
	return world_pos.xyz;
}

void fragment() {
	vec3 output_color;
	mat4 inv_proj = INV_PROJECTION_MATRIX;
	vec2 texel_size = 1.0 / vec2(textureSize(depth_texture, 0));

	if (buffer_mode == 0) {
		// Depth buffer (0 = near/black, 1 = far/white)
		float linear_depth = get_linear_depth(SCREEN_UV, inv_proj);
		float normalized = clamp(linear_depth / max_depth, 0.0, 1.0);
		if (use_curve) {
			normalized = texture(depth_curve, vec2(normalized, 0.5)).r;
		}
		output_color = vec3(normalized);
	}
	else if (buffer_mode == 1) {
		// Depth buffer inverted (0 = far/black, 1 = near/white)
		float linear_depth = get_linear_depth(SCREEN_UV, inv_proj);
		float normalized = clamp(linear_depth / max_depth, 0.0, 1.0);
		if (use_curve) {
			normalized = texture(depth_curve, vec2(normalized, 0.5)).r;
		}
		output_color = vec3(1.0 - normalized);
	}
	else if (buffer_mode == 2) {
		// World-space normals (mapped to 0-1 for visualization and triplanar)
		vec3 view_normal = normal_from_depth(SCREEN_UV, inv_proj, texel_size);
		// Convert view-space normal to world-space using inverse view matrix
		vec3 world_normal = normalize(mat3(INV_VIEW_MATRIX) * view_normal);
		output_color = world_normal * 0.5 + 0.5;
	}
	else if (buffer_mode == 3) {
		// View-space normals (raw, for shader use)
		vec3 normal = normal_from_depth(SCREEN_UV, inv_proj, texel_size);
		output_color = normal;
	}
	else {
		// World-space position (RGB = XYZ)
		// Output world position normalized to 0-1 range (assuming scene is within -50 to +50)
		vec3 world_pos = world_position_from_depth(SCREEN_UV, inv_proj, INV_VIEW_MATRIX);
		// Map -50..+50 to 0..1
		output_color = clamp(world_pos / 100.0 + 0.5, 0.0, 1.0);
	}

	ALBEDO = output_color;
	ALPHA = 1.0;
}
