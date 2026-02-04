@tool
class_name OutlineSetup
extends Node
## Automatic pixel-perfect outlines using depth + normal edge detection.
## Works with Compatibility renderer via dual-viewport technique.
##
## Setup:
## 1. Add this node to your scene
## 2. Set source_camera to your Camera3D  
## 3. Apply OutlineMaterial to your meshes OR use auto_setup_materials
## 4. Set mesh layers to include both layer 1 AND layer 5

signal setup_completed

const MAIN_CULL_MASK := 1          # Layer 1
const OUTLINE_CULL_MASK := 16      # Layer 5

@export_group("Setup")
@export var auto_setup: bool = true
@export var source_camera: Camera3D:
	set(v):
		source_camera = v
		if Engine.is_editor_hint():
			update_configuration_warnings()

@export var auto_setup_materials: bool = false:  ## Auto-add outline data pass to all MeshInstance3D
	set(v):
		auto_setup_materials = v

@export_group("Outline Appearance")
@export var outline_color: Color = Color.BLACK:
	set(v):
		outline_color = v
		_update_shader_params()

@export_range(0.5, 10.0, 0.5) var outline_width: float = 1.0:
	set(v):
		outline_width = v
		_update_shader_params()

@export var outline_active: bool = true:
	set(v):
		outline_active = v
		_update_shader_params()

@export_group("Edge Detection")
@export_range(0.0, 0.1, 0.001) var depth_threshold: float = 0.008:  ## Sensitivity for depth edges
	set(v):
		depth_threshold = v
		_update_shader_params()

@export_range(0.0, 1.0, 0.01) var normal_threshold: float = 0.3:  ## Sensitivity for normal edges
	set(v):
		normal_threshold = v
		_update_shader_params()

@export_group("Style")
@export_range(0.0, 1.0, 0.01) var line_highlight: float = 0.15:  ## Brightening on surface edges
	set(v):
		line_highlight = v
		_update_shader_params()

@export_range(0.0, 1.0, 0.01) var line_shadow: float = 0.4:  ## Darkening on depth edges
	set(v):
		line_shadow = v
		_update_shader_params()

@export_group("Viewport")
@export var viewport_size: Vector2i = Vector2i(640, 360):  ## Base resolution for pixel art
	set(v):
		viewport_size = v
		_update_viewport_size()

@export var use_window_size: bool = true:
	set(v):
		use_window_size = v
		_update_viewport_size()

@export var stretch_mode: bool = true:
	set(v):
		stretch_mode = v
		_update_stretch_mode()

var _main_viewport: SubViewport
var _outline_viewport: SubViewport
var _main_camera: Camera3D
var _outline_camera: Camera3D
var _canvas_layer: CanvasLayer
var _main_texture_rect: TextureRect
var _outline_texture_rect: TextureRect
var _outline_material: ShaderMaterial
var _is_setup := false
var _processed_meshes: Array[MeshInstance3D] = []


func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if not source_camera:
		warnings.append("Source Camera not set. Assign a Camera3D to copy settings from.")
	return warnings


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	if auto_setup:
		setup.call_deferred()


func _process(_delta: float) -> void:
	if Engine.is_editor_hint() or not _is_setup:
		return
	_sync_cameras()


func _sync_cameras() -> void:
	if not source_camera or not _main_camera or not _outline_camera:
		return
	
	_main_camera.global_transform = source_camera.global_transform
	_outline_camera.global_transform = source_camera.global_transform
	_main_camera.fov = source_camera.fov
	_outline_camera.fov = source_camera.fov
	_main_camera.near = source_camera.near
	_outline_camera.near = source_camera.near
	_main_camera.far = source_camera.far
	_outline_camera.far = source_camera.far
	_main_camera.projection = source_camera.projection
	_outline_camera.projection = source_camera.projection
	
	if source_camera.projection == Camera3D.PROJECTION_ORTHOGONAL:
		_main_camera.size = source_camera.size
		_outline_camera.size = source_camera.size


func setup() -> void:
	if _is_setup:
		return
	if not source_camera:
		push_error("OutlineSetup: No source camera assigned!")
		return
	
	_create_viewports()
	_create_canvas_layer()
	
	if auto_setup_materials:
		_auto_setup_all_materials()
	
	_is_setup = true
	source_camera.current = false
	
	setup_completed.emit()
	print("OutlineSetup: Initialized with depth+normal edge detection")


func teardown() -> void:
	if not _is_setup:
		return

	# Disconnect window resize signal
	if get_tree() and get_tree().root.size_changed.is_connected(_on_window_resized):
		get_tree().root.size_changed.disconnect(_on_window_resized)

	# Restore materials
	for mesh in _processed_meshes:
		if is_instance_valid(mesh):
			_remove_data_pass(mesh)
	_processed_meshes.clear()

	if _canvas_layer:
		_canvas_layer.queue_free()
	if _main_viewport:
		_main_viewport.queue_free()
	if _outline_viewport:
		_outline_viewport.queue_free()

	_canvas_layer = null
	_main_viewport = null
	_outline_viewport = null
	_main_camera = null
	_outline_camera = null
	_main_texture_rect = null
	_outline_texture_rect = null
	_outline_material = null
	_is_setup = false


