## Decoupled camera rig that follows a target character.
## NOT parented to the character — exists as a separate scene in the level.
## Supports smooth transitions between CameraPreset resources.
## Handles third-person, side-scroller, top-down, and first-person modes.
class_name CameraRig extends Node3D

#region Constants
## Dot product threshold for input direction change detection (~45 degrees).
const INPUT_DIRECTION_THRESHOLD := 0.7
## Squared velocity threshold to consider the player "moving".
const VELOCITY_MOVING_THRESHOLD := 0.1
## Minimum direction vector length for look_at operations.
const LOOK_DIRECTION_THRESHOLD := 0.001
## When direction Y component exceeds this, use alternate up vector.
const UP_VECTOR_THRESHOLD := 0.9
## Minimum squared input magnitude to register movement.
const INPUT_DEADZONE_SQ := 0.01
## Minimum difference to trigger zoom interpolation.
const ZOOM_THRESHOLD := 0.01
## Minimum FOV difference to trigger FOV interpolation.
const FOV_THRESHOLD := 0.1
## Minimum collision offset to apply position adjustment.
const COLLISION_OFFSET_THRESHOLD := 0.01
#endregion

## The character this camera follows.
@export var target: CharacterBody3D:
	set(value):
		if target != value:
			target = value
			if _collision_handler:
				_collision_handler.invalidate_mesh_cache()
## The default camera preset used when no zone overrides are active.
@export var default_preset: CameraPreset
## Reference to the player controller (for first-person mouse input).
@export var player_controller: PlayerController

@export_group("Zoom")
## Minimum zoom distance (closest to player).
@export var min_zoom: float = 2.0
## Maximum zoom distance (furthest from player).
@export var max_zoom: float = 15.0
## Zoom step per scroll wheel tick.
@export var zoom_step: float = 0.5
## Zoom smoothing speed.
@export var zoom_speed: float = 10.0
## Minimum FOV for marker mode zoom (zoomed in / telephoto ~85mm).
@export var min_fov: float = 35.0
## Maximum FOV for marker mode zoom (zoomed out / wide ~24mm).
@export var max_fov: float = 85.0
## FOV step per scroll wheel tick.
@export var fov_step: float = 5.0

@export_group("Framing")
## Offset applied to player position for look-at target (for cinematic framing).
@export var target_frame_offset: Vector3 = Vector3(0, 1.0, 0)

@export_group("Auto Framing")
## Enable automatic zoom based on nearby geometry (zoom in when open, out when near objects).
@export var auto_frame_enabled: bool = true:
	set(value):
		auto_frame_enabled = value
		if _auto_framer:
			_auto_framer.enabled = value
## Distance to check for nearby objects.
@export var auto_frame_distance: float = 5.0:
	set(value):
		auto_frame_distance = value
		if _auto_framer:
			_auto_framer.check_distance = value
## Zoom offset when area is completely open (positive = closer to player).
@export var auto_frame_zoom_in: float = 2.0:
	set(value):
		auto_frame_zoom_in = value
		if _auto_framer:
			_auto_framer.zoom_in = value
## Zoom offset when near objects (negative = further from player).
@export var auto_frame_zoom_out: float = -12.0:
	set(value):
		auto_frame_zoom_out = value
		if _auto_framer:
			_auto_framer.zoom_out = value
## How fast the auto-framing adjusts.
@export var auto_frame_speed: float = 3.0:
	set(value):
		auto_frame_speed = value
		if _auto_framer:
			_auto_framer.speed = value
## Number of rays to cast for detecting nearby geometry.
@export var auto_frame_ray_count: int = 8:
	set(value):
		auto_frame_ray_count = value
		if _auto_framer:
			_auto_framer.ray_count = value
## Collision mask for auto-framing detection.
@export_flags_3d_physics var auto_frame_mask: int = 1:
	set(value):
		auto_frame_mask = value
		if _auto_framer:
			_auto_framer.collision_mask = value

@export_group("Movement Zoom")
## Enable dynamic zoom based on movement speed.
@export var movement_zoom_enabled: bool = true:
	set(value):
		movement_zoom_enabled = value
		if _idle_effects:
			_idle_effects.zoom_enabled = value
## How much to zoom out when walking (negative = further from player).
@export var walk_zoom_amount: float = -2.0:
	set(value):
		walk_zoom_amount = value
		if _idle_effects:
			_idle_effects.walk_zoom_amount = value
## How much to zoom out when sprinting (negative = further from player).
@export var sprint_zoom_amount: float = -4.0:
	set(value):
		sprint_zoom_amount = value
		if _idle_effects:
			_idle_effects.sprint_zoom_amount = value
## How much to zoom in when idle (positive = closer to player).
@export var idle_zoom_amount: float = 0.0:
	set(value):
		idle_zoom_amount = value
		if _idle_effects:
			_idle_effects.idle_zoom_amount = value
## How long to wait after stopping before applying idle zoom.
@export var idle_zoom_delay: float = 0.5:
	set(value):
		idle_zoom_delay = value
		if _idle_effects:
			_idle_effects.idle_zoom_delay = value
## How fast to transition between zoom levels.
@export var movement_zoom_speed: float = 3.0:
	set(value):
		movement_zoom_speed = value
		if _idle_effects:
			_idle_effects.zoom_speed = value

@export_group("Aim Zoom")
## Enable zoom out when aiming.
@export var aim_zoom_enabled: bool = true
## How much to zoom out when aiming (negative = further from player).
@export var aim_zoom_amount: float = -2.0
## How fast to zoom in/out when aiming.
@export var aim_zoom_speed: float = 8.0

@export_group("Collision")
## Enable collision for marker/zone cameras (pulls camera closer when blocked).
@export var marker_collision_enabled: bool = false
## Collision mask for camera blocking geometry.
@export_flags_3d_physics var camera_collision_mask: int = 1:
	set(value):
		camera_collision_mask = value
		if _collision_handler:
			_collision_handler.collision_mask = value
