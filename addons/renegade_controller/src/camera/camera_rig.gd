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

## Assigned in _ready — NOT @onready because hierarchy may need building first.
var pivot: Node3D
var spring_arm: SpringArm3D
var camera: Camera3D


func _ready() -> void:
	if not has_node("Pivot"):
		_build_hierarchy()
	
	pivot = $Pivot
	spring_arm = $Pivot/SpringArm3D
	camera = $Pivot/SpringArm3D/Camera3D
	
	if default_preset:
		current_preset = default_preset
		_apply_preset_instant(default_preset)


func _physics_process(delta: float) -> void:
	if not target:
		return
	if _first_person_active:
		_update_first_person(delta)
	else:
		_update_third_person(delta)


#region Public API

func transition_to(preset: CameraPreset) -> void:
	if preset == current_preset and not is_transitioning:
		return
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
	elif was_first_person:
		_transition_from_first_person(preset, dur, trans, ease)
	else:
		_transition_third_person(preset, dur, trans, ease, was_fixed)
	_active_tween.chain().tween_callback(_on_transition_complete.bind(preset, entering_first_person))
	# Force immediate position update toward new target to prevent flash.
	if target and not entering_first_person:
		var target_pos := target.global_position + preset.offset
		global_position = global_position.lerp(target_pos, 0.3)
	# Prevent physics interpolation from showing old camera state.
	reset_physics_interpolation()
	pivot.reset_physics_interpolation()
	spring_arm.reset_physics_interpolation()
	camera.reset_physics_interpolation()


func apply_instant(preset: CameraPreset) -> void:
	_apply_preset_instant(preset)


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
	# Use the transition target preset during transitions for smooth position follow.
	var active_preset := _transition_target if is_transitioning and _transition_target else current_preset
	# Always follow position smoothly (even during transitions).
	var target_pos := target.global_position + active_preset.offset
	global_position = global_position.lerp(target_pos, 1.0 - exp(-active_preset.follow_speed * delta))
	# Don't touch rotation during transitions — let the tween drive it.
	if is_transitioning:
		return
	if not current_preset.fixed_rotation:
		var target_yaw := target.global_rotation.y + deg_to_rad(current_preset.yaw_offset)
		pivot.rotation.y = lerp_angle(pivot.rotation.y, target_yaw, 1.0 - exp(-current_preset.rotation_speed * delta))

#endregion


#region First Person Update

func _update_first_person(delta: float) -> void:
	if not current_preset:
		return
	global_position = target.global_position + current_preset.head_offset
	if player_controller:
		var look := player_controller.get_look_delta()
		_fp_yaw -= look.x * current_preset.mouse_sensitivity * delta * 10.0
		_fp_pitch -= look.y * current_preset.mouse_sensitivity * delta * 10.0
		_fp_pitch = clampf(_fp_pitch, deg_to_rad(current_preset.min_pitch), deg_to_rad(current_preset.max_pitch))
	pivot.rotation.y = _fp_yaw
	spring_arm.rotation.x = _fp_pitch

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
	# Disable collision during transition to prevent camera snapping.
	spring_arm.collision_mask = 0
	_active_tween.tween_property(spring_arm, "spring_length", preset.spring_length, dur).set_trans(trans).set_ease(ease_t)
	_active_tween.tween_property(spring_arm, "rotation:x", deg_to_rad(preset.pitch), dur).set_trans(trans).set_ease(ease_t)
	_active_tween.tween_property(camera, "fov", preset.fov, dur).set_trans(trans).set_ease(ease_t)
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
	var head_pos := target.global_position + preset.head_offset
	_active_tween.tween_property(spring_arm, "spring_length", 0.0, dur).set_trans(trans).set_ease(ease_t)
	_active_tween.tween_property(self, "global_position", head_pos, dur).set_trans(trans).set_ease(ease_t)
	_active_tween.tween_property(camera, "fov", preset.fov, dur).set_trans(trans).set_ease(ease_t)
	spring_arm.collision_mask = 0


func _transition_from_first_person(preset: CameraPreset, dur: float, trans: Tween.TransitionType, ease_t: Tween.EaseType) -> void:
	# Disable collision during transition to prevent camera snapping.
	spring_arm.collision_mask = 0
	_active_tween.tween_property(spring_arm, "spring_length", preset.spring_length, dur).set_trans(trans).set_ease(ease_t)
	_active_tween.tween_property(spring_arm, "rotation:x", deg_to_rad(preset.pitch), dur).set_trans(trans).set_ease(ease_t)
	_active_tween.tween_property(camera, "fov", preset.fov, dur).set_trans(trans).set_ease(ease_t)
	# Tween yaw back to player facing (or fixed yaw) so it doesn't snap.
	if preset.fixed_rotation:
		_active_tween.tween_property(pivot, "rotation:y", deg_to_rad(preset.fixed_yaw), dur).set_trans(trans).set_ease(ease_t)
	else:
		var target_yaw := target.global_rotation.y if target else 0.0
		_active_tween.tween_property(pivot, "rotation:y", target_yaw, dur).set_trans(trans).set_ease(ease_t)
	# Re-enable collision at end of transition.
	_active_tween.chain().tween_callback(func(): spring_arm.collision_mask = 1 if preset.use_collision else 0)

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
			global_position = target.global_position + preset.head_offset
		if player_controller:
			player_controller.set_first_person(true)
		first_person_changed.emit(true)
	else:
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
	camera = Camera3D.new()
	camera.name = "Camera3D"
	spring_arm.add_child(camera)

#endregion
