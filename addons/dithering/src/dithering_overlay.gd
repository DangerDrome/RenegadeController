@tool
class_name DitheringOverlay
extends CanvasLayer
## Advanced dithering post-processing overlay.
##
## Supports SCREEN-SPACE (pattern moves with camera) and WORLD-SPACE
## (surface-stable, pattern locked to geometry) modes with independent settings.
## Both modes can be enabled simultaneously for layered effects.
##
## Algorithms: Texture-based Ordered, Procedural Bayer, Blue Noise Error Diffusion
## Approximation, White Noise, Interleaved Gradient Noise (Jimenez 2014).
##
## Palette Modes: Classic luminance-based, Multi-color perceptual (Oklab).
##
## References:
## - Surma Ditherpunk: https://surma.dev/things/ditherpunk/
## - TIGSource (Lucas Pope): https://forums.tigsource.com/index.php?topic=40832.msg1363742
## - Rune Skovbo Johansen Dither3D: https://runevision.com/tech/dither3d/

const SCREEN_SHADER := preload("res://addons/dithering/src/dither_screen.gdshader")
const WORLD_SHADER := preload("res://addons/dithering/src/dither_world.gdshader")

# =============================================================================
# ENUMS
# =============================================================================

## Dithering algorithm to use.
enum Algorithm {
	TEXTURE_ORDERED,    ## Classic texture-based ordered dithering (Bayer/Blue Noise)
	PROCEDURAL_BAYER,   ## Procedurally generated Bayer matrix (no texture needed)
	ERROR_DIFFUSION,    ## Blue noise error diffusion approximation
	WHITE_NOISE,        ## Random threshold per pixel
	GRADIENT_NOISE,     ## Interleaved Gradient Noise (Jimenez 2014, good temporal stability)
}

## How to match colors to the palette.
enum PaletteMode {
	LUMINANCE,      ## Classic: convert to luminance, map through 1D palette
	MULTI_COLOR,    ## Find two nearest palette colors, dither between them
}

## Color distance metric for multi-color palette matching.
enum ColorDistance {
	RGB,            ## Naive Euclidean RGB (fast, less accurate)
	WEIGHTED_RGB,   ## Redmean-weighted RGB (cheap perceptual improvement)
	OKLAB,          ## Oklab perceptual color space (best quality)
}

## Dither pattern presets.
enum DitherPattern {
	BAYER_16X16,
	BAYER_8X8,
	BAYER_4X4,
	BAYER_2X2,
	BLUE_NOISE,
	CUSTOM,
}

## Color palette presets.
enum PalettePreset {
	MONO,
	MOONLIGHT,
	EEVEE,
	HOLLOW,
	RISING_SUN,
	CUSTOM,
}

## Blend modes for compositing.
enum BlendMode {
	NORMAL, ADD, SUBTRACT, MULTIPLY, SCREEN, OVERLAY,
	SOFT_LIGHT, HARD_LIGHT, COLOR_DODGE, COLOR_BURN, DIFFERENCE,
}

## Projection mode for world-space dithering.
enum ProjectionMode {
	XZ_FLOORS, XY_Z_WALLS, YZ_X_WALLS, AUTO_HARD, TRIPLANAR_BLEND,
}

## Procedural Bayer matrix size.
enum BayerLevel {
	BAYER_2X2 = 1,  ## 2×2 matrix (4 levels)
	BAYER_4X4 = 2,  ## 4×4 matrix (16 levels)
	BAYER_8X8 = 3,  ## 8×8 matrix (64 levels)
	BAYER_16X16 = 4,## 16×16 matrix (256 levels)
}

## Debug visualization modes.
enum DebugMode {
	OFF, DEPTH, WORLD_POS, NORMAL, SCREEN_UV, PASSTHROUGH,
	DITHER_UV, THRESHOLD, LUMINANCE, CHECKER, TRIPLANAR_WEIGHTS, MASK,
	ALGORITHM_OUTPUT,
}

# Preloaded textures
const PATTERNS := {
	DitherPattern.BAYER_16X16: preload("res://addons/dithering/assets/patterns/bayer16tile2.png"),
	DitherPattern.BAYER_8X8: preload("res://addons/dithering/assets/patterns/bayer8tile4.png"),
	DitherPattern.BAYER_4X4: preload("res://addons/dithering/assets/patterns/bayer4tile8.png"),
	DitherPattern.BAYER_2X2: preload("res://addons/dithering/assets/patterns/bayer2tile16.png"),
	DitherPattern.BLUE_NOISE: preload("res://addons/dithering/assets/patterns/blue_noise.png"),
}

