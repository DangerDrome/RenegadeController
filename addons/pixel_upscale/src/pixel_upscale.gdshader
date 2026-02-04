/*
Pixel Art Upscale Shader for Godot 4.x
Based on code by t3ssel8r: https://youtu.be/d6tp43wZqps
Adapted to Godot by denovodavid: https://git.sr.ht/~denovodavid/3d-pixel-art-in-godot

This shader provides crisp pixel art scaling with smooth subpixel movement.
It uses an adaptive box filter that maintains sharp edges while reducing
aliasing artifacts during camera movement or zooming.
*/

shader_type canvas_item;
render_mode unshaded;

uniform float sharpness : hint_range(0.0, 1.0, 0.01) = 1.0;

void fragment() {
	// Box filter size in texel units
	vec2 box_size = clamp(fwidth(UV) / TEXTURE_PIXEL_SIZE, 1e-5, 1.0);

	// Apply sharpness - lower values create softer filtering
	box_size = mix(vec2(1.0), box_size, sharpness);

	// Scale UV by texture size to get texel coordinate
	vec2 tx = UV / TEXTURE_PIXEL_SIZE - 0.5 * box_size;

	// Compute offset for pixel-sized box filter
	vec2 tx_offset = smoothstep(vec2(1.0) - box_size, vec2(1.0), fract(tx));

	// Compute bilinear sample UV coordinates
	vec2 uv = (floor(tx) + 0.5 + tx_offset) * TEXTURE_PIXEL_SIZE;

	// Sample the texture with gradients for proper mipmap selection
	COLOR = textureGrad(TEXTURE, uv, dFdx(UV), dFdy(UV));
}
