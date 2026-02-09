@tool
class_name DitherOverlay
extends CanvasLayer
## A post-processing overlay that applies dither effects.
##
## Supports both SCREEN-SPACE (pattern moves with camera) and WORLD-SPACE
## (pattern locked to geometry like Obra Dinn) modes, with independent settings for each.
## Both modes can be enabled simultaneously for layered effects.

const DITHER_SHADER := preload("res://addons/dither_shader/src/dither.gdshader")
const WORLD_DITHER_SHADER := preload("res://addons/dither_shader/src/world_dither.gdshader")

## Available dither pattern presets.
enum DitherPattern {
	BAYER_16X16,  ## Smoothest dithering
	BAYER_8X8,    ## Balanced
	BAYER_4X4,    ## More visible pattern
	BAYER_2X2,    ## Most blocky
	BLUE_NOISE,   ## Organic/film-like (screen-space only - swims in world-space)
	CUSTOM,       ## Use custom texture
}

## Available color palette presets.
enum PalettePreset {
	MONO,         ## Black and white
	MOONLIGHT,    ## Cool blue tones
	EEVEE,        ## Warm brown/sepia
	HOLLOW,       ## Purple/blue fantasy
	RISING_SUN,   ## Warm sunset colors
	CUSTOM,       ## Use custom texture
}

## Blend modes for compositing dither with original scene.
enum BlendMode {
	NORMAL,       ## Replace with dither color
	ADD,          ## Brighten (base + blend)
	SUBTRACT,     ## Darken (base - blend)
	MULTIPLY,     ## Darken, preserve darks
	SCREEN,       ## Lighten, preserve lights
	OVERLAY,      ## Contrast boost
	SOFT_LIGHT,   ## Subtle contrast
	HARD_LIGHT,   ## Strong contrast
	COLOR_DODGE,  ## Brighten highlights
	COLOR_BURN,   ## Darken shadows
	DIFFERENCE,   ## Invert based on blend
}

## Projection mode for world-space dithering.
enum ProjectionMode {
	XZ_FLOORS,       ## Project onto horizontal surfaces only
	XY_Z_WALLS,      ## Project onto Z-facing walls only
	YZ_X_WALLS,      ## Project onto X-facing walls only
	AUTO_HARD,       ## Auto-pick dominant axis per pixel (hard switch, may seam)
	TRIPLANAR_BLEND, ## Smooth blend across all 3 axes (best quality)
}

## Debug visualization modes for troubleshooting world-space dithering.
enum DebugMode {
	OFF,              ## Normal dithering
	DEPTH,            ## Show linearized depth buffer
	WORLD_POS,        ## Show world position as RGB colors
	NORMAL,           ## Show reconstructed surface normals
	SCREEN_UV,        ## Show screen UV coordinates
	PASSTHROUGH,      ## Just pass through screen texture (no dither)
	DITHER_UV,        ## Show dither texture UV coordinates
	THRESHOLD,        ## Show dither threshold values from texture
	LUMINANCE,        ## Show calculated luminance
	CHECKER,          ## Procedural checker (respects projection mode)
	TRIPLANAR_WEIGHTS,## Show triplanar blend weights (R=X, G=Y, B=Z)
	MASK,             ## Show current mask values
}

# Preloaded pattern textures
const PATTERNS := {
	DitherPattern.BAYER_16X16: preload("res://addons/dither_shader/assets/patterns/bayer16tile2.png"),
	DitherPattern.BAYER_8X8: preload("res://addons/dither_shader/assets/patterns/bayer8tile4.png"),
	DitherPattern.BAYER_4X4: preload("res://addons/dither_shader/assets/patterns/bayer4tile8.png"),
	DitherPattern.BAYER_2X2: preload("res://addons/dither_shader/assets/patterns/bayer2tile16.png"),
	DitherPattern.BLUE_NOISE: preload("res://addons/dither_shader/assets/patterns/blue_noise.png"),
}

# Preloaded palette textures
const PALETTES := {
	PalettePreset.MONO: preload("res://addons/dither_shader/assets/palettes/palette_mono.png"),
	PalettePreset.MOONLIGHT: preload("res://addons/dither_shader/assets/palettes/palette_moonlight.png"),
	PalettePreset.EEVEE: preload("res://addons/dither_shader/assets/palettes/palette_eeve.png"),
	PalettePreset.HOLLOW: preload("res://addons/dither_shader/assets/palettes/palette_hollow.png"),
	PalettePreset.RISING_SUN: preload("res://addons/dither_shader/assets/palettes/palette_rising_sun.png"),
}

