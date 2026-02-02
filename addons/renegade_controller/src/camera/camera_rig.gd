## Decoupled camera rig that follows a target character.
## NOT parented to the character — exists as a separate scene in the level.
## Supports smooth transitions between CameraPreset resources.
## Handles third-person, side-scroller, top-down, and first-person modes.
class_name CameraRig extends Node3D

## The character this camera follows.
@export var target: CharacterBody3D
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
## Minimum FOV for marker mode zoom (zoomed in).
@export var min_fov: float = 30.0
## Maximum FOV for marker mode zoom (zoomed out).
@export var max_fov: float = 90.0
## FOV step per scroll wheel tick.
@export var fov_step: float = 5.0

## Emitted when the camera finishes transitioning to a new preset.
signal preset_changed(preset: CameraPreset)
## Emitted when entering or exiting first-person mode.
signal first_person_changed(enabled: bool)

var current_preset: CameraPreset
var is_transitioning: bool = false
var _transition_target: CameraPreset  # Preset we're transitioning TO.
var _first_person_active: bool = false
var _fp_yaw: float = 0.0
var _fp_pitch: float = 0.0
var _active_tween: Tween
var _locked_direction: Vector3 = Vector3.ZERO  # Locked world-space direction during transitions.
var _last_input: Vector2 = Vector2.ZERO  # Previous frame's input for change detection.
var _camera_marker: Marker3D  # Optional fixed camera position (from zone).
var _look_at_node: Node3D  # Optional look-at target (any Node3D).
var _target_zoom: float = 5.0  # Target spring arm length for smooth zoom.
var _target_fov: float = 75.0  # Target FOV for marker mode zoom.
var _marker_offset: Vector3 = Vector3.ZERO  # Current marker offset (for follow mode).
var _default_follow_offset: Vector3 = Vector3.ZERO  # Initial offset from player (set at startup, reused on zone exit).
var _transition_start_pos: Vector3 = Vector3.ZERO  # Camera position at start of transition.
var _transition_progress: float = 0.0  # 0 to 1 progress through transition.

## Default camera marker (set by CameraSystem for editor-adjustable positioning).
var default_camera_marker: Marker3D
## First-person camera marker (set by CameraSystem for editor-adjustable head position).
var first_person_marker: Marker3D

## Assigned in _ready — NOT @onready because hierarchy may need building first.
var pivot: Node3D
var spring_arm: SpringArm3D
var modifier_stack: CameraModifierStack
var camera: Camera3D


func _ready() -> void:
	if not has_node("Pivot"):
		_build_hierarchy()
	
	pivot = $Pivot
	spring_arm = $Pivot/SpringArm3D
	modifier_stack = $Pivot/SpringArm3D/CameraModifierStack
	camera = $Pivot/SpringArm3D/CameraModifierStack/Camera3D
	modifier_stack.camera = camera

	if default_preset:
		current_preset = default_preset
		_target_zoom = default_preset.spring_length
		_target_fov = default_preset.fov
		_apply_preset_instant(default_preset)


func _physics_process(delta: float) -> void:
	if not target:
		return
	if _first_person_active:
		_update_first_person(delta)
	else:
		_update_third_person(delta)


func _unhandled_input(event: InputEvent) -> void:
	if _first_person_active or is_transitioning:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed:
			# Use FOV zoom for marker mode, distance zoom for standard third-person.
			var is_marker_mode := _camera_marker and is_instance_valid(_camera_marker)
			if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
				if is_marker_mode:
					_target_fov = clampf(_target_fov - fov_step, min_fov, max_fov)
				else:
					_target_zoom = clampf(_target_zoom - zoom_step, min_zoom, max_zoom)
				get_viewport().set_input_as_handled()
			elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				if is_marker_mode:
					_target_fov = clampf(_target_fov + fov_step, min_fov, max_fov)
				else:
					_target_zoom = clampf(_target_zoom + zoom_step, min_zoom, max_zoom)
				get_viewport().set_input_as_handled()


#region Public API

