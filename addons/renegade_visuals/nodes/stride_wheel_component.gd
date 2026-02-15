## Procedural stride wheel for walk IK.
## Drives Marker3D foot targets in a phase-based gait cycle: feet plant on the ground
## during stance phase and swing through an arc to the next plant position.
## Also handles hip bob and ground-following hip drop.
class_name StrideWheelComponent
extends Node

@export var config: StrideWheelConfig:
	set(value):
		config = value
		if config:
			_sync_from_config()

@export_group("Stride")
## Base stride length at walk speed. Stride scales up with speed.
@export var stride_length: float = 0.7:
	set(value):
		stride_length = value
		if config:
			config.stride_length = value
## Maximum stride length at run speed.
@export var max_stride_length: float = 1.8:
	set(value):
		max_stride_length = value
		if config:
			config.max_stride_length = value
## Speed considered "walking" (uses stride_length).
@export var walk_speed: float = 2.0:
	set(value):
		walk_speed = value
		if config:
			config.walk_speed = value
## Speed considered "running" (uses max_stride_length).
@export var run_speed: float = 5.0:
	set(value):
		run_speed = value
		if config:
			config.run_speed = value
## Peak height of foot arc during swing phase.
@export var step_height: float = 0.15:
	set(value):
		step_height = value
		if config:
			config.step_height = value
## Lateral offset from character center for foot placement.
@export var foot_lateral_offset: float = 0.15:
	set(value):
		foot_lateral_offset = value
		if config:
			config.foot_lateral_offset = value
## Height from ankle bone to sole of foot. Raises foot target so sole sits on ground.
@export var foot_height: float = 0.08:
	set(value):
		foot_height = value
		if config:
			config.foot_height = value
## How far ahead of character to plant foot (as fraction of stride). 0.5 = centered stride.
@export_range(0.3, 0.8) var plant_ahead_ratio: float = 0.5:
	set(value):
		plant_ahead_ratio = value
		if config:
			config.plant_ahead_ratio = value
## Fraction of gait cycle spent in stance (foot planted). Lower = foot lifts earlier.
@export_range(0.3, 0.6) var stance_ratio: float = 0.5:
	set(value):
		stance_ratio = value
		if config:
			config.stance_ratio = value

@export_group("Hip")
## Vertical pelvis bob amplitude during walk cycle.
@export var hip_bob_amount: float = 0.03:
	set(value):
		hip_bob_amount = value
		if config:
			config.hip_bob_amount = value
## Hip offset (negative = lower hips, causes knee bend). -0.05 to -0.15 typical.
@export var hip_offset: float = -0.08:
	set(value):
		hip_offset = value
		if config:
			config.hip_offset = value
## Body offset along movement direction. Positive = body trails (feet lead), Negative = body leads.
@export_range(-0.5, 0.5) var body_trail_distance: float = 0.25:
	set(value):
		body_trail_distance = value
		if config:
			config.body_trail_distance = value
## Forward lean angle (degrees) during locomotion. Tilts torso forward into movement.
@export_range(-90.0, 90.0) var forward_lean_angle: float = 8.0:
	set(value):
		forward_lean_angle = value
		if config:
			config.forward_lean_angle = value
## Smoothing speed for hip offset changes.
@export_range(1.0, 30.0) var hip_smooth_speed: float = 10.0:
	set(value):
		hip_smooth_speed = value
		if config:
			config.hip_smooth_speed = value
## Smoothing speed for spine lean rotation. Higher = snappier response.
@export_range(1.0, 30.0) var spine_smooth_speed: float = 3.0:
	set(value):
		spine_smooth_speed = value
		if config:
			config.spine_smooth_speed = value

@export_group("Ground Detection")
## How far above the foot to start the raycast.
@export var ray_height: float = 0.5:
	set(value):
		ray_height = value
		if config:
			config.ray_height = value
## How far below the foot to cast the ray.
@export var ray_depth: float = 1.0:
	set(value):
		ray_depth = value
		if config:
			config.ray_depth = value
## Physics layers for ground detection.
@export_flags_3d_physics var ground_layers: int = 1:
	set(value):
		ground_layers = value
		if config:
			config.ground_layers = value

@export_group("Blending")
## Speed below which the stride wheel is inactive.
@export var idle_threshold: float = 0.1:
	set(value):
		idle_threshold = value
		if config:
			config.idle_threshold = value
## Speed at which IK influence blends in/out.
@export_range(1.0, 20.0) var influence_blend_speed: float = 8.0:
	set(value):
		influence_blend_speed = value
		if config:
			config.influence_blend_speed = value
## Smoothing speed for foot IK target positions (higher = snappier, lower = smoother).
@export_range(5.0, 50.0) var foot_smooth_speed: float = 20.0:
	set(value):
		foot_smooth_speed = value
		if config:
			config.foot_smooth_speed = value

@export_group("Turn In Place")
## Foot drift threshold as fraction of stride_length. Step triggers when foot drifts this far.
@export_range(0.1, 0.6) var turn_drift_threshold: float = 0.2:
	set(value):
		turn_drift_threshold = value
		if config:
			config.turn_drift_threshold = value
## Speed at which feet step to new positions during turn-in-place.
@export_range(1.0, 20.0) var turn_step_speed: float = 8.0:
	set(value):
		turn_step_speed = value
		if config:
			config.turn_step_speed = value
## Arc height for step during turn-in-place.
@export var turn_step_height: float = 0.08:
	set(value):
		turn_step_height = value
		if config:
			config.turn_step_height = value
## How much the hip lowers during turn-in-place (causes knee bend).
@export var turn_crouch_amount: float = 0.05:
	set(value):
		turn_crouch_amount = value
		if config:
			config.turn_crouch_amount = value
## Forward/back stagger for idle stance (one foot forward, one back). Set to 0 to use rest pose.
@export var stance_stagger: float = 0.0:
	set(value):
		stance_stagger = value
		if config:
			config.stance_stagger = value
## Maximum leg reach as multiplier of stride length. Prevents over-stretching.
@export_range(0.8, 2.0) var max_leg_reach: float = 1.2:
	set(value):
		max_leg_reach = value
		if config:
			config.max_leg_reach = value

@export_group("Foot Rotation")
## How much the foot rotates to match ground normal (0-1).
@export_range(0.0, 1.0) var foot_rotation_weight: float = 0.8:
	set(value):
		foot_rotation_weight = value
		if config:
			config.foot_rotation_weight = value
## Maximum foot rotation angle in degrees.
@export_range(0.0, 60.0) var max_foot_angle: float = 35.0:
	set(value):
		max_foot_angle = value
		if config:
			config.max_foot_angle = value
## Maximum toe-down pitch during swing lift-off (degrees). Creates "peel off" effect.
@export_range(0.0, 60.0) var swing_pitch_angle: float = 25.0:
	set(value):
		swing_pitch_angle = value
		if config:
			config.swing_pitch_angle = value

@export_group("IK Nodes")
## TwoBoneIK3D solver for the left leg.
@export var left_leg_ik: NodePath
## TwoBoneIK3D solver for the right leg.
@export var right_leg_ik: NodePath

@export_group("IK Targets")
## Marker3D target the left leg IK solver points at.
@export var left_foot_target: NodePath
## Marker3D target the right leg IK solver points at.
@export var right_foot_target: NodePath

@export_group("Debug")
## Enable debug visualization.
@export var debug_enabled: bool = false
## Show planted foot positions (green = left, blue = right).
@export var debug_show_plant_pos: bool = true
## Show predicted plant positions (yellow).
@export var debug_show_predicted: bool = true
## Show character reference point (white).
@export var debug_show_char_pos: bool = true
## Show movement direction (magenta arrow).
@export var debug_show_move_dir: bool = true
## Show stride wheel circles and phase indicators.
@export var debug_show_stride_wheel: bool = true
## Size of debug spheres.
@export var debug_sphere_size: float = 0.05