# =============================================================================
# EFFECT CONTROL
# =============================================================================
@export_group("Effect Control")

## Master toggle - disable to turn off all dithering.
@export var effect_enabled: bool = true:
	set(value):
		effect_enabled = value
		_update_visibility()

## Enable screen-space dithering (pattern moves with camera, film-grain look).
@export var screen_space_enabled: bool = false:
	set(value):
		screen_space_enabled = value
		_update_visibility()

## Enable world-space dithering (pattern locked to geometry like Obra Dinn).
@export var world_space_enabled: bool = true:
	set(value):
		world_space_enabled = value
		_warn_if_incompatible_pattern()
		_update_visibility()
		_update_shader_params()

# =============================================================================
# SCREEN-SPACE SETTINGS
# =============================================================================
@export_group("Screen-Space Settings")

@export_subgroup("Presets")

## Dither pattern for screen-space mode. Blue noise works great here.
@export var screen_pattern: DitherPattern = DitherPattern.BLUE_NOISE:
	set(value):
		screen_pattern = value
		if value != DitherPattern.CUSTOM and PATTERNS.has(value):
			screen_dither_texture = PATTERNS[value]

## Color palette for screen-space mode.
@export var screen_palette: PalettePreset = PalettePreset.MONO:
	set(value):
		screen_palette = value
		if value != PalettePreset.CUSTOM and PALETTES.has(value):
			screen_palette_texture = PALETTES[value]

@export_subgroup("Custom Textures")

## Custom dither pattern texture for screen-space. Set screen_pattern to CUSTOM.
@export var screen_dither_texture: Texture2D:
	set(value):
		screen_dither_texture = value
		_update_shader_params()

## Custom palette texture for screen-space. Set screen_palette to CUSTOM.
@export var screen_palette_texture: Texture2D:
	set(value):
		screen_palette_texture = value
		_update_shader_params()

@export_subgroup("Effect Parameters")

## Bit depth for luminance banding (screen-space).
@export_range(2, 64) var screen_bit_depth: int = 32:
	set(value):
		screen_bit_depth = value
		_update_shader_params()

## Contrast adjustment (screen-space).
@export_range(0.0, 5.0, 0.01) var screen_contrast: float = 1.0:
	set(value):
		screen_contrast = value
		_update_shader_params()

## Luminance offset (screen-space). Positive = brighter.
@export_range(-1.0, 1.0, 0.01) var screen_lum_offset: float = 0.0:
	set(value):
		screen_lum_offset = value
		_update_shader_params()

## Size of each dither pixel (screen-space).
@export_range(1, 8) var screen_dither_size: int = 2:
	set(value):
		screen_dither_size = value
		_update_shader_params()

## Mix between original and dithered (screen-space). 0 = original, 1 = full dither.
@export_range(0.0, 1.0, 0.01) var screen_color_mix: float = 1.0:
	set(value):
		screen_color_mix = value
		_update_shader_params()

## Blend mode for screen-space dithering.
@export var screen_blend_mode: BlendMode = BlendMode.NORMAL:
	set(value):
		screen_blend_mode = value
		_update_shader_params()

@export_subgroup("Masking")

## Apply dither only to dark areas (shadows).
@export var screen_mask_shadows: bool = false:
	set(value):
		screen_mask_shadows = value
		_update_shader_params()

## Luminance threshold below which is considered shadow.
@export_range(0.0, 1.0, 0.01) var screen_mask_shadows_threshold: float = 0.5:
	set(value):
		screen_mask_shadows_threshold = value
		_update_shader_params()

## Softness of shadow mask transition.
@export_range(0.0, 0.5, 0.01) var screen_mask_shadows_softness: float = 0.1:
	set(value):
		screen_mask_shadows_softness = value
		_update_shader_params()

## Apply dither only to bright areas (highlights).
@export var screen_mask_highlights: bool = false:
	set(value):
		screen_mask_highlights = value
		_update_shader_params()

## Luminance threshold above which is considered highlight.
@export_range(0.0, 1.0, 0.01) var screen_mask_highlights_threshold: float = 0.5:
	set(value):
		screen_mask_highlights_threshold = value
		_update_shader_params()

