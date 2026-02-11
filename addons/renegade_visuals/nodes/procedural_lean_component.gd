## Procedural lean into acceleration and pelvis tilt on slopes.
## Derived from acceleration (not velocity) for correct force representation.
## Applies additive rotation to spine bones each frame.
class_name ProceduralLeanComponent
extends Node

@export var config: LeanConfig

var _visuals: CharacterVisuals
var _skeleton: Skeleton3D

# Spine bone indices for lean
var _lean_bone_idx: int = -1  # Primary lean bone (spine_01 or spine_02)
var _pelvis_idx: int = -1

# Smoothed lean state
var _current_lean: Vector3 = Vector3.ZERO  # Euler angles
var _current_pelvis_tilt: Quaternion = Quaternion.IDENTITY

# Track what we applied last frame (to undo before applying new)
var _applied_lean_quat: Quaternion = Quaternion.IDENTITY
var _applied_pelvis_tilt: Quaternion = Quaternion.IDENTITY


func _ready() -> void:
	_visuals = get_parent() as CharacterVisuals
	if _visuals == null:
		push_error("ProceduralLeanComponent: Parent must be a CharacterVisuals node.")
		return
	
	if config == null:
		config = LeanConfig.new()
	
	_visuals.ready.connect(_setup, CONNECT_ONE_SHOT | CONNECT_DEFERRED)


func _setup() -> void:
	_skeleton = _visuals.skeleton
	if _skeleton == null:
		return
	
	var skel_config := _visuals.skeleton_config
	if skel_config == null:
		skel_config = SkeletonConfig.new()
	
	# Use spine_02 as primary lean bone (mid-spine gives natural look)
	_lean_bone_idx = _skeleton.find_bone(skel_config.spine_02)
	if _lean_bone_idx == -1:
		_lean_bone_idx = _skeleton.find_bone(skel_config.spine_01)
	
	_pelvis_idx = _skeleton.find_bone(skel_config.pelvis_bone)


func _physics_process(delta: float) -> void:
	if _skeleton == null:
		return

	# Skip lean updates while flinching (HitReactionComponent takes over spine)
	if _visuals.is_flinching:
		# Reset our tracking so we don't apply stale offsets when resuming
		_applied_lean_quat = Quaternion.IDENTITY
		_applied_pelvis_tilt = Quaternion.IDENTITY
		return

	_update_lean(delta)

	if config.enable_pelvis_tilt:
		_update_pelvis_tilt(delta)


func _update_lean(delta: float) -> void:
	if _lean_bone_idx == -1:
		return
	
	var acceleration := _visuals.get_acceleration()
	
	# Project acceleration to horizontal plane
	var horiz_accel := Vector3(acceleration.x, 0.0, acceleration.z)
	
	# Convert to character-local space
	var local_accel := Vector3.ZERO
	if _visuals.controller:
		local_accel = _visuals.controller.global_transform.basis.inverse() * horiz_accel
	
	# Compute lean angles from acceleration
	# Lean into movement: forward accel → forward pitch, lateral accel → roll
	var max_angle := deg_to_rad(config.max_lean_angle)
	var target_lean := Vector3(
		clampf(-local_accel.z * config.lean_multiplier, -max_angle, max_angle),  # Pitch
		0.0,  # No yaw lean
		clampf(local_accel.x * config.lean_multiplier, -max_angle, max_angle),   # Roll
	)
	
	# Damped spring smoothing
	_current_lean = _current_lean.lerp(target_lean, config.lean_speed * delta)

	# Apply additive rotation (undo previous frame, apply new)
	var new_lean_quat := Quaternion.from_euler(_current_lean)

	# Get current rotation and undo what we applied last frame
	var current_rot := _skeleton.get_bone_pose_rotation(_lean_bone_idx)
	var base_rot := current_rot * _applied_lean_quat.inverse()

	# Apply new lean
	_skeleton.set_bone_pose_rotation(_lean_bone_idx, base_rot * new_lean_quat)

	# Store what we applied for next frame
	_applied_lean_quat = new_lean_quat


func _update_pelvis_tilt(delta: float) -> void:
	if _pelvis_idx == -1:
		return
	
	var ground_normal := _visuals.get_ground_normal()
	
	# Compute target tilt from ground normal
	var target_tilt := Quaternion.IDENTITY
	if not ground_normal.is_equal_approx(Vector3.UP):
		var tilt_axis := Vector3.UP.cross(ground_normal).normalized()
		var tilt_angle := Vector3.UP.angle_to(ground_normal) * config.pelvis_tilt_weight
		if not tilt_axis.is_zero_approx():
			target_tilt = Quaternion(tilt_axis, tilt_angle)
	
	# Smooth tilt
	_current_pelvis_tilt = _current_pelvis_tilt.slerp(target_tilt, config.pelvis_tilt_speed * delta)

	# Apply additive rotation to pelvis (undo previous frame, apply new)
	var current_rot := _skeleton.get_bone_pose_rotation(_pelvis_idx)
	var base_rot := current_rot * _applied_pelvis_tilt.inverse()

	# Apply new tilt
	_skeleton.set_bone_pose_rotation(_pelvis_idx, base_rot * _current_pelvis_tilt)

	# Store what we applied for next frame
	_applied_pelvis_tilt = _current_pelvis_tilt