var _visuals: CharacterVisuals
var _skeleton: Skeleton3D

# IK node references
var _left_ik: Node
var _right_ik: Node
var _left_target: Marker3D
var _right_target: Marker3D

# Bone indices
var _pelvis_idx: int = -1
var _spine_01_idx: int = -1
var _left_foot_idx: int = -1
var _right_foot_idx: int = -1

# Phase accumulator — one full TAU = two steps (left + right)
var _phase: float = 0.0

# Per-foot state (position locked in world space, yaw stored for planted rotation)
var _left_plant_pos: Vector3 = Vector3.ZERO
var _right_plant_pos: Vector3 = Vector3.ZERO
var _left_plant_yaw: float = 0.0  # Stored Y rotation when foot planted
var _right_plant_yaw: float = 0.0
var _left_prev_cycle: float = 0.0   # Previous cycle value (0–1) for transition detection
var _right_prev_cycle: float = 0.0
var _left_swing_target: Vector3 = Vector3.ZERO  # Smoothed swing landing target
var _right_swing_target: Vector3 = Vector3.ZERO
var _left_swing_t: float = 0.0  # Current swing phase (0 = just lifted, 1 = landing)
var _right_swing_t: float = 0.0
var _left_ground_normal: Vector3 = Vector3.UP
var _right_ground_normal: Vector3 = Vector3.UP

# Hip
var _current_hip_offset: float = 0.0
var _current_hip_forward: Vector3 = Vector3.ZERO  # Torso lag offset (world space)
var _current_lean_angle: float = 0.0  # Forward tilt in radians
var _spine_rest_basis: Basis = Basis.IDENTITY  # Spine rest pose
var _current_spine_basis: Basis = Basis.IDENTITY  # Smoothed spine rotation

# Influence
var _current_influence: float = 0.0

# Physics
var _space_state: PhysicsDirectSpaceState3D

# Rest positions (bind pose feet in world space, cached each frame)
var _left_rest_pos: Vector3 = Vector3.ZERO
var _right_rest_pos: Vector3 = Vector3.ZERO

# Turn-in-place state
var _prev_yaw: float = 0.0
var _was_moving: bool = false  # Track previous frame movement state
var _is_turning_in_place: bool = false
var _turn_step_progress: float = 0.0  # 0–1 for step animation
var _left_step_start: Vector3 = Vector3.ZERO
var _left_step_end: Vector3 = Vector3.ZERO
var _right_step_start: Vector3 = Vector3.ZERO
var _right_step_end: Vector3 = Vector3.ZERO
var _stepping_foot: int = 0  # 0 = left, 1 = right

# Foot rotation is now applied directly in _apply_foot_bone_rotations() after IK runs

# Foot bone rest orientation (captured at setup to preserve skeleton's foot direction)
var _left_foot_rest_basis: Basis = Basis.IDENTITY
var _right_foot_rest_basis: Basis = Basis.IDENTITY
var _initial_char_yaw: float = 0.0  # Character yaw when rest basis was captured

# Smoothed foot target state (lerped each frame to avoid snapping)
var _left_current_pos: Vector3 = Vector3.ZERO
var _right_current_pos: Vector3 = Vector3.ZERO
var _left_current_basis: Basis = Basis.IDENTITY
var _right_current_basis: Basis = Basis.IDENTITY
var _left_foot_initialized: bool = false
var _right_foot_initialized: bool = false

# Debug visualization
var _debug_container: Node3D
var _debug_left_plant: MeshInstance3D
var _debug_right_plant: MeshInstance3D
var _debug_left_predicted: MeshInstance3D
var _debug_right_predicted: MeshInstance3D
var _debug_char_pos: MeshInstance3D
var _debug_move_dir: MeshInstance3D
var _debug_left_target: MeshInstance3D
var _debug_right_target: MeshInstance3D
var _debug_left_wheel: MeshInstance3D
var _debug_right_wheel: MeshInstance3D
var _debug_left_phase: MeshInstance3D
var _debug_right_phase: MeshInstance3D
var _debug_left_markers: Array[MeshInstance3D] = []
var _debug_right_markers: Array[MeshInstance3D] = []
var _debug_left_spokes: Array[MeshInstance3D] = []
var _debug_right_spokes: Array[MeshInstance3D] = []
var _debug_overhead_left_label: Label3D
var _debug_overhead_right_label: Label3D

# Cache for debug - store last predicted positions
var _debug_left_predicted_pos: Vector3 = Vector3.ZERO
var _debug_right_predicted_pos: Vector3 = Vector3.ZERO
var _debug_move_dir_vec: Vector3 = Vector3.ZERO


## Sync local @export properties from the config resource.
func _sync_from_config() -> void:
	if config == null:
		return
	# Use direct assignment to avoid setter triggering back
	stride_length = config.stride_length
	max_stride_length = config.max_stride_length
	walk_speed = config.walk_speed
	run_speed = config.run_speed
	step_height = config.step_height
	foot_lateral_offset = config.foot_lateral_offset
	foot_height = config.foot_height
	plant_ahead_ratio = config.plant_ahead_ratio
	stance_ratio = config.stance_ratio
	hip_bob_amount = config.hip_bob_amount
	hip_offset = config.hip_offset
	body_trail_distance = config.body_trail_distance
	forward_lean_angle = config.forward_lean_angle
	hip_smooth_speed = config.hip_smooth_speed
	spine_smooth_speed = config.spine_smooth_speed
	ray_height = config.ray_height
	ray_depth = config.ray_depth
	ground_layers = config.ground_layers
	idle_threshold = config.idle_threshold
	influence_blend_speed = config.influence_blend_speed
	foot_smooth_speed = config.foot_smooth_speed
	turn_drift_threshold = config.turn_drift_threshold
	turn_step_speed = config.turn_step_speed
	turn_step_height = config.turn_step_height
	turn_crouch_amount = config.turn_crouch_amount
	stance_stagger = config.stance_stagger
	max_leg_reach = config.max_leg_reach
	foot_rotation_weight = config.foot_rotation_weight
	max_foot_angle = config.max_foot_angle
	swing_pitch_angle = config.swing_pitch_angle


## Calculate effective stride length based on current speed.
## Interpolates between stride_length (at walk_speed) and max_stride_length (at run_speed).
func _get_effective_stride(speed: float) -> float:
	if speed <= walk_speed:
		return stride_length
	elif speed >= run_speed:
		return max_stride_length
	else:
		# Lerp between walk and run stride
		var t := (speed - walk_speed) / (run_speed - walk_speed)
		return lerpf(stride_length, max_stride_length, t)


func _ready() -> void:
	_visuals = get_parent() as CharacterVisuals
	if _visuals == null:
		push_error("StrideWheelComponent: Parent must be a CharacterVisuals node.")
		return

	if config == null:
		config = StrideWheelConfig.new()
	_sync_from_config()

	_visuals.ready.connect(_setup, CONNECT_ONE_SHOT | CONNECT_DEFERRED)


func _exit_tree() -> void:
	_cleanup_debug()