## Softness of highlight mask transition.
@export_range(0.0, 0.5, 0.01) var screen_mask_highlights_softness: float = 0.1:
	set(value):
		screen_mask_highlights_softness = value
		_update_shader_params()

# =============================================================================
# WORLD-SPACE SETTINGS
# =============================================================================
@export_group("World-Space Settings")

@export_subgroup("Presets")

## Dither pattern for world-space mode. Use Bayer patterns (blue noise will swim).
@export var world_pattern: DitherPattern = DitherPattern.BAYER_16X16:
	set(value):
		world_pattern = value
		if value != DitherPattern.CUSTOM and PATTERNS.has(value):
			world_dither_texture = PATTERNS[value]
		_warn_if_incompatible_pattern()

## Color palette for world-space mode.
@export var world_palette: PalettePreset = PalettePreset.MONO:
	set(value):
		world_palette = value
		if value != PalettePreset.CUSTOM and PALETTES.has(value):
			world_palette_texture = PALETTES[value]

@export_subgroup("Custom Textures")

## Custom dither pattern texture for world-space. Set world_pattern to CUSTOM.
@export var world_dither_texture: Texture2D:
	set(value):
		world_dither_texture = value
		_update_shader_params()

## Custom palette texture for world-space. Set world_palette to CUSTOM.
@export var world_palette_texture: Texture2D:
	set(value):
		world_palette_texture = value
		_update_shader_params()

@export_subgroup("Effect Parameters")

## Bit depth for luminance banding (world-space).
@export_range(2, 64) var world_bit_depth: int = 32:
	set(value):
		world_bit_depth = value
		_update_shader_params()

## Contrast adjustment (world-space).
@export_range(0.0, 5.0, 0.01) var world_contrast: float = 1.0:
	set(value):
		world_contrast = value
		_update_shader_params()

## Luminance offset (world-space). Positive = brighter.
@export_range(-1.0, 1.0, 0.01) var world_lum_offset: float = 0.0:
	set(value):
		world_lum_offset = value
		_update_shader_params()

## Size of each dither pixel (world-space).
@export_range(1, 8) var world_dither_size: int = 2:
	set(value):
		world_dither_size = value
		_update_shader_params()

## Mix between original and dithered (world-space). 0 = original, 1 = full dither.
@export_range(0.0, 1.0, 0.01) var world_color_mix: float = 1.0:
	set(value):
		world_color_mix = value
		_update_shader_params()

## Blend mode for world-space dithering.
@export var world_blend_mode: BlendMode = BlendMode.NORMAL:
	set(value):
		world_blend_mode = value
		_update_shader_params()

@export_subgroup("Masking")

## Apply dither only to dark areas (shadows).
@export var world_mask_shadows: bool = false:
	set(value):
		world_mask_shadows = value
		_update_shader_params()

## Luminance threshold below which is considered shadow.
@export_range(0.0, 1.0, 0.01) var world_mask_shadows_threshold: float = 0.5:
	set(value):
		world_mask_shadows_threshold = value
		_update_shader_params()

## Softness of shadow mask transition.
@export_range(0.0, 0.5, 0.01) var world_mask_shadows_softness: float = 0.1:
	set(value):
		world_mask_shadows_softness = value
		_update_shader_params()

## Apply dither only to bright areas (highlights).
@export var world_mask_highlights: bool = false:
	set(value):
		world_mask_highlights = value
		_update_shader_params()

## Luminance threshold above which is considered highlight.
@export_range(0.0, 1.0, 0.01) var world_mask_highlights_threshold: float = 0.5:
	set(value):
		world_mask_highlights_threshold = value
		_update_shader_params()

## Softness of highlight mask transition.
@export_range(0.0, 0.5, 0.01) var world_mask_highlights_softness: float = 0.1:
	set(value):
		world_mask_highlights_softness = value
		_update_shader_params()

## Apply dither only to edges (depth/normal discontinuities).
@export var world_mask_edges: bool = false:
	set(value):
		world_mask_edges = value
		_update_shader_params()

## Edge mask strength.
@export_range(0.0, 1.0, 0.01) var world_mask_edges_strength: float = 1.0:
	set(value):
		world_mask_edges_strength = value
		_update_shader_params()

## Depth difference threshold for edge detection.
@export_range(0.0, 0.1, 0.001) var world_mask_edges_depth_threshold: float = 0.01:
	set(value):
		world_mask_edges_depth_threshold = value
		_update_shader_params()

