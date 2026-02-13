shader_type spatial;
render_mode unshaded;

uniform sampler2D screen_texture : source_color, hint_screen_texture, filter_nearest;
uniform sampler2D depth_texture : source_color, hint_depth_texture, filter_nearest;

uniform float depth_threshold : hint_range(0, 1) = 0.05;
uniform float reverse_depth_threshold : hint_range(0, 1) = 0.25;
uniform float normal_threshold : hint_range(0, 1) = 0.6;

uniform float darken_amount : hint_range(0, 1, 0.01) = 0.3;
uniform float lighten_amount : hint_range(0, 10, 0.01) = 1.5;

uniform vec3 normal_edge_bias = vec3(1, 1, 1);
uniform vec3 light_direction = vec3(-0.96, -0.18, 0.2);

// Convert raw depth buffer to linear eye-space distance.
float linearize_depth(float raw_depth, mat4 proj) {
	float z_ndc = raw_depth * 2.0 - 1.0;
	return proj[3][2] / (z_ndc + proj[2][2]);
}

// View-space position from UV and pre-linearized depth.
vec3 view_pos(vec2 uv, float lin_depth, mat4 proj) {
	vec2 ndc_xy = uv * 2.0 - 1.0;
	return vec3(
		ndc_xy.x * lin_depth / proj[0][0],
		ndc_xy.y * lin_depth / proj[1][1],
		-lin_depth
	);
}

void vertex() {
	POSITION = vec4(VERTEX, 1.0);
}

void fragment() {
	vec3 original = texture(screen_texture, SCREEN_UV).rgb;
	vec2 texel = 1.0 / VIEWPORT_SIZE;
	mat4 proj = PROJECTION_MATRIX;

	// Sample 3x3 depth grid (9 texture reads total, down from 20).
	// Layout: [0]TL [1]T [2]TR / [3]L [4]C [5]R / [6]BL [7]B [8]BR
	vec2 uv0 = clamp(SCREEN_UV + vec2(-texel.x, -texel.y), vec2(0.0), vec2(1.0 - 0.001));
	vec2 uv1 = clamp(SCREEN_UV + vec2(      0.0, -texel.y), vec2(0.0), vec2(1.0 - 0.001));
	vec2 uv2 = clamp(SCREEN_UV + vec2( texel.x, -texel.y), vec2(0.0), vec2(1.0 - 0.001));
	vec2 uv3 = clamp(SCREEN_UV + vec2(-texel.x,       0.0), vec2(0.0), vec2(1.0 - 0.001));
	vec2 uv4 = SCREEN_UV;
	vec2 uv5 = clamp(SCREEN_UV + vec2( texel.x,       0.0), vec2(0.0), vec2(1.0 - 0.001));
	vec2 uv6 = clamp(SCREEN_UV + vec2(-texel.x,  texel.y), vec2(0.0), vec2(1.0 - 0.001));
	vec2 uv7 = clamp(SCREEN_UV + vec2(      0.0,  texel.y), vec2(0.0), vec2(1.0 - 0.001));
	vec2 uv8 = clamp(SCREEN_UV + vec2( texel.x,  texel.y), vec2(0.0), vec2(1.0 - 0.001));

	float d0 = linearize_depth(texture(depth_texture, uv0).r, proj);
	float d1 = linearize_depth(texture(depth_texture, uv1).r, proj);
	float d2 = linearize_depth(texture(depth_texture, uv2).r, proj);
	float d3 = linearize_depth(texture(depth_texture, uv3).r, proj);
	float d4 = linearize_depth(texture(depth_texture, uv4).r, proj);
	float d5 = linearize_depth(texture(depth_texture, uv5).r, proj);
	float d6 = linearize_depth(texture(depth_texture, uv6).r, proj);
	float d7 = linearize_depth(texture(depth_texture, uv7).r, proj);
	float d8 = linearize_depth(texture(depth_texture, uv8).r, proj);

	vec3 p0 = view_pos(uv0, d0, proj);
	vec3 p1 = view_pos(uv1, d1, proj);
	vec3 p2 = view_pos(uv2, d2, proj);
	vec3 p3 = view_pos(uv3, d3, proj);
	vec3 p4 = view_pos(uv4, d4, proj);
	vec3 p5 = view_pos(uv5, d5, proj);
	vec3 p6 = view_pos(uv6, d6, proj);
	vec3 p7 = view_pos(uv7, d7, proj);
	vec3 p8 = view_pos(uv8, d8, proj);

	// Depth edges (cardinal neighbors: T=1, B=7, L=3, R=5).
	float depth_diff = (d4 - d1) + (d4 - d7) + (d4 - d3) + (d4 - d5);
	float depth_diff_reversed = (d1 - d4) + (d7 - d4) + (d3 - d4) + (d5 - d4);

	float nearest_depth = d4;
	vec2 nearest_uv = uv4;
	if (d1 < nearest_depth) { nearest_depth = d1; nearest_uv = uv1; }
	if (d7 < nearest_depth) { nearest_depth = d7; nearest_uv = uv7; }
	if (d3 < nearest_depth) { nearest_depth = d3; nearest_uv = uv3; }
	if (d5 < nearest_depth) { nearest_depth = d5; nearest_uv = uv5; }

	float depth_edge = step(depth_threshold, depth_diff);
	float reverse_depth_edge = step(reverse_depth_threshold, depth_diff_reversed);

	// Normals from 3x3 positions (no extra texture reads).
	// Center: central differences. Neighbors: forward/backward differences.
	vec3 n_c = normalize(cross(p7 - p1, p5 - p3));
	vec3 n_t = normalize(cross(p4 - p1, p2 - p0));
	vec3 n_b = normalize(cross(p7 - p4, p8 - p6));
	vec3 n_l = normalize(cross(p6 - p0, p4 - p3));
	vec3 n_r = normalize(cross(p8 - p2, p5 - p4));

	// Normal edge detection.
	float normal_sum = 0.0;

	vec3 nd_t = n_c - n_t;
	normal_sum += dot(nd_t, nd_t) * smoothstep(-0.01, 0.01, dot(nd_t, normal_edge_bias));

	vec3 nd_b = n_c - n_b;
	normal_sum += dot(nd_b, nd_b) * smoothstep(-0.01, 0.01, dot(nd_b, normal_edge_bias));

	vec3 nd_l = n_c - n_l;
	normal_sum += dot(nd_l, nd_l) * smoothstep(-0.01, 0.01, dot(nd_l, normal_edge_bias));

	vec3 nd_r = n_c - n_r;
	normal_sum += dot(nd_r, nd_r) * smoothstep(-0.01, 0.01, dot(nd_r, normal_edge_bias));

	float normal_edge = step(normal_threshold, sqrt(normal_sum) - reverse_depth_edge);

	// Depth edges sample the nearest (foreground) pixel color.
	vec3 nearest = texture(screen_texture, nearest_uv).rgb;

	// Light-aware shading: depth edges darken, normal edges lighten or darken.
	mat3 view_to_world = mat3(
		INV_VIEW_MATRIX[0].xyz,
		INV_VIEW_MATRIX[1].xyz,
		INV_VIEW_MATRIX[2].xyz
	);
	float ld = dot(view_to_world * n_c, normalize(light_direction));

	vec3 depth_col = nearest * darken_amount;
	vec3 normal_col = original * (ld > 0.0 ? darken_amount : lighten_amount);
	vec3 edge_mix = mix(normal_col, depth_col, depth_edge);

	ALBEDO = mix(original, edge_mix, (depth_edge > 0.0 ? depth_edge : normal_edge));
}
