/*
dither_functions.gdshaderinc
Shared dithering algorithm library for the Dithering plugin.

Provides:
- Oklab perceptual color space conversions
- Procedural Bayer matrix generation (no texture needed)
- Luminance calculations (multiple methods)
- Palette matching with perceptual color distance
- Error diffusion approximation via blue noise
- Blend mode functions
- Edge and mask detection utilities

References:
- Surma "Ditherpunk": https://surma.dev/things/ditherpunk/
- Lucas Pope TIGSource: https://forums.tigsource.com/index.php?topic=40832.msg1363742
- Björn Ottosson Oklab: https://bottosson.github.io/posts/oklab/
*/

// =============================================================================
// COLOR SPACE: OKLAB
// =============================================================================

// sRGB -> Linear RGB (inverse sRGB transfer function)
vec3 srgb_to_linear(vec3 c) {
	return mix(
		c / 12.92,
		pow((c + 0.055) / 1.055, vec3(2.4)),
		step(0.04045, c)
	);
}

// Linear RGB -> sRGB (forward sRGB transfer function)
vec3 linear_to_srgb(vec3 c) {
	return mix(
		c * 12.92,
		1.055 * pow(c, vec3(1.0 / 2.4)) - 0.055,
		step(0.0031308, c)
	);
}

// Linear RGB -> Oklab
vec3 linear_rgb_to_oklab(vec3 c) {
	float l = 0.4122214708 * c.r + 0.5363325363 * c.g + 0.0514459929 * c.b;
	float m = 0.2119034982 * c.r + 0.6806995451 * c.g + 0.1073969566 * c.b;
	float s = 0.0883024619 * c.r + 0.2817188376 * c.g + 0.6299787005 * c.b;

	float l_ = pow(max(l, 0.0), 1.0 / 3.0);
	float m_ = pow(max(m, 0.0), 1.0 / 3.0);
	float s_ = pow(max(s, 0.0), 1.0 / 3.0);

	return vec3(
		0.2104542553 * l_ + 0.7936177850 * m_ - 0.0040720468 * s_,
		1.9779984951 * l_ - 2.4285922050 * m_ + 0.4505937099 * s_,
		0.0259040371 * l_ + 0.7827717662 * m_ - 0.8086757660 * s_
	);
}

// Oklab -> Linear RGB
vec3 oklab_to_linear_rgb(vec3 lab) {
	float l_ = lab.x + 0.3963377774 * lab.y + 0.2158037573 * lab.z;
	float m_ = lab.x - 0.1055613458 * lab.y - 0.0638541728 * lab.z;
	float s_ = lab.x - 0.0894841775 * lab.y - 1.2914855480 * lab.z;

	float l = l_ * l_ * l_;
	float m = m_ * m_ * m_;
	float s = s_ * s_ * s_;

	return vec3(
		 4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
		-1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
		-0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s
	);
}

// =============================================================================
// COLOR DISTANCE
// =============================================================================

// 0 = Euclidean RGB, 1 = Weighted RGB (redmean), 2 = Oklab perceptual
// distance_mode is passed as a parameter to allow the overlay script to control it

float color_distance_rgb(vec3 a, vec3 b) {
	vec3 d = a - b;
	return dot(d, d);  // squared distance, skip sqrt for comparison
}

float color_distance_weighted(vec3 a, vec3 b) {
	// Redmean approximation - cheap perceptual improvement over naive RGB
	float rmean = (a.r + b.r) * 0.5;
	vec3 d = a - b;
	return (2.0 + rmean) * d.r * d.r + 4.0 * d.g * d.g + (3.0 - rmean) * d.b * d.b;
}

float color_distance_oklab(vec3 a, vec3 b) {
	vec3 lab_a = linear_rgb_to_oklab(srgb_to_linear(a));
	vec3 lab_b = linear_rgb_to_oklab(srgb_to_linear(b));
	vec3 d = lab_a - lab_b;
	return dot(d, d);  // squared Oklab distance
}

float color_distance(vec3 a, vec3 b, int mode) {
	if (mode == 2) return color_distance_oklab(a, b);
	if (mode == 1) return color_distance_weighted(a, b);
	return color_distance_rgb(a, b);
}

// =============================================================================
// LUMINANCE
// =============================================================================

