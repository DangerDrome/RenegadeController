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
@export var ray_length: float = 500.0
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
@export var default_color: Color = Color(0.0, 0.0, 0.0, 1.0)
## Color when hovering an interactable.
@export var interactable_color: Color = Color(0.2, 1.0, 0.4, 0.9)
## Color when aiming (holding aim action).
@export var aim_color: Color = Color(1.0, 0.2, 0.2, 0.9)
## Surface offset to prevent z-fighting with ground.
@export var surface_offset: float = 0.02

@export_group("Aim Line")
## The character to draw the aim line from.
@export var aim_line_origin: Node3D
## Height offset for the aim line origin (e.g., chest height).
@export var aim_line_height: float = 1.2
## Color of the aim line.
@export var aim_line_color: Color = Color(1.0, 0.2, 0.2, 0.8)
## Width of the aim line.
@export var aim_line_width: float = 0.02
## Length of each dash segment.
@export var aim_line_dash_length: float = 0.3
## Length of each gap between dashes.
@export var aim_line_gap_length: float = 0.15

@export_group("Aim Hit Plane")
## Size of the aim hit plane.
@export var aim_plane_size: float = 0.5
## Color of the aim hit plane.
@export var aim_plane_color: Color = Color(1.0, 0.3, 0.3, 0.5)

@export_group("Sticky")
## Enable sticky cursor on interactables.
@export var sticky_enabled: bool = true
## Radius in screen-space to detect nearby interactables for sticky effect.
@export var sticky_radius: float = 120.0
## Smoothing speed for sticky transitions (higher = snappier).
@export var sticky_speed: float = 15.0

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
## Marker3D that follows the cursor position - use this as a camera look_at target.
var look_at_target: Marker3D

var _active: bool = true
var _cursor_mesh: MeshInstance3D
var _aim_line_mesh: MeshInstance3D
var _aim_line_immediate: ImmediateMesh
var _aim_plane_mesh: MeshInstance3D
var _previous_hovered: Node3D = null
var _space_state: PhysicsDirectSpaceState3D
var _sticky_target: Node3D = null
var _sticky_position: Vector3 = Vector3.ZERO
var _cached_interactables: Array[Node3D] = []
var _interactable_cache_valid: bool = false


func _ready() -> void:
	# Create look_at_target marker for camera system to use.
	look_at_target = Marker3D.new()
	look_at_target.name = "CursorLookAtTarget"
	look_at_target.top_level = true  # Independent of parent transform.
	add_child(look_at_target)

	# Connect to tree signals for cache invalidation.
	get_tree().node_added.connect(_on_tree_changed)
	get_tree().node_removed.connect(_on_tree_changed)

	if show_cursor:
		_create_cursor_visual()
	_create_aim_line_visual()
	_create_aim_plane_visual()


func _on_tree_changed(_node: Node) -> void:
	# Invalidate cache when scene tree changes.
	_interactable_cache_valid = false


## Get cached list of interactables (refreshed when tree changes).
func _get_interactables() -> Array[Node3D]:
	if not _interactable_cache_valid:
		_cached_interactables.clear()
		for node in get_tree().get_nodes_in_group("interactable"):
			if node is Node3D:
				_cached_interactables.append(node as Node3D)
		_interactable_cache_valid = true
	return _cached_interactables


func _physics_process(delta: float) -> void:
	if not _active or not camera:
		_set_cursor_visible(false)
		_set_aim_line_visible(false)
		_set_aim_plane_visible(false)
		has_hit = false
		return

	_do_raycast()
	_apply_sticky(delta)
	_update_look_at_target()
	_update_cursor_visual()
	_update_aim_line()
	_update_aim_plane()
	_check_hover_changes()


func _update_look_at_target() -> void:
	if look_at_target:
		look_at_target.global_position = world_position


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


#region Sticky Cursor

