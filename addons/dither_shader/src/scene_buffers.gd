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
		# Restore old camera's cull_mask if we had one
		if source_camera:
			source_camera.cull_mask |= (1 << 19)  # Re-enable layer 20
		source_camera = value
		# Make sure source camera doesn't see our buffer quad (layer 20)
		if source_camera:
			source_camera.cull_mask &= ~(1 << 19)  # Disable layer 20
		# Initialize viewport when camera is assigned
		if is_inside_tree() and _viewport:
			_update_viewport_size()

## Which buffer to show for visualization/debugging. Set to NONE to hide.
@export var active_buffer: BufferType = BufferType.NONE:
	set(value):
		if active_buffer == value:
			return
		active_buffer = value
		_update_viewport_enabled()
		_update_shader_params()
		buffer_changed.emit(value)

## Buffer requested by DitherOverlay for world-space effects. Internal use.
var requested_buffer: BufferType = BufferType.NONE:
	set(value):
		if requested_buffer == value:
			return
		requested_buffer = value
		_update_viewport_enabled()
		_update_shader_params()

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

@export_group("World Position Settings")

## World position encoding range. Positions from -world_range to +world_range are encoded.
## Increase this if your scene is larger than the default 100 unit range.
@export_range(10.0, 1000.0, 10.0) var world_range: float = 100.0:
	set(value):
		world_range = value
		_update_shader_params()

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

# Second viewport for normals (used for triplanar dithering)
var _normal_viewport: SubViewport
var _normal_camera: Camera3D
var _normal_quad: MeshInstance3D
var _normal_material: ShaderMaterial


## Returns the buffer texture for use with shaders.
## Returns null if no buffer is being rendered.
func get_buffer_texture() -> ViewportTexture:
	if _viewport and _get_effective_buffer() != BufferType.NONE:
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


## Returns the normals texture for triplanar dithering.
## This is separate from the main buffer and renders when WORLD_POSITION is active.
func get_triplanar_normal_texture() -> ViewportTexture:
	if _normal_viewport and _get_effective_buffer() == BufferType.WORLD_POSITION:
		return _normal_viewport.get_texture()
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
	# Use effective buffer (includes requested_buffer from DitherOverlay)
	if _get_effective_buffer() == BufferType.NONE or not source_camera:
		return

	# Mirror the source camera's transform and projection
	if _camera:
		_camera.global_transform = source_camera.global_transform
		_camera.fov = source_camera.fov
		_camera.near = source_camera.near
		_camera.far = source_camera.far
		_camera.projection = source_camera.projection

	# Also update normal camera if active
	if _normal_camera and _get_effective_buffer() == BufferType.WORLD_POSITION:
		_normal_camera.global_transform = source_camera.global_transform
		_normal_camera.fov = source_camera.fov
		_normal_camera.near = source_camera.near
		_normal_camera.far = source_camera.far
		_normal_camera.projection = source_camera.projection

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
	_viewport.use_hdr_2d = true

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
	# Use layer 20 so main camera doesn't see it
	_quad.layers = 1 << 19

	_camera.add_child(_quad)
	# Buffer camera sees layer 20 + layer 1 (scene)
	_camera.cull_mask = (1 << 19) | 1

	# Add viewport to tree root instead of as child of this node
	# This fully isolates it from the main 3D scene
	# Always defer to avoid "busy setting up children" error
	get_tree().root.call_deferred("add_child", _viewport)

	# Create second viewport for normals (used for triplanar dithering)
	_setup_normal_viewport()

	_update_viewport_enabled()
	_update_shader_params()


