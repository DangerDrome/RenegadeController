// Outline Post-Processing Shader - Depth + Normal Edge Detection
// Reads depth and normals encoded in the data texture
// Compatible with Godot 4.x Compatibility renderer

shader_type canvas_item;

uniform vec4 outline_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float outline_width : hint_range(0.5, 10.0, 0.5) = 1.0;
uniform bool active = true;

// Edge detection sensitivity
uniform float depth_threshold : hint_range(0.0, 0.1, 0.001) = 0.01;
uniform float normal_threshold : hint_range(0.0, 1.0, 0.01) = 0.4;

// Style options (like 3D Pixel Art shader)
uniform float line_highlight : hint_range(0.0, 1.0, 0.01) = 0.2;
uniform float line_shadow : hint_range(0.0, 1.0, 0.01) = 0.4;

const vec2 DIRECTIONS[8] = {
	vec2(1.0, 0.0),
	vec2(0.0, 1.0),
	vec2(-1.0, 0.0),
	vec2(0.0, -1.0),
	vec2(1.0, 1.0),
	vec2(-1.0, 1.0),
	vec2(-1.0, -1.0),
	vec2(1.0, -1.0)
};

// Decode normal from texture (was encoded as val * 0.5 + 0.5)
vec3 decode_normal(vec4 data) {
	return vec3(data.g, data.b, data.a) * 2.0 - 1.0;
}

// Get depth from texture
float get_depth(vec4 data) {
	return data.r;
}

// Check if this pixel has valid geometry data
bool has_geometry(vec4 data) {
	return data.a > 0.01; // Alpha channel has normal.z, will be ~0.5 for most geometry
}

void fragment() {
	vec2 pixel_size = TEXTURE_PIXEL_SIZE * outline_width;
	vec4 center_data = texture(TEXTURE, UV);
	
	// Check if we should process
	bool should_process = active && has_geometry(center_data);
	
	float center_depth = get_depth(center_data);
	vec3 center_normal = decode_normal(center_data);
	
	float depth_edge = 0.0;
	float normal_edge = 0.0;
	float silhouette_edge = 0.0;
	
	// Sample 8 neighbors for edge detection
	if (should_process) {
		for (int i = 0; i < 8; i++) {
			vec2 sample_uv = UV + DIRECTIONS[i] * pixel_size;
			vec4 sample_data = texture(TEXTURE, sample_uv);
			
			float sample_depth = get_depth(sample_data);
			vec3 sample_normal = decode_normal(sample_data);
			bool sample_has_geo = has_geometry(sample_data);
			
			// Silhouette edge: geometry vs no geometry
			if (!sample_has_geo) {
				silhouette_edge += 1.0;
			} else {
				// Depth edge: significant depth difference
				float depth_diff = abs(center_depth - sample_depth);
				if (depth_diff > depth_threshold) {
					// Weight by how much the neighbor is behind us (outlines on front faces)
					float behind_weight = max(0.0, sign(sample_depth - center_depth));
					depth_edge += depth_diff * 10.0 * (0.5 + behind_weight * 0.5);
				}
				
				// Normal edge: surface facing changes
				float normal_diff = 1.0 - dot(center_normal, sample_normal);
				if (normal_diff > normal_threshold) {
					normal_edge += normal_diff;
				}
			}
		}
	}
	
	// Combine edges
	depth_edge = clamp(depth_edge, 0.0, 1.0);
	normal_edge = clamp(normal_edge * 0.5, 0.0, 1.0);
	silhouette_edge = clamp(silhouette_edge * 0.25, 0.0, 1.0);
	
	float total_edge = max(max(depth_edge, normal_edge), silhouette_edge);
	
	// Apply shadow (darken) for depth edges, highlight for normal edges
	vec3 edge_color = outline_color.rgb;
	
	// Depth edges get full shadow color
	// Normal edges get slightly highlighted version
	float highlight_amount = normal_edge * line_highlight * (1.0 - depth_edge);
	float shadow_amount = depth_edge * line_shadow;
	
	edge_color = edge_color * (1.0 - shadow_amount) + vec3(highlight_amount);
	
	// Final output - zero alpha if not processing
	COLOR.rgb = edge_color;
	COLOR.a = should_process ? total_edge * outline_color.a : 0.0;
}
