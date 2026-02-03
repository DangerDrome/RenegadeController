## Root node for the camera system.
## Exposes camera rig settings at the top level for easy editing when instanced.
## Uses Camera3D nodes as templates - position them in the editor to define camera angles.
## The CameraRig's actual camera copies settings from these templates.
class_name CameraSystem extends Node3D


#region Setup
@export_group("Setup")
## The character this camera follows.
@export var target: CharacterBody3D:
	set(value):
		target = value
		if _camera_rig:
			_camera_rig.target = value
## Reference to the player controller (for first-person mouse input).
@export var player_controller: PlayerController:
	set(value):
		player_controller = value
		if _camera_rig:
			_camera_rig.player_controller = value
## The default camera preset (used when returning from zone cameras).
@export var default_preset: CameraPreset:
	set(value):
		default_preset = value
		if _camera_rig:
			_camera_rig.default_preset = value
## Template camera defining the default third-person view.
## Position and rotate this camera in the editor - the rig will copy its transform.
@export var third_person_camera: Camera3D
## Template camera defining the first-person view (head position).
@export var first_person_camera: Camera3D
#endregion


#region Cursor Panning
@export_group("Cursor Panning")
## Enable camera panning toward cursor when aiming.
@export var cursor_panning_enabled: bool = true
## Maximum angle (degrees) the camera can look away from center toward cursor.
@export var max_cursor_angle: float = 15.0
## Multiplier for cursor influence (0 = no effect, 1 = full effect).
@export_range(0.0, 1.0) var cursor_influence: float = 0.3
#endregion


#region Zoom
@export_group("Zoom")
## Minimum zoom distance (closest to player).
@export var min_zoom: float = 2.0:
	set(value):
		min_zoom = value
		if _camera_rig:
			_camera_rig.min_zoom = value
## Maximum zoom distance (furthest from player).
@export var max_zoom: float = 15.0:
	set(value):
		max_zoom = value
		if _camera_rig:
			_camera_rig.max_zoom = value
## Zoom step per scroll wheel tick.
@export var zoom_step: float = 0.5:
	set(value):
		zoom_step = value
		if _camera_rig:
			_camera_rig.zoom_step = value
## Zoom smoothing speed.
@export var zoom_speed: float = 10.0:
	set(value):
		zoom_speed = value
		if _camera_rig:
			_camera_rig.zoom_speed = value
#endregion


#region Framing
@export_group("Framing")
## Offset applied to player position for look-at target (for cinematic framing).
@export var target_frame_offset: Vector3 = Vector3(0, 1.0, 0):
	set(value):
		target_frame_offset = value
		if _camera_rig:
			_camera_rig.target_frame_offset = value
#endregion


#region Auto Framing
@export_group("Auto Framing")
## Enable automatic zoom based on nearby geometry.
@export var auto_frame_enabled: bool = true:
	set(value):
		auto_frame_enabled = value
		if _camera_rig:
			_camera_rig.auto_frame_enabled = value
## Distance to check for nearby objects.
@export var auto_frame_distance: float = 5.0:
	set(value):
		auto_frame_distance = value
		if _camera_rig:
			_camera_rig.auto_frame_distance = value
## Zoom offset when area is completely open (positive = closer to player).
@export var auto_frame_zoom_in: float = 2.0:
	set(value):
		auto_frame_zoom_in = value
		if _camera_rig:
			_camera_rig.auto_frame_zoom_in = value
## Zoom offset when near objects (negative = further from player).
@export var auto_frame_zoom_out: float = -12.0:
	set(value):
		auto_frame_zoom_out = value
		if _camera_rig:
			_camera_rig.auto_frame_zoom_out = value
## How fast the auto-framing adjusts.
@export var auto_frame_speed: float = 3.0:
	set(value):
		auto_frame_speed = value
		if _camera_rig:
			_camera_rig.auto_frame_speed = value
## Number of rays to cast for detecting nearby geometry.
@export var auto_frame_ray_count: int = 8:
	set(value):
		auto_frame_ray_count = value
		if _camera_rig:
			_camera_rig.auto_frame_ray_count = value