const PALETTES := {
	PalettePreset.MONO: preload("res://addons/dithering/assets/palettes/palette_mono.png"),
	PalettePreset.MOONLIGHT: preload("res://addons/dithering/assets/palettes/palette_moonlight.png"),
	PalettePreset.EEVEE: preload("res://addons/dithering/assets/palettes/palette_eeve.png"),
	PalettePreset.HOLLOW: preload("res://addons/dithering/assets/palettes/palette_hollow.png"),
	PalettePreset.RISING_SUN: preload("res://addons/dithering/assets/palettes/palette_rising_sun.png"),
}

# =============================================================================
# EFFECT CONTROL
# =============================================================================
@export_group("Effect Control")

@export var effect_enabled: bool = true:
	set(value):
		effect_enabled = value
		_update_visibility()

@export var screen_space_enabled: bool = false:
	set(value):
		screen_space_enabled = value
		_update_visibility()

@export var world_space_enabled: bool = true:
	set(value):
		world_space_enabled = value
		_warn_if_incompatible()
		_update_visibility()
		_update_shader_params()

# =============================================================================
# SCREEN-SPACE SETTINGS
# =============================================================================
@export_group("Screen-Space Settings")

@export_subgroup("Algorithm")

## Dithering algorithm for screen-space mode.
@export var screen_algorithm: Algorithm = Algorithm.TEXTURE_ORDERED:
	set(value):
		screen_algorithm = value
		_update_shader_params()

## Procedural Bayer matrix size (only used with PROCEDURAL_BAYER algorithm).
@export var screen_bayer_level: BayerLevel = BayerLevel.BAYER_8X8:
	set(value):
		screen_bayer_level = value
		_update_shader_params()

## How to match colors to palette.
@export var screen_palette_mode: PaletteMode = PaletteMode.LUMINANCE:
	set(value):
		screen_palette_mode = value
		_update_shader_params()

## Color distance metric for multi-color mode.
@export var screen_color_distance: ColorDistance = ColorDistance.OKLAB:
	set(value):
		screen_color_distance = value
		_update_shader_params()

## Error diffusion approximation strength (for ERROR_DIFFUSION algorithm).
@export_range(0.0, 2.0, 0.01) var screen_error_strength: float = 1.0:
	set(value):
		screen_error_strength = value
		_update_shader_params()

## Operate in linear color space for more accurate dithering.
@export var screen_linear_space: bool = false:
	set(value):
		screen_linear_space = value
		_update_shader_params()

@export_subgroup("Presets")

@export var screen_pattern: DitherPattern = DitherPattern.BLUE_NOISE:
	set(value):
		screen_pattern = value
		if value != DitherPattern.CUSTOM and PATTERNS.has(value):
			screen_dither_texture = PATTERNS[value]

@export var screen_palette: PalettePreset = PalettePreset.MONO:
	set(value):
		screen_palette = value
		if value != PalettePreset.CUSTOM and PALETTES.has(value):
			screen_palette_texture = PALETTES[value]

@export_subgroup("Custom Textures")

@export var screen_dither_texture: Texture2D:
	set(value):
		screen_dither_texture = value
		_update_shader_params()

@export var screen_palette_texture: Texture2D:
	set(value):
		screen_palette_texture = value
		_update_shader_params()

@export_subgroup("Effect Parameters")

@export_range(2, 64) var screen_bit_depth: int = 32:
	set(value):
		screen_bit_depth = value
		_update_shader_params()

@export_range(0.0, 5.0, 0.01) var screen_contrast: float = 1.0:
	set(value):
		screen_contrast = value
		_update_shader_params()

@export_range(-1.0, 1.0, 0.01) var screen_lum_offset: float = 0.0:
	set(value):
		screen_lum_offset = value
		_update_shader_params()

@export_range(1, 8) var screen_dither_size: int = 2:
	set(value):
		screen_dither_size = value
		_update_shader_params()

@export_range(0.0, 1.0, 0.01) var screen_color_mix: float = 1.0:
	set(value):
		screen_color_mix = value
		_update_shader_params()

@export var screen_blend_mode: BlendMode = BlendMode.NORMAL:
	set(value):
		screen_blend_mode = value
		_update_shader_params()

@export_subgroup("Masking")

@export var screen_mask_shadows: bool = false:
	set(value):
		screen_mask_shadows = value
		_update_shader_params()