func transition_to(preset: CameraPreset, camera_marker: Marker3D = null, look_at_node: Node3D = null) -> void:
	# Debug: Log transition details.
	if camera_marker:
		print("CameraRig.transition_to: Using marker at ", camera_marker.global_position)
	else:
		print("CameraRig.transition_to: No marker, using preset values (offset=", preset.offset if preset else "null", ")")

	if preset == current_preset and not is_transitioning and camera_marker == _camera_marker:
		print("CameraRig.transition_to: Early return - already at this state")
		return
	_camera_marker = camera_marker
	_look_at_node = look_at_node
	# Calculate offset as difference between marker's global position and player's global position.
	# This ensures the camera starts at marker's exact world position when follow_target is true.
	if camera_marker and target:
		# When returning to the default marker, use the stored startup offset for consistency.
		if camera_marker == default_camera_marker and _default_follow_offset != Vector3.ZERO:
			_marker_offset = _default_follow_offset
			print("CameraRig.transition_to: Using stored _default_follow_offset=", _default_follow_offset)
		else:
			_marker_offset = camera_marker.global_position - target.global_position
	elif camera_marker:
		_marker_offset = camera_marker.global_position
	var was_first_person := _first_person_active
	var was_fixed := current_preset and current_preset.fixed_rotation
	var entering_first_person := preset.is_first_person
	if _active_tween and _active_tween.is_valid():
		_active_tween.kill()
	# Lock current movement direction before transition starts.
	if _last_input.length_squared() > 0.01 and current_preset:
		_locked_direction = _calculate_raw_direction(_last_input)
	is_transitioning = true
	_transition_target = preset
	# Disable cursor during camera transitions.
	if player_controller and player_controller.cursor:
		player_controller.cursor.set_active(false)
	_active_tween = create_tween()
	_active_tween.set_parallel(true)
	var dur := preset.transition_duration
	var trans := preset.transition_type
	var ease := preset.ease_type
	if entering_first_person:
		_transition_to_first_person(preset, dur, trans, ease)
	elif _camera_marker:
		# Marker mode takes priority - use marker position regardless of previous mode.
		_transition_to_marker(preset, dur, trans, ease)
	elif was_first_person:
		_transition_from_first_person(preset, dur, trans, ease)
	else:
		_transition_third_person(preset, dur, trans, ease, was_fixed)
	_active_tween.chain().tween_callback(_on_transition_complete.bind(preset, entering_first_person))
	# Force immediate position update toward new target to prevent flash.
	if target and not entering_first_person and not _camera_marker:
		var target_pos := target.global_position + preset.offset
		global_position = global_position.lerp(target_pos, 0.3)
	# Prevent physics interpolation from showing old camera state.
	reset_physics_interpolation()
	pivot.reset_physics_interpolation()
	spring_arm.reset_physics_interpolation()
	camera.reset_physics_interpolation()


func apply_instant(preset: CameraPreset) -> void:
	_apply_preset_instant(preset)


## Reset camera to the default preset, using the default_camera_marker if set.
func reset_to_default() -> void:
	print("CameraRig.reset_to_default: Called")
	if not default_preset:
		push_warning("CameraRig.reset_to_default: No default_preset set!")
		return

	# Try multiple ways to find the marker.
	var marker: Marker3D = null
	var found_via := "none"

	# Method 1: Use stored default_camera_marker.
	if default_camera_marker and is_instance_valid(default_camera_marker):
		marker = default_camera_marker
		found_via = "stored default_camera_marker"

	# Method 2: Get from parent CameraSystem.
	if not marker:
		var parent := get_parent()
		print("CameraRig.reset_to_default: Parent is ", parent, " (is CameraSystem: ", parent is CameraSystem, ")")
		if parent is CameraSystem and parent.third_person_camera:
			marker = parent.third_person_camera
			found_via = "parent.third_person_camera"
		elif parent:
			# Method 3: Search sibling nodes for ThirdPersonCamera.
			var sibling := parent.get_node_or_null("ThirdPersonCamera")
			if sibling is Marker3D:
				marker = sibling
				found_via = "sibling ThirdPersonCamera"

	print("CameraRig.reset_to_default: Marker found via '", found_via, "', marker=", marker)

	# Update stored reference.
	if marker and is_instance_valid(marker):
		default_camera_marker = marker
		# Get look_at_target from DefaultCameraMarker if set.
		var look_at: Node3D = null
		if marker is DefaultCameraMarker:
			look_at = marker.look_at_target
		transition_to(default_preset, marker, look_at)
	else:
		push_warning("CameraRig.reset_to_default: No marker found, using preset values only!")
		transition_to(default_preset, null, null)


