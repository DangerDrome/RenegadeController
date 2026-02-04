shader_type spatial;
render_mode unshaded;

uniform float near : hint_range(0.01, 10.0) = 0.1;
uniform float far : hint_range(1.0, 1000.0) = 100.0;
uniform bool invert = false;

void fragment() {
	// FRAGCOORD.z is 0-1 in clip space (0=near, 1=far)
	float depth = FRAGCOORD.z;
	
	// Linearize for better visualization
	float linear_depth = (2.0 * near) / (far + near - depth * (far - near));
	
	if (invert) {
		linear_depth = 1.0 - linear_depth;
	}
	
	ALBEDO = vec3(linear_depth);
}
