@tool
class_name DitherOverlay
extends CanvasLayer
## A post-processing overlay that applies an Obra Dinn-style dither effect.
##
## Add this node to your scene to apply the dither effect to everything rendered below it.
## The effect converts the scene to a limited color palette with ordered dithering.

const DITHER_SHADER := preload("res://addons/dither_shader/src/dither.gdshader")

## Available dither pattern presets.
enum DitherPattern {
	BAYER_16X16,  ## Smoothest dithering
	BAYER_8X8,    ## Balanced
	BAYER_4X4,    ## More visible pattern
	BAYER_2X2,    ## Most blocky
	BLUE_NOISE,   ## Organic/film-like
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

@export_group("Presets")

## Select a dither pattern preset.
@export var pattern_preset: DitherPattern = DitherPattern.BAYER_8X8:
	set(value):
		pattern_preset = value
		if value != DitherPattern.CUSTOM and PATTERNS.has(value):
			dither_pattern = PATTERNS[value]

## Select a color palette preset.
@export var palette_preset: PalettePreset = PalettePreset.MONO:
	set(value):
		palette_preset = value
		if value != PalettePreset.CUSTOM and PALETTES.has(value):
			color_palette = PALETTES[value]

@export_group("Custom Textures")

## Custom dither pattern texture. Set pattern_preset to CUSTOM to use this.
@export var dither_pattern: Texture2D:
	set(value):
		dither_pattern = value
		_update_shader_params()

## Custom color palette texture. Set palette_preset to CUSTOM to use this.
@export var color_palette: Texture2D:
	set(value):
		color_palette = value
		_update_shader_params()

@export_group("Effect Parameters")

## Bit depth for luminance banding. Lower values create more distinct bands.
@export_range(2, 64) var bit_depth: int = 32:
	set(value):
		bit_depth = value
		_update_shader_params()

## Contrast adjustment. Higher values increase the difference between light and dark areas.
@export_range(0.0, 5.0, 0.01) var contrast: float = 1.0:
	set(value):
		contrast = value
		_update_shader_params()

## Luminance offset. Positive values brighten, negative values darken.
@export_range(-1.0, 1.0, 0.01) var lum_offset: float = 0.0:
	set(value):
		lum_offset = value
		_update_shader_params()

## Size of each dither pixel. Higher values create a more pixelated look.
@export_range(1, 8) var dither_size: int = 2:
	set(value):
		dither_size = value
		_update_shader_params()

## Mix between original scene colors and dithered output. 0.0 = original, 1.0 = full dither.
@export_range(0.0, 1.0, 0.01) var color_mix: float = 1.0:
	set(value):
		color_mix = value
		_update_shader_params()

## How the dither effect blends with the original scene.
@export var blend_mode: BlendMode = BlendMode.NORMAL:
	set(value):
		blend_mode = value
		_update_shader_params()

@export_group("World-Space Dithering")

## Reference to a SceneBuffers node that provides world position texture.
@export var scene_buffers: SceneBuffers:
	set(value):
		# Disconnect from old scene_buffers and clear its request
		if scene_buffers:
			if scene_buffers.buffer_changed.is_connected(_on_buffer_changed):
				scene_buffers.buffer_changed.disconnect(_on_buffer_changed)
			scene_buffers.requested_buffer = SceneBuffers.BufferType.NONE
		scene_buffers = value
		# Connect to new scene_buffers and set our request
		if scene_buffers:
			if not scene_buffers.buffer_changed.is_connected(_on_buffer_changed):
				scene_buffers.buffer_changed.connect(_on_buffer_changed)
			_update_scene_buffers_request()
		_update_shader_params()

## Set to WORLD_POSITION for world-space triplanar dithering, NONE for screen-space.
## When WORLD_POSITION is selected, the dither pattern sticks to geometry using
## triplanar mapping with proper normals. Other buffer types are for visualization only.
@export var dither_buffer: SceneBuffers.BufferType = SceneBuffers.BufferType.NONE:
	set(value):
		dither_buffer = value
		_update_scene_buffers_request()
		# Defer shader update to ensure SceneBuffers has updated first
		if is_inside_tree():
			call_deferred("_update_shader_params")
		else:
			_update_shader_params()

## Size of the world-space dither pattern in world units. Larger = bigger pattern.
@export_range(1.0, 100.0, 0.5) var world_dither_scale: float = 5.0:
	set(value):
		world_dither_scale = value
		_update_shader_params()

enum ProjectionPlane { XZ_FLOORS, XY_Z_WALLS, YZ_X_WALLS, AUTO }

## Which plane to project the dither pattern onto. AUTO detects surface orientation.
@export var world_dither_projection: ProjectionPlane = ProjectionPlane.AUTO:
	set(value):
		world_dither_projection = value
		_update_shader_params()

@export_group("Overlay Settings")

## Enable or disable the dither effect at runtime.
@export var effect_enabled: bool = true:
	set(value):
		effect_enabled = value
		if _color_rect:
			_color_rect.visible = value

var _color_rect: ColorRect
var _material: ShaderMaterial
var _last_buffer_type: int = -1  # Track buffer changes


func _ready() -> void:
	_setup_overlay()
	# Apply presets on ready if textures not set
	if not dither_pattern and PATTERNS.has(pattern_preset):
		dither_pattern = PATTERNS[pattern_preset]
	if not color_palette and PALETTES.has(palette_preset):
		color_palette = PALETTES[palette_preset]
	# Ensure signal connection if scene_buffers was set from scene file
	if scene_buffers:
		if not scene_buffers.buffer_changed.is_connected(_on_buffer_changed):
			scene_buffers.buffer_changed.connect(_on_buffer_changed)
		_update_scene_buffers_request()
	_update_shader_params()


func _process(_delta: float) -> void:
	# Poll for buffer type changes every frame
	if not scene_buffers or not _material:
		return

