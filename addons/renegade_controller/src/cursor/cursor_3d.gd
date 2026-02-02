## 3D mouse cursor for aiming and interactable selection.
## Raycasts from the camera through the mouse position into 3D space.
## Shows a visual cursor at the hit point and detects interactable objects.
class_name Cursor3D extends Node3D

## Emitted when clicking on an object in the "interactable" group.
signal interactable_clicked(target: Node3D)
## Emitted when clicking on ground/world geometry (non-interactable).
signal ground_clicked(position: Vector3)
## Emitted when the cursor hovers over an interactable.
signal interactable_hovered(target: Node3D)
## Emitted when the cursor stops hovering over an interactable.
signal interactable_unhovered(target: Node3D)

@export_group("Raycast")
## The camera to raycast from.
@export var camera: Camera3D
## Maximum raycast distance.
@export var ray_length: float = 100.0
## Collision mask for the raycast (what layers it hits).
@export_flags_3d_physics var collision_mask: int = 0xFFFFFFFF
## Collision mask specifically for interactable detection (set to your interactable layer).
@export_flags_3d_physics var interactable_mask: int = 2

@export_group("Visual")
## Show a visual cursor in the 3D world.
@export var show_cursor: bool = true
## Size of the cursor visual.
@export var cursor_size: float = 0.3
## Default cursor color.
@export var default_color: Color = Color(1.0, 1.0, 1.0, 0.7)
## Color when hovering an interactable.
@export var interactable_color: Color = Color(0.2, 1.0, 0.4, 0.9)
## Color when aiming (holding aim action).
@export var aim_color: Color = Color(1.0, 0.2, 0.2, 0.9)
## Surface offset to prevent z-fighting with ground.
@export var surface_offset: float = 0.02

@export_group("Input")
## Action name for primary click (interact / shoot).
@export var click_action: String = "interact"
## Action name for aim mode.
@export var aim_action: String = "aim"

## Current world position of the cursor hit point.
var world_position: Vector3 = Vector3.ZERO
## Current surface normal at hit point.
var world_normal: Vector3 = Vector3.UP
## True if the raycast hit something this frame.
var has_hit: bool = false
## The object currently under the cursor (null if none).
var hovered_object: Node3D = null
## True if hovered_object is an interactable.
var hovering_interactable: bool = false

var _active: bool = true
var _cursor_mesh: MeshInstance3D
var _previous_hovered: Node3D = null
var _space_state: PhysicsDirectSpaceState3D


func _ready() -> void:
	if show_cursor:
		_create_cursor_visual()


func _physics_process(_delta: float) -> void:
	if not _active or not camera:
		_set_cursor_visible(false)
		has_hit = false
		return
	
	_do_raycast()
	_update_cursor_visual()
	_check_hover_changes()


func _unhandled_input(event: InputEvent) -> void:
	if not _active:
		return
	
	if event.is_action_pressed(click_action) and has_hit:
		if hovering_interactable and hovered_object:
			interactable_clicked.emit(hovered_object)
		else:
			ground_clicked.emit(world_position)


#region Public API

## Enable or disable the cursor (disabled during first-person).
func set_active(enabled: bool) -> void:
	_active = enabled
	_set_cursor_visible(enabled and has_hit)
	if not enabled:
		_clear_hover()


## Get the aim direction from a character position to the cursor.
func get_aim_direction_from(origin: Vector3) -> Vector3:
	if not has_hit:
		return Vector3.FORWARD
	var dir := (world_position - origin)
	dir.y = 0.0  # Keep aim on horizontal plane for TPS.
	return dir.normalized() if dir.length() > 0.01 else Vector3.FORWARD

#endregion


#region Raycasting