func _setup() -> void:
	_skeleton = _visuals.skeleton
	if _skeleton == null:
		push_error("StrideWheelComponent: No skeleton found on CharacterVisuals.")
		return

	var skel_config := _visuals.skeleton_config
	if skel_config == null:
		skel_config = SkeletonConfig.new()

	_pelvis_idx = _skeleton.find_bone(skel_config.pelvis_bone)
	_spine_01_idx = _skeleton.find_bone(skel_config.spine_01)
	_left_foot_idx = _skeleton.find_bone(skel_config.left_foot)
	_right_foot_idx = _skeleton.find_bone(skel_config.right_foot)

	if _pelvis_idx == -1:
		push_warning("StrideWheelComponent: Pelvis bone '%s' not found." % skel_config.pelvis_bone)
	if _spine_01_idx == -1:
		push_warning("StrideWheelComponent: Spine_01 bone '%s' not found." % skel_config.spine_01)
	if _left_foot_idx == -1:
		push_warning("StrideWheelComponent: Left foot bone '%s' not found." % skel_config.left_foot)
	if _right_foot_idx == -1:
		push_warning("StrideWheelComponent: Right foot bone '%s' not found." % skel_config.right_foot)

	# Cache spine rest pose
	if _spine_01_idx != -1:
		_spine_rest_basis = _skeleton.get_bone_rest(_spine_01_idx).basis
		_current_spine_basis = _spine_rest_basis

	# Resolve IK solver nodes
	if not left_leg_ik.is_empty():
		_left_ik = get_node_or_null(left_leg_ik)
	if not right_leg_ik.is_empty():
		_right_ik = get_node_or_null(right_leg_ik)

	# Resolve target Marker3Ds
	if not left_foot_target.is_empty():
		_left_target = get_node_or_null(left_foot_target) as Marker3D
	if not right_foot_target.is_empty():
		_right_target = get_node_or_null(right_foot_target) as Marker3D

	# Capture foot bone rest orientations (before any IK modifies them)
	# This preserves the skeleton's intended foot direction
	_initial_char_yaw = _visuals.global_rotation.y
	if _left_foot_idx != -1:
		var left_bone_pose := _skeleton.get_bone_global_pose(_left_foot_idx)
		_left_foot_rest_basis = (_skeleton.global_transform * Transform3D(left_bone_pose)).basis
	if _right_foot_idx != -1:
		var right_bone_pose := _skeleton.get_bone_global_pose(_right_foot_idx)
		_right_foot_rest_basis = (_skeleton.global_transform * Transform3D(right_bone_pose)).basis

	# Initialize plant positions at current foot locations
	if _left_foot_idx != -1:
		_left_plant_pos = _get_bone_world_position(_left_foot_idx)
	if _right_foot_idx != -1:
		_right_plant_pos = _get_bone_world_position(_right_foot_idx)

	# Initialize plant yaw to current facing
	var initial_yaw := _visuals.global_rotation.y
	_left_plant_yaw = initial_yaw
	_right_plant_yaw = initial_yaw

	# Initialize yaw tracking for turn-in-place
	_prev_yaw = initial_yaw

	# Setup rotation modifiers to copy Marker3D rotation to foot bones
	_setup_foot_rotation_modifiers(skel_config)

	# Setup debug visualization
	_setup_debug()


## Setup foot rotation - we'll apply rotation directly to bones after IK runs.
## CopyTransformModifier3D approach doesn't work reliably with TwoBoneIK3D.
func _setup_foot_rotation_modifiers(_skel_config: SkeletonConfig) -> void:
	# Connect to skeleton_updated to apply foot rotation AFTER IK solvers run
	if _skeleton and not _skeleton.skeleton_updated.is_connected(_apply_foot_bone_rotations):
		_skeleton.skeleton_updated.connect(_apply_foot_bone_rotations)


## Apply foot bone rotations directly after IK has run.
## This ensures our rotation takes effect after TwoBoneIK3D positions the legs.
func _apply_foot_bone_rotations() -> void:
	if _skeleton == null:
		return
	if _current_influence < 0.01:
		return

	# Apply left foot rotation from Marker3D
	if _left_target and _left_foot_idx != -1:
		var target_basis := _left_target.global_transform.basis
		# Convert world basis to bone-local basis
		var parent_idx := _skeleton.get_bone_parent(_left_foot_idx)
		var parent_global: Transform3D
		if parent_idx != -1:
			parent_global = _skeleton.global_transform * Transform3D(_skeleton.get_bone_global_pose(parent_idx))
		else:
			parent_global = _skeleton.global_transform
		var local_basis := parent_global.basis.inverse() * target_basis
		# Blend with influence
		var current_pose := _skeleton.get_bone_pose(_left_foot_idx)
		var blended_basis := current_pose.basis.slerp(local_basis, _current_influence)
		_skeleton.set_bone_pose_rotation(_left_foot_idx, blended_basis.get_rotation_quaternion())

	# Apply right foot rotation from Marker3D
	if _right_target and _right_foot_idx != -1:
		var target_basis := _right_target.global_transform.basis
		var parent_idx := _skeleton.get_bone_parent(_right_foot_idx)
		var parent_global: Transform3D
		if parent_idx != -1:
			parent_global = _skeleton.global_transform * Transform3D(_skeleton.get_bone_global_pose(parent_idx))
		else:
			parent_global = _skeleton.global_transform
		var local_basis := parent_global.basis.inverse() * target_basis
		var current_pose := _skeleton.get_bone_pose(_right_foot_idx)
		var blended_basis := current_pose.basis.slerp(local_basis, _current_influence)
		_skeleton.set_bone_pose_rotation(_right_foot_idx, blended_basis.get_rotation_quaternion())


func _physics_process(delta: float) -> void:
	if _skeleton == null:
		return
	if _left_foot_idx == -1 or _right_foot_idx == -1:
		return

	_space_state = _skeleton.get_world_3d().direct_space_state
	if _space_state == null:
		return

	var velocity := _visuals.get_velocity()
	var horizontal_vel := Vector3(velocity.x, 0.0, velocity.z)
	var speed := horizontal_vel.length()
	var is_moving: bool = speed > idle_threshold
	var move_dir: Vector3 = horizontal_vel.normalized() if is_moving else Vector3.ZERO

	# Update influence
	_update_influence(delta, is_moving)

	# Cache rest positions (skeleton bind pose in world)
	_left_rest_pos = _get_bone_world_position(_left_foot_idx)
	_right_rest_pos = _get_bone_world_position(_right_foot_idx)

	# Store for debug
	var char_pos := _visuals.controller.global_position if _visuals.controller else Vector3.ZERO
	_debug_move_dir_vec = move_dir

	if is_moving:
		# Reset turn-in-place state when starting to move
		_is_turning_in_place = false

		# Track yaw so _prev_yaw is up-to-date when we stop
		_prev_yaw = _visuals.global_rotation.y

		# Calculate effective stride based on speed (longer strides at higher speeds)
		var effective_stride := _get_effective_stride(speed)

		# Advance phase - use effective stride so faster = longer steps, not more steps
		_phase += (speed / effective_stride) * PI * delta
		_phase = fmod(_phase, TAU)

		# Compute per-foot cycle values (0–1)
		var left_cycle := fmod(_phase / TAU, 1.0)
		var right_cycle := fmod((_phase + PI) / TAU, 1.0)

		# IMPORTANT: Update plant positions BEFORE processing feet
		# This prevents one-frame delay when foot plants at new position
		if _crossed_threshold(left_cycle, _left_prev_cycle, 0.0):
			_left_plant_pos = _predict_plant_position(move_dir, speed, -1.0)
		if _crossed_threshold(right_cycle, _right_prev_cycle, 0.0):
			_right_plant_pos = _predict_plant_position(move_dir, speed, 1.0)

		# Update debug predicted positions (always, not just on threshold)
		_debug_left_predicted_pos = _predict_plant_position(move_dir, speed, -1.0)
		_debug_right_predicted_pos = _predict_plant_position(move_dir, speed, 1.0)

		# Safety: clamp plant distance before processing
		_left_plant_pos = _clamp_plant_distance(_left_plant_pos, effective_stride * max_leg_reach)
		_right_plant_pos = _clamp_plant_distance(_right_plant_pos, effective_stride * max_leg_reach)

		# Process each foot with updated plant positions
		var left_pos := _process_foot(
			left_cycle, _left_prev_cycle,
			_left_plant_pos, _left_rest_pos,
			move_dir, speed, -1.0, delta  # left side
		)
		var right_pos := _process_foot(
			right_cycle, _right_prev_cycle,
			_right_plant_pos, _right_rest_pos,
			move_dir, speed, 1.0, delta  # right side
		)

		_left_prev_cycle = left_cycle
		_right_prev_cycle = right_cycle

		# Apply positions to targets (during locomotion, feet follow character facing)
		var current_yaw := _visuals.global_rotation.y
		_apply_foot_target(_left_target, left_pos, current_yaw, _left_ground_normal, _left_foot_rest_basis, _left_swing_t, delta)
		_apply_foot_target(_right_target, right_pos, current_yaw, _right_ground_normal, _right_foot_rest_basis, _right_swing_t, delta)
		# Update planted yaw so it's current when we stop
		_left_plant_yaw = current_yaw
		_right_plant_yaw = current_yaw

		# Hip adjustment for natural knee bend:
		# 1. Bob: vertical oscillation during gait cycle
		# 2. Extension drop: hip lowers when legs are spread apart (Pythagorean theorem)
		var hip_bob: float = -absf(sin(_phase)) * hip_bob_amount

		# Calculate leg extension drop - when feet are spread apart, hip must drop
		# to maintain contact (otherwise legs would need to stretch)
		var foot_spread := left_pos.distance_to(right_pos)
		var max_spread := effective_stride * 1.2  # Maximum expected spread
		var spread_factor := clampf(foot_spread / max_spread, 0.0, 1.0)
		# Drop more when legs are spread (quadratic for more natural feel)
		var extension_drop := -spread_factor * spread_factor * step_height * 0.5

		_update_hip(delta, hip_bob + extension_drop, move_dir)
	else:
		# Idle — handle turn-in-place or rest
		_process_idle_or_turn(delta)

	_apply_influence()

	# Track movement state for next frame transition detection
	_was_moving = is_moving

	# Update debug visualization
	_update_debug(char_pos, move_dir)


