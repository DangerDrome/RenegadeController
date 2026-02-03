## Level volume that triggers a camera preset change when the player enters.
## Place these in your level as Area3D nodes with collision shapes.
## Add to the "camera_zones" group for auto-detection by CameraZoneManager.
##
## Child nodes (editable):
## - Marker3D "CameraRig": Parent container. Select to move camera+target together.
##   - Camera3D "ZoneCamera": Position/rotate to define camera angle. FOV is used at runtime.
##   - Marker3D "LookAtTarget": Position where camera looks in editor preview.
## - CollisionShape3D: Define zone bounds directly.
##
## Editor behavior:
## - Select CameraRig: Move both camera and target together
## - Select ZoneCamera: Move camera only (camera keeps looking at target)
## - Select LookAtTarget: Move target only (camera adjusts aim)
@tool
class_name CameraZone extends Area3D


#region Zone Settings
@export_group("Zone")
## The camera preset to transition to when a player enters this zone.
@export var camera_preset: CameraPreset:
	set(value):
		camera_preset = value
		notify_property_list_changed()

## Priority for overlapping zones. Higher priority wins.
@export var zone_priority: int = 0

## When true, leaving this zone reverts to the previous preset or default.
@export var revert_on_exit: bool = true
#endregion


#region Camera Settings
@export_group("Camera")
## Camera template defining position, rotation, and FOV for this zone.
## Position this camera in the editor to frame your shot.
@export var zone_camera: Camera3D:
	set(value):
		zone_camera = value
		_update_camera_sync()

## Field of view in degrees. Synced to zone_camera.
@export_range(1, 179, 0.1, "suffix:°") var camera_fov: float = 70.0:
	set(value):
		camera_fov = value
		if zone_camera:
			zone_camera.fov = value

## When true, camera follows the player (camera position is offset from player).
## When false, camera stays at fixed world position.
@export var follow_player: bool = true
#endregion


#region Look-At Settings
@export_group("Look At")
## When true, camera will look at the player at runtime.
@export var target_player: bool = true

## Custom look-at target (any Node3D). If set and target_player is false,
## camera will look at this instead of the player.
@export var look_at_target: Node3D

## Marker for editor preview of look-at point. Move this to frame your shot.
## At runtime with target_player enabled, camera looks at player instead.
@export var look_at_marker: Marker3D
#endregion


## Emitted when a player enters this zone. CameraZoneManager listens for this.
signal zone_entered(zone: CameraZone)
## Emitted when a player exits this zone.
signal zone_exited(zone: CameraZone)

# Editor: Gizmo visualization.
var _gizmo_mesh: MeshInstance3D
var _gizmo_material: StandardMaterial3D

# Parent rig for camera and target.
var _camera_rig: Marker3D


func _ready() -> void:
	# Auto-add to group for discovery.
	if not is_in_group("camera_zones"):
		add_to_group("camera_zones")

	# Zone doesn't block anything physically, but detects player on layer 1.
	collision_layer = 0
	collision_mask = 1

	# Auto-discover child nodes if not assigned.
	_auto_discover_children()

	# Connect signals.
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	# Sync initial FOV from camera if it exists.
	if zone_camera and not Engine.is_editor_hint():
		camera_fov = zone_camera.fov

	# Create editor gizmo visualization.
	if Engine.is_editor_hint():
		_create_gizmo()


func _auto_discover_children() -> void:
	var scene_root: Node = get_tree().edited_scene_root if Engine.is_editor_hint() and get_tree() else null

	# Auto-discover or create CameraRig (parent for camera and target).
	_camera_rig = get_node_or_null("CameraRig") as Marker3D
	if not _camera_rig and Engine.is_editor_hint():
		_camera_rig = Marker3D.new()
		_camera_rig.name = "CameraRig"
		_camera_rig.gizmo_extents = 0.4
		add_child(_camera_rig, true)
		_camera_rig.owner = scene_root

	# Auto-discover camera if not assigned.
	if not zone_camera:
		# Check old location first (direct child), then new location (under CameraRig).
		var cam := get_node_or_null("ZoneCamera") as Camera3D
		if not cam and _camera_rig:
			cam = _camera_rig.get_node_or_null("ZoneCamera") as Camera3D
		if cam:
			zone_camera = cam
			zone_camera.current = false  # Template only.
			# Reparent to CameraRig if needed.
			if _camera_rig and zone_camera.get_parent() != _camera_rig:
				zone_camera.reparent(_camera_rig)
		elif Engine.is_editor_hint() and _camera_rig:
			# Create camera as child of CameraRig.
			zone_camera = Camera3D.new()
			zone_camera.name = "ZoneCamera"
			zone_camera.current = false
			zone_camera.fov = camera_fov
			_camera_rig.add_child(zone_camera, true)
			zone_camera.owner = scene_root
			zone_camera.position = Vector3(0, 3, -5)
			zone_camera.rotation_degrees = Vector3(-15, 180, 0)

	# Auto-discover look-at marker if not assigned.
	if not look_at_marker:
		# Check old location first (direct child), then new location (under CameraRig).
		var marker := get_node_or_null("LookAtTarget") as Marker3D
		if not marker and _camera_rig:
			marker = _camera_rig.get_node_or_null("LookAtTarget") as Marker3D
		if marker:
			look_at_marker = marker
			# Reparent to CameraRig if needed.
			if _camera_rig and look_at_marker.get_parent() != _camera_rig:
				look_at_marker.reparent(_camera_rig)
		elif Engine.is_editor_hint() and _camera_rig:
			# Create marker as child of CameraRig.
			look_at_marker = Marker3D.new()
			look_at_marker.name = "LookAtTarget"
			look_at_marker.gizmo_extents = 0.5
			_camera_rig.add_child(look_at_marker, true)
			look_at_marker.owner = scene_root
			look_at_marker.position = Vector3(0, 1.5, 0)

	# Ensure collision shape exists.
	var has_shape := false
	for child in get_children():
		if child is CollisionShape3D:
			has_shape = true
			break

	if not has_shape and Engine.is_editor_hint():
		var shape := CollisionShape3D.new()
		shape.name = "ZoneShape"
		var box := BoxShape3D.new()
		box.size = Vector3(10, 5, 10)
		shape.shape = box
		shape.position.y = 2.5  # Center vertically.
		add_child(shape, true)
		shape.owner = scene_root