func _create_viewports() -> void:
	var size := _get_viewport_size()
	var scene_world := source_camera.get_viewport().world_3d

	# Main viewport - shares the scene's world_3d
	_main_viewport = SubViewport.new()
	_main_viewport.name = "MainViewport"
	_main_viewport.size = size
	_main_viewport.world_3d = scene_world
	_main_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_main_viewport.transparent_bg = true
	_main_viewport.handle_input_locally = false
	_main_viewport.msaa_3d = Viewport.MSAA_DISABLED
	add_child(_main_viewport)

	_main_camera = Camera3D.new()
	_main_camera.name = "MainCamera"
	_main_camera.cull_mask = MAIN_CULL_MASK
	_main_camera.current = true
	_main_viewport.add_child(_main_camera)

	# Outline data viewport - shares the scene's world_3d
	_outline_viewport = SubViewport.new()
	_outline_viewport.name = "OutlineViewport"
	_outline_viewport.size = size
	_outline_viewport.world_3d = scene_world
	_outline_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_outline_viewport.transparent_bg = true
	_outline_viewport.handle_input_locally = false
	_outline_viewport.msaa_3d = Viewport.MSAA_DISABLED
	add_child(_outline_viewport)

	_outline_camera = Camera3D.new()
	_outline_camera.name = "OutlineCamera"
	_outline_camera.cull_mask = OUTLINE_CULL_MASK
	_outline_camera.current = true
	_outline_viewport.add_child(_outline_camera)

	# Connect to window resize
	get_tree().root.size_changed.connect(_on_window_resized)


func _create_canvas_layer() -> void:
	_canvas_layer = CanvasLayer.new()
	_canvas_layer.name = "OutlineCanvasLayer"
	_canvas_layer.layer = 100
	add_child(_canvas_layer)
	
	# Main scene texture
	_main_texture_rect = TextureRect.new()
	_main_texture_rect.name = "MainView"
	_main_texture_rect.texture = _main_viewport.get_texture()
	_main_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED if stretch_mode else TextureRect.STRETCH_SCALE
	_main_texture_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas_layer.add_child(_main_texture_rect)
	
	# Outline texture with shader
	_outline_texture_rect = TextureRect.new()
	_outline_texture_rect.name = "OutlineView"
	_outline_texture_rect.texture = _outline_viewport.get_texture()
	_outline_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED if stretch_mode else TextureRect.STRETCH_SCALE
	_outline_texture_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas_layer.add_child(_outline_texture_rect)
	
	_outline_material = ShaderMaterial.new()
	_outline_material.shader = preload("res://addons/pixel_outline/outline_post_process.gdshader")
	_outline_texture_rect.material = _outline_material
	_update_shader_params()


func _update_shader_params() -> void:
	if not _outline_material:
		return
	_outline_material.set_shader_parameter("outline_color", outline_color)
	_outline_material.set_shader_parameter("outline_width", outline_width)
	_outline_material.set_shader_parameter("active", outline_active)
	_outline_material.set_shader_parameter("depth_threshold", depth_threshold)
	_outline_material.set_shader_parameter("normal_threshold", normal_threshold)
	_outline_material.set_shader_parameter("line_highlight", line_highlight)
	_outline_material.set_shader_parameter("line_shadow", line_shadow)


func _get_viewport_size() -> Vector2i:
	if use_window_size:
		return get_viewport().size if get_viewport() else viewport_size
	return viewport_size


func _update_viewport_size() -> void:
	if not _is_setup:
		return
	var size := _get_viewport_size()
	if _main_viewport:
		_main_viewport.size = size
	if _outline_viewport:
		_outline_viewport.size = size


func _update_stretch_mode() -> void:
	if not _is_setup:
		return
	var mode := TextureRect.STRETCH_KEEP_ASPECT_COVERED if stretch_mode else TextureRect.STRETCH_SCALE
	if _main_texture_rect:
		_main_texture_rect.stretch_mode = mode
	if _outline_texture_rect:
		_outline_texture_rect.stretch_mode = mode


func _on_window_resized() -> void:
	if use_window_size:
		_update_viewport_size()


## Auto-setup materials on all MeshInstance3D in the scene tree
func _auto_setup_all_materials() -> void:
	var root := get_tree().root
	_process_node_recursive(root)


func _process_node_recursive(node: Node) -> void:
	if node is MeshInstance3D:
		setup_mesh_for_outlines(node)
	for child in node.get_children():
		_process_node_recursive(child)


## Configure a mesh for outline rendering
func setup_mesh_for_outlines(mesh: MeshInstance3D) -> void:
	# Set visibility layers
	mesh.layers = MAIN_CULL_MASK | OUTLINE_CULL_MASK
	
	# Add data pass material
	_add_data_pass(mesh)
	
	if mesh not in _processed_meshes:
		_processed_meshes.append(mesh)


func _add_data_pass(mesh: MeshInstance3D) -> void:
	var surface_count := mesh.mesh.get_surface_count() if mesh.mesh else 0
	
	for i in range(surface_count):
		var mat := mesh.get_surface_override_material(i)
		if not mat:
			mat = mesh.mesh.surface_get_material(i)
		
		if mat:
			# Check if already has data pass
			if mat.next_pass and mat.next_pass.shader == preload("res://addons/pixel_outline/outline_data_pass.gdshader"):
				continue
			
			# Add data pass as next_pass
			var data_mat := ShaderMaterial.new()
			data_mat.shader = preload("res://addons/pixel_outline/outline_data_pass.gdshader")
			mat.next_pass = data_mat
		else:
			# No material - create one with data pass
			var new_mat := StandardMaterial3D.new()
			var data_mat := ShaderMaterial.new()
			data_mat.shader = preload("res://addons/pixel_outline/outline_data_pass.gdshader")
			new_mat.next_pass = data_mat
			mesh.set_surface_override_material(i, new_mat)


func _remove_data_pass(mesh: MeshInstance3D) -> void:
	var surface_count := mesh.mesh.get_surface_count() if mesh.mesh else 0
	
	for i in range(surface_count):
		var mat := mesh.get_surface_override_material(i)
		if mat and mat.next_pass:
			if mat.next_pass.shader == preload("res://addons/pixel_outline/outline_data_pass.gdshader"):
				mat.next_pass = null