@export_range(0.0, 1.0, 0.01) var screen_mask_shadows_threshold: float = 0.5:
	set(value):
		screen_mask_shadows_threshold = value
		_update_shader_params()

@export_range(0.0, 0.5, 0.01) var screen_mask_shadows_softness: float = 0.1:
	set(value):
		screen_mask_shadows_softness = value
		_update_shader_params()

@export var screen_mask_highlights: bool = false:
	set(value):
		screen_mask_highlights = value
		_update_shader_params()

@export_range(0.0, 1.0, 0.01) var screen_mask_highlights_threshold: float = 0.5:
	set(value):
		screen_mask_highlights_threshold = value
		_update_shader_params()

@export_range(0.0, 0.5, 0.01) var screen_mask_highlights_softness: float = 0.1:
	set(value):
		screen_mask_highlights_softness = value
		_update_shader_params()

# =============================================================================
# WORLD-SPACE SETTINGS
# =============================================================================
@export_group("World-Space Settings")

@export_subgroup("Algorithm")

@export var world_algorithm: Algorithm = Algorithm.TEXTURE_ORDERED:
	set(value):
		world_algorithm = value
		_warn_if_incompatible()
		_update_shader_params()

@export var world_bayer_level: BayerLevel = BayerLevel.BAYER_8X8:
	set(value):
		world_bayer_level = value
		_update_shader_params()

@export var world_palette_mode: PaletteMode = PaletteMode.LUMINANCE:
	set(value):
		world_palette_mode = value
		_update_shader_params()

@export var world_color_distance: ColorDistance = ColorDistance.OKLAB:
	set(value):
		world_color_distance = value
		_update_shader_params()

@export_range(0.0, 2.0, 0.01) var world_error_strength: float = 1.0:
	set(value):
		world_error_strength = value
		_update_shader_params()

@export var world_linear_space: bool = false:
	set(value):
		world_linear_space = value
		_update_shader_params()

@export_subgroup("Presets")

@export var world_pattern: DitherPattern = DitherPattern.BAYER_16X16:
	set(value):
		world_pattern = value
		if value != DitherPattern.CUSTOM and PATTERNS.has(value):
			world_dither_texture = PATTERNS[value]
		_warn_if_incompatible()

@export var world_palette: PalettePreset = PalettePreset.MONO:
	set(value):
		world_palette = value
		if value != PalettePreset.CUSTOM and PALETTES.has(value):
			world_palette_texture = PALETTES[value]

@export_subgroup("Custom Textures")

@export var world_dither_texture: Texture2D:
	set(value):
		world_dither_texture = value
		_update_shader_params()

@export var world_palette_texture: Texture2D:
	set(value):
		world_palette_texture = value
		_update_shader_params()

@export_subgroup("Effect Parameters")

@export_range(2, 64) var world_bit_depth: int = 32:
	set(value):
		world_bit_depth = value
		_update_shader_params()

@export_range(0.0, 5.0, 0.01) var world_contrast: float = 1.0:
	set(value):
		world_contrast = value
		_update_shader_params()

@export_range(-1.0, 1.0, 0.01) var world_lum_offset: float = 0.0:
	set(value):
		world_lum_offset = value
		_update_shader_params()

@export_range(1, 8) var world_dither_size: int = 2:
	set(value):
		world_dither_size = value
		_update_shader_params()

@export_range(0.0, 1.0, 0.01) var world_color_mix: float = 1.0:
	set(value):
		world_color_mix = value
		_update_shader_params()

@export var world_blend_mode: BlendMode = BlendMode.NORMAL:
	set(value):
		world_blend_mode = value
		_update_shader_params()

@export_subgroup("Masking")

@export var world_mask_shadows: bool = false:
	set(value):
		world_mask_shadows = value
		_update_shader_params()

@export_range(0.0, 1.0, 0.01) var world_mask_shadows_threshold: float = 0.5:
	set(value):
		world_mask_shadows_threshold = value
		_update_shader_params()

@export_range(0.0, 0.5, 0.01) var world_mask_shadows_softness: float = 0.1:
	set(value):
		world_mask_shadows_softness = value
		_update_shader_params()

@export var world_mask_highlights: bool = false:
	set(value):
		world_mask_highlights = value
		_update_shader_params()

@export_range(0.0, 1.0, 0.01) var world_mask_highlights_threshold: float = 0.5:
	set(value):
		world_mask_highlights_threshold = value
		_update_shader_params()