## Handle idle state with turn-in-place detection and foot stepping.
func _process_idle_or_turn(delta: float) -> void:
	# If we just stopped moving, update plant positions to where feet currently are
	# This prevents snapping back to old plant positions when stopping mid-swing
	if _was_moving:
		_left_plant_pos = _left_current_pos
		_right_plant_pos = _right_current_pos
		_left_plant_yaw = _visuals.global_rotation.y
		_right_plant_yaw = _visuals.global_rotation.y
		# Reset swing state
		_left_swing_t = 0.0
		_right_swing_t = 0.0

	_prev_yaw = _visuals.global_rotation.y

	# Calculate where feet SHOULD be based on current facing
	var left_target_pos := _calculate_ideal_foot_position(-1.0)
	var right_target_pos := _calculate_ideal_foot_position(1.0)

	# Process ongoing step
	if _is_turning_in_place:
		_process_turn_step(delta, left_target_pos, right_target_pos)
	else:
		# Check if either foot has drifted too far from ideal position
		var left_drift := _horizontal_distance(_left_plant_pos, left_target_pos)
		var right_drift := _horizontal_distance(_right_plant_pos, right_target_pos)
		var threshold := stride_length * turn_drift_threshold

		if left_drift > threshold or right_drift > threshold:
			_start_turn_step(left_target_pos, right_target_pos, left_drift, right_drift)
		else:
			# Feet stay planted at current world positions with stored yaw
			_apply_foot_target(_left_target, _left_plant_pos, _left_plant_yaw, _left_ground_normal, _left_foot_rest_basis, 0.0, delta)
			_apply_foot_target(_right_target, _right_plant_pos, _right_plant_yaw, _right_ground_normal, _right_foot_rest_basis, 0.0, delta)
			_update_hip(delta, 0.0)

	# Reset phase so next move starts cleanly
	_phase = 0.0
	_left_prev_cycle = 0.0
	_right_prev_cycle = 0.5


## Calculate ideal foot position based on character position and facing.
## side: -1.0 for left foot, +1.0 for right foot
func _calculate_ideal_foot_position(side: float) -> Vector3:
	if _visuals.controller == null:
		return Vector3.ZERO

	var char_pos := _visuals.controller.global_position
	var facing := _visuals.global_basis

	# Lateral offset perpendicular to facing direction
	var lateral: Vector3 = facing.x * side * foot_lateral_offset

	# Forward/back stagger: left foot forward, right foot back
	var forward: Vector3 = -facing.z * side * stance_stagger

	var target_pos: Vector3 = char_pos + lateral + forward
	return _raycast_ground(target_pos)


## Horizontal distance between two points (ignoring Y).
func _horizontal_distance(a: Vector3, b: Vector3) -> float:
	var diff := a - b
	diff.y = 0.0
	return diff.length()


## Start a turn-in-place step.
func _start_turn_step(left_target: Vector3, right_target: Vector3, left_drift: float, right_drift: float) -> void:
	_is_turning_in_place = true
	_turn_step_progress = 0.0

	# Step the foot that's furthest from its target
	_stepping_foot = 0 if left_drift >= right_drift else 1

	# Set up step start/end positions
	_left_step_start = _left_plant_pos
	_left_step_end = left_target
	_right_step_start = _right_plant_pos
	_right_step_end = right_target


## Process ongoing turn-in-place step animation.
func _process_turn_step(delta: float, left_target: Vector3, right_target: Vector3) -> void:
	# Advance step progress
	_turn_step_progress += turn_step_speed * delta

	# Update targets in case character is still rotating
	_left_step_end = left_target
	_right_step_end = right_target

	# Get current yaw for stepping foot target
	var current_yaw := _visuals.global_rotation.y

	if _turn_step_progress >= 1.0:
		# First foot step complete — update plant position AND yaw
		if _stepping_foot == 0:
			_left_plant_pos = _left_step_end
			_left_plant_yaw = current_yaw
		else:
			_right_plant_pos = _right_step_end
			_right_plant_yaw = current_yaw

		# Check if other foot needs to step
		var left_drift := _horizontal_distance(_left_plant_pos, left_target)
		var right_drift := _horizontal_distance(_right_plant_pos, right_target)
		var threshold := stride_length * turn_drift_threshold

		var other_foot := 1 if _stepping_foot == 0 else 0
		var other_drift := right_drift if other_foot == 1 else left_drift

		if other_drift > threshold:
			# Other foot needs to step
			_stepping_foot = other_foot
			_turn_step_progress = 0.0
			if _stepping_foot == 0:
				_left_step_start = _left_plant_pos
			else:
				_right_step_start = _right_plant_pos
		else:
			# Turn complete - update planted yaw to current facing
			_is_turning_in_place = false
			_left_plant_pos = _left_step_end
			_right_plant_pos = _right_step_end
			var final_yaw := _visuals.global_rotation.y
			_left_plant_yaw = final_yaw
			_right_plant_yaw = final_yaw

		_apply_foot_target(_left_target, _left_plant_pos, _left_plant_yaw, _left_ground_normal, _left_foot_rest_basis, 0.0, delta)
		_apply_foot_target(_right_target, _right_plant_pos, _right_plant_yaw, _right_ground_normal, _right_foot_rest_basis, 0.0, delta)
		_update_hip(delta, 0.0)
		return

	# Animate the stepping foot
	var current_progress: float = _turn_step_progress
	var arc_height: float = turn_step_height * sin(current_progress * PI)
	# Weight shift: planted foot lowers slightly, bending that knee via IK
	var plant_dip: float = -turn_crouch_amount * sin(current_progress * PI)
	var target_yaw := _visuals.global_rotation.y

	var left_pos: Vector3
	var right_pos: Vector3
	var left_yaw: float
	var right_yaw: float

	var left_swing_t: float = 0.0
	var right_swing_t: float = 0.0

	if _stepping_foot == 0:
		# Left is stepping — interpolate toward target yaw
		left_pos = _left_step_start.lerp(_left_step_end, current_progress)
		left_pos.y += arc_height
		left_yaw = lerp_angle(_left_plant_yaw, target_yaw, current_progress)
		left_swing_t = current_progress  # Foot is in swing
		# Right stays planted — lower it to bend knee (weight shift)
		right_pos = _right_plant_pos
		right_pos.y += plant_dip
		right_yaw = _right_plant_yaw
	else:
		# Right is stepping — interpolate toward target yaw
		right_pos = _right_step_start.lerp(_right_step_end, current_progress)
		right_pos.y += arc_height
		right_yaw = lerp_angle(_right_plant_yaw, target_yaw, current_progress)
		right_swing_t = current_progress  # Foot is in swing
		# Left stays planted — lower it to bend knee (weight shift)
		left_pos = _left_plant_pos
		left_pos.y += plant_dip
		left_yaw = _left_plant_yaw

	_apply_foot_target(_left_target, left_pos, left_yaw, _left_ground_normal, _left_foot_rest_basis, left_swing_t, delta)
	_apply_foot_target(_right_target, right_pos, right_yaw, _right_ground_normal, _right_foot_rest_basis, right_swing_t, delta)

	# Hip follows lowest foot
	_update_hip(delta, 0.0)