func _do_raycast() -> void:
	if not camera or not camera.is_inside_tree():
		has_hit = false
		return
	
	var viewport := camera.get_viewport()
	if not viewport:
		has_hit = false
		return
	
	var mouse_pos := viewport.get_mouse_position()
	var from := camera.project_ray_origin(mouse_pos)
	var direction := camera.project_ray_normal(mouse_pos)
	var to := from + direction * ray_length
	
	# Get physics space state.
	_space_state = camera.get_world_3d().direct_space_state
	if not _space_state:
		has_hit = false
		return
	
	# Primary raycast: world geometry + interactables.
	var query := PhysicsRayQueryParameters3D.create(from, to, collision_mask)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	
	var result := _space_state.intersect_ray(query)
	
	if result.is_empty():
		has_hit = false
		hovered_object = null
		hovering_interactable = false
		return
	
	has_hit = true
	world_position = result.position
	world_normal = result.normal
	
	# Check if the hit object is an interactable.
	var collider: Node3D = result.collider
	hovered_object = collider
	hovering_interactable = _is_interactable(collider)

#endregion


#region Hover Management

func _check_hover_changes() -> void:
	if hovered_object != _previous_hovered:
		# Unhover previous.
		if _previous_hovered and is_instance_valid(_previous_hovered):
			interactable_unhovered.emit(_previous_hovered)
			if _previous_hovered.has_method("on_cursor_exit"):
				_previous_hovered.on_cursor_exit()
		
		# Hover new.
		if hovering_interactable and hovered_object:
			interactable_hovered.emit(hovered_object)
			if hovered_object.has_method("on_cursor_enter"):
				hovered_object.on_cursor_enter()
		
		_previous_hovered = hovered_object


func _clear_hover() -> void:
	if _previous_hovered and is_instance_valid(_previous_hovered):
		interactable_unhovered.emit(_previous_hovered)
		if _previous_hovered.has_method("on_cursor_exit"):
			_previous_hovered.on_cursor_exit()
	_previous_hovered = null
	hovered_object = null
	hovering_interactable = false

#endregion


#region Cursor Visual

func _create_cursor_visual() -> void:
	_cursor_mesh = MeshInstance3D.new()
	_cursor_mesh.name = "CursorVisual"
	
	# Simple quad/disc mesh.
	var mesh := QuadMesh.new()
	mesh.size = Vector2(cursor_size, cursor_size)
	_cursor_mesh.mesh = mesh
	
	# Material.
	var mat := StandardMaterial3D.new()
	mat.albedo_color = default_color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.no_depth_test = true  # Always visible.
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
	_cursor_mesh.material_override = mat
	
	# Top-level so it doesn't inherit parent transforms weirdly.
	_cursor_mesh.top_level = true
	add_child(_cursor_mesh)


func _update_cursor_visual() -> void:
	if not _cursor_mesh or not show_cursor:
		return
	
	if not has_hit:
		_set_cursor_visible(false)
		return
	
	_set_cursor_visible(true)
	
	# Position on surface with slight offset.
	_cursor_mesh.global_position = world_position + world_normal * surface_offset
	
	# Orient to surface normal.
	if world_normal.length_squared() > 0.001:
		var up := world_normal
		var forward := Vector3.FORWARD
		# Avoid parallel vectors.
		if absf(up.dot(forward)) > 0.99:
			forward = Vector3.RIGHT
		_cursor_mesh.look_at(_cursor_mesh.global_position + up, forward)
		_cursor_mesh.rotate_object_local(Vector3.RIGHT, deg_to_rad(90))
	
	# Color based on state.
	var mat: StandardMaterial3D = _cursor_mesh.material_override
	if mat:
		if Input.is_action_pressed(aim_action):
			mat.albedo_color = aim_color
		elif hovering_interactable:
			mat.albedo_color = interactable_color
		else:
			mat.albedo_color = default_color


func _set_cursor_visible(visible: bool) -> void:
	if _cursor_mesh:
		_cursor_mesh.visible = visible

#endregion


#region Helpers

func _is_interactable(node: Node3D) -> bool:
	if not node:
		return false
	# Check group membership.
	if node.is_in_group("interactable"):
		return true
	# Walk up to parent to check (e.g., click on mesh child of interactable).
	var parent := node.get_parent()
	if parent is Node3D and parent.is_in_group("interactable"):
		return true
	return false

#endregion