// Standard Rec.709 luminance
float luminance_709(vec3 col) {
	return dot(col, vec3(0.2126, 0.7152, 0.0722));
}

// Rec.601 luminance (compatible with existing plugin)
float luminance_601(vec3 col) {
	return dot(col, vec3(0.299, 0.587, 0.114));
}

// =============================================================================
// PROCEDURAL BAYER MATRIX
// =============================================================================

// Compute Bayer threshold procedurally from pixel coordinates.
// level: number of recursion levels (1=2x2, 2=4x4, 3=8x8, 4=16x16)
// This avoids needing a texture at all for Bayer dithering.
float bayer_procedural(vec2 coord, int level) {
	float result = 0.0;
	float divisor = 0.0;
	vec2 c = coord;

	for (int i = 0; i < level; i++) {
		vec2 cell = floor(mod(c, 2.0));
		// Map (x,y) in {0,1}x{0,1} to Bayer(0) index: 0,2,3,1
		float idx = cell.x + cell.y * 2.0;
		float val;
		if (idx < 0.5) val = 0.0;       // (0,0) -> 0
		else if (idx < 1.5) val = 2.0;   // (1,0) -> 2
		else if (idx < 2.5) val = 3.0;   // (0,1) -> 3
		else val = 1.0;                   // (1,1) -> 1

		result += val * exp2(float(i) * 2.0);
		divisor += 3.0 * exp2(float(i) * 2.0);
		c = floor(c / 2.0);
	}

	return result / divisor;
}

// =============================================================================
// DITHERING ALGORITHMS
// =============================================================================

// Algorithm modes:
// 0 = Texture-based ordered (Bayer/Blue Noise from texture)
// 1 = Procedural Bayer (no texture needed)
// 2 = Blue Noise Error Diffusion Approximation
// 3 = White Noise (random threshold)
// 4 = Interleaved Gradient Noise (Jimenez 2014, good temporal stability)

// Interleaved gradient noise - produces good dither with no texture
// Jorge Jimenez, "Next Generation Post Processing in Call of Duty: Advanced Warfare"
float ign(vec2 coord) {
	return fract(52.9829189 * fract(0.06711056 * coord.x + 0.00583715 * coord.y));
}

// Hash-based white noise
float white_noise(vec2 coord) {
	return fract(sin(dot(coord, vec2(12.9898, 78.233))) * 43758.5453);
}

// =============================================================================
// PALETTE MATCHING
// =============================================================================

// Find the two nearest palette colors and interpolation factor for ordered dithering.
// palette_tex: horizontal 1D palette texture (dark left, light right)
// lum: input luminance [0,1]
// Returns: vec3(lower_u, upper_u, frac) where frac is position between them
vec3 palette_lookup(sampler2D palette_tex, float lum) {
	ivec2 pal_size = textureSize(palette_tex, 0);
	int num_colors = pal_size.x / max(pal_size.y, 1);
	float col_x = float(num_colors) - 1.0;
	float texel = 1.0 / col_x;

	float l = max(lum - 0.00001, 0.0);
	float lower = floor(l * col_x) * texel;
	float upper = (floor(l * col_x) + 1.0) * texel;
	float frac = l * col_x - floor(l * col_x);

	return vec3(lower, upper, frac);
}

// Multi-color palette matching: find the nearest palette color to input color
// Uses the specified color distance metric
vec3 find_nearest_palette_color(vec3 input_col, sampler2D palette_tex, int dist_mode) {
	ivec2 pal_size = textureSize(palette_tex, 0);
	int num_colors = pal_size.x / max(pal_size.y, 1);

	vec3 best_col = texture(palette_tex, vec2(0.5 / float(num_colors), 0.5)).rgb;
	float best_dist = color_distance(input_col, best_col, dist_mode);

	for (int i = 1; i < num_colors; i++) {
		float u = (float(i) + 0.5) / float(num_colors);
		vec3 pal_col = texture(palette_tex, vec2(u, 0.5)).rgb;
		float d = color_distance(input_col, pal_col, dist_mode);
		if (d < best_dist) {
			best_dist = d;
			best_col = pal_col;
		}
	}

	return best_col;
}