## Apply the default camera marker immediately (called by CameraSystem after setting markers).
## Works exactly like zone cameras - camera at marker position, looks at player.
func apply_default_marker() -> void:
	if not default_camera_marker:
		return

	# Use marker mode - exactly like zone cameras.
	_camera_marker = default_camera_marker

	# Get look_at_target from DefaultCameraMarker if available.
	if default_camera_marker is DefaultCameraMarker:
		_look_at_node = default_camera_marker.look_at_target
	else:
		_look_at_node = null

	# Calculate and STORE the initial offset from player at startup.
	# This offset is reused when returning from zones to maintain consistent follow behavior.
	if target:
		_default_follow_offset = default_camera_marker.global_position - target.global_position
		_marker_offset = _default_follow_offset
	else:
		_default_follow_offset = default_camera_marker.global_position
		_marker_offset = _default_follow_offset
	_target_fov = default_preset.fov if default_preset else 70.0
	print("apply_default_marker: Stored _default_follow_offset=", _default_follow_offset)

	# Apply preset for marker mode.
	if default_preset:
		_apply_preset_instant_for_marker(default_preset, 0.0)

	# Set camera position and rotation immediately to match preview.
	if _camera_marker:
		# Use follow mode position if enabled, otherwise fixed marker position.
		if default_preset and default_preset.follow_target and target:
			global_position = target.global_position + _marker_offset
		else:
			global_position = _camera_marker.global_position

		# Rotation: use look_at_node if set, otherwise use marker's rotation.
		if _look_at_node and is_instance_valid(_look_at_node):
			var look_target := _look_at_node.global_position
			var dir := look_target - camera.global_position
			if dir.length_squared() > 0.001:
				var up := Vector3.FORWARD if absf(dir.normalized().y) > 0.9 else Vector3.UP
				camera.look_at(look_target, up)
		elif default_preset and default_preset.follow_target and target:
			var look_target := target.global_position + Vector3.UP * 1.0
			var dir := look_target - camera.global_position
			if dir.length_squared() > 0.001:
				var up := Vector3.FORWARD if absf(dir.normalized().y) > 0.9 else Vector3.UP
				camera.look_at(look_target, up)
		else:
			camera.global_basis = _camera_marker.global_basis
		reset_physics_interpolation()
		camera.reset_physics_interpolation()


func get_camera() -> Camera3D:
	return camera


func get_input_mode() -> String:
	if current_preset:
		return current_preset.input_mode
	return "CAMERA_RELATIVE"


func calculate_move_direction(input: Vector2) -> Vector3:
	if not current_preset:
		_last_input = Vector2.ZERO
		_locked_direction = Vector3.ZERO
		return Vector3.ZERO

	# Check if input changed (different keys pressed, not just magnitude).
	var input_changed := _has_input_direction_changed(input, _last_input)
	_last_input = input

	# No input: clear lock and return zero.
	if input.length_squared() < 0.01:
		_locked_direction = Vector3.ZERO
		return Vector3.ZERO

	# During transitions: use locked direction if we have one and input hasn't changed.
	if is_transitioning:
		if _locked_direction.length_squared() > 0.01 and not input_changed:
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
	var old_has_input := old_input.length_squared() > 0.01
	var new_has_input := new_input.length_squared() > 0.01

	# Started or stopped moving.
	if old_has_input != new_has_input:
		return true

	# Both have input: check if direction changed significantly.
	if old_has_input and new_has_input:
		var old_dir := old_input.normalized()
		var new_dir := new_input.normalized()
		# Threshold for direction change (about 45 degrees).
		if old_dir.dot(new_dir) < 0.7:
			return true

	return false

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
	var is_zooming := absf(spring_arm.spring_length - _target_zoom) > 0.01
	if is_zooming:
		spring_arm.spring_length = lerpf(spring_arm.spring_length, _target_zoom, 1.0 - exp(-zoom_speed * delta))
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
		var look_point := target.global_position + Vector3.UP * 1.0
		var dir := (look_point - camera.global_position).normalized()
		if dir.length_squared() > 0.001:
			var target_basis := Basis.looking_at(dir, Vector3.UP)
			camera.global_basis = camera.global_basis.slerp(target_basis, 1.0 - exp(-zoom_speed * delta))