## Normal difference threshold for edge detection.
@export_range(0.0, 1.0, 0.01) var world_mask_edges_normal_threshold: float = 0.5:
	set(value):
		world_mask_edges_normal_threshold = value
		_update_shader_params()

## Apply dither based on distance from camera.
@export var world_mask_depth: bool = false:
	set(value):
		world_mask_depth = value
		_update_shader_params()

## Distance where effect is at full strength.
@export_range(0.0, 100.0, 0.1) var world_mask_depth_near: float = 0.0:
	set(value):
		world_mask_depth_near = value
		_update_shader_params()

## Distance where effect fades to zero.
@export_range(0.0, 500.0, 1.0) var world_mask_depth_far: float = 50.0:
	set(value):
		world_mask_depth_far = value
		_update_shader_params()

## Invert depth mask (far = full effect instead of near).
@export var world_mask_depth_invert: bool = false:
	set(value):
		world_mask_depth_invert = value
		_update_shader_params()

@export_subgroup("Projection")

## Camera to use for world-space dithering. Auto-detects if not set.
@export var source_camera: Camera3D:
	set(value):
		source_camera = value
		_setup_world_quad()

## Size of the dither pattern in world units. Larger = bigger pattern.
@export_range(0.01, 50.0, 0.01) var world_scale: float = 5.0:
	set(value):
		world_scale = value
		_update_shader_params()

## How to project the dither pattern onto surfaces.
@export var projection_mode: ProjectionMode = ProjectionMode.TRIPLANAR_BLEND:
	set(value):
		projection_mode = value
		_update_shader_params()

@export_subgroup("Triplanar")

## How sharply the projection blends between axes. Higher = harder transitions.
@export_range(0.1, 32.0, 0.1) var triplanar_sharpness: float = 4.0:
	set(value):
		triplanar_sharpness = value
		_update_shader_params()

## Offset the projected pattern in world space.
@export var triplanar_offset: Vector3 = Vector3.ZERO:
	set(value):
		triplanar_offset = value
		_update_shader_params()

@export_subgroup("Anti-Aliasing")

## Moiré reduction via texture LOD bias. Higher = blurrier at small scales.
@export_range(0.0, 8.0, 0.1) var moire_reduction: float = 0.0:
	set(value):
		moire_reduction = value
		_update_shader_params()

## Edge softness for dither transitions. 0 = hard, higher = softer.
@export_range(0.0, 0.5, 0.01) var edge_softness: float = 0.0:
	set(value):
		edge_softness = value
		_update_shader_params()

## Enable bilinear filtering on dither pattern (smoother but less crisp).
@export var pattern_filtering: bool = true:
	set(value):
		pattern_filtering = value
		_update_shader_params()

@export_subgroup("Debug")

## Debug visualization mode for troubleshooting.
@export var debug_mode: DebugMode = DebugMode.OFF:
	set(value):
		debug_mode = value
		_update_shader_params()

## Size of debug checker pattern in world units.
@export_range(0.1, 10.0, 0.1) var checker_scale: float = 1.0:
	set(value):
		checker_scale = value
		_update_shader_params()

# =============================================================================
# INTERNAL
# =============================================================================

# Screen-space nodes
var _color_rect: ColorRect
var _screen_material: ShaderMaterial

# World-space nodes
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

	_warn_if_incompatible_pattern()
	_update_visibility()
	_update_shader_params()


func _setup_screen_overlay() -> void:
	_color_rect = ColorRect.new()
	_color_rect.name = "ScreenDitherRect"
	_color_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_color_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	_screen_material = ShaderMaterial.new()
	_screen_material.shader = DITHER_SHADER
	_color_rect.material = _screen_material

	add_child(_color_rect)


func _setup_world_quad() -> void:
	if _world_quad:
		_world_quad.queue_free()
		_world_quad = null

	var camera := _get_camera()
	if not camera:
		push_warning("DitherOverlay: No camera found for world-space mode. Assign source_camera or ensure a Camera3D exists.")
		return

	_world_quad = MeshInstance3D.new()
	_world_quad.name = "WorldDitherQuad"

	var mesh := QuadMesh.new()
	mesh.size = Vector2(2.0, 2.0)
	mesh.orientation = PlaneMesh.FACE_Z
	mesh.flip_faces = true
	_world_quad.mesh = mesh

	_world_material = ShaderMaterial.new()
	_world_material.shader = WORLD_DITHER_SHADER
	_world_material.render_priority = 100  # Render late to capture scene, cursor renders later
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