## Process one foot's position for the current cycle value.
func _process_foot(
	cycle: float, prev_cycle: float,
	plant_pos: Vector3, rest_pos: Vector3,
	move_dir: Vector3, speed: float, side: float, delta: float
) -> Vector3:
	if cycle < stance_ratio:
		# Plant phase — foot stays at planted world position
		# Reset swing target so it's fresh when swing starts
		if side < 0:
			_left_swing_target = plant_pos
			_left_swing_t = 0.0
		else:
			_right_swing_target = plant_pos
			_right_swing_t = 0.0
		return plant_pos
	else:
		# Swing phase — arc from plant position toward next predicted plant
		var swing_t := (cycle - stance_ratio) / (1.0 - stance_ratio)  # 0–1 within swing

		# Store swing progress for foot rotation
		if side < 0:
			_left_swing_t = swing_t
		else:
			_right_swing_t = swing_t

		# Smoothstep for horizontal movement (ease-in lift, ease-out land)
		var eased_t := swing_t * swing_t * (3.0 - 2.0 * swing_t)

		# Target is recalculated each frame to track character movement
		var raw_target := _predict_plant_position(move_dir, speed, side)

		# Smooth the swing target (prevents snappy prediction changes)
		var target_smooth := 1.0 - exp(-8.0 * delta)
		var swing_target: Vector3
		if side < 0:
			# Just started swing - snap to target
			if prev_cycle < stance_ratio:
				_left_swing_target = raw_target
			else:
				_left_swing_target = _left_swing_target.lerp(raw_target, target_smooth)
			swing_target = _left_swing_target
		else:
			if prev_cycle < stance_ratio:
				_right_swing_target = raw_target
			else:
				_right_swing_target = _right_swing_target.lerp(raw_target, target_smooth)
			swing_target = _right_swing_target

		# Swing from where we lifted (plant_pos) to where we're landing (smoothed target)
		var ground_pos := plant_pos.lerp(swing_target, eased_t)

		# Arc height - quick lift, soft landing
		# pow(t, 0.6) lifts faster at start, settles slower at end
		var lift_t := pow(swing_t, 0.6)
		var arc_height: float = step_height * sin(lift_t * PI)
		ground_pos.y += arc_height

		return ground_pos


## Predict where the foot should plant next based on movement.
## Standard stride wheel: foot plants 0.5 stride ahead, ends 0.5 stride behind when lifting.
## This creates natural weight transfer as the body passes over the planted foot.
func _predict_plant_position(move_dir: Vector3, speed: float, side: float) -> Vector3:
	if _visuals.controller == null:
		return Vector3.ZERO

	var char_pos := _visuals.controller.global_position

	# Use effective stride (scales with speed)
	var effective_stride := _get_effective_stride(speed)

	# Forward offset: plant ahead of current position
	# Higher plant_ahead_ratio = foot lands further forward from body center
	var forward_offset: Vector3 = move_dir * effective_stride * plant_ahead_ratio

	# Lateral offset perpendicular to movement direction
	var lateral: Vector3 = move_dir.cross(Vector3.UP).normalized() * side * foot_lateral_offset
	if lateral.is_zero_approx():
		# Fallback: use character's right vector
		lateral = _visuals.controller.global_basis.x * side * foot_lateral_offset

	var predicted: Vector3 = char_pos + forward_offset + lateral

	# Raycast to find actual ground
	return _raycast_ground(predicted)


## Raycast down from a position to find the ground point.
func _raycast_ground(world_pos: Vector3) -> Vector3:
	if _space_state == null:
		return world_pos

	var origin: Vector3 = world_pos + Vector3.UP * ray_height
	var end: Vector3 = world_pos + Vector3.DOWN * ray_depth

	var query := PhysicsRayQueryParameters3D.create(origin, end)
	query.collision_mask = ground_layers
	if _visuals.controller:
		query.exclude = [_visuals.controller.get_rid()]

	var result := _space_state.intersect_ray(query)
	if result.is_empty():
		return world_pos

	# Store normal for foot rotation (determine which foot by proximity)
	var hit_normal: Vector3 = result.normal
	if world_pos.distance_squared_to(_left_rest_pos) < world_pos.distance_squared_to(_right_rest_pos):
		_left_ground_normal = hit_normal
	else:
		_right_ground_normal = hit_normal

	# Raise hit position by foot_height so sole sits on ground (not ankle)
	return result.position + Vector3.UP * foot_height


## Detect if a cycle value crossed a threshold (handles wrap-around).
func _crossed_threshold(current: float, previous: float, threshold: float) -> bool:
	if previous <= current:
		# Normal progression
		return previous < threshold and current >= threshold
	else:
		# Wrapped around (1.0 → 0.0)
		return previous < threshold or current >= threshold


## Force re-plant if foot is too far from character. Returns clamped position.
func _clamp_plant_distance(plant_pos: Vector3, max_dist: float) -> Vector3:
	if _visuals.controller == null:
		return plant_pos

	var char_pos := _visuals.controller.global_position
	var offset := plant_pos - char_pos
	offset.y = 0.0
	if offset.length_squared() > max_dist * max_dist:
		var clamped := char_pos + offset.normalized() * max_dist
		clamped.y = plant_pos.y
		return clamped
	return plant_pos