	var current_buffer := int(scene_buffers.active_buffer)
	if current_buffer != _last_buffer_type:
		_last_buffer_type = current_buffer
		_update_shader_params()


func _setup_overlay() -> void:
	# Create the ColorRect that will display the effect
	_color_rect = ColorRect.new()
	_color_rect.name = "DitherRect"
	_color_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_color_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_color_rect.visible = effect_enabled

	# Create the shader material
	_material = ShaderMaterial.new()
	_material.shader = DITHER_SHADER
	_color_rect.material = _material

	add_child(_color_rect)


func _update_shader_params() -> void:
	if not _material:
		return

	if dither_pattern:
		_material.set_shader_parameter("u_dither_tex", dither_pattern)

	if color_palette:
		_material.set_shader_parameter("u_color_tex", color_palette)

	_material.set_shader_parameter("u_bit_depth", bit_depth)
	_material.set_shader_parameter("u_contrast", contrast)
	_material.set_shader_parameter("u_offset", lum_offset)
	_material.set_shader_parameter("u_dither_size", dither_size)
	_material.set_shader_parameter("u_mix", color_mix)
	_material.set_shader_parameter("u_blend_mode", blend_mode)

	# Get buffer texture if SceneBuffers is rendering something
	var buffer_tex: ViewportTexture = null
	if scene_buffers:
		buffer_tex = scene_buffers.get_buffer_texture()

	# World-space dithering (when WORLD_POSITION buffer is set)
	var use_world_dither := dither_buffer == SceneBuffers.BufferType.WORLD_POSITION and buffer_tex != null
	_material.set_shader_parameter("u_world_dither", use_world_dither)
	_material.set_shader_parameter("u_world_dither_scale", world_dither_scale)
	_material.set_shader_parameter("u_world_dither_projection", world_dither_projection)
	_material.set_shader_parameter("u_world_pos_tex", buffer_tex)


## Called when SceneBuffers changes its active buffer type.
func _on_buffer_changed(_new_buffer: SceneBuffers.BufferType) -> void:
	_last_buffer_type = int(_new_buffer)
	_update_shader_params()


## Tell SceneBuffers which buffer we need for dithering.
func _update_scene_buffers_request() -> void:
	if scene_buffers:
		scene_buffers.requested_buffer = dither_buffer


## Set all parameters at once. Useful for transitions or presets.
func set_params(p_bit_depth: int = 32, p_contrast: float = 1.0, p_lum_offset: float = 0.0, p_dither_size: int = 2) -> void:
	bit_depth = p_bit_depth
	contrast = p_contrast
	lum_offset = p_lum_offset
	dither_size = p_dither_size


## Cycle to the next pattern preset.
func next_pattern() -> void:
	var next := (pattern_preset + 1) % DitherPattern.CUSTOM
	pattern_preset = next as DitherPattern


## Cycle to the next palette preset.
func next_palette() -> void:
	var next := (palette_preset + 1) % PalettePreset.CUSTOM
	palette_preset = next as PalettePreset


## Toggle world-space dithering on/off.
func toggle_world_dither() -> void:
	if dither_buffer == SceneBuffers.BufferType.NONE:
		dither_buffer = SceneBuffers.BufferType.WORLD_POSITION
	else:
		dither_buffer = SceneBuffers.BufferType.NONE