func _apply_sticky(delta: float) -> void:
	if not sticky_enabled or not has_hit or not camera:
		_sticky_target = null
		return

	var viewport := camera.get_viewport()
	if not viewport:
		return

	var mouse_pos := viewport.get_mouse_position()

	# Find the closest interactable within sticky_radius.
	var best_target: Node3D = null
	var best_dist_sq: float = sticky_radius * sticky_radius

	# Get cached interactables in the scene.
	var interactables := _get_interactables()

	for node3d in interactables:
		if not node3d.is_inside_tree():
			continue

		# Project interactable position to screen.
		var screen_pos := camera.unproject_position(node3d.global_position)

		# Check if on screen (behind camera check).
		if camera.is_position_behind(node3d.global_position):
			continue

		# Calculate screen-space distance to mouse.
		var dist_sq := mouse_pos.distance_squared_to(screen_pos)
		if dist_sq < best_dist_sq:
			best_dist_sq = dist_sq
			best_target = node3d

	# Update sticky target.
	if best_target:
		_sticky_target = best_target
		# Smoothly interpolate toward sticky position.
		var target_pos := best_target.global_position
		_sticky_position = _sticky_position.lerp(target_pos, 1.0 - exp(-sticky_speed * delta))
		world_position = _sticky_position
		hovered_object = best_target
		hovering_interactable = true
	else:
		_sticky_target = null
		_sticky_position = world_position


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

	var mesh := BoxMesh.new()
	mesh.size = Vector3(cursor_size, cursor_size, cursor_size)
	_cursor_mesh.mesh = mesh

	# Material renders AFTER dithering (priority 100) so it's unaffected.
	var mat := StandardMaterial3D.new()
	mat.albedo_color = default_color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.no_depth_test = true
	mat.render_priority = 127
	_cursor_mesh.material_override = mat
	_cursor_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	_cursor_mesh.top_level = true
	_cursor_mesh.add_to_group("no_dither")
	add_child(_cursor_mesh)


func _update_cursor_visual() -> void:
	if not _cursor_mesh or not show_cursor:
		return

	if not has_hit:
		_set_cursor_visible(false)
		return

	_set_cursor_visible(true)
	_cursor_mesh.global_position = world_position

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


#region Aim Line Visual

func _create_aim_line_visual() -> void:
	_aim_line_mesh = MeshInstance3D.new()
	_aim_line_mesh.name = "AimLineVisual"
	_aim_line_mesh.top_level = true
	_aim_line_mesh.visible = false

	_aim_line_immediate = ImmediateMesh.new()
	_aim_line_mesh.mesh = _aim_line_immediate

	# Material renders AFTER dithering (priority 100) so it's unaffected.
	var mat := StandardMaterial3D.new()
	mat.albedo_color = aim_line_color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.no_depth_test = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.render_priority = 127
	_aim_line_mesh.material_override = mat
	_aim_line_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	_aim_line_mesh.add_to_group("no_dither")
	add_child(_aim_line_mesh)


func _update_aim_line() -> void:
	if not _aim_line_mesh or not _aim_line_immediate:
		return

	var is_aim_pressed := Input.is_action_pressed(aim_action)

	if not is_aim_pressed or not has_hit or not aim_line_origin:
		_set_aim_line_visible(false)
		return

	_set_aim_line_visible(true)

	# Calculate line endpoints.
	var start_pos := aim_line_origin.global_position + Vector3.UP * aim_line_height
	var end_pos := world_position

	# Update material color.
	var mat: StandardMaterial3D = _aim_line_mesh.material_override
	if mat:
		mat.albedo_color = aim_line_color

	# Rebuild the dashed line geometry.
	_draw_dashed_line(start_pos, end_pos)


func _draw_dashed_line(start: Vector3, end: Vector3) -> void:
	_aim_line_immediate.clear_surfaces()

	var direction := end - start
	var total_length := direction.length()
	if total_length < 0.01:
		return

	direction = direction.normalized()
	var segment_length := aim_line_dash_length + aim_line_gap_length
	var current_dist := 0.0

	# Calculate perpendicular vectors for line width.
	var up := Vector3.UP
	if absf(direction.dot(up)) > 0.99:
		up = Vector3.RIGHT
	var right := direction.cross(up).normalized() * aim_line_width * 0.5
	var forward := direction.cross(right).normalized() * aim_line_width * 0.5

	_aim_line_immediate.surface_begin(Mesh.PRIMITIVE_TRIANGLES)

	while current_dist < total_length:
		var dash_start := current_dist
		var dash_end := minf(current_dist + aim_line_dash_length, total_length)

		if dash_end > dash_start:
			var p1 := start + direction * dash_start
			var p2 := start + direction * dash_end

			# Create a quad strip (two triangles per face, 4 faces for a box-like line).
			_add_line_segment(p1, p2, right, forward)

		current_dist += segment_length

	_aim_line_immediate.surface_end()


