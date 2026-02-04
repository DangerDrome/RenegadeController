// Outline Data Pass Shader
// Apply this as "next_pass" on any existing material
// Only renders on outline camera (layer 5), outputs depth + normals
// Compatible with Godot 4.x Compatibility renderer

shader_type spatial;
render_mode unshaded, depth_draw_always;

const int MAIN_LAYER = 1;
const int OUTLINE_LAYER = 16;

void fragment() {
	int visible_layers = int(CAMERA_VISIBLE_LAYERS);
	
	if ((visible_layers & MAIN_LAYER) != 0) {
		// Main camera - discard (let the base material render)
		discard;
	} else if ((visible_layers & OUTLINE_LAYER) != 0) {
		// Outline camera - output depth + normals
		float depth = FRAGCOORD.z;
		vec3 view_normal = normalize(NORMAL);
		vec3 encoded_normal = view_normal * 0.5 + 0.5;
		
		ALBEDO = vec3(depth, encoded_normal.x, encoded_normal.y);
		ALPHA = encoded_normal.z;
	}
}