func _update_marker_camera(delta: float) -> void:
	# Use the transition target preset during transitions, otherwise current preset.
	var active_preset := _transition_target if is_transitioning and _transition_target else current_preset
	var follow_speed := active_preset.follow_speed if active_preset else 8.0

	# Calculate current target position.
	var target_pos: Vector3
	if active_preset and active_preset.follow_target and target:
		# Follow mode: marker offset is relative to player.
		target_pos = target.global_position + _marker_offset
	else:
		# Fixed mode: camera at marker's world position.
		target_pos = _camera_marker.global_position

	if is_transitioning and active_preset and active_preset.follow_target:
		# During follow-mode transitions: interpolate from start to current target using progress.
		# This ensures we always track the player, even if they move during the transition.
		global_position = _transition_start_pos.lerp(target_pos, _transition_progress)
	elif not is_transitioning:
		# After transition: smoothly lerp position to track the player.
		global_position = global_position.lerp(target_pos, 1.0 - exp(-follow_speed * delta))

	# Smooth FOV zoom interpolation for marker mode.
	if absf(camera.fov - _target_fov) > 0.1:
		camera.fov = lerpf(camera.fov, _target_fov, 1.0 - exp(-zoom_speed * delta))
		camera.reset_physics_interpolation()

	# During fixed-mode transitions, let the tween handle rotation.
	# For follow-mode transitions, we handle rotation here with slerp.
	if is_transitioning and not (active_preset and active_preset.follow_target):
		return

	# Rotation: look at target if follow_target is true or explicit look_at_node is set.
	# Otherwise use marker's rotation directly (matches 3D viewport).
	var should_look_at_target := false
	var look_target: Vector3

	if _look_at_node and is_instance_valid(_look_at_node):
		should_look_at_target = true
		look_target = _look_at_node.global_position
	elif active_preset and active_preset.follow_target and target:
		# Follow mode: always look at the player.
		should_look_at_target = true
		look_target = target.global_position + Vector3.UP * 1.0

	if should_look_at_target:
		var dir := look_target - camera.global_position
		if dir.length_squared() > 0.001:
			var up := Vector3.FORWARD if absf(dir.normalized().y) > 0.9 else Vector3.UP
			# Smooth slerp - use faster speed during transitions to catch up, slower after.
			var rot_speed := 4.0 if is_transitioning else 2.0
			var target_basis := Basis.looking_at(dir, up)
			camera.global_basis = camera.global_basis.slerp(target_basis, 1.0 - exp(-rot_speed * delta))
	else:
		# Fixed mode: use marker's rotation directly.
		camera.global_basis = _camera_marker.global_basis
	camera.reset_physics_interpolation()

#endregion


#region First Person Update

func _update_first_person(_delta: float) -> void:
	if not current_preset:
		return
	# Use first_person_marker position if available, otherwise use preset's head_offset.
	var head_offset := _get_head_offset()
	global_position = target.global_position + head_offset
	if player_controller:
		var look := player_controller.get_look_delta()
		_fp_yaw -= look.x * current_preset.mouse_sensitivity * 0.001
		_fp_pitch -= look.y * current_preset.mouse_sensitivity * 0.001
		_fp_pitch = clampf(_fp_pitch, deg_to_rad(current_preset.min_pitch), deg_to_rad(current_preset.max_pitch))
	pivot.rotation.y = _fp_yaw
	spring_arm.rotation.x = _fp_pitch


## Get head offset from first_person_marker if set, otherwise from preset.
func _get_head_offset() -> Vector3:
	if first_person_marker and is_instance_valid(first_person_marker):
		return first_person_marker.position
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
	return dir.normalized() if dir.length() > 0.01 else Vector3.ZERO


func _fixed_axis_direction(input: Vector2) -> Vector3:
	var forward := current_preset.fixed_forward.normalized()
	var right := current_preset.fixed_right.normalized()
	var dir := right * input.x + forward * (-input.y)
	return dir.normalized() if dir.length() > 0.01 else Vector3.ZERO