## Collision mask for auto-framing geometry detection.
@export_flags_3d_physics var auto_frame_mask: int = 1:
	set(value):
		auto_frame_mask = value
		if _camera_rig:
			_camera_rig.auto_frame_mask = value
#endregion


#region Idle Effects
@export_group("Idle Effects")
## Enable zoom out when player stops moving.
@export var idle_zoom_enabled: bool = true:
	set(value):
		idle_zoom_enabled = value
		if _camera_rig:
			_camera_rig.idle_zoom_enabled = value
## How much to zoom out when idle (negative = further from player).
@export var idle_zoom_amount: float = -4.0:
	set(value):
		idle_zoom_amount = value
		if _camera_rig:
			_camera_rig.idle_zoom_amount = value
## Seconds to wait after stopping before starting idle zoom.
@export var idle_zoom_delay: float = 0.1:
	set(value):
		idle_zoom_delay = value
		if _camera_rig:
			_camera_rig.idle_zoom_delay = value
## How fast to zoom out when idle (lower = slower, more cinematic).
@export var idle_zoom_speed: float = 0.3:
	set(value):
		idle_zoom_speed = value
		if _camera_rig:
			_camera_rig.idle_zoom_speed = value
## Idle shake modifier for subtle camera sway when player is idle.
@export var idle_shake_modifier: IdleShakeModifier:
	set(value):
		idle_shake_modifier = value
		if _camera_rig:
			_camera_rig.idle_shake_modifier = value
#endregion


#region Collision
@export_group("Collision")
## Enable collision for marker/zone cameras (pulls camera closer when blocked).
@export var collision_enabled: bool = true:
	set(value):
		collision_enabled = value
		if _camera_rig:
			_camera_rig.marker_collision_enabled = value
## Collision mask for camera blocking geometry.
@export_flags_3d_physics var collision_mask: int = 1:
	set(value):
		collision_mask = value
		if _camera_rig:
			_camera_rig.camera_collision_mask = value
## Margin from collision surface.
@export var collision_margin: float = 0.3:
	set(value):
		collision_margin = value
		if _camera_rig:
			_camera_rig.collision_margin = value
## How fast the camera pulls in when blocked.
@export var collision_speed: float = 15.0:
	set(value):
		collision_speed = value
		if _camera_rig:
			_camera_rig.collision_speed = value
## Minimum distance camera can get to player during collision.
@export var min_camera_distance: float = 1.5:
	set(value):
		min_camera_distance = value
		if _camera_rig:
			_camera_rig.min_camera_distance = value
## Distance at which the player model starts fading out.
@export var player_fade_distance: float = 2.0:
	set(value):
		player_fade_distance = value
		if _camera_rig:
			_camera_rig.player_fade_distance = value
## Hide player when camera is closer than this distance.
@export var player_hide_distance: float = 1.0:
	set(value):
		player_hide_distance = value
		if _camera_rig:
			_camera_rig.player_hide_distance = value
#endregion


#region Lens & DOF
@export_group("Lens & DOF")
## Enable depth of field blur.
@export var dof_enabled: bool = false:
	set(value):
		dof_enabled = value
		if _camera_rig:
			_camera_rig.dof_enabled = value
## Focus distance from camera. Set to 0 to auto-focus on player.
@export var focus_distance: float = 0.0:
	set(value):
		focus_distance = value
		if _camera_rig:
			_camera_rig.focus_distance = value
## DOF blur amount (0 = sharp, 1 = very blurry).
@export_range(0.0, 1.0) var dof_blur_amount: float = 0.1:
	set(value):
		dof_blur_amount = value
		if _camera_rig:
			_camera_rig.dof_blur_amount = value
#endregion


#region Transitions
@export_group("Transitions")
## Global multiplier for transition speed. Higher = faster transitions.
@export var transition_speed_mult: float = 1.0:
	set(value):
		transition_speed_mult = value
		if _camera_rig:
			_camera_rig.transition_speed_mult = value
## Percentage through transition when cursor should be re-enabled (0.0-1.0).
## Lower = cursor comes back sooner during transitions.
@export_range(0.0, 1.0) var cursor_reenable_percent: float = 0.5:
	set(value):
		cursor_reenable_percent = value
		if _camera_rig:
			_camera_rig.cursor_reenable_percent = value