func _update_camera_sync() -> void:
	if zone_camera:
		zone_camera.current = false  # Never active, template only.
		camera_fov = zone_camera.fov


## Returns the camera marker/template for CameraZoneManager.
func get_camera_marker() -> Node3D:
	return zone_camera


## Returns the effective look-at node for runtime.
## If target_player is true, returns the player. Otherwise returns look_at_target or look_at_marker.
func get_look_at_node() -> Node3D:
	if target_player and not Engine.is_editor_hint():
		# At runtime with target_player enabled, find the player.
		var players := get_tree().get_nodes_in_group("player")
		if not players.is_empty() and players[0] is Node3D:
			return players[0] as Node3D
	# Fallback to explicit target or marker.
	if look_at_target and is_instance_valid(look_at_target):
		return look_at_target
	if look_at_marker and is_instance_valid(look_at_marker):
		return look_at_marker
	return null


func _on_body_entered(body: Node3D) -> void:
	if Engine.is_editor_hint():
		return
	if body.is_in_group("player"):
		zone_entered.emit(self)


func _on_body_exited(body: Node3D) -> void:
	if Engine.is_editor_hint():
		return
	if body.is_in_group("player"):
		zone_exited.emit(self)


## Create editor gizmo for camera-to-target visualization.
func _create_gizmo() -> void:
	_gizmo_mesh = MeshInstance3D.new()
	_gizmo_mesh.name = "_EditorGizmo"
	_gizmo_mesh.mesh = ImmediateMesh.new()
	_gizmo_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_gizmo_mesh)

	_gizmo_material = StandardMaterial3D.new()
	_gizmo_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_gizmo_material.albedo_color = Color(0.4, 0.8, 1.0, 0.8)
	_gizmo_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_gizmo_material.no_depth_test = true


## Update editor gizmo - draws line to target and wireframe cube.
func _update_gizmo() -> void:
	if not _gizmo_mesh or not _gizmo_mesh.mesh is ImmediateMesh:
		return
	if not zone_camera or not look_at_marker:
		return

	var im: ImmediateMesh = _gizmo_mesh.mesh
	im.clear_surfaces()

	var cam_pos := zone_camera.global_position
	var target_pos := look_at_marker.global_position

	# Convert to local space of the CameraZone.
	var local_cam := to_local(cam_pos)
	var local_target := to_local(target_pos)

	# Draw line from camera to target.
	im.surface_begin(Mesh.PRIMITIVE_LINES, _gizmo_material)
	im.surface_add_vertex(local_cam)
	im.surface_add_vertex(local_target)
	im.surface_end()

	# Draw wireframe cube at target.
	var cube_size := 0.15
	_draw_wireframe_cube(im, local_target, cube_size)


## Draw a wireframe cube centered at position.
func _draw_wireframe_cube(im: ImmediateMesh, center: Vector3, size: float) -> void:
	var half := size * 0.5
	var corners: Array[Vector3] = [
		center + Vector3(-half, -half, -half),
		center + Vector3(half, -half, -half),
		center + Vector3(half, half, -half),
		center + Vector3(-half, half, -half),
		center + Vector3(-half, -half, half),
		center + Vector3(half, -half, half),
		center + Vector3(half, half, half),
		center + Vector3(-half, half, half),
	]

	im.surface_begin(Mesh.PRIMITIVE_LINES, _gizmo_material)
	# Bottom face.
	im.surface_add_vertex(corners[0]); im.surface_add_vertex(corners[1])
	im.surface_add_vertex(corners[1]); im.surface_add_vertex(corners[2])
	im.surface_add_vertex(corners[2]); im.surface_add_vertex(corners[3])
	im.surface_add_vertex(corners[3]); im.surface_add_vertex(corners[0])
	# Top face.
	im.surface_add_vertex(corners[4]); im.surface_add_vertex(corners[5])
	im.surface_add_vertex(corners[5]); im.surface_add_vertex(corners[6])
	im.surface_add_vertex(corners[6]); im.surface_add_vertex(corners[7])
	im.surface_add_vertex(corners[7]); im.surface_add_vertex(corners[4])
	# Vertical edges.
	im.surface_add_vertex(corners[0]); im.surface_add_vertex(corners[4])
	im.surface_add_vertex(corners[1]); im.surface_add_vertex(corners[5])
	im.surface_add_vertex(corners[2]); im.surface_add_vertex(corners[6])
	im.surface_add_vertex(corners[3]); im.surface_add_vertex(corners[7])
	im.surface_end()


## Editor: Camera always looks at target.
func _process(_delta: float) -> void:
	if not Engine.is_editor_hint():
		return

	if not zone_camera or not look_at_marker:
		return
	if not is_instance_valid(zone_camera) or not is_instance_valid(look_at_marker):
		return

	var cam_pos := zone_camera.global_position
	var target_pos := look_at_marker.global_position

	# Make camera look at target.
	var dir := target_pos - cam_pos
	if dir.length_squared() > 0.001:
		var up := Vector3.UP if absf(dir.normalized().y) < 0.9 else Vector3.FORWARD
		zone_camera.look_at(target_pos, up)

	# Update gizmo visualization.
	_update_gizmo()