func _world_direction(input: Vector2) -> Vector3:
	var dir := Vector3(input.x, 0.0, input.y)
	return dir.normalized() if dir.length() > 0.01 else Vector3.ZERO

#endregion


#region Transitions

func _transition_third_person(preset: CameraPreset, dur: float, trans: Tween.TransitionType, ease_t: Tween.EaseType, from_fixed: bool = false) -> void:
	print(">>> _transition_third_person: Using preset values! offset=", preset.offset, " spring_length=", preset.spring_length)
	# Disable collision during transition to prevent camera snapping.
	spring_arm.collision_mask = 0
	# Update target zoom to match preset (user can still override with scroll wheel).
	_target_zoom = preset.spring_length
	_active_tween.tween_property(spring_arm, "spring_length", preset.spring_length, dur).set_trans(trans).set_ease(ease_t)
	_active_tween.tween_property(spring_arm, "rotation:x", deg_to_rad(preset.pitch), dur).set_trans(trans).set_ease(ease_t)
	_active_tween.tween_property(camera, "fov", preset.fov, dur).set_trans(trans).set_ease(ease_t)
	# Reset camera local rotation (may have been set by marker mode's look_at).
	_active_tween.tween_property(camera, "rotation", Vector3.ZERO, dur).set_trans(trans).set_ease(ease_t)
	if preset.fixed_rotation:
		# Entering a fixed-rotation zone: tween to the fixed yaw.
		_active_tween.tween_property(pivot, "rotation:y", deg_to_rad(preset.fixed_yaw), dur).set_trans(trans).set_ease(ease_t)
	elif from_fixed:
		# Exiting a fixed-rotation zone back to free-follow:
		# Tween yaw toward the player's current facing so it doesn't snap.
		var target_yaw := target.global_rotation.y if target else 0.0
		_active_tween.tween_property(pivot, "rotation:y", target_yaw, dur).set_trans(trans).set_ease(ease_t)
	# Re-enable collision at end of transition via callback (chained after all parallel tweens).
	_active_tween.chain().tween_callback(func(): spring_arm.collision_mask = 1 if preset.use_collision else 0)


func _transition_to_first_person(preset: CameraPreset, dur: float, trans: Tween.TransitionType, ease_t: Tween.EaseType) -> void:
	_fp_yaw = pivot.rotation.y
	_fp_pitch = spring_arm.rotation.x
	# Use first_person_marker position if available.
	var head_offset := first_person_marker.position if first_person_marker else preset.head_offset
	var head_pos := target.global_position + head_offset
	_active_tween.tween_property(spring_arm, "spring_length", 0.0, dur).set_trans(trans).set_ease(ease_t)
	_active_tween.tween_property(self, "global_position", head_pos, dur).set_trans(trans).set_ease(ease_t)
	_active_tween.tween_property(camera, "fov", preset.fov, dur).set_trans(trans).set_ease(ease_t)
	spring_arm.collision_mask = 0


func _transition_from_first_person(preset: CameraPreset, dur: float, trans: Tween.TransitionType, ease_t: Tween.EaseType) -> void:
	# Disable collision during transition to prevent camera snapping.
	spring_arm.collision_mask = 0
	# Update target zoom to match preset.
	_target_zoom = preset.spring_length
	_active_tween.tween_property(spring_arm, "spring_length", preset.spring_length, dur).set_trans(trans).set_ease(ease_t)
	_active_tween.tween_property(spring_arm, "rotation:x", deg_to_rad(preset.pitch), dur).set_trans(trans).set_ease(ease_t)
	_active_tween.tween_property(camera, "fov", preset.fov, dur).set_trans(trans).set_ease(ease_t)
	# Reset camera local rotation (may have been set by marker mode's look_at).
	_active_tween.tween_property(camera, "rotation", Vector3.ZERO, dur).set_trans(trans).set_ease(ease_t)
	# Tween yaw back to player facing (or fixed yaw) so it doesn't snap.
	if preset.fixed_rotation:
		_active_tween.tween_property(pivot, "rotation:y", deg_to_rad(preset.fixed_yaw), dur).set_trans(trans).set_ease(ease_t)
	else:
		var target_yaw := target.global_rotation.y if target else 0.0
		_active_tween.tween_property(pivot, "rotation:y", target_yaw, dur).set_trans(trans).set_ease(ease_t)
	# Re-enable collision at end of transition.
	_active_tween.chain().tween_callback(func(): spring_arm.collision_mask = 1 if preset.use_collision else 0)