## Margin from collision surface.
@export var collision_margin: float = 0.3:
	set(value):
		collision_margin = value
		if _collision_handler:
			_collision_handler.collision_margin = value
## How fast the camera pulls in when blocked.
@export var collision_speed: float = 15.0:
	set(value):
		collision_speed = value
		if _collision_handler:
			_collision_handler.collision_speed = value
## Minimum distance camera can get to player during collision.
@export var min_camera_distance: float = 5.0:
	set(value):
		min_camera_distance = value
		if _collision_handler:
			_collision_handler.min_camera_distance = value
## Distance at which the player model starts fading out.
@export var player_fade_distance: float = 2.0:
	set(value):
		player_fade_distance = value
		if _collision_handler:
			_collision_handler.player_fade_distance = value
## Hide player when camera is closer than this distance.
@export var player_hide_distance: float = 1.0:
	set(value):
		player_hide_distance = value
		if _collision_handler:
			_collision_handler.player_hide_distance = value

@export_group("Transitions")
## Global multiplier for transition speed. Higher = faster transitions.
@export var transition_speed_mult: float = 1.0
## Curve for transitioning INTO a zone/preset (entering). X=time(0-1), Y=progress(0-1).
@export var transition_curve_in: Curve
## Curve for transitioning OUT OF a zone/preset (exiting). X=time(0-1), Y=progress(0-1).
@export var transition_curve_out: Curve
## Percentage through transition when cursor should be re-enabled (0.0-1.0).
@export_range(0.0, 1.0) var cursor_reenable_percent: float = 0.5

## Emitted when the camera finishes transitioning to a new preset.
signal preset_changed(preset: CameraPreset)
## Emitted when entering or exiting first-person mode.
signal first_person_changed(enabled: bool)

var current_preset: CameraPreset
var is_transitioning: bool = false
var _transition_target: CameraPreset  # Preset we're transitioning TO.
var _transition_is_entering: bool = true  # True = entering zone (IN curve), False = exiting (OUT curve).
var _first_person_active: bool = false
var _fp_yaw: float = 0.0
var _fp_pitch: float = 0.0
var _active_tween: Tween
var _locked_direction: Vector3 = Vector3.ZERO  # Locked world-space direction during transitions.
var _last_input: Vector2 = Vector2.ZERO  # Previous frame's input for change detection.
var _camera_marker: Node3D  # Optional fixed camera position (Camera3D template or Marker3D from zone).
var _look_at_node: Node3D  # Optional look-at target (any Node3D).
var _target_zoom: float = 5.0  # Target spring arm length for smooth zoom.
var _target_fov: float = 50.0  # Target FOV for marker mode zoom (50mm default).
var _marker_offset: Vector3 = Vector3.ZERO  # Current marker offset (for follow mode).
var _default_follow_offset: Vector3 = Vector3.ZERO  # Initial offset from player (set at startup, reused on zone exit).
var _transition_start_pos: Vector3 = Vector3.ZERO  # Camera position at start of transition.
var _transition_progress: float = 0.0  # 0 to 1 progress through transition.
var _position_follow_only: bool = false  # When true, follow position but keep marker's rotation.
var _collision_offset: float = 0.0  # Current collision pull-in distance (0 = no collision).
var _marker_base_distance: float = 0.0  # Initial distance from marker to look target (for zoom).
var _cursor_reenabled_early: bool = false  # Track if cursor was re-enabled before transition end.
var _current_zoom: float = 0.0  # Current zoom offset (smoothly interpolates toward _target_zoom).
var _auto_frame_zoom: float = 0.0  # Current auto-framing zoom offset (from CameraAutoFramer).
var _movement_zoom: float = 0.0  # Current movement zoom offset (from CameraIdleEffects).
var _aim_zoom: float = 0.0  # Current aim zoom offset (smoothly interpolates when aiming).

## Template camera defining third-person view (set by CameraSystem).
var template_camera: Camera3D
## Template camera for first-person view (set by CameraSystem).
var first_person_template: Camera3D
## Reference to parent CameraSystem (for cursor panning).
var _camera_system: CameraSystem

## Assigned in _ready — NOT @onready because hierarchy may need building first.
var pivot: Node3D
var spring_arm: SpringArm3D
var camera: Camera3D

## Composition modules for focused responsibilities.
var _collision_handler: CameraCollisionHandler
var _auto_framer: CameraAutoFramer
var _idle_effects: CameraIdleEffects

## Debug visualization.
@export_group("Debug")
## Enable debug visualization (spheres for target/look-at, line to look target).
@export var debug_draw_enabled: bool = false
## Print debug info every frame during transitions (very spammy - use sparingly).
@export var debug_print_transitions: bool = false
var _debug_mesh: MeshInstance3D
var _debug_material: StandardMaterial3D
var _debug_target_sphere: MeshInstance3D
var _debug_lookat_sphere: MeshInstance3D


func _ready() -> void:
	if not has_node("Pivot"):
		_build_hierarchy()

	pivot = $Pivot
	spring_arm = $Pivot/SpringArm3D
	camera = $Pivot/SpringArm3D/Camera3D

	# Get parent CameraSystem for cursor panning.
	var parent := get_parent()
	if parent is CameraSystem:
		_camera_system = parent

	# Initialize composition modules.
	_collision_handler = CameraCollisionHandler.new()
	_collision_handler.configure(
		camera_collision_mask, collision_margin, collision_speed,
		min_camera_distance, player_fade_distance, player_hide_distance
	)

	_auto_framer = CameraAutoFramer.new()
	_auto_framer.configure(
		auto_frame_enabled, auto_frame_distance, auto_frame_zoom_in,
		auto_frame_zoom_out, auto_frame_speed, auto_frame_ray_count, auto_frame_mask
	)

	_idle_effects = CameraIdleEffects.new()
	_idle_effects.configure(movement_zoom_enabled, walk_zoom_amount, sprint_zoom_amount, idle_zoom_amount, idle_zoom_delay, movement_zoom_speed)

	# Initialize debug visualization.
	_setup_debug_visualization()

	if default_preset:
		current_preset = default_preset
		_target_zoom = default_preset.spring_length
		_target_fov = default_preset.fov
		_apply_preset_instant(default_preset)


