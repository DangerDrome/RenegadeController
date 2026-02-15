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
## Distance per step (half-cycle). Larger = longer strides.
@export var stride_length: float = 0.7:
	set(value):
		stride_length = value
		if config:
			config.stride_length = value
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

@export_group("Hip")
## Vertical pelvis bob amplitude during walk cycle.
@export var hip_bob_amount: float = 0.03:
	set(value):
		hip_bob_amount = value
		if config:
			config.hip_bob_amount = value
## Hip offset (negative = lower hips, causes knee bend).
@export var hip_offset: float = 0.0:
	set(value):
		hip_offset = value
		if config:
			config.hip_offset = value
## Smoothing speed for hip offset changes.
@export_range(1.0, 30.0) var hip_smooth_speed: float = 10.0:
	set(value):
		hip_smooth_speed = value
		if config:
			config.hip_smooth_speed = value

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

var _visuals: CharacterVisuals
var _skeleton: Skeleton3D

# IK node references
var _left_ik: Node
var _right_ik: Node
var _left_target: Marker3D
var _right_target: Marker3D

# Bone indices
var _pelvis_idx: int = -1
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
var _left_ground_normal: Vector3 = Vector3.UP
var _right_ground_normal: Vector3 = Vector3.UP

# Hip
var _current_hip_offset: float = 0.0

# Influence
var _current_influence: float = 0.0

# Physics
var _space_state: PhysicsDirectSpaceState3D

# Rest positions (bind pose feet in world space, cached each frame)
var _left_rest_pos: Vector3 = Vector3.ZERO
var _right_rest_pos: Vector3 = Vector3.ZERO

# Turn-in-place state
var _prev_yaw: float = 0.0
var _is_turning_in_place: bool = false
var _turn_step_progress: float = 0.0  # 0–1 for step animation
var _left_step_start: Vector3 = Vector3.ZERO
var _left_step_end: Vector3 = Vector3.ZERO
var _right_step_start: Vector3 = Vector3.ZERO
var _right_step_end: Vector3 = Vector3.ZERO
var _stepping_foot: int = 0  # 0 = left, 1 = right

# Foot rotation modifiers (copy rotation from Marker3D targets to foot bones)
var _left_foot_rot_modifier: CopyTransformModifier3D
var _right_foot_rot_modifier: CopyTransformModifier3D

# Foot bone rest orientation (captured at setup to preserve skeleton's foot direction)
var _left_foot_rest_basis: Basis = Basis.IDENTITY
var _right_foot_rest_basis: Basis = Basis.IDENTITY
var _initial_char_yaw: float = 0.0  # Character yaw when rest basis was captured



## Sync local @export properties from the config resource.
func _sync_from_config() -> void:
	if config == null:
		return
	# Use direct assignment to avoid setter triggering back
	stride_length = config.stride_length
	step_height = config.step_height
	foot_lateral_offset = config.foot_lateral_offset
	foot_height = config.foot_height
	hip_bob_amount = config.hip_bob_amount
	hip_offset = config.hip_offset
	hip_smooth_speed = config.hip_smooth_speed
	ray_height = config.ray_height
	ray_depth = config.ray_depth
	ground_layers = config.ground_layers
	idle_threshold = config.idle_threshold
	influence_blend_speed = config.influence_blend_speed
	turn_drift_threshold = config.turn_drift_threshold
	turn_step_speed = config.turn_step_speed
	turn_step_height = config.turn_step_height
	turn_crouch_amount = config.turn_crouch_amount
	stance_stagger = config.stance_stagger
	foot_rotation_weight = config.foot_rotation_weight
	max_foot_angle = config.max_foot_angle


func _ready() -> void:
	_visuals = get_parent() as CharacterVisuals
	if _visuals == null:
		push_error("StrideWheelComponent: Parent must be a CharacterVisuals node.")
		return

	if config == null:
		config = StrideWheelConfig.new()
	_sync_from_config()

	_visuals.ready.connect(_setup, CONNECT_ONE_SHOT | CONNECT_DEFERRED)


func _setup() -> void:
	_skeleton = _visuals.skeleton
	if _skeleton == null:
		push_error("StrideWheelComponent: No skeleton found on CharacterVisuals.")
		return

	var skel_config := _visuals.skeleton_config
	if skel_config == null:
		skel_config = SkeletonConfig.new()

	_pelvis_idx = _skeleton.find_bone(skel_config.pelvis_bone)
	_left_foot_idx = _skeleton.find_bone(skel_config.left_foot)
	_right_foot_idx = _skeleton.find_bone(skel_config.right_foot)

	if _pelvis_idx == -1:
		push_warning("StrideWheelComponent: Pelvis bone '%s' not found." % skel_config.pelvis_bone)
	if _left_foot_idx == -1:
		push_warning("StrideWheelComponent: Left foot bone '%s' not found." % skel_config.left_foot)
	if _right_foot_idx == -1:
		push_warning("StrideWheelComponent: Right foot bone '%s' not found." % skel_config.right_foot)

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