@export_range(0.0, 0.5, 0.01) var world_mask_highlights_softness: float = 0.1:
	set(value):
		world_mask_highlights_softness = value
		_update_shader_params()

@export var world_mask_edges: bool = false:
	set(value):
		world_mask_edges = value
		_update_shader_params()

@export_range(0.0, 1.0, 0.01) var world_mask_edges_strength: float = 1.0:
	set(value):
		world_mask_edges_strength = value
		_update_shader_params()

@export_range(0.0, 0.1, 0.001) var world_mask_edges_depth_threshold: float = 0.01:
	set(value):
		world_mask_edges_depth_threshold = value
		_update_shader_params()

@export_range(0.0, 1.0, 0.01) var world_mask_edges_normal_threshold: float = 0.5:
	set(value):
		world_mask_edges_normal_threshold = value
		_update_shader_params()

@export var world_mask_depth: bool = false:
	set(value):
		world_mask_depth = value
		_update_shader_params()

@export_range(0.0, 100.0, 0.1) var world_mask_depth_near: float = 0.0:
	set(value):
		world_mask_depth_near = value
		_update_shader_params()

@export_range(0.0, 500.0, 1.0) var world_mask_depth_far: float = 50.0:
	set(value):
		world_mask_depth_far = value
		_update_shader_params()

@export var world_mask_depth_invert: bool = false:
	set(value):
		world_mask_depth_invert = value
		_update_shader_params()

@export_subgroup("Projection")

@export var source_camera: Camera3D:
	set(value):
		source_camera = value
		_setup_world_quad()

@export_range(0.01, 50.0, 0.01) var world_scale: float = 5.0:
	set(value):
		world_scale = value
		_update_shader_params()

@export var projection_mode: ProjectionMode = ProjectionMode.TRIPLANAR_BLEND:
	set(value):
		projection_mode = value
		_update_shader_params()

@export_subgroup("Triplanar")

@export_range(0.1, 32.0, 0.1) var triplanar_sharpness: float = 4.0:
	set(value):
		triplanar_sharpness = value
		_update_shader_params()

@export var triplanar_offset: Vector3 = Vector3.ZERO:
	set(value):
		triplanar_offset = value
		_update_shader_params()

@export_subgroup("Anti-Aliasing")

@export_range(0.0, 8.0, 0.1) var moire_reduction: float = 0.0:
	set(value):
		moire_reduction = value
		_update_shader_params()

@export_range(0.0, 0.5, 0.01) var edge_softness: float = 0.0:
	set(value):
		edge_softness = value
		_update_shader_params()

@export var pattern_filtering: bool = true:
	set(value):
		pattern_filtering = value
		_update_shader_params()

@export_subgroup("Debug")

@export var debug_mode: DebugMode = DebugMode.OFF:
	set(value):
		debug_mode = value
		_update_shader_params()

@export_range(0.1, 10.0, 0.1) var checker_scale: float = 1.0:
	set(value):
		checker_scale = value
		_update_shader_params()

# =============================================================================
# INTERNAL
# =============================================================================

var _color_rect: ColorRect
var _screen_material: ShaderMaterial
var _world_quad: MeshInstance3D
var _world_material: ShaderMaterial


func _ready() -> void:
	_setup_screen_overlay()
	_setup_world_quad()

	# Apply presets on ready if textures not set
	if not screen_dither_texture and PATTERNS.has(screen_pattern):
		screen_dither_texture = PATTERNS[screen_pattern]
	if not screen_palette_texture and PALETTES.has(screen_palette):
		screen_palette_texture = PALETTES[screen_palette]
	if not world_dither_texture and PATTERNS.has(world_pattern):
		world_dither_texture = PATTERNS[world_pattern]
	if not world_palette_texture and PALETTES.has(world_palette):
		world_palette_texture = PALETTES[world_palette]

	_warn_if_incompatible()
	_update_visibility()
	_update_shader_params()


func _setup_screen_overlay() -> void:
	_color_rect = ColorRect.new()
	_color_rect.name = "ScreenDitherRect"
	_color_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_color_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	_screen_material = ShaderMaterial.new()
	_screen_material.shader = SCREEN_SHADER
	_color_rect.material = _screen_material

	add_child(_color_rect)


