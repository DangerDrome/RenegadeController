## 3D character turntable preview rendered inside a SubViewport.
## Handles mouse drag-to-rotate, scroll-to-zoom, and manages render update modes
## for performance. CassettePunk lighting: warm halogen key, green fluorescent fill,
## orange-pink rim light.
class_name TurntablePreview
extends SubViewportContainer

## Emitted when the user rotates the turntable (degrees of Y rotation applied).
signal rotated(degrees: float)
## Emitted when the user zooms (new zoom distance).
signal zoomed(distance: float)

@export_group("Rotation")
@export_range(0.1, 2.0) var rotation_sensitivity := 0.4
## Auto-rotate speed in degrees/second. Set to 0 to disable.
@export_range(0.0, 90.0) var auto_rotate_speed := 15.0

@export_group("Zoom")
@export_range(0.5, 5.0) var zoom_min := 1.5
@export_range(0.5, 10.0) var zoom_max := 4.0
@export_range(0.5, 5.0) var zoom_default := 2.5
@export_range(0.01, 0.5) var zoom_step := 0.15

## The Node3D that the character model should be instanced under.
## This node gets rotated by mouse drag.
@onready var _character_pivot: Node3D = %CharacterPivot
@onready var _camera: Camera3D = %Camera3D
@onready var _sub_viewport: SubViewport = %SubViewport

var _is_dragging := false
var _current_zoom := 2.5
var _character_model: Node3D


func _ready() -> void:
	_current_zoom = zoom_default
	if _camera:
		_camera.position.z = _current_zoom

	# Start with efficient update mode — only render when visible.
	if _sub_viewport:
		_sub_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE


func _process(delta: float) -> void:
	# Auto-rotate when not being dragged.
	if not _is_dragging and auto_rotate_speed > 0.0 and _character_pivot:
		_character_pivot.rotate_y(deg_to_rad(auto_rotate_speed * delta))


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_handle_mouse_button(event)
	elif event is InputEventMouseMotion and _is_dragging:
		_handle_mouse_drag(event)


## Instance a character model scene into the turntable pivot.
## Removes any previously loaded model.
func load_character(scene: PackedScene) -> Node3D:
	clear_character()
	if not scene:
		return null

	_character_model = scene.instantiate() as Node3D
	if _character_model and _character_pivot:
		_character_pivot.add_child(_character_model)
	return _character_model


## Load a character from an existing node (reparents it).
func load_character_node(model: Node3D) -> void:
	clear_character()
	if not model or not _character_pivot:
		return
	_character_model = model
	if model.get_parent():
		model.get_parent().remove_child(model)
	_character_pivot.add_child(model)


## Remove the current character model.
func clear_character() -> void:
	if _character_model and is_instance_valid(_character_model):
		_character_model.queue_free()
		_character_model = null


## Get the currently loaded character model.
func get_character_model() -> Node3D:
	return _character_model


## Find the Skeleton3D in the loaded character (searches first level children).
func find_skeleton() -> Skeleton3D:
	if not _character_model:
		return null
	# Check if the model itself is a Skeleton3D.
	if _character_model is Skeleton3D:
		return _character_model as Skeleton3D
	# Search children.
	for child in _character_model.get_children():
		if child is Skeleton3D:
			return child as Skeleton3D
		# One level deeper for common scene structures.
		for grandchild in child.get_children():
			if grandchild is Skeleton3D:
				return grandchild as Skeleton3D
	return null


## Reset rotation and zoom to defaults.
func reset_view() -> void:
	if _character_pivot:
		_character_pivot.rotation = Vector3.ZERO
	_current_zoom = zoom_default
	if _camera:
		_camera.position.z = _current_zoom


## Snap to a specific view angle (front=0, back=180, left=90, right=-90).
func snap_to_angle(degrees: float) -> void:
	if _character_pivot:
		_character_pivot.rotation.y = deg_to_rad(degrees)


## Force a single render update (useful after equipment changes while paused).
func request_render() -> void:
	if _sub_viewport:
		_sub_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE


## Enable or disable rendering entirely.
func set_rendering_enabled(enabled: bool) -> void:
	if not _sub_viewport:
		return
	_sub_viewport.render_target_update_mode = (
		SubViewport.UPDATE_WHEN_VISIBLE if enabled
		else SubViewport.UPDATE_DISABLED
	)


# -- Input handlers ----------------------------------------------------------

func _handle_mouse_button(event: InputEventMouseButton) -> void:
	match event.button_index:
		MOUSE_BUTTON_LEFT:
			_is_dragging = event.is_pressed()
			# Render every frame while dragging for smooth rotation.
			if _sub_viewport:
				_sub_viewport.render_target_update_mode = (
					SubViewport.UPDATE_ALWAYS if _is_dragging
					else SubViewport.UPDATE_WHEN_VISIBLE
				)
		MOUSE_BUTTON_WHEEL_UP:
			if event.is_pressed():
				_current_zoom = maxf(zoom_min, _current_zoom - zoom_step)
				if _camera:
					_camera.position.z = _current_zoom
				zoomed.emit(_current_zoom)
		MOUSE_BUTTON_WHEEL_DOWN:
			if event.is_pressed():
				_current_zoom = minf(zoom_max, _current_zoom + zoom_step)
				if _camera:
					_camera.position.z = _current_zoom
				zoomed.emit(_current_zoom)


func _handle_mouse_drag(event: InputEventMouseMotion) -> void:
	if _character_pivot:
		var rotation_amount := deg_to_rad(-event.relative.x * rotation_sensitivity)
		_character_pivot.rotate_y(rotation_amount)
		rotated.emit(rad_to_deg(rotation_amount))