#endregion


#region Debug
@export_group("Debug")
## Enable debug visualization (spheres for target/look-at, line to look target).
@export var debug_draw_enabled: bool = false:
	set(value):
		debug_draw_enabled = value
		if _camera_rig:
			_camera_rig.debug_draw_enabled = value
## Print debug info every frame during transitions (very spammy - use sparingly).
@export var debug_print_transitions: bool = false:
	set(value):
		debug_print_transitions = value
		if _camera_rig:
			_camera_rig.debug_print_transitions = value
#endregion


#region Camera Modifiers
@export_group("Camera Modifiers")
## Shake modifier for camera trauma/impact effects.
@export var shake_modifier: ShakeModifier:
	set(value):
		shake_modifier = value
		_update_stack_modifiers()
## Zoom modifier for FOV pulse effects.
@export var zoom_modifier: ZoomModifier:
	set(value):
		zoom_modifier = value
		_update_stack_modifiers()
## Framing modifier for position offset effects.
@export var framing_modifier: FramingModifier:
	set(value):
		framing_modifier = value
		_update_stack_modifiers()
#endregion


var _modifier_stack: CameraModifierStack
var _camera_rig: CameraRig
var _cursor: Cursor3D


func _ready() -> void:
	# Resolve template cameras.
	var tp_cam := get_node_or_null("ThirdPersonCamera") as Camera3D
	var fp_cam := get_node_or_null("FirstPersonCamera") as Camera3D
	if tp_cam:
		third_person_camera = tp_cam
		tp_cam.current = false  # Template only, never active.
	if fp_cam:
		first_person_camera = fp_cam
		fp_cam.current = false

	# Find cursor for panning.
	_cursor = get_node_or_null("Cursor3D") as Cursor3D

	# Find the camera rig and modifier stack.
	_camera_rig = get_node_or_null("CameraRig") as CameraRig
	if _camera_rig:
		if _camera_rig.modifier_stack:
			_modifier_stack = _camera_rig.modifier_stack
			_update_stack_modifiers()

		# Push all exported values down to the rig.
		_sync_all_to_rig()

		# Apply the default camera after the scene is fully ready.
		if third_person_camera:
			call_deferred("_apply_default_camera")


## Push all CameraSystem exports down to the CameraRig.
func _sync_all_to_rig() -> void:
	if not _camera_rig:
		return

	# Setup.
	_camera_rig.target = target
	_camera_rig.player_controller = player_controller
	_camera_rig.default_preset = default_preset

	# Pass template cameras to rig.
	_camera_rig.template_camera = third_person_camera
	_camera_rig.first_person_template = first_person_camera

	# Zoom.
	_camera_rig.min_zoom = min_zoom
	_camera_rig.max_zoom = max_zoom
	_camera_rig.zoom_step = zoom_step
	_camera_rig.zoom_speed = zoom_speed

	# Framing.
	_camera_rig.target_frame_offset = target_frame_offset

	# Auto Framing.
	_camera_rig.auto_frame_enabled = auto_frame_enabled
	_camera_rig.auto_frame_distance = auto_frame_distance
	_camera_rig.auto_frame_zoom_in = auto_frame_zoom_in
	_camera_rig.auto_frame_zoom_out = auto_frame_zoom_out
	_camera_rig.auto_frame_speed = auto_frame_speed
	_camera_rig.auto_frame_ray_count = auto_frame_ray_count
	_camera_rig.auto_frame_mask = auto_frame_mask

	# Idle Effects.
	_camera_rig.idle_zoom_enabled = idle_zoom_enabled
	_camera_rig.idle_zoom_amount = idle_zoom_amount
	_camera_rig.idle_zoom_delay = idle_zoom_delay
	_camera_rig.idle_zoom_speed = idle_zoom_speed
	if idle_shake_modifier:
		_camera_rig.idle_shake_modifier = idle_shake_modifier

	# Collision.
	_camera_rig.marker_collision_enabled = collision_enabled
	_camera_rig.camera_collision_mask = collision_mask
	_camera_rig.collision_margin = collision_margin
	_camera_rig.collision_speed = collision_speed
	_camera_rig.min_camera_distance = min_camera_distance
	_camera_rig.player_fade_distance = player_fade_distance
	_camera_rig.player_hide_distance = player_hide_distance

	# DOF.
	_camera_rig.dof_enabled = dof_enabled
	_camera_rig.focus_distance = focus_distance
	_camera_rig.dof_blur_amount = dof_blur_amount

	# Transitions.
	_camera_rig.transition_speed_mult = transition_speed_mult
	_camera_rig.cursor_reenable_percent = cursor_reenable_percent

	# Debug.
	_camera_rig.debug_draw_enabled = debug_draw_enabled
	_camera_rig.debug_print_transitions = debug_print_transitions