func _physics_process(delta: float) -> void:
	if not target:
		return

	# Update auto-framing and idle effects via composition modules.
	_auto_frame_zoom = _auto_framer.update(delta, target, target_frame_offset, get_world_3d())
	_idle_effects.update(delta, target)
	_movement_zoom = _idle_effects.get_zoom_offset()

	# Update aim zoom - check if target has is_aiming property.
	_update_aim_zoom(delta)

	if _first_person_active:
		_update_first_person(delta)
	else:
		_update_third_person(delta)

	# Update debug visualization.
	_update_debug_visualization()


func _unhandled_input(event: InputEvent) -> void:
	if _first_person_active or is_transitioning:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed:
			var is_marker_mode := _camera_marker and is_instance_valid(_camera_marker)
			# Zoom always changes distance, never FOV.
			if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
				if is_marker_mode:
					# Marker mode: positive zoom = closer to target.
					_target_zoom = clampf(_target_zoom + zoom_step, -max_zoom, max_zoom)
				else:
					# Spring arm mode: smaller length = closer.
					_target_zoom = clampf(_target_zoom - zoom_step, min_zoom, max_zoom)
				get_viewport().set_input_as_handled()
			elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				if is_marker_mode:
					# Marker mode: negative zoom = further from target.
					_target_zoom = clampf(_target_zoom - zoom_step, -max_zoom, max_zoom)
				else:
					# Spring arm mode: larger length = further.
					_target_zoom = clampf(_target_zoom + zoom_step, min_zoom, max_zoom)
				get_viewport().set_input_as_handled()


#region Public API

## Transition to a preset with optional Camera3D template for position.
func transition_to_template(preset: CameraPreset, cam_template: Camera3D = null, look_at_node: Node3D = null) -> void:
	# Convert Camera3D to position marker for internal use.
	var marker_node: Node3D = cam_template if cam_template else template_camera
	if preset == current_preset and not is_transitioning and marker_node == _camera_marker:
		return
	_camera_marker = marker_node
	_look_at_node = look_at_node

	# Calculate offset from template camera position.
	if marker_node and target:
		if marker_node == template_camera and _default_follow_offset != Vector3.ZERO:
			_marker_offset = _default_follow_offset
		else:
			_marker_offset = marker_node.global_position - target.global_position
	elif marker_node:
		_marker_offset = marker_node.global_position

	var was_first_person := _first_person_active
	var was_fixed := current_preset and current_preset.fixed_rotation
	var entering_first_person := preset.is_first_person
	if _active_tween and _active_tween.is_valid():
		_active_tween.kill()
	# Lock current movement direction before transition starts.
	if _last_input.length_squared() > INPUT_DEADZONE_SQ and current_preset:
		_locked_direction = _calculate_raw_direction(_last_input)
	is_transitioning = true
	_transition_target = preset
	_cursor_reenabled_early = false
	# Disable cursor during camera transitions.
	if player_controller and player_controller.cursor:
		player_controller.cursor.set_active(false)
	_active_tween = create_tween()
	_active_tween.set_parallel(true)
	var dur := preset.transition_duration / transition_speed_mult
	if entering_first_person:
		_transition_to_first_person(preset, dur)
	elif _camera_marker:
		_transition_to_marker(preset, dur)
	elif was_first_person:
		_transition_from_first_person(preset, dur)
	else:
		_transition_third_person(preset, dur, was_fixed)
	_active_tween.chain().tween_callback(_on_transition_complete.bind(preset, entering_first_person))
	# Force immediate position update toward new target to prevent flash.
	if target and not entering_first_person and not _camera_marker:
		var target_pos := target.global_position + preset.offset
		global_position = global_position.lerp(target_pos, 0.3)
	_reset_all_interpolation()


## Transition method for zone cameras (accepts Camera3D or any Node3D as position template).
## is_entering: true = entering zone (uses IN curve), false = exiting (uses OUT curve).
func transition_to(preset: CameraPreset, camera_marker: Node3D = null, look_at_node: Node3D = null, is_entering: bool = true) -> void:
	_transition_is_entering = is_entering
	_camera_marker = camera_marker
	_look_at_node = look_at_node

	# If camera_marker is a Camera3D, pass it directly to transition_to_template.
	# Otherwise, calculate offset manually and use default template.
	var cam_template: Camera3D = camera_marker as Camera3D if camera_marker is Camera3D else null
	if cam_template:
		transition_to_template(preset, cam_template, look_at_node)
	else:
		# Non-Camera3D marker: calculate offset before calling template transition.
		if camera_marker and target:
			_marker_offset = camera_marker.global_position - target.global_position
		elif camera_marker:
			_marker_offset = camera_marker.global_position
		transition_to_template(preset, null, look_at_node)

	_camera_marker = camera_marker  # Restore marker after template call.


func apply_instant(preset: CameraPreset) -> void:
	_apply_preset_instant(preset)


## Reset camera to the default preset using the template camera.
## Always targets the player for smooth orbit transitions.
## This is an EXIT transition (uses OUT curve).
func reset_to_default() -> void:
	_position_follow_only = false
	_transition_is_entering = false  # Exiting zone = OUT curve.
	if not default_preset:
		push_warning("CameraRig.reset_to_default: No default_preset set!")
		return

	# Use player as look-at target for smooth orbit transition back to default.
	var look_at: Node3D = target if target and is_instance_valid(target) else null

	if template_camera and is_instance_valid(template_camera):
		transition_to_template(default_preset, template_camera, look_at)
	else:
		push_warning("CameraRig.reset_to_default: No template camera, using preset values only!")
		transition_to_template(default_preset, null, look_at)