func _add_line_segment(p1: Vector3, p2: Vector3, right: Vector3, forward: Vector3) -> void:
	# Top face.
	_aim_line_immediate.surface_add_vertex(p1 - right + forward)
	_aim_line_immediate.surface_add_vertex(p1 + right + forward)
	_aim_line_immediate.surface_add_vertex(p2 + right + forward)

	_aim_line_immediate.surface_add_vertex(p1 - right + forward)
	_aim_line_immediate.surface_add_vertex(p2 + right + forward)
	_aim_line_immediate.surface_add_vertex(p2 - right + forward)

	# Bottom face.
	_aim_line_immediate.surface_add_vertex(p1 + right - forward)
	_aim_line_immediate.surface_add_vertex(p1 - right - forward)
	_aim_line_immediate.surface_add_vertex(p2 - right - forward)

	_aim_line_immediate.surface_add_vertex(p1 + right - forward)
	_aim_line_immediate.surface_add_vertex(p2 - right - forward)
	_aim_line_immediate.surface_add_vertex(p2 + right - forward)

	# Left face.
	_aim_line_immediate.surface_add_vertex(p1 - right - forward)
	_aim_line_immediate.surface_add_vertex(p1 - right + forward)
	_aim_line_immediate.surface_add_vertex(p2 - right + forward)

	_aim_line_immediate.surface_add_vertex(p1 - right - forward)
	_aim_line_immediate.surface_add_vertex(p2 - right + forward)
	_aim_line_immediate.surface_add_vertex(p2 - right - forward)

	# Right face.
	_aim_line_immediate.surface_add_vertex(p1 + right + forward)
	_aim_line_immediate.surface_add_vertex(p1 + right - forward)
	_aim_line_immediate.surface_add_vertex(p2 + right - forward)

	_aim_line_immediate.surface_add_vertex(p1 + right + forward)
	_aim_line_immediate.surface_add_vertex(p2 + right - forward)
	_aim_line_immediate.surface_add_vertex(p2 + right + forward)


func _set_aim_line_visible(visible: bool) -> void:
	if _aim_line_mesh:
		_aim_line_mesh.visible = visible

#endregion


#region Aim Plane Visual

func _create_aim_plane_visual() -> void:
	_aim_plane_mesh = MeshInstance3D.new()
	_aim_plane_mesh.name = "AimPlaneVisual"
	_aim_plane_mesh.top_level = true
	_aim_plane_mesh.visible = false

	# Squashed cube instead of flat plane to avoid z-fighting.
	var mesh := BoxMesh.new()
	mesh.size = Vector3(aim_plane_size, aim_plane_size, 0.05)
	_aim_plane_mesh.mesh = mesh

	# Material renders AFTER dithering (priority 100) so it's unaffected.
	var mat := StandardMaterial3D.new()
	mat.albedo_color = aim_plane_color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.no_depth_test = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.render_priority = 127
	_aim_plane_mesh.material_override = mat
	_aim_plane_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	_aim_plane_mesh.add_to_group("no_dither")
	add_child(_aim_plane_mesh)


func _update_aim_plane() -> void:
	if not _aim_plane_mesh:
		return

	var is_aim_pressed := Input.is_action_pressed(aim_action)

	if not is_aim_pressed or not has_hit or not aim_line_origin or not _space_state:
		_set_aim_plane_visible(false)
		return

	# Raycast from player toward cursor to find obstacles in firing line.
	var start_pos := aim_line_origin.global_position + Vector3.UP * aim_line_height
	var direction := (world_position - start_pos).normalized()
	var distance := start_pos.distance_to(world_position) + 5.0  # Extend past target to ensure hit.
	var end_pos := start_pos + direction * distance

	var query := PhysicsRayQueryParameters3D.create(start_pos, end_pos, collision_mask)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	query.exclude = [aim_line_origin.get_rid()]

	var result := _space_state.intersect_ray(query)

	if result.is_empty():
		_set_aim_plane_visible(false)
		return

	var hit_pos: Vector3 = result.position
	var hit_normal: Vector3 = result.normal

	_set_aim_plane_visible(true)

	# Update material color.
	var mat: StandardMaterial3D = _aim_plane_mesh.material_override
	if mat:
		mat.albedo_color = aim_plane_color

	# Position at hit point.
	_aim_plane_mesh.global_position = hit_pos

	# Orient plane to face along the surface normal.
	# QuadMesh faces -Z, so we set Z to -normal.
	if hit_normal.length_squared() > 0.001:
		var normal := hit_normal.normalized()
		var up := Vector3.UP
		if absf(normal.dot(up)) > 0.99:
			up = Vector3.FORWARD
		var right := up.cross(normal).normalized()
		up = normal.cross(right).normalized()
		_aim_plane_mesh.global_basis = Basis(right, up, normal)


func _set_aim_plane_visible(visible: bool) -> void:
	if _aim_plane_mesh:
		_aim_plane_mesh.visible = visible

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