func _apply_default_camera() -> void:
	if not _camera_rig or not third_person_camera:
		return
	# Apply FOV from template camera.
	if third_person_camera.fov > 0:
		_camera_rig._target_fov = third_person_camera.fov
	_camera_rig.apply_template_camera()


func _update_stack_modifiers() -> void:
	if not _modifier_stack:
		return
	_modifier_stack.shake_modifier = shake_modifier
	_modifier_stack.zoom_modifier = zoom_modifier
	_modifier_stack.framing_modifier = framing_modifier


#region Cursor Panning

## Get clamped cursor position for camera look-at when aiming.
## Returns center_target if not aiming or cursor panning disabled.
func get_cursor_look_target(camera_pos: Vector3, center_target: Vector3) -> Vector3:
	if not cursor_panning_enabled:
		return center_target
	if not _cursor or not is_instance_valid(_cursor):
		return center_target
	if not _cursor.look_at_target:
		return center_target
	if not Input.is_action_pressed("aim"):
		return center_target

	var cursor_pos := _cursor.look_at_target.global_position

	# Direction from camera to center (player).
	var center_dir := (center_target - camera_pos).normalized()
	# Direction from camera to cursor.
	var cursor_dir := (cursor_pos - camera_pos).normalized()

	# Calculate angle between them.
	var dot := center_dir.dot(cursor_dir)
	var angle_rad := acos(clampf(dot, -1.0, 1.0))
	var max_angle_rad := deg_to_rad(max_cursor_angle)

	# Clamp angle to max and apply influence.
	var clamped_angle := minf(angle_rad, max_angle_rad) * cursor_influence

	if clamped_angle < 0.001:
		return center_target

	# Rotate center_dir toward cursor_dir by clamped angle.
	var axis := center_dir.cross(cursor_dir)
	if axis.length_squared() < 0.0001:
		return center_target
	axis = axis.normalized()
	var result_dir := center_dir.rotated(axis, clamped_angle)

	# Project to same distance as cursor for consistent look-at.
	var cursor_dist := camera_pos.distance_to(cursor_pos)
	return camera_pos + result_dir * cursor_dist


## Check if cursor panning is currently active.
func is_cursor_panning_active() -> bool:
	if not cursor_panning_enabled:
		return false
	if not _cursor or not is_instance_valid(_cursor):
		return false
	return Input.is_action_pressed("aim")

#endregion


#region Public API

## Get the CameraRig child node.
func get_camera_rig() -> CameraRig:
	return _camera_rig


## Get the active Camera3D.
func get_camera() -> Camera3D:
	return _camera_rig.get_camera() if _camera_rig else null


## Get the Cursor3D.
func get_cursor() -> Cursor3D:
	return _cursor


## Transition to a camera preset with optional position template.
func transition_to(preset: CameraPreset, template_camera: Camera3D = null, look_at_node: Node3D = null) -> void:
	if _camera_rig:
		_camera_rig.transition_to_template(preset, template_camera, look_at_node)


## Reset camera to the default preset.
func reset_to_default() -> void:
	if _camera_rig:
		_camera_rig.reset_to_default()


## Calculate movement direction based on camera orientation.
func calculate_move_direction(input: Vector2) -> Vector3:
	if _camera_rig:
		return _camera_rig.calculate_move_direction(input)
	return Vector3.ZERO

#endregion