## Apply the template camera immediately (called by CameraSystem on startup).
func apply_template_camera() -> void:
	if not template_camera:
		return

	_camera_marker = template_camera
	_look_at_node = null  # Always look at player; cursor panning handled by CameraSystem.

	# Store initial offset from player for consistent follow behavior.
	if target:
		_default_follow_offset = template_camera.global_position - target.global_position
	else:
		_default_follow_offset = template_camera.global_position
	_marker_offset = _default_follow_offset

	# Use FOV from template camera.
	_target_fov = template_camera.fov if template_camera.fov > 0 else (default_preset.fov if default_preset else 50.0)

	# Reset zoom offset for template mode.
	_target_zoom = 0.0
	_current_zoom = 0.0

	# Apply preset for template mode.
	if default_preset:
		_apply_preset_instant_for_marker(default_preset, 0.0)

	# Set camera position and rotation immediately.
	if default_preset and default_preset.follow_target and target:
		global_position = target.global_position + _marker_offset
	else:
		global_position = template_camera.global_position

	# Look at player on startup.
	if default_preset and default_preset.follow_target and target:
		var look_target := target.global_position + target_frame_offset
		var dir := look_target - camera.global_position
		if dir.length_squared() > LOOK_DIRECTION_THRESHOLD:
			var up := Vector3.FORWARD if absf(dir.normalized().y) > UP_VECTOR_THRESHOLD else Vector3.UP
			camera.look_at(look_target, up)
	else:
		camera.global_basis = template_camera.global_basis

	reset_physics_interpolation()
	camera.reset_physics_interpolation()


func get_camera() -> Camera3D:
	return camera


func get_input_mode() -> String:
	if current_preset:
		return current_preset.input_mode
	return "CAMERA_RELATIVE"


## Set position-follow-only mode (follow player position but don't auto-look at them).
func set_position_follow_only(enabled: bool) -> void:
	_position_follow_only = enabled


func calculate_move_direction(input: Vector2) -> Vector3:
	if not current_preset:
		_last_input = Vector2.ZERO
		_locked_direction = Vector3.ZERO
		return Vector3.ZERO

	# Check if input changed (different keys pressed, not just magnitude).
	var input_changed := _has_input_direction_changed(input, _last_input)
	_last_input = input

	# No input: clear lock and return zero.
	if input.length_squared() < INPUT_DEADZONE_SQ:
		_locked_direction = Vector3.ZERO
		return Vector3.ZERO

	# During transitions: use locked direction if we have one and input hasn't changed.
	if is_transitioning:
		if _locked_direction.length_squared() > INPUT_DEADZONE_SQ and not input_changed:
			return _locked_direction
		# Lock current direction if starting to move or input changed.
		_locked_direction = _calculate_raw_direction(input)
		return _locked_direction

	# Not transitioning: calculate fresh direction and clear lock.
	_locked_direction = Vector3.ZERO
	return _calculate_raw_direction(input)


func _calculate_raw_direction(input: Vector2) -> Vector3:
	match current_preset.input_mode:
		"CAMERA_RELATIVE":
			return _camera_relative_direction(input)
		"FIXED_AXIS":
			return _fixed_axis_direction(input)
		"WORLD":
			return _world_direction(input)
	return _camera_relative_direction(input)


func _has_input_direction_changed(new_input: Vector2, old_input: Vector2) -> bool:
	# Check if input direction changed (ignoring magnitude).
	var old_has_input := old_input.length_squared() > INPUT_DEADZONE_SQ
	var new_has_input := new_input.length_squared() > INPUT_DEADZONE_SQ

	# Started or stopped moving.
	if old_has_input != new_has_input:
		return true

	# Both have input: check for key combination changes.
	if old_has_input and new_has_input:
		# Check if which keys are pressed changed (not just the angle).
		# If a new axis became active or an axis was released, that's a key change.
		var old_has_x := absf(old_input.x) > 0.1
		var new_has_x := absf(new_input.x) > 0.1
		var old_has_y := absf(old_input.y) > 0.1
		var new_has_y := absf(new_input.y) > 0.1

		# New key pressed (axis wasn't active before, now is).
		if (new_has_x and not old_has_x) or (new_has_y and not old_has_y):
			return true

		# Key released (axis was active, now isn't).
		if (old_has_x and not new_has_x) or (old_has_y and not new_has_y):
			return true

		# Check if direction on same axis flipped (e.g., left to right).
		if old_has_x and new_has_x and signf(old_input.x) != signf(new_input.x):
			return true
		if old_has_y and new_has_y and signf(old_input.y) != signf(new_input.y):
			return true

	return false

#endregion


#region Aim Zoom

func _update_aim_zoom(delta: float) -> void:
	if not aim_zoom_enabled:
		_aim_zoom = lerpf(_aim_zoom, 0.0, 1.0 - exp(-aim_zoom_speed * delta))
		return

	# Check if target has is_aiming property (RenegadeCharacter).
	var is_aiming := false
	if target and "is_aiming" in target:
		is_aiming = target.is_aiming

	var target_aim_zoom := aim_zoom_amount if is_aiming else 0.0
	_aim_zoom = lerpf(_aim_zoom, target_aim_zoom, 1.0 - exp(-aim_zoom_speed * delta))

#endregion


#region Third Person Update

