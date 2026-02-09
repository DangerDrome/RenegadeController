@tool
class_name WorldSpaceDither
extends Node3D
## World-space dithering effect using fullscreen quad with spatial shader.
##
## This node creates a fullscreen quad that renders a dither effect where the
## pattern is locked to world geometry (like Obra Dinn) rather than the screen.
## Must be added as a child of your Camera3D for proper rendering.
##
## Usage:
## 1. Add WorldSpaceDither as a child of your Camera3D
## 2. Configure dither_pattern and color_palette textures
## 3. Adjust world_scale to control pattern size in world units

const WORLD_DITHER_SHADER := preload("res://addons/dither_shader/src/world_dither.gdshader")

## Built-in dither pattern presets
enum DitherPattern { BAYER_16X16, BAYER_8X8, BAYER_4X4, BAYER_2X2, BLUE_NOISE, CUSTOM }

## Built-in palette presets
enum PalettePreset { MONO, MOONLIGHT, EEVEE, HOLLOW, RISING_SUN, CUSTOM }

## Projection mode for dither pattern
enum ProjectionMode { XZ_FLOORS, XY_Z_WALLS, YZ_X_WALLS, AUTO }

const PATTERNS := {
	DitherPattern.BAYER_16X16: preload("res://addons/dither_shader/assets/patterns/bayer16tile2.png"),
	DitherPattern.BAYER_8X8: preload("res://addons/dither_shader/assets/patterns/bayer8tile4.png"),
	DitherPattern.BAYER_4X4: preload("res://addons/dither_shader/assets/patterns/bayer4tile8.png"),
	DitherPattern.BAYER_2X2: preload("res://addons/dither_shader/assets/patterns/bayer2tile16.png"),
	DitherPattern.BLUE_NOISE: preload("res://addons/dither_shader/assets/patterns/blue_noise.png"),
}

const PALETTES := {
	PalettePreset.MONO: preload("res://addons/dither_shader/assets/palettes/palette_mono.png"),
	PalettePreset.MOONLIGHT: preload("res://addons/dither_shader/assets/palettes/palette_moonlight.png"),
	PalettePreset.EEVEE: preload("res://addons/dither_shader/assets/palettes/palette_eeve.png"),
	PalettePreset.HOLLOW: preload("res://addons/dither_shader/assets/palettes/palette_hollow.png"),
	PalettePreset.RISING_SUN: preload("res://addons/dither_shader/assets/palettes/palette_rising_sun.png"),
}

@export_group("Textures")

## Select a built-in dither pattern preset.
@export var pattern_preset: DitherPattern = DitherPattern.BAYER_8X8:
	set(value):
		pattern_preset = value
		if value != DitherPattern.CUSTOM and PATTERNS.has(value):
			dither_pattern = PATTERNS[value]

## Custom dither pattern texture (grayscale threshold map).
@export var dither_pattern: Texture2D:
	set(value):
		dither_pattern = value
		_update_shader()

## Select a built-in color palette preset.
@export var palette_preset: PalettePreset = PalettePreset.MONO:
	set(value):
		palette_preset = value
		if value != PalettePreset.CUSTOM and PALETTES.has(value):
			color_palette = PALETTES[value]

## Custom color palette texture (horizontal gradient).
@export var color_palette: Texture2D:
	set(value):
		color_palette = value
		_update_shader()

@export_group("Dither Settings")

## Number of colors/bands in the output (lower = more banded).
@export_range(2, 64) var bit_depth: int = 32:
	set(value):
		bit_depth = value
		_update_shader()

## Contrast adjustment for luminance calculation.
@export_range(0.0, 5.0, 0.1) var contrast: float = 1.0:
	set(value):
		contrast = value
		_update_shader()

## Luminance offset (shifts the threshold).
@export_range(-1.0, 1.0, 0.05) var lum_offset: float = 0.0:
	set(value):
		lum_offset = value
		_update_shader()

## Pixel size of the dither effect (1 = native res, higher = more pixelated).
@export_range(1, 8) var dither_size: int = 2:
	set(value):
		dither_size = value
		_update_shader()

## Mix between original scene (0) and dithered result (1).
@export_range(0.0, 1.0, 0.05) var color_mix: float = 1.0:
	set(value):
		color_mix = value
		_update_shader()

@export_group("World-Space Settings")

## Size of the dither pattern in world units. Larger = bigger pattern.
@export_range(0.5, 50.0, 0.5) var world_scale: float = 5.0:
	set(value):
		world_scale = value
		_update_shader()

## How to project the dither pattern onto surfaces.
@export var projection_mode: ProjectionMode = ProjectionMode.AUTO:
	set(value):
		projection_mode = value
		_update_shader()

@export_group("Effect Control")

## Enable or disable the effect.
@export var effect_enabled: bool = true:
	set(value):
		effect_enabled = value
		if _quad:
			_quad.visible = value

var _quad: MeshInstance3D
var _material: ShaderMaterial


func _ready() -> void:
	_setup_fullscreen_quad()
	# Apply presets if textures not set
	if not dither_pattern and PATTERNS.has(pattern_preset):
		dither_pattern = PATTERNS[pattern_preset]
	if not color_palette and PALETTES.has(palette_preset):
		color_palette = PALETTES[palette_preset]
	_update_shader()


func _setup_fullscreen_quad() -> void:
	# Create the fullscreen quad mesh
	_quad = MeshInstance3D.new()
	_quad.name = "DitherQuad"
	
	var mesh := QuadMesh.new()
	mesh.size = Vector2(2.0, 2.0)
	mesh.orientation = PlaneMesh.FACE_Z
	mesh.flip_faces = true  # Face the camera
	_quad.mesh = mesh
	
	# Create material with world dither shader
	_material = ShaderMaterial.new()
	_material.shader = WORLD_DITHER_SHADER
	_material.render_priority = 127  # Render last
	_quad.material_override = _material
	
	# Disable shadows and GI
	_quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_quad.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	
	# Set huge cull margin so it's never culled
	_quad.extra_cull_margin = 16384.0
	
	_quad.visible = effect_enabled
	add_child(_quad)


func _update_shader() -> void:
	if not _material:
		return
	
	if dither_pattern:
		_material.set_shader_parameter("dither_texture", dither_pattern)
	if color_palette:
		_material.set_shader_parameter("palette_texture", color_palette)
	
	_material.set_shader_parameter("bit_depth", bit_depth)
	_material.set_shader_parameter("contrast", contrast)
	_material.set_shader_parameter("lum_offset", lum_offset)
	_material.set_shader_parameter("dither_size", dither_size)
	_material.set_shader_parameter("color_mix", color_mix)
	_material.set_shader_parameter("world_scale", world_scale)
	_material.set_shader_parameter("projection_mode", projection_mode)


## Toggle the effect on/off.
func toggle() -> void:
	effect_enabled = not effect_enabled


## Cycle to the next pattern preset.
func next_pattern() -> void:
	var next := (pattern_preset + 1) % DitherPattern.CUSTOM
	pattern_preset = next as DitherPattern


## Cycle to the next palette preset.
func next_palette() -> void:
	var next := (palette_preset + 1) % PalettePreset.CUSTOM
	palette_preset = next as PalettePreset


## Cycle to the next projection mode.
func next_projection() -> void:
	var next := (projection_mode + 1) % 4
	projection_mode = next as ProjectionMode
