@tool
class_name SceneBuffers
extends Node3D
## Captures scene buffers (depth, normals, etc.) to ViewportTextures for post-processing.
##
## This creates a viewport that mirrors the main camera and renders
## various scene buffers. The texture can be used by canvas_item shaders
## for effects like dithering, outlines, fog, SSAO, etc.
##
## Usage:
## 1. Add SceneBuffers to your scene (sibling of your camera)
## 2. Set source_camera to your main Camera3D
## 3. Select active_buffer from the dropdown
## 4. Call get_buffer_texture() for your shader

const BUFFER_SHADER := preload("res://addons/dither_shader/src/scene_buffers.gdshader")

## Emitted when the active buffer type changes.
signal buffer_changed(new_buffer: BufferType)

## Available buffer types to capture.
enum BufferType {
	NONE,            ## Disabled - no buffer capture
	DEPTH,           ## Linear depth (black=near, white=far)
	DEPTH_INVERTED,  ## Linear depth inverted (white=near, black=far)
	NORMALS,         ## World-space normals (RGB mapped 0-1)
	NORMALS_RAW,     ## View-space normals (raw values)
	WORLD_POSITION,  ## World-space position (RGB = XYZ)
}

@export_group("Setup")

## The camera to mirror for buffer capture.
@export var source_camera: Camera3D:
	set(value):
		source_camera = value
		# Initialize viewport when camera is assigned
		if is_inside_tree() and _viewport:
			_update_viewport_size()

## Which buffer to capture. Only one buffer is active at a time.
@export var active_buffer: BufferType = BufferType.DEPTH:
	set(value):
		if active_buffer == value:
			return
		active_buffer = value
		_update_viewport_enabled()
		_update_shader_params()
		buffer_changed.emit(value)

@export_group("Depth Settings")

## Maximum depth distance for normalization.
@export_range(1.0, 500.0, 1.0) var max_depth: float = 100.0:
	set(value):
		max_depth = value
		_update_shader_params()

## Curve for remapping depth values. X=input depth (0-1), Y=output (0-1).
@export var depth_curve: Curve:
	set(value):
		depth_curve = value
		_update_curve_texture()

@export_group("Advanced")

## Resolution divisor (1 = full, 2 = half, etc.)
@export_range(1, 4) var resolution_divisor: int = 1:
	set(value):
		resolution_divisor = value
		_update_viewport_size()

var _viewport: SubViewport
var _camera: Camera3D
var _quad: MeshInstance3D
var _material: ShaderMaterial
var _curve_texture: CurveTexture


## Returns the buffer texture for use with shaders.
## Returns null if active_buffer is NONE.
func get_buffer_texture() -> ViewportTexture:
	if _viewport and active_buffer != BufferType.NONE:
		return _viewport.get_texture()
	return null


## Convenience method - returns depth texture if a depth buffer is active.
func get_depth_texture() -> ViewportTexture:
	if active_buffer == BufferType.DEPTH or active_buffer == BufferType.DEPTH_INVERTED:
		return get_buffer_texture()
	return null


## Convenience method - returns normal texture if a normal buffer is active.
func get_normal_texture() -> ViewportTexture:
	if active_buffer == BufferType.NORMALS or active_buffer == BufferType.NORMALS_RAW:
		return get_buffer_texture()
	return null


## Cycle to the next buffer type.
func next_buffer() -> void:
	var next := (active_buffer + 1) % BufferType.size()
	active_buffer = next as BufferType


## Cycle to the previous buffer type.
func prev_buffer() -> void:
	var prev := (active_buffer - 1) if active_buffer > 0 else BufferType.size() - 1
	active_buffer = prev as BufferType


func _ready() -> void:
	_setup_buffer_viewport()
	_update_curve_texture()
	# Initialize viewport size and world_3d immediately if source_camera is already set
	if source_camera:
		call_deferred("_update_viewport_size")


func _process(_delta: float) -> void:
	if active_buffer == BufferType.NONE or not source_camera:
		return

	# Mirror the source camera's transform and projection
	if _camera:
		_camera.global_transform = source_camera.global_transform
		_camera.fov = source_camera.fov
		_camera.near = source_camera.near
		_camera.far = source_camera.far
		_camera.projection = source_camera.projection

	_update_viewport_size()


func _setup_buffer_viewport() -> void:
	# Create SubViewport
	_viewport = SubViewport.new()
	_viewport.name = "BufferViewport"
	_viewport.transparent_bg = false
	_viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	_viewport.msaa_3d = Viewport.MSAA_DISABLED
	_viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	_viewport.use_occlusion_culling = false
	_viewport.positional_shadow_atlas_size = 0
	_viewport.snap_2d_transforms_to_pixel = false
	_viewport.snap_2d_vertices_to_pixel = false
	_viewport.use_hdr_2d = true  # Higher precision for depth values
	add_child(_viewport)

	# Create camera
	_camera = Camera3D.new()
	_camera.name = "BufferCamera"
	_camera.current = false
	_viewport.add_child(_camera)

	# Create full-screen quad with buffer shader
	_quad = MeshInstance3D.new()
	_quad.name = "BufferQuad"

	var quad := QuadMesh.new()
	quad.size = Vector2(2.0, 2.0)
	quad.orientation = PlaneMesh.FACE_Z
	_quad.mesh = quad

	_material = ShaderMaterial.new()
	_material.shader = BUFFER_SHADER
	_material.render_priority = 127
	_quad.material_override = _material

	_quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_quad.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	_quad.position = Vector3(0, 0, -1.0)

	_camera.add_child(_quad)

	_update_viewport_enabled()
	_update_shader_params()


func _update_viewport_enabled() -> void:
	var is_active := active_buffer != BufferType.NONE
	if _viewport:
		_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if is_active else SubViewport.UPDATE_DISABLED
	if _quad:
		_quad.visible = is_active


func _update_viewport_size() -> void:
	if not source_camera or not _viewport:
		return

	var source_viewport := source_camera.get_viewport()
	if not source_viewport:
		return

	var size := source_viewport.get_visible_rect().size
	var target_size := Vector2i(size) / resolution_divisor

	_viewport.size = target_size
	if source_viewport is SubViewport:
		_viewport.world_3d = source_viewport.world_3d
	elif source_viewport.world_3d:
		_viewport.world_3d = source_viewport.world_3d


func _update_shader_params() -> void:
	if not _material:
		return

	# Map our enum to shader buffer_mode (shader expects 0-3, we have NONE=0 so subtract 1)
	var shader_mode := maxi(0, active_buffer - 1)
	_material.set_shader_parameter("buffer_mode", shader_mode)
	_material.set_shader_parameter("max_depth", max_depth)
	_material.set_shader_parameter("use_curve", depth_curve != null)
	if _curve_texture:
		_material.set_shader_parameter("depth_curve", _curve_texture)


func _update_curve_texture() -> void:
	if depth_curve:
		_curve_texture = CurveTexture.new()
		_curve_texture.curve = depth_curve
	else:
		_curve_texture = null
	_update_shader_params()