func _setup_world_quad() -> void:
	if _world_quad:
		_world_quad.queue_free()
		_world_quad = null

	var camera := _get_camera()
	if not camera:
		push_warning("DitheringOverlay: No camera found for world-space mode. Assign source_camera or ensure a Camera3D exists.")
		return

	_world_quad = MeshInstance3D.new()
	_world_quad.name = "WorldDitherQuad"

	var mesh := QuadMesh.new()
	mesh.size = Vector2(2.0, 2.0)
	mesh.orientation = PlaneMesh.FACE_Z
	mesh.flip_faces = true
	_world_quad.mesh = mesh

	_world_material = ShaderMaterial.new()
	_world_material.shader = WORLD_SHADER
	_world_material.render_priority = 100
	_world_quad.material_override = _world_material

	_world_quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_world_quad.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	_world_quad.extra_cull_margin = 16384.0

	camera.add_child(_world_quad)

	_update_visibility()
	_update_shader_params()


func _get_camera() -> Camera3D:
	if source_camera:
		return source_camera
	var viewport := get_viewport()
	if viewport:
		return viewport.get_camera_3d()
	return null


func _warn_if_incompatible() -> void:
	if world_space_enabled and world_pattern == DitherPattern.BLUE_NOISE and world_algorithm == Algorithm.TEXTURE_ORDERED:
		push_warning("DitheringOverlay: Blue noise pattern is designed for screen-space dithering. " +
			"In world-space mode it will appear to swim/shimmer. " +
			"Consider using a Bayer pattern, or switch to PROCEDURAL_BAYER or GRADIENT_NOISE algorithm.")


func _update_visibility() -> void:
	if _color_rect:
		_color_rect.visible = effect_enabled and screen_space_enabled
	if _world_quad:
		_world_quad.visible = effect_enabled and world_space_enabled


func _update_shader_params() -> void:
	# === SCREEN-SPACE ===
	if _screen_material:
		if screen_dither_texture:
			_screen_material.set_shader_parameter("u_dither_tex", screen_dither_texture)
		if screen_palette_texture:
			_screen_material.set_shader_parameter("u_color_tex", screen_palette_texture)

		_screen_material.set_shader_parameter("u_algorithm", screen_algorithm)
		_screen_material.set_shader_parameter("u_bayer_level", screen_bayer_level)
		_screen_material.set_shader_parameter("u_palette_mode", screen_palette_mode)
		_screen_material.set_shader_parameter("u_color_distance", screen_color_distance)
		_screen_material.set_shader_parameter("u_error_strength", screen_error_strength)
		_screen_material.set_shader_parameter("u_linear_space", screen_linear_space)
		_screen_material.set_shader_parameter("u_bit_depth", screen_bit_depth)
		_screen_material.set_shader_parameter("u_contrast", screen_contrast)
		_screen_material.set_shader_parameter("u_offset", screen_lum_offset)
		_screen_material.set_shader_parameter("u_dither_size", screen_dither_size)
		_screen_material.set_shader_parameter("u_mix", screen_color_mix)
		_screen_material.set_shader_parameter("u_blend_mode", screen_blend_mode)
		_screen_material.set_shader_parameter("u_mask_shadows_enabled", screen_mask_shadows)
		_screen_material.set_shader_parameter("u_mask_shadows_threshold", screen_mask_shadows_threshold)
		_screen_material.set_shader_parameter("u_mask_shadows_softness", screen_mask_shadows_softness)
		_screen_material.set_shader_parameter("u_mask_highlights_enabled", screen_mask_highlights)
		_screen_material.set_shader_parameter("u_mask_highlights_threshold", screen_mask_highlights_threshold)
		_screen_material.set_shader_parameter("u_mask_highlights_softness", screen_mask_highlights_softness)

	# === WORLD-SPACE ===
	if _world_material:
		if world_dither_texture:
			_world_material.set_shader_parameter("dither_texture", world_dither_texture)
		if world_palette_texture:
			_world_material.set_shader_parameter("palette_texture", world_palette_texture)

		_world_material.set_shader_parameter("algorithm", world_algorithm)
		_world_material.set_shader_parameter("bayer_level", world_bayer_level)
		_world_material.set_shader_parameter("palette_mode", world_palette_mode)
		_world_material.set_shader_parameter("color_distance_mode", world_color_distance)
		_world_material.set_shader_parameter("error_strength", world_error_strength)
		_world_material.set_shader_parameter("linear_space", world_linear_space)
		_world_material.set_shader_parameter("bit_depth", world_bit_depth)
		_world_material.set_shader_parameter("contrast", world_contrast)
		_world_material.set_shader_parameter("lum_offset", world_lum_offset)
		_world_material.set_shader_parameter("dither_size", world_dither_size)
		_world_material.set_shader_parameter("color_mix", world_color_mix)
		_world_material.set_shader_parameter("blend_mode", world_blend_mode)
		_world_material.set_shader_parameter("world_scale", world_scale)
		_world_material.set_shader_parameter("projection_mode", projection_mode)
		_world_material.set_shader_parameter("triplanar_sharpness", triplanar_sharpness)
		_world_material.set_shader_parameter("triplanar_offset", triplanar_offset)
		_world_material.set_shader_parameter("moire_reduction", moire_reduction)
		_world_material.set_shader_parameter("edge_softness", edge_softness)
		_world_material.set_shader_parameter("pattern_filtering", pattern_filtering)
		# Masking
		_world_material.set_shader_parameter("mask_shadows_enabled", world_mask_shadows)
		_world_material.set_shader_parameter("mask_shadows_threshold", world_mask_shadows_threshold)
		_world_material.set_shader_parameter("mask_shadows_softness", world_mask_shadows_softness)
		_world_material.set_shader_parameter("mask_highlights_enabled", world_mask_highlights)
		_world_material.set_shader_parameter("mask_highlights_threshold", world_mask_highlights_threshold)
		_world_material.set_shader_parameter("mask_highlights_softness", world_mask_highlights_softness)
		_world_material.set_shader_parameter("mask_edges_enabled", world_mask_edges)
		_world_material.set_shader_parameter("mask_edges_strength", world_mask_edges_strength)
		_world_material.set_shader_parameter("mask_edges_threshold", world_mask_edges_depth_threshold)
		_world_material.set_shader_parameter("mask_edges_normal_threshold", world_mask_edges_normal_threshold)
		_world_material.set_shader_parameter("mask_depth_enabled", world_mask_depth)
		_world_material.set_shader_parameter("mask_depth_near", world_mask_depth_near)
		_world_material.set_shader_parameter("mask_depth_far", world_mask_depth_far)
		_world_material.set_shader_parameter("mask_depth_invert", world_mask_depth_invert)
		# Debug
		_world_material.set_shader_parameter("debug_mode", debug_mode)
		_world_material.set_shader_parameter("debug_checker_size", checker_scale)