func _update_third_person(delta: float) -> void:
	if not current_preset:
		return

	# Marker mode: camera stays at marker, looks at target (used by zones AND default camera).
	if _camera_marker and is_instance_valid(_camera_marker):
		_update_marker_camera(delta)
		return

	# Standard third-person follow mode (no marker).
	# Use the transition target preset during transitions for smooth position follow.
	var active_preset := _transition_target if is_transitioning and _transition_target else current_preset
	# Always follow position smoothly (even during transitions).
	var target_pos := target.global_position + active_preset.offset
	global_position = global_position.lerp(target_pos, 1.0 - exp(-active_preset.follow_speed * delta))

	# Smooth zoom interpolation (always runs, even during transitions).
	# For spring arm: subtract dynamic zoom offset (positive = closer = shorter arm).
	# Compose auto-frame and idle zoom by taking whichever pushes camera further out.
	# Aim zoom is additive on top (intentional player action always applies).
	var dynamic_zoom_offset := minf(_auto_frame_zoom, _movement_zoom)
	var effective_zoom := _target_zoom - dynamic_zoom_offset - _aim_zoom
	effective_zoom = clampf(effective_zoom, min_zoom, max_zoom)
	var is_zooming := absf(spring_arm.spring_length - effective_zoom) > ZOOM_THRESHOLD
	if is_zooming:
		spring_arm.spring_length = lerpf(spring_arm.spring_length, effective_zoom, 1.0 - exp(-zoom_speed * delta))
		spring_arm.reset_physics_interpolation()

	# Don't touch rotation during transitions — let the tween drive it.
	if is_transitioning:
		return
	if not current_preset.fixed_rotation:
		var target_yaw := target.global_rotation.y + deg_to_rad(current_preset.yaw_offset)
		pivot.rotation.y = lerp_angle(pivot.rotation.y, target_yaw, 1.0 - exp(-current_preset.rotation_speed * delta))

	# Only adjust camera look-at when actively zooming to keep character centered.
	# Otherwise let the spring arm control orientation (no lag).
	if is_zooming:
		var look_point := target.global_position + target_frame_offset
		var dir := (look_point - camera.global_position).normalized()
		if dir.length_squared() > LOOK_DIRECTION_THRESHOLD:
			var target_basis := Basis.looking_at(dir, Vector3.UP)
			camera.global_basis = camera.global_basis.slerp(target_basis, 1.0 - exp(-zoom_speed * delta))


func _update_marker_camera(delta: float) -> void:
	# Use the transition target preset during transitions, otherwise current preset.
	var active_preset := _transition_target if is_transitioning and _transition_target else current_preset
	var follow_speed := active_preset.follow_speed if active_preset else 8.0

	# Calculate current target position (base marker position).
	var base_pos: Vector3
	if active_preset and active_preset.follow_target and target:
		# Follow mode: marker offset is relative to player.
		base_pos = target.global_position + _marker_offset
	else:
		# Fixed mode: camera at marker's world position.
		base_pos = _camera_marker.global_position

	# Smooth zoom interpolation (distance-based, not FOV).
	_current_zoom = lerpf(_current_zoom, _target_zoom, 1.0 - exp(-zoom_speed * delta))

	# Calculate look target for zoom direction.
	var player_center := target.global_position + target_frame_offset if target else base_pos
	var zoom_target := player_center
	if _look_at_node and is_instance_valid(_look_at_node):
		zoom_target = _look_at_node.global_position if _look_at_node != target else player_center

	# Apply zoom offset along the direction toward the look target.
	# Compose auto-frame and idle zoom - whichever pushes camera further out wins.
	# Aim zoom is additive on top (intentional player action always applies).
	var dynamic_zoom_offset := minf(_auto_frame_zoom, _movement_zoom)
	var total_zoom := _current_zoom + dynamic_zoom_offset + _aim_zoom
	var target_pos := base_pos
	if absf(total_zoom) > ZOOM_THRESHOLD:
		var zoom_dir := (zoom_target - base_pos).normalized()
		target_pos = base_pos + zoom_dir * total_zoom

	if is_transitioning and active_preset and active_preset.follow_target:
		# TWEEN MODE: Interpolate from start to current target using tween progress.
		# Apply dynamic zoom to the transition endpoint so auto-frame works during transitions.
		var current_end := target.global_position + _marker_offset
		if absf(total_zoom) > ZOOM_THRESHOLD:
			var zoom_dir := (zoom_target - current_end).normalized()
			current_end = current_end + zoom_dir * total_zoom
		global_position = _transition_start_pos.lerp(current_end, _transition_progress)
	elif not is_transitioning:
		# After transition: smoothly lerp position to track.
		global_position = global_position.lerp(target_pos, 1.0 - exp(-follow_speed * delta))

	# Collision detection: pull camera closer when blocked by geometry.
	if marker_collision_enabled and target and not is_transitioning:
		_collision_offset = _collision_handler.update_collision(
			delta, target, target_pos, target_frame_offset, get_world_3d()
		)
		if _collision_offset > COLLISION_OFFSET_THRESHOLD:
			var direction := (target_pos - (target.global_position + target_frame_offset)).normalized()
			global_position = target_pos - direction * _collision_offset
		# Update player visibility based on final camera distance.
		_collision_handler.update_player_visibility(target, global_position, target_frame_offset)

	# Smooth FOV interpolation (only for preset changes, not zoom).
	if absf(camera.fov - _target_fov) > FOV_THRESHOLD:
		camera.fov = lerpf(camera.fov, _target_fov, 1.0 - exp(-zoom_speed * delta))
		camera.reset_physics_interpolation()

	# Handle rotation - determine look target.
	var look_target: Vector3 = player_center

	# During transitions, always use _look_at_node (the player) for smooth orbit.
	if is_transitioning and _look_at_node and is_instance_valid(_look_at_node):
		if _look_at_node == target:
			look_target = player_center
		else:
			look_target = _look_at_node.global_position
	elif _camera_marker == template_camera and _camera_system:
		# Default camera: cursor panning via CameraSystem (only when not transitioning).
		look_target = _camera_system.get_cursor_look_target(camera.global_position, player_center)
	elif _look_at_node and is_instance_valid(_look_at_node):
		# Zone cameras: use their explicit look_at_node.
		if _look_at_node == target:
			look_target = player_center
		else:
			look_target = _look_at_node.global_position

	var dir := look_target - camera.global_position
	if dir.length_squared() > LOOK_DIRECTION_THRESHOLD:
		var up := Vector3.FORWARD if absf(dir.normalized().y) > UP_VECTOR_THRESHOLD else Vector3.UP
		var target_basis := Basis.looking_at(dir, up)

		# During transitions, lock instantly to target - no lag.
		# After transition, use smooth rotation for natural camera feel.
		if is_transitioning:
			camera.global_basis = target_basis
		else:
			var rot_speed := 6.0 * transition_speed_mult
			camera.global_basis = camera.global_basis.slerp(target_basis, 1.0 - exp(-rot_speed * delta))

	# Re-enable cursor early during transition (before it fully completes).
	if is_transitioning and not _cursor_reenabled_early and _transition_progress >= cursor_reenable_percent:
		if not _first_person_active and player_controller and player_controller.cursor:
			player_controller.cursor.set_active(true)
			_cursor_reenabled_early = true

	# Idle effects are handled by _idle_effects composition module.
	camera.reset_physics_interpolation()

