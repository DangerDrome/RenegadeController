## Procedural stride wheel for walk IK.
## Drives Marker3D foot targets in a phase-based gait cycle: feet plant on the ground
## during stance phase and swing through an arc to the next plant position.
## Also handles hip bob and ground-following hip drop.
class_name StrideWheelComponent
extends Node

@export var config: StrideWheelConfig

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

# Per-foot state
var _left_plant_pos: Vector3 = Vector3.ZERO
var _right_plant_pos: Vector3 = Vector3.ZERO
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


func _ready() -> void:
	_visuals = get_parent() as CharacterVisuals
	if _visuals == null:
		push_error("StrideWheelComponent: Parent must be a CharacterVisuals node.")
		return

	if config == null:
		config = StrideWheelConfig.new()

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

	# Initialize plant positions at current foot locations
	if _left_foot_idx != -1:
		_left_plant_pos = _get_bone_world_position(_left_foot_idx)
	if _right_foot_idx != -1:
		_right_plant_pos = _get_bone_world_position(_right_foot_idx)


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
	var is_moving: bool = speed > config.idle_threshold
	var move_dir: Vector3 = horizontal_vel.normalized() if is_moving else Vector3.ZERO

	# Update influence
	_update_influence(delta, is_moving)

	# Cache rest positions (skeleton bind pose in world)
	_left_rest_pos = _get_bone_world_position(_left_foot_idx)
	_right_rest_pos = _get_bone_world_position(_right_foot_idx)

	if is_moving:
		# Advance phase
		_phase += (speed / config.stride_length) * PI * delta
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
		_left_plant_pos = _clamp_plant_distance(_left_plant_pos, config.stride_length * 1.5)
		_right_plant_pos = _clamp_plant_distance(_right_plant_pos, config.stride_length * 1.5)

		# Apply positions to targets
		_apply_foot_target(_left_target, left_pos, _left_ground_normal)
		_apply_foot_target(_right_target, right_pos, _right_ground_normal)

		# Hip bob — peaks when legs cross (at 0.25 and 0.75 of each half-cycle)
		var hip_bob: float = -absf(sin(_phase)) * config.hip_bob_amount
		_update_hip(delta, left_pos.y, right_pos.y, hip_bob)
	else:
		# Idle — blend targets toward rest position on ground
		var left_ground := _raycast_ground(_left_rest_pos)
		var right_ground := _raycast_ground(_right_rest_pos)

		_apply_foot_target(_left_target, left_ground, _left_ground_normal)
		_apply_foot_target(_right_target, right_ground, _right_ground_normal)

		_update_hip(delta, left_ground.y, right_ground.y, 0.0)

		# Reset phase so next move starts cleanly
		_phase = 0.0
		_left_plant_pos = left_ground
		_right_plant_pos = right_ground
		_left_prev_cycle = 0.0
		_right_prev_cycle = 0.5  # Right foot offset by half cycle

	_apply_influence()


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
		var arc_height: float = config.step_height * sin(swing_t * PI)
		ground_pos.y += arc_height

		return ground_pos


## Predict where the foot should plant next based on movement.
func _predict_plant_position(move_dir: Vector3, speed: float, side: float) -> Vector3:
	if _visuals.controller == null:
		return Vector3.ZERO

	var char_pos := _visuals.controller.global_position

	# Forward offset based on stride
	var forward_offset: Vector3 = move_dir * config.stride_length * 0.5

	# Lateral offset perpendicular to movement direction
	var lateral: Vector3 = move_dir.cross(Vector3.UP).normalized() * side * config.foot_lateral_offset
	if lateral.is_zero_approx():
		# Fallback: use character's right vector
		lateral = _visuals.controller.global_basis.x * side * config.foot_lateral_offset

	var predicted: Vector3 = char_pos + forward_offset + lateral

	# Raycast to find actual ground
	return _raycast_ground(predicted)


## Raycast down from a position to find the ground point.
func _raycast_ground(world_pos: Vector3) -> Vector3:
	if _space_state == null:
		return world_pos

	var origin: Vector3 = world_pos + Vector3.UP * config.ray_height
	var end: Vector3 = world_pos + Vector3.DOWN * config.ray_depth

	var query := PhysicsRayQueryParameters3D.create(origin, end)
	query.collision_mask = config.ground_layers
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

	return result.position


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


## Update hip offset: ground-following drop + sinusoidal bob.
func _update_hip(delta: float, left_y: float, right_y: float, bob: float) -> void:
	var target_offset := bob

	if config.hip_drop_enabled and _visuals.controller:
		var char_y := _visuals.controller.global_position.y
		var lowest_foot := minf(left_y, right_y)
		var ground_drop := lowest_foot - char_y
		ground_drop = clampf(ground_drop, -config.max_hip_drop, 0.0)
		target_offset += ground_drop

	_current_hip_offset = lerpf(
		_current_hip_offset, target_offset,
		1.0 - exp(-config.hip_smooth_speed * delta)
	)

	# Apply to visual root Y — NOT pelvis bone (avoids bone-space drift)
	_visuals.position.y = _current_hip_offset


## Blend IK influence up when moving, down at idle.
func _update_influence(delta: float, is_moving: bool) -> void:
	var grounded := _visuals.is_grounded()
	var target: float = 1.0 if (is_moving and grounded) else 0.0

	if not grounded:
		target = 0.0

	_current_influence = lerpf(
		_current_influence, target,
		1.0 - exp(-config.influence_blend_speed * delta)
	)


## Apply influence to both IK solvers.
func _apply_influence() -> void:
	if _left_ik and _left_ik.has_method("set"):
		_left_ik.set("influence", _current_influence)
	if _right_ik and _right_ik.has_method("set"):
		_right_ik.set("influence", _current_influence)


## Position and rotate a foot target Marker3D.
func _apply_foot_target(target: Marker3D, world_pos: Vector3, ground_normal: Vector3) -> void:
	if target == null:
		return

	target.global_position = world_pos
	target.basis = _compute_foot_rotation(ground_normal)


## Construct a basis aligned to the ground normal for foot rotation.
func _compute_foot_rotation(ground_normal: Vector3) -> Basis:
	if ground_normal.is_equal_approx(Vector3.UP):
		return Basis.IDENTITY

	var angle := Vector3.UP.angle_to(ground_normal)
	angle = clampf(angle, 0.0, deg_to_rad(config.max_foot_angle))
	angle *= config.foot_rotation_weight

	var axis := Vector3.UP.cross(ground_normal).normalized()
	if axis.is_zero_approx():
		return Basis.IDENTITY

	return Basis(axis, angle)


## Get a bone's position in world space.
func _get_bone_world_position(bone_idx: int) -> Vector3:
	var bone_global_pose := _skeleton.get_bone_global_pose(bone_idx)
	return _skeleton.global_transform * bone_global_pose.origin