## Update hip offset: base offset + sinusoidal bob + torso lag + forward lean.
func _update_hip(delta: float, bob: float, move_dir: Vector3 = Vector3.ZERO) -> void:
	var target_offset := hip_offset + bob
	var smooth_factor := 1.0 - exp(-hip_smooth_speed * delta)

	_current_hip_offset = lerpf(
		_current_hip_offset, target_offset,
		smooth_factor
	)

	# Torso lag: offset torso BEHIND movement direction so feet appear to lead
	var target_lag := -move_dir * body_trail_distance
	_current_hip_forward = _current_hip_forward.lerp(target_lag, smooth_factor)

	# Forward lean: tilt torso forward when moving
	var target_lean := deg_to_rad(forward_lean_angle) if move_dir.length_squared() > 0.01 else 0.0
	_current_lean_angle = lerpf(_current_lean_angle, target_lean, smooth_factor)

	# Apply position to visual root
	_visuals.position.y = _current_hip_offset
	_visuals.position.x = _current_hip_forward.x
	_visuals.position.z = _current_hip_forward.z

	# Apply forward lean to spine_01 bone
	if _skeleton and _spine_01_idx != -1:
		var target_basis: Basis = _spine_rest_basis
		if _current_lean_angle != 0.0:
			# Rotate around local Z axis (bone's forward axis for pitch)
			var lean_rotation := Basis(Vector3.FORWARD, _current_lean_angle)
			target_basis = _spine_rest_basis * lean_rotation

		# Smooth spine rotation
		var spine_smooth := 1.0 - exp(-spine_smooth_speed * delta)
		_current_spine_basis = _current_spine_basis.slerp(target_basis, spine_smooth)

		var rest_pose := _skeleton.get_bone_rest(_spine_01_idx)
		_skeleton.set_bone_pose(_spine_01_idx, Transform3D(_current_spine_basis, rest_pose.origin))


## Blend IK influence up when moving, down at idle.
func _update_influence(delta: float, _is_moving: bool) -> void:
	var grounded := _visuals.is_grounded()
	# For procedural stride wheel, IK should be active whenever grounded
	# (feet need to stay planted whether moving, idle, or turning)
	var target: float = 1.0 if grounded else 0.0

	_current_influence = lerpf(
		_current_influence, target,
		1.0 - exp(-influence_blend_speed * delta)
	)


## Apply influence to both IK solvers.
func _apply_influence() -> void:
	if _left_ik and _left_ik.has_method("set"):
		_left_ik.set("influence", _current_influence)
	if _right_ik and _right_ik.has_method("set"):
		_right_ik.set("influence", _current_influence)


## Position and rotate a foot target Marker3D with smoothing.
## yaw: The Y rotation (facing direction) for the foot.
## ground_normal: The ground normal from raycast for slope adaptation.
## rest_basis: The foot bone's rest orientation (captured at setup).
## swing_t: Swing phase progress (0 = planted, >0 = in swing). Used for foot pitch during swing.
## delta: Frame delta for smoothing.
func _apply_foot_target(target: Marker3D, world_pos: Vector3, yaw: float, ground_normal: Vector3, rest_basis: Basis, swing_t: float, delta: float) -> void:
	if target == null:
		return

	# Build foot basis from rest pose + yaw delta + ground tilt + swing pitch
	var target_basis := _compute_foot_basis(yaw, ground_normal, rest_basis, swing_t)

	# Determine which foot and get/set smoothed state
	var is_left := target == _left_target
	var current_pos: Vector3 = _left_current_pos if is_left else _right_current_pos

	# Always smooth foot movement
	var distance_to_target := current_pos.distance_to(world_pos)
	var far_threshold := stride_length * 0.5

	# Consistent smoothing with slight boost when far
	var speed_mult := 1.0 + clampf(distance_to_target / far_threshold, 0.0, 1.0)
	var smooth_factor := 1.0 - exp(-foot_smooth_speed * speed_mult * delta)

	if is_left:
		if not _left_foot_initialized:
			_left_current_pos = world_pos
			_left_current_basis = target_basis
			_left_foot_initialized = true
		else:
			_left_current_pos = _left_current_pos.lerp(world_pos, smooth_factor)
			_left_current_basis = _left_current_basis.slerp(target_basis, smooth_factor)
	else:
		if not _right_foot_initialized:
			_right_current_pos = world_pos
			_right_current_basis = target_basis
			_right_foot_initialized = true
		else:
			_right_current_pos = _right_current_pos.lerp(world_pos, smooth_factor)
			_right_current_basis = _right_current_basis.slerp(target_basis, smooth_factor)

	# Apply smoothed values
	var final_pos: Vector3
	var final_basis: Basis
	if is_left:
		final_pos = _left_current_pos
		final_basis = _left_current_basis
	else:
		final_pos = _right_current_pos
		final_basis = _right_current_basis

	target.global_transform = Transform3D(final_basis, final_pos)


## Compute foot basis from yaw delta, ground normal, and swing phase.
## Preserves the foot bone's rest orientation while rotating to face the target yaw.
## swing_t: 0 = planted/just lifted, 1 = about to land. Adds pitch during swing.
func _compute_foot_basis(yaw: float, ground_normal: Vector3, rest_basis: Basis, swing_t: float) -> Basis:
	# Compute how much we need to rotate from the initial character yaw
	var delta_yaw := yaw - _initial_char_yaw

	# Rotate the rest basis around Y by the delta
	var yaw_rotation := Basis(Vector3.UP, delta_yaw)
	var result := yaw_rotation * rest_basis

	# Swing phase pitch - toes down at lift-off, level at mid-swing
	if swing_t > 0.0 and swing_pitch_angle > 0.0:
		# Pitch curve: negative at start (toes down), approaches zero at landing
		var pitch_angle := -sin((1.0 - swing_t) * PI * 0.5) * deg_to_rad(swing_pitch_angle)
		if pitch_angle != 0.0:
			# Rotate around the foot's local lateral axis (not world X)
			var pitch_axis := result.x.normalized()
			result = Basis(pitch_axis, pitch_angle) * result

	# Apply ground normal tilt if not flat (only when planted, not during swing)
	if swing_t == 0.0 and not ground_normal.is_equal_approx(Vector3.UP):
		var angle := Vector3.UP.angle_to(ground_normal)
		angle = clampf(angle, 0.0, deg_to_rad(max_foot_angle))
		angle *= foot_rotation_weight

		var tilt_axis := Vector3.UP.cross(ground_normal).normalized()
		if not tilt_axis.is_zero_approx():
			var tilt_basis := Basis(tilt_axis, angle)
			result = tilt_basis * result

	return result


## Get a bone's position in world space.
func _get_bone_world_position(bone_idx: int) -> Vector3:
	var bone_global_pose := _skeleton.get_bone_global_pose(bone_idx)
	return _skeleton.global_transform * bone_global_pose.origin


# =============================================================================
# DEBUG VISUALIZATION
# =============================================================================

