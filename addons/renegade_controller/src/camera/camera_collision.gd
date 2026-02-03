## Handles camera collision detection and player mesh visibility.
## Pulls camera closer when blocked by geometry and fades player mesh when too close.
class_name CameraCollisionHandler extends RefCounted


#region Settings
## Collision mask for camera blocking geometry.
var collision_mask: int = 1
## Margin from collision surface.
var collision_margin: float = 0.3
## How fast the camera pulls in when blocked.
var collision_speed: float = 15.0
## Minimum distance camera can get to player during collision.
var min_camera_distance: float = 1.5
## Distance at which the player model starts fading out.
var player_fade_distance: float = 2.0
## Hide player when camera is closer than this distance.
var player_hide_distance: float = 1.0
#endregion


#region State
var _collision_offset: float = 0.0
var _cached_player_meshes: Array[MeshInstance3D] = []
var _player_meshes_valid: bool = false
#endregion


## Configure collision settings from CameraRig exports.
func configure(
	p_collision_mask: int,
	p_collision_margin: float,
	p_collision_speed: float,
	p_min_camera_distance: float,
	p_player_fade_distance: float,
	p_player_hide_distance: float
) -> void:
	collision_mask = p_collision_mask
	collision_margin = p_collision_margin
	collision_speed = p_collision_speed
	min_camera_distance = p_min_camera_distance
	player_fade_distance = p_player_fade_distance
	player_hide_distance = p_player_hide_distance


## Invalidate mesh cache (call when target changes).
func invalidate_mesh_cache() -> void:
	_player_meshes_valid = false
	_cached_player_meshes.clear()


## Get the current collision offset.
func get_collision_offset() -> float:
	return _collision_offset


## Reset collision state.
func reset() -> void:
	_collision_offset = 0.0


## Apply collision detection and return adjusted position.
## Returns the position offset to apply (subtract from desired position direction).
func update_collision(
	delta: float,
	target: CharacterBody3D,
	desired_pos: Vector3,
	target_frame_offset: Vector3,
	world_3d: World3D
) -> float:
	if not target:
		_collision_offset = 0.0
		return 0.0

	var player_pos := target.global_position + target_frame_offset
	var to_camera := desired_pos - player_pos
	var distance := to_camera.length()

	if distance < 0.1:
		_collision_offset = 0.0
		_update_player_visibility(target, distance)
		return 0.0

	var space_state := world_3d.direct_space_state
	if not space_state:
		return _collision_offset

	# Raycast from player toward camera.
	var query := PhysicsRayQueryParameters3D.create(player_pos, desired_pos, collision_mask)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.exclude = [target.get_rid()]

	var result := space_state.intersect_ray(query)

	var target_offset: float = 0.0
	if not result.is_empty():
		# Hit something - calculate how much to pull in.
		var hit_pos: Vector3 = result.position
		var hit_distance := player_pos.distance_to(hit_pos)
		# Pull camera to hit point minus margin.
		target_offset = distance - hit_distance + collision_margin
		# Clamp to minimum distance.
		var max_offset := distance - min_camera_distance
		target_offset = minf(target_offset, max_offset)

	# Smoothly interpolate collision offset.
	_collision_offset = lerpf(_collision_offset, target_offset, 1.0 - exp(-collision_speed * delta))

	return _collision_offset


## Update player visibility based on camera distance.
func update_player_visibility(target: CharacterBody3D, camera_position: Vector3, target_frame_offset: Vector3) -> void:
	if not target:
		return
	var player_pos := target.global_position + target_frame_offset
	var final_distance := player_pos.distance_to(camera_position)
	_update_player_visibility(target, final_distance)


func _update_player_visibility(target: CharacterBody3D, camera_distance: float) -> void:
	if not target:
		return

	var meshes := _get_player_meshes(target)
	if meshes.is_empty():
		return

	if camera_distance <= player_hide_distance:
		# Too close - hide completely.
		for mesh in meshes:
			mesh.visible = false
	elif camera_distance <= player_fade_distance:
		# Fade zone - adjust transparency.
		var t := (camera_distance - player_hide_distance) / (player_fade_distance - player_hide_distance)
		for mesh in meshes:
			mesh.visible = true
			_set_mesh_transparency(mesh, 1.0 - t)
	else:
		# Normal distance - fully visible.
		for mesh in meshes:
			mesh.visible = true
			_set_mesh_transparency(mesh, 0.0)


func _get_player_meshes(target: CharacterBody3D) -> Array[MeshInstance3D]:
	if not target:
		_cached_player_meshes.clear()
		_player_meshes_valid = false
		return _cached_player_meshes

	if _player_meshes_valid:
		return _cached_player_meshes

	_cached_player_meshes.clear()
	_collect_meshes(target, _cached_player_meshes)
	_player_meshes_valid = true
	return _cached_player_meshes


func _collect_meshes(node: Node, meshes: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		meshes.append(node)
	for child in node.get_children():
		_collect_meshes(child, meshes)


func _set_mesh_transparency(mesh: MeshInstance3D, transparency: float) -> void:
	if transparency <= 0.01:
		# Fully opaque - restore original material if we modified it.
		if mesh.has_meta("_original_transparency"):
			var mat := mesh.get_active_material(0)
			if mat is StandardMaterial3D:
				mat.transparency = mesh.get_meta("_original_transparency")
				mat.albedo_color.a = 1.0
			mesh.remove_meta("_original_transparency")
		return

	var mat := mesh.get_active_material(0)
	if not mat:
		return

	# Store original transparency mode.
	if not mesh.has_meta("_original_transparency"):
		if mat is StandardMaterial3D:
			mesh.set_meta("_original_transparency", mat.transparency)

	# Apply transparency.
	if mat is StandardMaterial3D:
		if mat.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED:
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color.a = 1.0 - transparency
