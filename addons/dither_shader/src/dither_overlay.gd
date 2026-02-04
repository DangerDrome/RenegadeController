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

@export_group("Overlay Settings")

## Enable or disable the dither effect at runtime.
@export var effect_enabled: bool = true:
	set(value):
		effect_enabled = value
		if _color_rect:
			_color_rect.visible = value

var _color_rect: ColorRect
var _material: ShaderMaterial


func _ready() -> void:
	_setup_overlay()
	# Apply presets on ready if textures not set
	if not dither_pattern and PATTERNS.has(pattern_preset):
		dither_pattern = PATTERNS[pattern_preset]
	if not color_palette and PALETTES.has(palette_preset):
		color_palette = PALETTES[palette_preset]
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