func _transition_to_marker(preset: CameraPreset, dur: float, trans: Tween.TransitionType, ease_t: Tween.EaseType) -> void:
	# Transition to a marker position (fixed or follow mode).
	spring_arm.collision_mask = 0
	# Reset FOV target to preset default for marker mode.
	_target_fov = preset.fov

	# IMMEDIATELY collapse spring arm and reset rotations.
	# This ensures camera world position = rig position for clean transitions.
	# First, move rig to camera's current world position so the snap doesn't cause a visual pop.
	var camera_world_pos := camera.global_position
	spring_arm.spring_length = 0.0
	spring_arm.rotation = Vector3.ZERO
	pivot.rotation = Vector3.ZERO
	global_position = camera_world_pos

	# Tween FOV.
	_active_tween.tween_property(camera, "fov", preset.fov, dur).set_trans(trans).set_ease(ease_t)

	if preset.follow_target and target:
		# FOLLOW MODE: Use progress-based interpolation so target updates each frame.
		# This ensures we always end up at the correct position even if player moves.
		_transition_start_pos = camera_world_pos
		_transition_progress = 0.0
		print(">>> _transition_to_marker: FOLLOW MODE - progress-based from ", camera_world_pos)
		_active_tween.tween_property(self, "_transition_progress", 1.0, dur).set_trans(trans).set_ease(ease_t)
		# Note: position is updated in _update_marker_camera using _transition_progress
	else:
		# FIXED MODE: Tween both position and rotation to fixed marker location.
		var target_pos := _camera_marker.global_position
		print(">>> _transition_to_marker: FIXED MODE marker=", _camera_marker.name, " pos=", target_pos)
		_active_tween.tween_property(self, "global_position", target_pos, dur).set_trans(trans).set_ease(ease_t)

		var look_target: Vector3
		if _look_at_node and is_instance_valid(_look_at_node):
			look_target = _look_at_node.global_position
		elif target:
			look_target = target.global_position + Vector3.UP * 1.0
		else:
			look_target = target_pos + _camera_marker.global_basis.z * -1.0

		var dir := (look_target - target_pos).normalized()
		if dir.length_squared() > 0.001:
			var up := Vector3.FORWARD if absf(dir.y) > 0.9 else Vector3.UP
			var target_basis := Basis.looking_at(dir, up)
			_active_tween.tween_property(camera, "global_basis", target_basis, dur).set_trans(trans).set_ease(ease_t)

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
	elif not _first_person_active and player_controller and player_controller.cursor:
		# Re-enable cursor after third-person to third-person transition.
		player_controller.cursor.set_active(true)
	# Reset physics interpolation to prevent flash frame after transition.
	reset_physics_interpolation()
	pivot.reset_physics_interpolation()
	spring_arm.reset_physics_interpolation()
	camera.reset_physics_interpolation()
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
			# Use first_person_marker position if available.
			var head_offset := first_person_marker.position if first_person_marker else preset.head_offset
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
	reset_physics_interpolation()
	pivot.reset_physics_interpolation()
	spring_arm.reset_physics_interpolation()
	camera.reset_physics_interpolation()
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
	modifier_stack.transform = Transform3D.IDENTITY
	camera.transform = Transform3D.IDENTITY
	camera.fov = preset.fov
	_first_person_active = false
	if player_controller:
		player_controller.set_first_person(false)
	first_person_changed.emit(false)
	# Reset physics interpolation to prevent flash frame.
	reset_physics_interpolation()
	pivot.reset_physics_interpolation()
	spring_arm.reset_physics_interpolation()
	camera.reset_physics_interpolation()
	preset_changed.emit(preset)


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
	modifier_stack = CameraModifierStack.new()
	modifier_stack.name = "CameraModifierStack"
	spring_arm.add_child(modifier_stack)
	camera = Camera3D.new()
	camera.name = "Camera3D"
	modifier_stack.add_child(camera)
	modifier_stack.camera = camera

#endregion