func _warn_if_incompatible_pattern() -> void:
	if world_space_enabled and world_pattern == DitherPattern.BLUE_NOISE:
		push_warning("DitherOverlay: Blue noise pattern is designed for screen-space dithering. " +
			"In world-space mode it will appear to swim/shimmer instead of sticking to geometry. " +
			"Consider using a Bayer pattern for world-space mode.")


func _update_visibility() -> void:
	if _color_rect:
		_color_rect.visible = effect_enabled and screen_space_enabled
	if _world_quad:
		_world_quad.visible = effect_enabled and world_space_enabled


func _update_shader_params() -> void:
	# Update screen-space shader
	if _screen_material:
		if screen_dither_texture:
			_screen_material.set_shader_parameter("u_dither_tex", screen_dither_texture)
		if screen_palette_texture:
			_screen_material.set_shader_parameter("u_color_tex", screen_palette_texture)

		_screen_material.set_shader_parameter("u_bit_depth", screen_bit_depth)
		_screen_material.set_shader_parameter("u_contrast", screen_contrast)
		_screen_material.set_shader_parameter("u_offset", screen_lum_offset)
		_screen_material.set_shader_parameter("u_dither_size", screen_dither_size)
		_screen_material.set_shader_parameter("u_mix", screen_color_mix)
		_screen_material.set_shader_parameter("u_blend_mode", screen_blend_mode)
		# Screen masking
		_screen_material.set_shader_parameter("u_mask_shadows_enabled", screen_mask_shadows)
		_screen_material.set_shader_parameter("u_mask_shadows_threshold", screen_mask_shadows_threshold)
		_screen_material.set_shader_parameter("u_mask_shadows_softness", screen_mask_shadows_softness)
		_screen_material.set_shader_parameter("u_mask_highlights_enabled", screen_mask_highlights)
		_screen_material.set_shader_parameter("u_mask_highlights_threshold", screen_mask_highlights_threshold)
		_screen_material.set_shader_parameter("u_mask_highlights_softness", screen_mask_highlights_softness)

	# Update world-space shader
	if _world_material:
		if world_dither_texture:
			_world_material.set_shader_parameter("dither_texture", world_dither_texture)
		if world_palette_texture:
			_world_material.set_shader_parameter("palette_texture", world_palette_texture)

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
		# World masking
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

## Toggle the effect on/off.
func toggle() -> void:
	effect_enabled = not effect_enabled


## Toggle screen-space dithering on/off.
func toggle_screen_space() -> void:
	screen_space_enabled = not screen_space_enabled


## Toggle world-space dithering on/off.
func toggle_world_space() -> void:
	world_space_enabled = not world_space_enabled


## Set screen-space parameters at once.
func set_screen_params(p_bit_depth: int = 32, p_contrast: float = 1.0, p_lum_offset: float = 0.0, p_dither_size: int = 2) -> void:
	screen_bit_depth = p_bit_depth
	screen_contrast = p_contrast
	screen_lum_offset = p_lum_offset
	screen_dither_size = p_dither_size


## Set world-space parameters at once.
func set_world_params(p_bit_depth: int = 32, p_contrast: float = 1.0, p_lum_offset: float = 0.0, p_dither_size: int = 2) -> void:
	world_bit_depth = p_bit_depth
	world_contrast = p_contrast
	world_lum_offset = p_lum_offset
	world_dither_size = p_dither_size


## Cycle to the next screen-space pattern preset.
func next_screen_pattern() -> void:
	var next := (screen_pattern + 1) % DitherPattern.CUSTOM
	screen_pattern = next as DitherPattern


## Cycle to the next world-space pattern preset.
func next_world_pattern() -> void:
	var next := (world_pattern + 1) % DitherPattern.CUSTOM
	world_pattern = next as DitherPattern


## Cycle to the next screen-space palette preset.
func next_screen_palette() -> void:
	var next := (screen_palette + 1) % PalettePreset.CUSTOM
	screen_palette = next as PalettePreset


## Cycle to the next world-space palette preset.
func next_world_palette() -> void:
	var next := (world_palette + 1) % PalettePreset.CUSTOM
	world_palette = next as PalettePreset


## Cycle to the next projection mode (world-space only).
func next_projection() -> void:
	var next := (projection_mode + 1) % 5
	projection_mode = next as ProjectionMode
