## Handles automatic camera zoom based on nearby geometry.
## Zooms in when the area is open, zooms out when near objects.
class_name CameraAutoFramer extends RefCounted


#region Settings
## Enable automatic zoom based on nearby geometry.
var enabled: bool = true
## Distance to check for nearby objects.
var check_distance: float = 5.0
## Zoom offset when area is completely open (positive = closer to player).
var zoom_in: float = 2.0
## Zoom offset when near objects (negative = further from player).
var zoom_out: float = -12.0
## How fast the auto-framing adjusts.
var speed: float = 3.0
## Number of rays to cast for detecting nearby geometry.
var ray_count: int = 8
## Collision mask for auto-framing detection.
var collision_mask: int = 1
#endregion


#region State
var _current_zoom: float = 0.0
#endregion


## Configure auto-framing settings.
func configure(
	p_enabled: bool,
	p_check_distance: float,
	p_zoom_in: float,
	p_zoom_out: float,
	p_speed: float,
	p_ray_count: int,
	p_collision_mask: int
) -> void:
	enabled = p_enabled
	check_distance = p_check_distance
	zoom_in = p_zoom_in
	zoom_out = p_zoom_out
	speed = p_speed
	ray_count = p_ray_count
	collision_mask = p_collision_mask


## Get the current auto-frame zoom offset.
func get_zoom_offset() -> float:
	return _current_zoom


## Reset auto-frame state.
func reset() -> void:
	_current_zoom = 0.0


## Update auto-framing and return the zoom offset to apply.
func update(
	delta: float,
	target: CharacterBody3D,
	target_frame_offset: Vector3,
	world_3d: World3D
) -> float:
	if not enabled or not target:
		_current_zoom = lerpf(_current_zoom, 0.0, 1.0 - exp(-speed * delta))
		return _current_zoom

	var space_state := world_3d.direct_space_state
	if not space_state:
		return _current_zoom

	var player_pos := target.global_position + target_frame_offset
	var total_openness := 0.0

	# Cast rays in a circle around the player to detect nearby geometry.
	for i in ray_count:
		var angle := TAU * i / ray_count
		var direction := Vector3(cos(angle), 0.0, sin(angle))
		var ray_end := player_pos + direction * check_distance

		var query := PhysicsRayQueryParameters3D.create(player_pos, ray_end, collision_mask)
		query.collide_with_areas = false
		query.collide_with_bodies = true
		query.exclude = [target.get_rid()]

		var result := space_state.intersect_ray(query)

		if result.is_empty():
			# No hit - fully open in this direction.
			total_openness += 1.0
		else:
			# Hit something - openness based on distance.
			var hit_distance := player_pos.distance_to(result.position)
			total_openness += hit_distance / check_distance

	# Average openness (0 = surrounded by objects, 1 = completely open).
	var openness := total_openness / ray_count

	# Map openness to zoom offset.
	# openness = 1.0 (open) -> zoom in (positive offset, closer to player)
	# openness = 0.0 (closed) -> zoom out (negative offset, further from player)
	var target_zoom := lerpf(zoom_out, zoom_in, openness)

	# Smoothly interpolate.
	_current_zoom = lerpf(_current_zoom, target_zoom, 1.0 - exp(-speed * delta))

	return _current_zoom