// Multi-color ordered dithering: find the two nearest palette colors
// and use threshold to choose between them.
// This generalizes ordered dithering to arbitrary (non-linear) palettes.
vec3 dither_multicolor(vec3 input_col, float threshold, sampler2D palette_tex, int dist_mode) {
	ivec2 pal_size = textureSize(palette_tex, 0);
	int num_colors = pal_size.x / max(pal_size.y, 1);

	// Find nearest and second-nearest
	vec3 nearest = input_col;
	vec3 second = input_col;
	float best_dist = 1e10;
	float second_dist = 1e10;

	for (int i = 0; i < num_colors; i++) {
		float u = (float(i) + 0.5) / float(num_colors);
		vec3 pal_col = texture(palette_tex, vec2(u, 0.5)).rgb;
		float d = color_distance(input_col, pal_col, dist_mode);
		if (d < best_dist) {
			second_dist = best_dist;
			second = nearest;
			best_dist = d;
			nearest = pal_col;
		} else if (d < second_dist) {
			second_dist = d;
			second = pal_col;
		}
	}

	// Mix ratio based on relative distances
	float total = best_dist + second_dist;
	float mix_factor = (total > 0.0001) ? best_dist / total : 0.0;

	return (threshold < mix_factor) ? nearest : second;
}

// =============================================================================
// BLEND MODES
// =============================================================================

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
vec3 blend_color_dodge(vec3 base, vec3 blend) {
	return min(base / max(1.0 - blend, 0.001), vec3(1.0));
}
vec3 blend_color_burn(vec3 base, vec3 blend) {
	return 1.0 - min((1.0 - base) / max(blend, 0.001), vec3(1.0));
}
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

// =============================================================================
// EDGE AND DEPTH UTILITIES
// =============================================================================

vec3 reconstruct_world_pos(vec2 uv, float depth_val, mat4 inv_proj, mat4 inv_view) {
	vec3 ndc;
	ndc.xy = uv * 2.0 - 1.0;
	ndc.z = depth_val * 2.0 - 1.0;

	vec4 view_pos = inv_proj * vec4(ndc, 1.0);
	view_pos.xyz /= view_pos.w;

	vec4 wpos = inv_view * vec4(view_pos.xyz, 1.0);
	return wpos.xyz;
}

vec3 triplanar_weights(vec3 normal, float sharpness) {
	vec3 w = pow(abs(normal), vec3(sharpness));
	w /= (w.x + w.y + w.z + 0.0001);
	return w;
}

float get_linear_depth(float depth_raw, mat4 inv_proj) {
	vec4 ndc = vec4(0.0, 0.0, depth_raw * 2.0 - 1.0, 1.0);
	vec4 view_pos = inv_proj * ndc;
	return -view_pos.z / view_pos.w;
}

// Edge detection from depth discontinuities
float detect_edges_depth(sampler2D depth_tex, vec2 uv, vec2 texel_size, float threshold) {
	float d_c = texture(depth_tex, uv).r;
	float d_l = texture(depth_tex, uv + vec2(-texel_size.x, 0.0)).r;
	float d_r = texture(depth_tex, uv + vec2(texel_size.x, 0.0)).r;
	float d_u = texture(depth_tex, uv + vec2(0.0, -texel_size.y)).r;
	float d_d = texture(depth_tex, uv + vec2(0.0, texel_size.y)).r;

	float diff = abs(d_l - d_c) + abs(d_r - d_c) + abs(d_u - d_c) + abs(d_d - d_c);
	return smoothstep(0.0, threshold, diff);
}

// =============================================================================
// TEXTURE SAMPLING WITH LOD AND OPTIONAL FILTERING
// =============================================================================

float sample_bilinear_lod(sampler2D tex, vec2 uv, float lod_bias) {
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

float sample_dither_tex(sampler2D tex, vec2 uv, float lod_bias, bool use_filter) {
	if (use_filter) {
		return sample_bilinear_lod(tex, uv, lod_bias);
	} else {
		return textureLod(tex, uv, lod_bias).r;
	}
}

float sample_triplanar_dither(sampler2D tex, vec3 pos, vec3 weights, float lod_bias, bool use_filter) {
	float s_xz = sample_dither_tex(tex, pos.xz, lod_bias, use_filter);
	float s_xy = sample_dither_tex(tex, pos.xy, lod_bias, use_filter);
	float s_yz = sample_dither_tex(tex, pos.yz, lod_bias, use_filter);
	return s_xz * weights.y + s_xy * weights.z + s_yz * weights.x;
}