func _setup_normal_viewport() -> void:
	# Create SubViewport for normals
	_normal_viewport = SubViewport.new()
	_normal_viewport.name = "NormalBufferViewport"
	_normal_viewport.transparent_bg = false
	_normal_viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	_normal_viewport.msaa_3d = Viewport.MSAA_DISABLED
	_normal_viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	_normal_viewport.use_occlusion_culling = false
	_normal_viewport.positional_shadow_atlas_size = 0
	_normal_viewport.snap_2d_transforms_to_pixel = false
	_normal_viewport.snap_2d_vertices_to_pixel = false
	_normal_viewport.use_hdr_2d = true

	# Create camera
	_normal_camera = Camera3D.new()
	_normal_camera.name = "NormalBufferCamera"
	_normal_camera.current = false
	_normal_viewport.add_child(_normal_camera)

	# Create full-screen quad with buffer shader set to normals mode
	_normal_quad = MeshInstance3D.new()
	_normal_quad.name = "NormalBufferQuad"

	var quad := QuadMesh.new()
	quad.size = Vector2(2.0, 2.0)
	quad.orientation = PlaneMesh.FACE_Z
	_normal_quad.mesh = quad

	_normal_material = ShaderMaterial.new()
	_normal_material.shader = BUFFER_SHADER
	_normal_material.render_priority = 127
	# Set to NORMALS mode (buffer_mode 2 = world-space normals mapped 0-1)
	_normal_material.set_shader_parameter("buffer_mode", 2)
	_normal_material.set_shader_parameter("max_depth", max_depth)
	_normal_quad.material_override = _normal_material

	_normal_quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_normal_quad.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	_normal_quad.position = Vector3(0, 0, -1.0)
	# Use layer 20 so main camera doesn't see it
	_normal_quad.layers = 1 << 19

	_normal_camera.add_child(_normal_quad)
	_normal_camera.cull_mask = (1 << 19) | 1

	get_tree().root.call_deferred("add_child", _normal_viewport)


func _exit_tree() -> void:
	# Restore source camera's cull_mask
	if source_camera:
		source_camera.cull_mask |= (1 << 19)  # Re-enable layer 20
	# Clean up viewport from root when this node is removed
	if _viewport and _viewport.is_inside_tree():
		_viewport.get_parent().remove_child(_viewport)
		_viewport.queue_free()
	# Clean up normal viewport
	if _normal_viewport and _normal_viewport.is_inside_tree():
		_normal_viewport.get_parent().remove_child(_normal_viewport)
		_normal_viewport.queue_free()


func _update_viewport_enabled() -> void:
	# Render if either visualization or dither needs a buffer
	var effective_buffer := _get_effective_buffer()
	var should_render := effective_buffer != BufferType.NONE

	if _viewport:
		_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if should_render else SubViewport.UPDATE_DISABLED
	# Quad must always be visible when rendering - it's what draws the buffer!
	# The viewport itself is internal, user doesn't see it directly
	if _quad:
		_quad.visible = should_render

	# Normal viewport only renders when WORLD_POSITION is active (for triplanar)
	var should_render_normals := effective_buffer == BufferType.WORLD_POSITION
	if _normal_viewport:
		_normal_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if should_render_normals else SubViewport.UPDATE_DISABLED
	if _normal_quad:
		_normal_quad.visible = should_render_normals


## Returns the buffer that should actually be rendered (requested_buffer takes priority if set).
func _get_effective_buffer() -> BufferType:
	if requested_buffer != BufferType.NONE:
		return requested_buffer
	return active_buffer


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

	# Also update normal viewport
	if _normal_viewport:
		_normal_viewport.size = target_size
		if source_viewport is SubViewport:
			_normal_viewport.world_3d = source_viewport.world_3d
		elif source_viewport.world_3d:
			_normal_viewport.world_3d = source_viewport.world_3d


func _update_shader_params() -> void:
	if not _material:
		return

	# Use effective buffer (requested_buffer takes priority)
	var effective := _get_effective_buffer()
	# Map our enum to shader buffer_mode (shader expects 0-4, we have NONE=0 so subtract 1)
	var shader_mode := maxi(0, effective - 1)
	_material.set_shader_parameter("buffer_mode", shader_mode)
	_material.set_shader_parameter("max_depth", max_depth)
	_material.set_shader_parameter("world_range", world_range)
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