## Create debug visualization meshes.
func _setup_debug() -> void:
	if _debug_container:
		_debug_container.queue_free()

	_debug_container = Node3D.new()
	_debug_container.name = "StrideWheelDebug"
	get_tree().root.add_child.call_deferred(_debug_container)

	# Left plant position - GREEN
	_debug_left_plant = _create_debug_sphere(Color.GREEN, "L PLANT")
	_debug_left_plant.name = "LeftPlant"

	# Right plant position - BLUE
	_debug_right_plant = _create_debug_sphere(Color.BLUE, "R PLANT")
	_debug_right_plant.name = "RightPlant"

	# Left predicted position - YELLOW
	_debug_left_predicted = _create_debug_sphere(Color.YELLOW, "L PRED")
	_debug_left_predicted.name = "LeftPredicted"

	# Right predicted position - ORANGE
	_debug_right_predicted = _create_debug_sphere(Color.ORANGE, "R PRED")
	_debug_right_predicted.name = "RightPredicted"

	# Character reference position - WHITE
	_debug_char_pos = _create_debug_sphere(Color.WHITE, "CHAR")
	_debug_char_pos.name = "CharPos"

	# Left foot target (actual IK target) - LIME
	_debug_left_target = _create_debug_sphere(Color.LIME, "L IK")
	_debug_left_target.name = "LeftTarget"

	# Right foot target (actual IK target) - CYAN
	_debug_right_target = _create_debug_sphere(Color.CYAN, "R IK")
	_debug_right_target.name = "RightTarget"

	# Movement direction - MAGENTA (use a stretched sphere as arrow)
	_debug_move_dir = _create_debug_sphere(Color.MAGENTA, "DIR")
	_debug_move_dir.name = "MoveDir"

	# Stride wheels - torus showing the wheel path
	_debug_left_wheel = _create_debug_wheel(Color.GREEN)
	_debug_left_wheel.name = "LeftWheel"
	_debug_right_wheel = _create_debug_wheel(Color.BLUE)
	_debug_right_wheel.name = "RightWheel"

	# Clock position markers (12, 3, 6, 9 o'clock)
	var marker_labels := ["12", "3", "6", "9"]
	_debug_left_markers.clear()
	_debug_right_markers.clear()
	for i in range(4):
		var left_marker := _create_debug_sphere(Color.GREEN_YELLOW, marker_labels[i])
		left_marker.name = "LeftMarker" + str(i)
		_debug_left_markers.append(left_marker)
		var right_marker := _create_debug_sphere(Color.DODGER_BLUE, marker_labels[i])
		right_marker.name = "RightMarker" + str(i)
		_debug_right_markers.append(right_marker)

	# Spokes on each wheel (4 spokes for visibility)
	_debug_left_spokes.clear()
	_debug_right_spokes.clear()
	for i in range(4):
		var left_spoke := _create_debug_spoke(Color.GREEN)
		left_spoke.name = "LeftSpoke" + str(i)
		_debug_left_spokes.append(left_spoke)
		var right_spoke := _create_debug_spoke(Color.BLUE)
		right_spoke.name = "RightSpoke" + str(i)
		_debug_right_spokes.append(right_spoke)

	# Phase indicators - small spheres showing current position on wheel (no label)
	_debug_left_phase = _create_debug_sphere(Color.GREEN, "")
	_debug_left_phase.name = "LeftPhase"
	_debug_right_phase = _create_debug_sphere(Color.BLUE, "")
	_debug_right_phase.name = "RightPhase"

	# Overhead labels above player's head
	_debug_overhead_left_label = _create_overhead_label(Color.GREEN)
	_debug_overhead_left_label.name = "OverheadLeftLabel"
	_debug_overhead_right_label = _create_overhead_label(Color.CYAN)
	_debug_overhead_right_label.name = "OverheadRightLabel"


## Create a debug cog tooth (box pointing outward).
func _create_debug_spoke(color: Color) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.02, 0.15, 0.01)  # Longer rectangular spike
	mesh_instance.mesh = box

	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh_instance.material_override = material

	_debug_container.add_child(mesh_instance)
	return mesh_instance


## Create a debug wheel (torus) mesh.
func _create_debug_wheel(color: Color) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = stride_length * 0.48
	torus.outer_radius = stride_length * 0.52
	torus.rings = 32
	torus.ring_segments = 8
	mesh_instance.mesh = torus

	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.albedo_color.a = 0.3
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh_instance.material_override = material

	_debug_container.add_child(mesh_instance)
	return mesh_instance