## Create CopyTransformModifier3D nodes to copy rotation from Marker3D targets to foot bones.
## TwoBoneIK3D only handles position; this handles rotation.
func _setup_foot_rotation_modifiers(skel_config: SkeletonConfig) -> void:
	if _skeleton == null:
		return

	# Create left foot rotation modifier
	if _left_target and _left_foot_idx != -1:
		_left_foot_rot_modifier = CopyTransformModifier3D.new()
		_left_foot_rot_modifier.name = "StrideWheelLeftFootRotation"
		_left_foot_rot_modifier.setting_count = 1
		_left_foot_rot_modifier.set_apply_bone_name(0, skel_config.left_foot)
		_left_foot_rot_modifier.set_reference_type(0, BoneConstraint3D.REFERENCE_TYPE_NODE)
		_left_foot_rot_modifier.set_reference_node(0, _left_target.get_path())
		# Copy rotation only, not position (TwoBoneIK3D handles that)
		_left_foot_rot_modifier.set_copy_position(0, false)
		_left_foot_rot_modifier.set_copy_rotation(0, true)
		_left_foot_rot_modifier.set_copy_scale(0, false)
		_left_foot_rot_modifier.set_axis_flags(0, CopyTransformModifier3D.AXIS_FLAG_ALL)
		# Not additive - we want to SET the rotation, not add to it
		_left_foot_rot_modifier.set_additive(0, false)
		# Not relative - we want absolute world rotation
		_left_foot_rot_modifier.set_relative(0, false)
		_skeleton.add_child(_left_foot_rot_modifier)

	# Create right foot rotation modifier
	if _right_target and _right_foot_idx != -1:
		_right_foot_rot_modifier = CopyTransformModifier3D.new()
		_right_foot_rot_modifier.name = "StrideWheelRightFootRotation"
		_right_foot_rot_modifier.setting_count = 1
		_right_foot_rot_modifier.set_apply_bone_name(0, skel_config.right_foot)
		_right_foot_rot_modifier.set_reference_type(0, BoneConstraint3D.REFERENCE_TYPE_NODE)
		_right_foot_rot_modifier.set_reference_node(0, _right_target.get_path())
		_right_foot_rot_modifier.set_copy_position(0, false)
		_right_foot_rot_modifier.set_copy_rotation(0, true)
		_right_foot_rot_modifier.set_copy_scale(0, false)
		_right_foot_rot_modifier.set_axis_flags(0, CopyTransformModifier3D.AXIS_FLAG_ALL)
		_right_foot_rot_modifier.set_additive(0, false)
		_right_foot_rot_modifier.set_relative(0, false)
		_skeleton.add_child(_right_foot_rot_modifier)


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

	if is_moving:
		# Reset turn-in-place state when starting to move
		_is_turning_in_place = false

		# Track yaw so _prev_yaw is up-to-date when we stop
		_prev_yaw = _visuals.global_rotation.y

		# Advance phase
		_phase += (speed / stride_length) * PI * delta
		_phase = fmod(_phase, TAU)

		# Compute per-foot cycle values (0–1)
		var left_cycle := fmod(_phase / TAU, 1.0)
		var right_cycle := fmod((_phase + PI) / TAU, 1.0)

		# Process each foot
		var left_pos := _process_foot(
			left_cycle, _left_prev_cycle,
			_left_plant_pos, _left_rest_pos,
			move_dir, speed, -1.0  # left side
		)
		var right_pos := _process_foot(
			right_cycle, _right_prev_cycle,
			_right_plant_pos, _right_rest_pos,
			move_dir, speed, 1.0  # right side
		)

		# Update plant positions if foot just entered plant phase
		if _crossed_threshold(left_cycle, _left_prev_cycle, 0.0):
			_left_plant_pos = _predict_plant_position(move_dir, speed, -1.0)
		if _crossed_threshold(right_cycle, _right_prev_cycle, 0.0):
			_right_plant_pos = _predict_plant_position(move_dir, speed, 1.0)

		# Detect swing→plant transition to lock new plant pos
		if _crossed_threshold(left_cycle, _left_prev_cycle, 0.5):
			pass  # Swing begins — plant pos already predicted at 0.0 crossing
		if _crossed_threshold(right_cycle, _right_prev_cycle, 0.5):
			pass

		_left_prev_cycle = left_cycle
		_right_prev_cycle = right_cycle

		# Safety: if planted foot drifted too far, force re-plant
		_left_plant_pos = _clamp_plant_distance(_left_plant_pos, stride_length * 1.5)
		_right_plant_pos = _clamp_plant_distance(_right_plant_pos, stride_length * 1.5)

		# Apply positions to targets (during locomotion, feet follow character facing)
		var current_yaw := _visuals.global_rotation.y
		_apply_foot_target(_left_target, left_pos, current_yaw, _left_ground_normal, _left_foot_rest_basis)
		_apply_foot_target(_right_target, right_pos, current_yaw, _right_ground_normal, _right_foot_rest_basis)
		# Update planted yaw so it's current when we stop
		_left_plant_yaw = current_yaw
		_right_plant_yaw = current_yaw

		# Hip bob — peaks when legs cross (at 0.25 and 0.75 of each half-cycle)
		var hip_bob: float = -absf(sin(_phase)) * hip_bob_amount
		_update_hip(delta, hip_bob)
	else:
		# Idle — handle turn-in-place or rest
		_process_idle_or_turn(delta)

	_apply_influence()


