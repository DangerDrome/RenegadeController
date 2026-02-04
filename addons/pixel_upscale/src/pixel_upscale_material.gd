@tool
class_name PixelUpscaleMaterial
extends SubViewportContainer
## Applies pixel-perfect upscaling shader to a SubViewportContainer.
##
## Attach this script to your existing SubViewportContainer to get
## crisp pixel art scaling with adjustable settings in the inspector.

const UPSCALE_SHADER := preload("res://addons/pixel_upscale/src/pixel_upscale.gdshader")

@export_group("Pixel Upscale")

## Enable or disable the upscale effect.
@export var effect_enabled: bool = true:
	set(value):
		effect_enabled = value
		_update_material()

## Sharpness of the upscale filter. 1.0 = crisp pixels, 0.0 = bilinear blur.
@export_range(0.0, 1.0, 0.01) var sharpness: float = 1.0:
	set(value):
		sharpness = value
		_update_shader_params()

var _material: ShaderMaterial


func _ready() -> void:
	_setup_material()


func _setup_material() -> void:
	# Check if we already have a shader material
	if material is ShaderMaterial and material.shader == UPSCALE_SHADER:
		_material = material as ShaderMaterial
	else:
		_material = ShaderMaterial.new()
		_material.shader = UPSCALE_SHADER

	_update_material()
	_update_shader_params()


func _update_material() -> void:
	if effect_enabled:
		material = _material
		# Shader needs linear filtering to do its smart subpixel sampling
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	else:
		material = null
		# Without shader, use nearest for crisp pixels
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _update_shader_params() -> void:
	if _material:
		_material.set_shader_parameter("sharpness", sharpness)