func _notification(what: int) -> void:
	if what == NOTIFICATION_ENTER_TREE:
		call_deferred("_setup_world_quad")


# =============================================================================
# PUBLIC API
# =============================================================================

## Toggle the entire effect on/off.
func toggle() -> void:
	effect_enabled = not effect_enabled

## Toggle screen-space dithering.
func toggle_screen_space() -> void:
	screen_space_enabled = not screen_space_enabled

## Toggle world-space dithering.
func toggle_world_space() -> void:
	world_space_enabled = not world_space_enabled

## Cycle to next screen algorithm.
func next_screen_algorithm() -> void:
	screen_algorithm = ((screen_algorithm + 1) % 5) as Algorithm

## Cycle to next world algorithm.
func next_world_algorithm() -> void:
	world_algorithm = ((world_algorithm + 1) % 5) as Algorithm

## Cycle to next screen pattern.
func next_screen_pattern() -> void:
	screen_pattern = ((screen_pattern + 1) % DitherPattern.CUSTOM) as DitherPattern

## Cycle to next world pattern.
func next_world_pattern() -> void:
	world_pattern = ((world_pattern + 1) % DitherPattern.CUSTOM) as DitherPattern

## Cycle to next screen palette.
func next_screen_palette() -> void:
	screen_palette = ((screen_palette + 1) % PalettePreset.CUSTOM) as PalettePreset

## Cycle to next world palette.
func next_world_palette() -> void:
	world_palette = ((world_palette + 1) % PalettePreset.CUSTOM) as PalettePreset

## Cycle projection mode.
func next_projection() -> void:
	projection_mode = ((projection_mode + 1) % 5) as ProjectionMode

## Set screen params at once.
func set_screen_params(p_bit_depth: int = 32, p_contrast: float = 1.0, p_lum_offset: float = 0.0, p_dither_size: int = 2) -> void:
	screen_bit_depth = p_bit_depth
	screen_contrast = p_contrast
	screen_lum_offset = p_lum_offset
	screen_dither_size = p_dither_size

## Set world params at once.
func set_world_params(p_bit_depth: int = 32, p_contrast: float = 1.0, p_lum_offset: float = 0.0, p_dither_size: int = 2) -> void:
	world_bit_depth = p_bit_depth
	world_contrast = p_contrast
	world_lum_offset = p_lum_offset
	world_dither_size = p_dither_size