## Handle idle state with turn-in-place detection and foot stepping.
func _process_idle_or_turn(delta: float) -> void:
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
			_apply_foot_target(_left_target, _left_plant_pos, _left_plant_yaw, _left_ground_normal, _left_foot_rest_basis)
			_apply_foot_target(_right_target, _right_plant_pos, _right_plant_yaw, _right_ground_normal, _right_foot_rest_basis)
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

		_apply_foot_target(_left_target, _left_plant_pos, _left_plant_yaw, _left_ground_normal, _left_foot_rest_basis)
		_apply_foot_target(_right_target, _right_plant_pos, _right_plant_yaw, _right_ground_normal, _right_foot_rest_basis)
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

	if _stepping_foot == 0:
		# Left is stepping — interpolate toward target yaw
		left_pos = _left_step_start.lerp(_left_step_end, current_progress)
		left_pos.y += arc_height
		left_yaw = lerp_angle(_left_plant_yaw, target_yaw, current_progress)
		# Right stays planted — lower it to bend knee (weight shift)
		right_pos = _right_plant_pos
		right_pos.y += plant_dip
		right_yaw = _right_plant_yaw
	else:
		# Right is stepping — interpolate toward target yaw
		right_pos = _right_step_start.lerp(_right_step_end, current_progress)
		right_pos.y += arc_height
		right_yaw = lerp_angle(_right_plant_yaw, target_yaw, current_progress)
		# Left stays planted — lower it to bend knee (weight shift)
		left_pos = _left_plant_pos
		left_pos.y += plant_dip
		left_yaw = _left_plant_yaw

	_apply_foot_target(_left_target, left_pos, left_yaw, _left_ground_normal, _left_foot_rest_basis)
	_apply_foot_target(_right_target, right_pos, right_yaw, _right_ground_normal, _right_foot_rest_basis)

	# Hip follows lowest foot
	_update_hip(delta, 0.0)


## Process one foot's position for the current cycle value.
func _process_foot(
	cycle: float, _prev_cycle: float,
	plant_pos: Vector3, rest_pos: Vector3,
	move_dir: Vector3, speed: float, side: float
) -> Vector3:
	if cycle < 0.5:
		# Plant phase — foot stays at planted world position
		return plant_pos
	else:
		# Swing phase — arc from plant position to predicted next plant
		var swing_t := (cycle - 0.5) / 0.5  # 0–1 within swing
		var next_plant := _predict_plant_position(move_dir, speed, side)
		var ground_pos := plant_pos.lerp(next_plant, swing_t)

		# Arc height
		var arc_height: float = step_height * sin(swing_t * PI)
		ground_pos.y += arc_height

		return ground_pos


## Predict where the foot should plant next based on movement.
func _predict_plant_position(move_dir: Vector3, speed: float, side: float) -> Vector3:
	if _visuals.controller == null:
		return Vector3.ZERO

	var char_pos := _visuals.controller.global_position

	# Forward offset based on stride
	var forward_offset: Vector3 = move_dir * stride_length * 0.5

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


## Update hip offset: base offset + sinusoidal bob.
func _update_hip(delta: float, bob: float) -> void:
	var target_offset := hip_offset + bob

	_current_hip_offset = lerpf(
		_current_hip_offset, target_offset,
		1.0 - exp(-hip_smooth_speed * delta)
	)

	# Apply to visual root Y — NOT pelvis bone (avoids bone-space drift)
	_visuals.position.y = _current_hip_offset


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


## Position and rotate a foot target Marker3D.
## yaw: The Y rotation (facing direction) for the foot.
## ground_normal: The ground normal from raycast for slope adaptation.
## rest_basis: The foot bone's rest orientation (captured at setup).
func _apply_foot_target(target: Marker3D, world_pos: Vector3, yaw: float, ground_normal: Vector3, rest_basis: Basis) -> void:
	if target == null:
		return

	# Build foot basis from rest pose + yaw delta + ground tilt
	var foot_basis := _compute_foot_basis(yaw, ground_normal, rest_basis)

	target.global_position = world_pos
	target.global_transform = Transform3D(foot_basis, world_pos)


## Compute foot basis from yaw delta and ground normal.
## Preserves the foot bone's rest orientation while rotating to face the target yaw.
func _compute_foot_basis(yaw: float, ground_normal: Vector3, rest_basis: Basis) -> Basis:
	# Compute how much we need to rotate from the initial character yaw
	var delta_yaw := yaw - _initial_char_yaw

	# Rotate the rest basis around Y by the delta
	var yaw_rotation := Basis(Vector3.UP, delta_yaw)
	var result := yaw_rotation * rest_basis

	# Apply ground normal tilt if not flat
	if not ground_normal.is_equal_approx(Vector3.UP):
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
