@tool
class_name PixelUpscaleDisplay
extends SubViewportContainer
## A SubViewportContainer with pixel-perfect upscaling shader.
##
## This node renders its SubViewport contents with a smart pixel art filter
## that maintains crisp edges while allowing smooth subpixel camera movement.
## Just add your game scene as a child of the SubViewport inside this node.

const UPSCALE_SHADER := preload("res://addons/pixel_upscale/src/pixel_upscale.gdshader")

## The internal resolution width. Set to 0 to match window size (no downscaling).
@export var internal_width: int = 480:
	set(value):
		internal_width = value
		_update_viewport_size()

## The internal resolution height. Set to 0 to match window size (no downscaling).
@export var internal_height: int = 270:
	set(value):
		internal_height = value
		_update_viewport_size()

@export_group("Upscale Settings")

## Sharpness of the upscale filter. 1.0 = crisp pixels, 0.0 = bilinear blur.
@export_range(0.0, 1.0, 0.01) var sharpness: float = 1.0:
	set(value):
		sharpness = value
		_update_shader_params()

## Enable or disable the upscale effect.
@export var effect_enabled: bool = true:
	set(value):
		effect_enabled = value
		_update_shader_params()

@export_group("Viewport Settings")

## Enable 3D rendering in the SubViewport.
@export var enable_3d: bool = true:
	set(value):
		enable_3d = value
		if _viewport:
			_viewport.disable_3d = not value

## Enable transparent background.
@export var transparent_bg: bool = false:
	set(value):
		transparent_bg = value
		if _viewport:
			_viewport.transparent_bg = value

## MSAA setting for the SubViewport.
@export_enum("Disabled", "2x", "4x", "8x") var msaa: int = 0:
	set(value):
		msaa = value
		if _viewport:
			_viewport.msaa_3d = value as Viewport.MSAA

var _viewport: SubViewport
var _material: ShaderMaterial


func _ready() -> void:
	_setup_container()
	_setup_viewport()
	_setup_material()
	_update_viewport_size()
	_update_shader_params()

	# Connect to window resize
	if not Engine.is_editor_hint():
		get_tree().root.size_changed.connect(_on_window_resized)


func _setup_container() -> void:
	# Make container fill the screen
	set_anchors_preset(Control.PRESET_FULL_RECT)
	stretch = true
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _setup_viewport() -> void:
	# Find or create the SubViewport
	if get_child_count() > 0 and get_child(0) is SubViewport:
		_viewport = get_child(0) as SubViewport
	else:
		_viewport = SubViewport.new()
		_viewport.name = "SubViewport"
		add_child(_viewport)
		if Engine.is_editor_hint():
			_viewport.owner = get_tree().edited_scene_root

	_viewport.handle_input_locally = false
	_viewport.disable_3d = not enable_3d
	_viewport.transparent_bg = transparent_bg
	_viewport.msaa_3d = msaa as Viewport.MSAA
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS


func _setup_material() -> void:
	_material = ShaderMaterial.new()
	_material.shader = UPSCALE_SHADER
	material = _material


func _update_viewport_size() -> void:
	if not _viewport:
		return

	var target_width := internal_width if internal_width > 0 else int(get_viewport_rect().size.x)
	var target_height := internal_height if internal_height > 0 else int(get_viewport_rect().size.y)

	_viewport.size = Vector2i(target_width, target_height)


func _update_shader_params() -> void:
	if not _material:
		return

	if effect_enabled:
		_material.shader = UPSCALE_SHADER
		_material.set_shader_parameter("sharpness", sharpness)
	else:
		_material.shader = null


func _on_window_resized() -> void:
	if internal_width <= 0 or internal_height <= 0:
		_update_viewport_size()


## Get the SubViewport to add your scene content to.
func get_sub_viewport() -> SubViewport:
	return _viewport
