// TreeIt tree wind shader for Godot 4
// Original TreeIt shader by EVOLVED Software
// Adapted for Godot 4 based on godotshaders.com/shader/treeit-tree-shader/
// MIT License
//
// TreeIt exports vertex colors with specific meanings:
// - Red (COLOR.x): Leaf flutter animation strength
// - Green (COLOR.y): Wind variant randomization
// - Blue (COLOR.z): Branch sway intensity

shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx;

group_uniforms albedo;
uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D texture_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;

group_uniforms backlight;
uniform vec4 backlight_color : source_color = vec4(1.0);
uniform sampler2D texture_backlight : source_color, filter_linear_mipmap_anisotropic, repeat_enable;

group_uniforms normal_roughness;
uniform sampler2D texture_normal : hint_roughness_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float normal_scale : hint_range(-16, 16) = 1.0;
uniform float roughness : hint_range(0, 1) = 1.0;
uniform float specular : hint_range(0, 1) = 0.5;

group_uniforms uv;
uniform vec2 uv1_scale = vec2(1.0);
uniform vec2 uv1_offset = vec2(0.0);
uniform vec2 uv2_scale = vec2(1.0);
uniform vec2 uv2_offset = vec2(0.0);

group_uniforms alpha;
uniform float alpha_scissor_threshold : hint_range(0, 1) = 0.5;
uniform float max_distance = 100.0;
uniform bool is_branch = false;

group_uniforms wind;
uniform bool wind_enabled = true;
// Fallback multipliers when vertex colors are missing (FBX often loses them)
uniform float fallback_flutter : hint_range(0, 1) = 0.5;
uniform float fallback_branch_sway : hint_range(0, 1) = 0.3;

// Wind parameters - can be set per-material or controlled via script
// tree_wind_size: x=wind_scale, y=trunk_height, z=unused, w=flutter_frequency
// tree_wind_power: x=trunk_sway, y=branch_sway, z=leaf_flutter
uniform vec4 tree_wind_size = vec4(10.0, 10.0, 1.0, 4.0);
uniform vec3 tree_wind_power = vec3(0.5, 0.3, 0.2);

varying float view_distance;

void vertex() {
	UV = UV * uv1_scale.xy + uv1_offset.xy;
	UV2 = UV2 * uv2_scale.xy + uv2_offset.xy;

	vec3 world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 world_camera = INV_VIEW_MATRIX[3].xyz;
	view_distance = distance(world_position, world_camera);

	// Time with per-tree variation based on world position
	vec4 tree_wind_timer = vec4(TIME) + vec4(NODE_POSITION_WORLD, 1.0);

	if (wind_enabled) {
		vec3 world_normals = MODEL_NORMAL_MATRIX * NORMAL;

		// Detect if vertex colors are present (TreeIt sets them, FBX may lose them)
		// If all channels are 0 or 1, use position-based fallback
		float vc_sum = COLOR.x + COLOR.y + COLOR.z;
		bool has_vertex_colors = vc_sum > 0.01 && vc_sum < 2.99;

		// Get wind variation values - use vertex colors if available, else fallback
		float flutter_strength = has_vertex_colors ? COLOR.x : fallback_flutter * (VERTEX.y / tree_wind_size.y);
		float wind_variant_seed = has_vertex_colors ? COLOR.y : (length(VERTEX.xz) * 0.5);
		float branch_sway = has_vertex_colors ? COLOR.z : fallback_branch_sway * length(VERTEX.xz);

		// Global wind direction
		vec3 global_wind = (world_position.xyz / tree_wind_size.x) + tree_wind_timer.x;
		global_wind = vec3(cos(global_wind.x), 0.0, sin(global_wind.z));
		global_wind.y = 1.0 + abs(dot(global_wind.x, global_wind.z));

		// Trunk sway - based on vertex Y position (uses VERTEX.y to avoid wandering bug)
		vec3 wind_force = (world_position / tree_wind_size.x) + tree_wind_timer.y - global_wind;
		wind_force = vec3(cos(wind_force.x), 0.0, sin(wind_force.y));

		vec3 wind_animate = wind_force * tree_wind_power.x * (VERTEX.y / tree_wind_size.y);

		// Branch variation - uses vertex color GREEN for randomization (or fallback)
		float wind_variant = tree_wind_timer.z + (wind_variant_seed * 10.0);
		// Branch sway intensity from vertex color BLUE (or fallback)
		wind_animate.xz += vec2(cos(wind_variant), sin(wind_variant)) * branch_sway * tree_wind_power.y * 0.1;

		// Leaf flutter - uses vertex color RED for flutter strength (or fallback)
		vec3 wind_flutter = (world_position.xyz / tree_wind_size.w) + tree_wind_timer.w + wind_variant_seed;
		wind_animate += abs(world_normals) * sin(dot(wind_flutter, vec3(1.0)) * tree_wind_size.w) * flutter_strength * (tree_wind_power.z / tree_wind_size.w);

		// Apply wind to vertex position
		world_position += wind_animate * global_wind.y;
		VERTEX = (inverse(MODEL_MATRIX) * vec4(world_position, 1.0)).xyz;
	}
}

void fragment() {
	vec4 diffuse_alpha_tex = texture(texture_albedo, UV);
	vec4 normal_rough_tex = texture(texture_normal, UV);

	// Distance-based alpha threshold modifier (denser leaves at distance)
	float threshold_dist_modifier = 1.0 - min(view_distance / max_distance, 1.0);

	ALBEDO = diffuse_alpha_tex.rgb * albedo.rgb;
	ROUGHNESS = normal_rough_tex.a * roughness;
	SPECULAR = specular;
	NORMAL_MAP = normal_rough_tex.rgb;
	NORMAL_MAP_DEPTH = normal_scale;

	if (is_branch) {
		ALPHA = albedo.a * diffuse_alpha_tex.a;
		ALPHA_SCISSOR_THRESHOLD = alpha_scissor_threshold * threshold_dist_modifier;
		BACKLIGHT = texture(texture_backlight, UV).rgb * backlight_color.rgb;
	}
}