#endregion


#region First Person Update

func _update_first_person(_delta: float) -> void:
	if not current_preset:
		return
	# Use first_person_template position if available, otherwise use preset's head_offset.
	var head_offset := _get_head_offset()
	global_position = target.global_position + head_offset
	if player_controller:
		var look := player_controller.get_look_delta()
		_fp_yaw -= look.x * current_preset.mouse_sensitivity * 0.001
		_fp_pitch -= look.y * current_preset.mouse_sensitivity * 0.001
		_fp_pitch = clampf(_fp_pitch, deg_to_rad(current_preset.min_pitch), deg_to_rad(current_preset.max_pitch))
	pivot.rotation.y = _fp_yaw
	spring_arm.rotation.x = _fp_pitch


## Get head offset from first_person_template if set, otherwise from preset.
func _get_head_offset() -> Vector3:
	if first_person_template and is_instance_valid(first_person_template):
		return first_person_template.position
	if current_preset:
		return current_preset.head_offset
	return Vector3(0, 1.7, 0)

#endregion


#region Movement Direction Calculation

func _camera_relative_direction(input: Vector2) -> Vector3:
	var cam_transform := camera.global_transform
	var forward := -cam_transform.basis.z
	var right := cam_transform.basis.x
	forward.y = 0.0
	right.y = 0.0
	if forward.length_squared() < 0.001:
		forward = -cam_transform.basis.y
		forward.y = 0.0
	forward = forward.normalized()
	right = right.normalized()
	var dir := right * input.x + forward * (-input.y)
	return dir.normalized() if dir.length_squared() > INPUT_DEADZONE_SQ else Vector3.ZERO


func _fixed_axis_direction(input: Vector2) -> Vector3:
	var forward := current_preset.fixed_forward.normalized()
	var right := current_preset.fixed_right.normalized()
	var dir := right * input.x + forward * (-input.y)
	return dir.normalized() if dir.length_squared() > INPUT_DEADZONE_SQ else Vector3.ZERO


func _world_direction(input: Vector2) -> Vector3:
	var dir := Vector3(input.x, 0.0, input.y)
	return dir.normalized() if dir.length_squared() > INPUT_DEADZONE_SQ else Vector3.ZERO

#endregion


#region Transitions

## Apply transition curve to a PropertyTweener.
## Priority: 1) CameraRig's curve, 2) preset's curve, 3) default ease-out expo.
func _apply_curve(tweener: PropertyTweener) -> PropertyTweener:
	var curve := _get_active_curve()
	if curve:
		# Ensure curve starts at 0 and ends at 1 to avoid jolts.
		return tweener.from_current().set_custom_interpolator(func(t: float) -> float:
			return curve.sample_baked(t)
		)
	return tweener.from_current().set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)


## Get the active transition curve based on direction (entering vs exiting).
## Priority: 1) CameraRig's in/out curve, 2) preset's in/out curve, 3) null (use default).
func _get_active_curve() -> Curve:
	if _transition_is_entering:
		# Entering a zone - use IN curves.
		if transition_curve_in:
			return transition_curve_in
		if _transition_target and _transition_target.transition_curve_in:
			return _transition_target.transition_curve_in
	else:
		# Exiting a zone - use OUT curves.
		if transition_curve_out:
			return transition_curve_out
		if _transition_target and _transition_target.transition_curve_out:
			return _transition_target.transition_curve_out
	return null


func _transition_third_person(preset: CameraPreset, dur: float, from_fixed: bool = false) -> void:
	# Disable collision during transition to prevent camera snapping.
	spring_arm.collision_mask = 0
	# Update target zoom to match preset (user can still override with scroll wheel).
	_target_zoom = preset.spring_length
	_apply_curve(_active_tween.tween_property(spring_arm, "spring_length", preset.spring_length, dur))
	_apply_curve(_active_tween.tween_property(spring_arm, "rotation:x", deg_to_rad(preset.pitch), dur))
	_apply_curve(_active_tween.tween_property(camera, "fov", preset.fov, dur))
	# Reset camera local rotation (may have been set by marker mode's look_at).
	_apply_curve(_active_tween.tween_property(camera, "rotation", Vector3.ZERO, dur))
	if preset.fixed_rotation:
		# Entering a fixed-rotation zone: tween to the fixed yaw.
		_apply_curve(_active_tween.tween_property(pivot, "rotation:y", deg_to_rad(preset.fixed_yaw), dur))
	elif from_fixed:
		# Exiting a fixed-rotation zone back to free-follow:
		# Tween yaw toward the player's current facing so it doesn't snap.
		var target_yaw := target.global_rotation.y if target else 0.0
		_apply_curve(_active_tween.tween_property(pivot, "rotation:y", target_yaw, dur))
	# Re-enable collision at end of transition via callback (chained after all parallel tweens).
	_active_tween.chain().tween_callback(func(): spring_arm.collision_mask = 1 if preset.use_collision else 0)