## Create a debug sphere mesh with a label.
func _create_debug_sphere(color: Color, label_text: String) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = debug_sphere_size
	sphere.height = debug_sphere_size * 2.0
	mesh_instance.mesh = sphere

	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color.a = 0.8
	mesh_instance.material_override = material

	# Add a label above the sphere
	var label := Label3D.new()
	label.text = label_text
	label.font_size = 32
	label.pixel_size = 0.002
	label.position = Vector3(0, 0.15, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.modulate = color
	label.outline_size = 8
	label.outline_modulate = Color.BLACK
	mesh_instance.add_child(label)

	_debug_container.add_child(mesh_instance)
	return mesh_instance


## Create an overhead label for displaying phase info above the player.
func _create_overhead_label(color: Color) -> Label3D:
	var label := Label3D.new()
	label.text = ""
	label.font_size = 24
	label.pixel_size = 0.002
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.modulate = color
	label.outline_size = 6
	label.outline_modulate = Color.BLACK
	_debug_container.add_child(label)
	return label


## Update debug visualization positions.
func _update_debug(char_pos: Vector3, move_dir: Vector3) -> void:
	if not debug_enabled or not _debug_container:
		if _debug_container:
			_debug_container.visible = false
		return

	_debug_container.visible = true

	# Update sphere sizes
	var size := debug_sphere_size
	_update_sphere_size(_debug_left_plant, size)
	_update_sphere_size(_debug_right_plant, size)
	_update_sphere_size(_debug_left_predicted, size * 0.7)
	_update_sphere_size(_debug_right_predicted, size * 0.7)
	_update_sphere_size(_debug_char_pos, size * 1.2)
	_update_sphere_size(_debug_left_target, size * 0.5)
	_update_sphere_size(_debug_right_target, size * 0.5)
	_update_sphere_size(_debug_move_dir, size * 0.5)

	# Plant positions
	if debug_show_plant_pos:
		_debug_left_plant.visible = true
		_debug_right_plant.visible = true
		_debug_left_plant.global_position = _left_plant_pos + Vector3.UP * 0.01
		_debug_right_plant.global_position = _right_plant_pos + Vector3.UP * 0.01
	else:
		_debug_left_plant.visible = false
		_debug_right_plant.visible = false

	# Predicted positions
	if debug_show_predicted:
		_debug_left_predicted.visible = true
		_debug_right_predicted.visible = true
		_debug_left_predicted.global_position = _debug_left_predicted_pos + Vector3.UP * 0.02
		_debug_right_predicted.global_position = _debug_right_predicted_pos + Vector3.UP * 0.02
	else:
		_debug_left_predicted.visible = false
		_debug_right_predicted.visible = false

	# Character position
	if debug_show_char_pos:
		_debug_char_pos.visible = true
		_debug_char_pos.global_position = char_pos + Vector3.UP * 0.03
	else:
		_debug_char_pos.visible = false

	# Movement direction
	if debug_show_move_dir and move_dir.length_squared() > 0.01:
		_debug_move_dir.visible = true
		_debug_move_dir.global_position = char_pos + move_dir * 0.5 + Vector3.UP * 0.05
	else:
		_debug_move_dir.visible = false

	# Actual IK target positions
	if _left_target:
		_debug_left_target.visible = true
		_debug_left_target.global_position = _left_target.global_position + Vector3.UP * 0.03
	else:
		_debug_left_target.visible = false

	if _right_target:
		_debug_right_target.visible = true
		_debug_right_target.global_position = _right_target.global_position + Vector3.UP * 0.03
	else:
		_debug_right_target.visible = false

	# Stride wheels and phase indicators
	if debug_show_stride_wheel and _debug_left_wheel and _debug_right_wheel:
		var wheel_radius := stride_length * 0.5
		var wheel_height := step_height

		# Position wheels at hip height, offset laterally
		var hip_pos := char_pos + Vector3.UP * 0.5  # Approximate hip height
		var facing := _visuals.global_basis if _visuals else Basis.IDENTITY
		# Push wheels further out to the sides for visibility
		var wheel_lateral := foot_lateral_offset + 0.4
		var left_offset := -facing.x * wheel_lateral
		var right_offset := facing.x * wheel_lateral

		# Determine wheel orientation basis
		var wheel_basis: Basis
		if move_dir.length_squared() > 0.01:
			wheel_basis = Basis.looking_at(move_dir, Vector3.UP)
		else:
			wheel_basis = facing

		# Left wheel - vertical plane (standing upright like a rolling wheel)
		# Torus default is XZ plane (flat). Rotate around Z to stand vertical, facing movement.
		_debug_left_wheel.visible = true
		_debug_left_wheel.global_position = hip_pos + left_offset
		_debug_left_wheel.global_basis = wheel_basis * Basis(Vector3.FORWARD, PI * 0.5)

		# Right wheel
		_debug_right_wheel.visible = true
		_debug_right_wheel.global_position = hip_pos + right_offset
		_debug_right_wheel.global_basis = wheel_basis * Basis(Vector3.FORWARD, PI * 0.5)

		# Update wheel sizes based on current stride
		if _debug_left_wheel.mesh is TorusMesh:
			var torus := _debug_left_wheel.mesh as TorusMesh
			torus.inner_radius = wheel_radius * 0.96
			torus.outer_radius = wheel_radius * 1.04
		if _debug_right_wheel.mesh is TorusMesh:
			var torus := _debug_right_wheel.mesh as TorusMesh
			torus.inner_radius = wheel_radius * 0.96
			torus.outer_radius = wheel_radius * 1.04

		# Clock position markers at 12, 3, 6, 9 o'clock
		# In wheel space: 12=top, 3=front, 6=bottom, 9=back
		var clock_angles: Array[float] = [0.0, PI * 0.5, PI, PI * 1.5]  # 12, 3, 6, 9
		for i in range(4):
			var angle: float = clock_angles[i]
			# Y = height (cos), Z = forward/back (sin) so 12 o'clock = top
			var marker_local := Vector3(0, cos(angle) * wheel_radius, sin(angle) * wheel_radius)

			if i < _debug_left_markers.size():
				_debug_left_markers[i].visible = true
				_debug_left_markers[i].global_position = hip_pos + left_offset + wheel_basis * marker_local
				_update_sphere_size(_debug_left_markers[i], debug_sphere_size * 0.6)

			if i < _debug_right_markers.size():
				_debug_right_markers[i].visible = true
				_debug_right_markers[i].global_position = hip_pos + right_offset + wheel_basis * marker_local
				_update_sphere_size(_debug_right_markers[i], debug_sphere_size * 0.6)

		# Phase indicators - position on wheel circumference
		var left_cycle := fmod(_phase / TAU, 1.0)
		var right_cycle := fmod((_phase + PI) / TAU, 1.0)

		# Convert cycle to wheel angle:
		# Invert cycle so wheel rolls forward visually
		var left_angle := (1.0 - left_cycle) * TAU
		var right_angle := (1.0 - right_cycle) * TAU

		# Calculate position on wheel (Y = height via cos, Z = forward/back via sin)
		var left_phase_local := Vector3(0, cos(left_angle) * wheel_radius, sin(left_angle) * wheel_radius)
		var right_phase_local := Vector3(0, cos(right_angle) * wheel_radius, sin(right_angle) * wheel_radius)

		_debug_left_phase.visible = true
		_debug_right_phase.visible = true
		_update_sphere_size(_debug_left_phase, debug_sphere_size * 0.8)
		_update_sphere_size(_debug_right_phase, debug_sphere_size * 0.8)

		_debug_left_phase.global_position = hip_pos + left_offset + wheel_basis * left_phase_local
		_debug_right_phase.global_position = hip_pos + right_offset + wheel_basis * right_phase_local

		# Update overhead labels with percentage and state
		var left_pct := int(left_cycle * 100)
		var right_pct := int(right_cycle * 100)
		var left_state := "SWING" if left_cycle >= 0.5 else "STANCE"
		var right_state := "SWING" if right_cycle >= 0.5 else "STANCE"

		# Position overhead labels above player's head
		var head_pos := char_pos + Vector3.UP * 2.2
		if _debug_overhead_left_label:
			_debug_overhead_left_label.visible = true
			_debug_overhead_left_label.global_position = head_pos
			_debug_overhead_left_label.text = "L %d%% %s" % [left_pct, left_state]
		if _debug_overhead_right_label:
			_debug_overhead_right_label.visible = true
			_debug_overhead_right_label.global_position = head_pos + Vector3.DOWN * 0.12
			_debug_overhead_right_label.text = "R %d%% %s" % [right_pct, right_state]

		# Position cog teeth on wheel rim, rotating with phase
		var tooth_count := _debug_left_spokes.size()
		for i in range(tooth_count):
			var tooth_base_angle: float = (float(i) / float(tooth_count)) * TAU
			# Add phase offset so teeth rotate with the gait cycle
			var left_tooth_angle: float = tooth_base_angle + left_angle
			var right_tooth_angle: float = tooth_base_angle + right_angle

			# Position on the wheel rim (cos for Y, sin for Z so 0 angle = top)
			var left_tooth_pos := Vector3(0, cos(left_tooth_angle) * wheel_radius, sin(left_tooth_angle) * wheel_radius)
			var right_tooth_pos := Vector3(0, cos(right_tooth_angle) * wheel_radius, sin(right_tooth_angle) * wheel_radius)

			if i < _debug_left_spokes.size():
				_debug_left_spokes[i].visible = true
				var left_rim_pos: Vector3 = hip_pos + left_offset + wheel_basis * left_tooth_pos
				var left_center: Vector3 = hip_pos + left_offset
				var left_outward: Vector3 = (left_rim_pos - left_center).normalized()
				# Offset by half spike height so base sits on rim
				var left_world_pos: Vector3 = left_rim_pos + left_outward * 0.075
				_debug_left_spokes[i].global_position = left_world_pos
				_debug_left_spokes[i].global_basis = _basis_from_y(left_outward)

			if i < _debug_right_spokes.size():
				_debug_right_spokes[i].visible = true
				var right_rim_pos: Vector3 = hip_pos + right_offset + wheel_basis * right_tooth_pos
				var right_center: Vector3 = hip_pos + right_offset
				var right_outward: Vector3 = (right_rim_pos - right_center).normalized()
				var right_world_pos: Vector3 = right_rim_pos + right_outward * 0.075
				_debug_right_spokes[i].global_position = right_world_pos
				_debug_right_spokes[i].global_basis = _basis_from_y(right_outward)
	else:
		if _debug_left_wheel:
			_debug_left_wheel.visible = false
		if _debug_right_wheel:
			_debug_right_wheel.visible = false
		if _debug_left_phase:
			_debug_left_phase.visible = false
		if _debug_right_phase:
			_debug_right_phase.visible = false
		for marker in _debug_left_markers:
			marker.visible = false
		for marker in _debug_right_markers:
			marker.visible = false
		for spoke in _debug_left_spokes:
			spoke.visible = false
		for spoke in _debug_right_spokes:
			spoke.visible = false
		if _debug_overhead_left_label:
			_debug_overhead_left_label.visible = false
		if _debug_overhead_right_label:
			_debug_overhead_right_label.visible = false


## Update a sphere mesh size.
func _update_sphere_size(mesh_instance: MeshInstance3D, size: float) -> void:
	if mesh_instance and mesh_instance.mesh is SphereMesh:
		var sphere := mesh_instance.mesh as SphereMesh
		sphere.radius = size
		sphere.height = size * 2.0


## Update label text on a debug sphere.
func _update_debug_label(mesh_instance: MeshInstance3D, text: String) -> void:
	if mesh_instance == null:
		return
	for child in mesh_instance.get_children():
		if child is Label3D:
			child.text = text
			return


## Create a basis with Y axis pointing in the given direction.
func _basis_from_y(y_dir: Vector3) -> Basis:
	var up := y_dir.normalized()
	var right := up.cross(Vector3.FORWARD).normalized()
	if right.is_zero_approx():
		right = up.cross(Vector3.RIGHT).normalized()
	var forward := right.cross(up).normalized()
	return Basis(right, up, forward)


## Cleanup debug meshes.
func _cleanup_debug() -> void:
	if _debug_container:
		_debug_container.queue_free()
		_debug_container = null
