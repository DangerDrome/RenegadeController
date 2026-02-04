// Simple unshaded mesh shader for outline rendering
// Use with OutlineMaterial.simple() - pair with outline_data_pass as next_pass
shader_type spatial;
render_mode unshaded;

uniform vec4 albedo_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform sampler2D albedo_texture : source_color, filter_nearest;
uniform bool use_texture = false;

void fragment() {
	vec4 color = albedo_color;
	if (use_texture) {
		color *= texture(albedo_texture, UV);
	}
	ALBEDO = color.rgb;
	ALPHA = color.a;
}