func _transition_to_first_person(preset: CameraPreset, dur: float) -> void:
	_fp_yaw = pivot.rotation.y
	_fp_pitch = spring_arm.rotation.x
	# Use first_person_template position if available.
	var head_offset := first_person_template.position if first_person_template else preset.head_offset
	var head_pos := target.global_position + head_offset
	_apply_curve(_active_tween.tween_property(spring_arm, "spring_length", 0.0, dur))
	_apply_curve(_active_tween.tween_property(self, "global_position", head_pos, dur))
	_apply_curve(_active_tween.tween_property(camera, "fov", preset.fov, dur))
	spring_arm.collision_mask = 0


func _transition_from_first_person(preset: CameraPreset, dur: float) -> void:
	# Disable collision during transition to prevent camera snapping.
	spring_arm.collision_mask = 0
	# Update target zoom to match preset.
	_target_zoom = preset.spring_length
	_apply_curve(_active_tween.tween_property(spring_arm, "spring_length", preset.spring_length, dur))
	_apply_curve(_active_tween.tween_property(spring_arm, "rotation:x", deg_to_rad(preset.pitch), dur))
	_apply_curve(_active_tween.tween_property(camera, "fov", preset.fov, dur))
	# Reset camera local rotation (may have been set by marker mode's look_at).
	_apply_curve(_active_tween.tween_property(camera, "rotation", Vector3.ZERO, dur))
	# Tween yaw back to player facing (or fixed yaw) so it doesn't snap.
	if preset.fixed_rotation:
		_apply_curve(_active_tween.tween_property(pivot, "rotation:y", deg_to_rad(preset.fixed_yaw), dur))
	else:
		var target_yaw := target.global_rotation.y if target else 0.0
		_apply_curve(_active_tween.tween_property(pivot, "rotation:y", target_yaw, dur))
	# Re-enable collision at end of transition.
	_active_tween.chain().tween_callback(func(): spring_arm.collision_mask = 1 if preset.use_collision else 0)


func _transition_to_marker(preset: CameraPreset, dur: float) -> void:
	# Transition to a marker/template position (fixed or follow mode).
	spring_arm.collision_mask = 0
	# Use template camera's FOV if available, otherwise use preset.
	var marker_fov := preset.fov
	if _camera_marker is Camera3D and _camera_marker.fov > 0:
		marker_fov = _camera_marker.fov
	_target_fov = marker_fov

	# Reset zoom offset for marker mode (zoom moves camera, not changes FOV).
	_target_zoom = 0.0
	_current_zoom = 0.0

	# IMMEDIATELY collapse spring arm and reset rotations.
	# This ensures camera world position = rig position for clean transitions.
	# First, move rig to camera's current world position so the snap doesn't cause a visual pop.
	var camera_world_pos := camera.global_position
	spring_arm.spring_length = 0.0
	spring_arm.rotation = Vector3.ZERO
	pivot.rotation = Vector3.ZERO
	global_position = camera_world_pos

	# Tween FOV.
	_apply_curve(_active_tween.tween_property(camera, "fov", marker_fov, dur))

	if preset.follow_target and target:
		# FOLLOW MODE: Camera moves from current position to target position.
		_transition_start_pos = camera_world_pos
		_transition_progress = 0.0
		# TWEEN MODE: Time-based transition.
		_apply_curve(_active_tween.tween_property(self, "_transition_progress", 1.0, dur))
		# Note: position is updated in _update_marker_camera using _transition_progress
	else:
		# FIXED MODE: Tween position to fixed marker location.
		# Rotation is handled by slerp in _update_marker_camera to track player movement.
		var target_pos := _camera_marker.global_position
		_apply_curve(_active_tween.tween_property(self, "global_position", target_pos, dur))

#endregion


#region Internal

func _on_transition_complete(preset: CameraPreset, is_fp: bool) -> void:
	current_preset = preset
	is_transitioning = false
	_transition_target = null
	_active_tween = null
	if is_fp != _first_person_active:
		_first_person_active = is_fp
		if player_controller:
			player_controller.set_first_person(is_fp)
		first_person_changed.emit(is_fp)
	elif not _first_person_active and not _cursor_reenabled_early and player_controller and player_controller.cursor:
		# Re-enable cursor after third-person to third-person transition (if not already enabled).
		player_controller.cursor.set_active(true)
	# Reset physics interpolation to prevent flash frame after transition.
	_reset_all_interpolation()
	preset_changed.emit(preset)


func _apply_preset_instant(preset: CameraPreset) -> void:
	current_preset = preset
	if preset.is_first_person:
		spring_arm.spring_length = 0.0
		spring_arm.collision_mask = 0
		_first_person_active = true
		_fp_yaw = 0.0
		_fp_pitch = 0.0
		if target:
			# Use first_person_template position if available.
			var head_offset := first_person_template.position if first_person_template else preset.head_offset
			global_position = target.global_position + head_offset
		if player_controller:
			player_controller.set_first_person(true)
		first_person_changed.emit(true)
	else:
		_target_zoom = preset.spring_length
		spring_arm.spring_length = preset.spring_length
		spring_arm.rotation.x = deg_to_rad(preset.pitch)
		spring_arm.collision_mask = 1 if preset.use_collision else 0
		camera.fov = preset.fov
		_first_person_active = false
		if preset.fixed_rotation:
			pivot.rotation.y = deg_to_rad(preset.fixed_yaw)
		if player_controller:
			player_controller.set_first_person(false)
		first_person_changed.emit(false)
	# Reset physics interpolation to prevent flash frame.
	_reset_all_interpolation()
	preset_changed.emit(preset)


## Apply preset but preserve marker-based zoom distance (used for follow offset mode).
func _apply_preset_instant_for_marker(preset: CameraPreset, marker_distance: float) -> void:
	current_preset = preset
	# Preserve marker distance instead of using preset.spring_length.
	_target_zoom = marker_distance
	# Reset all intermediate transforms for follow offset mode.
	# Camera position is calculated directly on the rig, so children should be at origin.
	pivot.transform = Transform3D.IDENTITY
	spring_arm.transform = Transform3D.IDENTITY
	spring_arm.spring_length = 0.0
	spring_arm.collision_mask = 0
	camera.transform = Transform3D.IDENTITY
	camera.fov = preset.fov
	_first_person_active = false
	if player_controller:
		player_controller.set_first_person(false)
	first_person_changed.emit(false)
	# Reset physics interpolation to prevent flash frame.
	_reset_all_interpolation()
	preset_changed.emit(preset)


## Reset physics interpolation on all camera nodes to prevent visual pops.
func _reset_all_interpolation() -> void:
	reset_physics_interpolation()
	if pivot:
		pivot.reset_physics_interpolation()
	if spring_arm:
		spring_arm.reset_physics_interpolation()
	if camera:
		camera.reset_physics_interpolation()


func _build_hierarchy() -> void:
	pivot = Node3D.new()
	pivot.name = "Pivot"
	add_child(pivot)
	spring_arm = SpringArm3D.new()
	spring_arm.name = "SpringArm3D"
	spring_arm.spring_length = 5.0
	spring_arm.collision_mask = 1
	spring_arm.margin = 0.2
	pivot.add_child(spring_arm)
	camera = Camera3D.new()
	camera.name = "Camera3D"
	spring_arm.add_child(camera)

#endregion


#region Debug Visualization

func _setup_debug_visualization() -> void:
	# Line mesh for camera-to-target visualization.
	_debug_mesh = MeshInstance3D.new()
	_debug_mesh.name = "_DebugLine"
	_debug_mesh.mesh = ImmediateMesh.new()
	_debug_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	get_tree().root.add_child.call_deferred(_debug_mesh)

	_debug_material = StandardMaterial3D.new()
	_debug_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_debug_material.albedo_color = Color(1.0, 0.0, 1.0, 1.0)  # Magenta.
	_debug_material.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED

	# Target sphere (green).
	_debug_target_sphere = _create_debug_sphere(Color(0.0, 1.0, 0.0), 0.3)
	get_tree().root.add_child.call_deferred(_debug_target_sphere)

	# Look-at sphere (cyan).
	_debug_lookat_sphere = _create_debug_sphere(Color(0.0, 1.0, 1.0), 0.25)
	get_tree().root.add_child.call_deferred(_debug_lookat_sphere)


func _create_debug_sphere(color: Color, radius: float) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	mesh_instance.mesh = sphere
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mesh_instance.material_override = mat
	return mesh_instance


func _update_debug_visualization() -> void:
	if not debug_draw_enabled:
		if _debug_mesh:
			_debug_mesh.visible = false
		if _debug_target_sphere:
			_debug_target_sphere.visible = false
		if _debug_lookat_sphere:
			_debug_lookat_sphere.visible = false
		return

	# Wait until debug nodes are in the scene tree.
	if not _debug_mesh or not _debug_mesh.is_inside_tree():
		return
	if not _debug_target_sphere or not _debug_target_sphere.is_inside_tree():
		return
	if not _debug_lookat_sphere or not _debug_lookat_sphere.is_inside_tree():
		return

	_debug_mesh.visible = true
	_debug_target_sphere.visible = true
	_debug_lookat_sphere.visible = true

	# Position target sphere at player (green).
	var player_center := Vector3.ZERO
	if target:
		player_center = target.global_position + target_frame_offset
		_debug_target_sphere.global_position = player_center

	# Calculate the actual look target used in _update_marker_camera (cyan sphere).
	var actual_look_target := player_center
	if _camera_marker and is_instance_valid(_camera_marker):
		# Mirror the logic from _update_marker_camera.
		if is_transitioning and _look_at_node and is_instance_valid(_look_at_node):
			if _look_at_node == target:
				actual_look_target = player_center
			else:
				actual_look_target = _look_at_node.global_position
		elif _camera_marker == template_camera and _camera_system:
			actual_look_target = _camera_system.get_cursor_look_target(camera.global_position, player_center)
		elif _look_at_node and is_instance_valid(_look_at_node):
			if _look_at_node == target:
				actual_look_target = player_center
			else:
				actual_look_target = _look_at_node.global_position

	if _debug_lookat_sphere:
		_debug_lookat_sphere.global_position = actual_look_target

	# Draw line from camera to look target.
	if _debug_mesh and _debug_mesh.mesh is ImmediateMesh and camera:
		var im: ImmediateMesh = _debug_mesh.mesh
		im.clear_surfaces()

		var cam_pos := camera.global_position
		im.surface_begin(Mesh.PRIMITIVE_LINES, _debug_material)
		im.surface_add_vertex(cam_pos)
		im.surface_add_vertex(actual_look_target)
		im.surface_end()

	# Print debug info during transitions.
	if is_transitioning and debug_print_transitions:
		var active_preset := _transition_target if _transition_target else current_preset
		print("[CameraRig] TRANSITIONING:")
		print("  target (player): %s" % (target.name if target else "NULL"))
		print("  _look_at_node: %s" % (_look_at_node.name if _look_at_node else "NULL"))
		print("  _camera_marker: %s" % (_camera_marker.name if _camera_marker else "NULL"))
		print("  template_camera: %s" % (template_camera.name if template_camera else "NULL"))
		print("  _camera_marker == template_camera: %s" % (_camera_marker == template_camera))
		print("  active_preset: %s" % (active_preset.preset_name if active_preset else "NULL"))
		print("  active_preset.follow_target: %s" % (active_preset.follow_target if active_preset else "N/A"))
		print("  actual_look_target: %s" % actual_look_target)
		print("  _transition_progress: %.2f" % _transition_progress)

#endregion
