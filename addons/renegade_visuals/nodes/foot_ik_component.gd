## Raycast-based foot IK ground adaptation.
## Positions Marker3D targets for TwoBoneIK3D using offset-based approach
## (only corrects the difference from animated position, never fights root motion).
## Also handles hip offset and foot rotation to match ground slope.
class_name FootIKComponent
extends Node

@export var config: FootIKConfig

## The TwoBoneIK3D nodes on the skeleton (set up manually or by default scene).
@export_group("IK Nodes")
@export var left_leg_ik: NodePath
@export var right_leg_ik: NodePath

## External Marker3D targets for the IK solvers.
@export_group("IK Targets")
@export var left_foot_target: NodePath
@export var right_foot_target: NodePath

var _visuals: CharacterVisuals
var _skeleton: Skeleton3D

# Bone indices (cached)
var _pelvis_idx: int = -1
var _left_foot_idx: int = -1
var _right_foot_idx: int = -1

# IK node references
var _left_ik: Node  # TwoBoneIK3D
var _right_ik: Node  # TwoBoneIK3D
var _left_target: Marker3D
var _right_target: Marker3D

# State
var _current_hip_offset: float = 0.0
var _current_influence: float = 0.0
var _space_state: PhysicsDirectSpaceState3D

# Per-foot state
var _left_ground_offset: float = 0.0
var _right_ground_offset: float = 0.0
var _left_ground_normal: Vector3 = Vector3.UP
var _right_ground_normal: Vector3 = Vector3.UP


func _ready() -> void:
	_visuals = get_parent() as CharacterVisuals
	if _visuals == null:
		push_error("FootIKComponent: Parent must be a CharacterVisuals node.")
		return
	
	if config == null:
		config = FootIKConfig.new()
	
	# Defer setup to ensure skeleton is ready
	_visuals.ready.connect(_setup, CONNECT_ONE_SHOT | CONNECT_DEFERRED)


func _setup() -> void:
	_skeleton = _visuals.skeleton
	if _skeleton == null:
		push_error("FootIKComponent: No skeleton found on CharacterVisuals.")
		return
	
	var skel_config := _visuals.skeleton_config
	if skel_config == null:
		skel_config = SkeletonConfig.new()
	
	# Cache bone indices
	_pelvis_idx = _skeleton.find_bone(skel_config.pelvis_bone)
	_left_foot_idx = _skeleton.find_bone(skel_config.left_foot)
	_right_foot_idx = _skeleton.find_bone(skel_config.right_foot)
	
	if _pelvis_idx == -1:
		push_warning("FootIKComponent: Pelvis bone '%s' not found." % skel_config.pelvis_bone)
	if _left_foot_idx == -1:
		push_warning("FootIKComponent: Left foot bone '%s' not found." % skel_config.left_foot)
	if _right_foot_idx == -1:
		push_warning("FootIKComponent: Right foot bone '%s' not found." % skel_config.right_foot)
	
	# Resolve IK nodes
	if not left_leg_ik.is_empty():
		_left_ik = get_node_or_null(left_leg_ik)
	if not right_leg_ik.is_empty():
		_right_ik = get_node_or_null(right_leg_ik)
	
	# Resolve targets
	if not left_foot_target.is_empty():
		_left_target = get_node_or_null(left_foot_target) as Marker3D
	if not right_foot_target.is_empty():
		_right_target = get_node_or_null(right_foot_target) as Marker3D


func _physics_process(delta: float) -> void:
	if _skeleton == null:
		return
	if _left_foot_idx == -1 or _right_foot_idx == -1:
		return
	
	_space_state = _skeleton.get_world_3d().direct_space_state
	if _space_state == null:
		return
	
	# Update IK influence based on movement state
	_update_influence(delta)
	
	# Get animated foot positions (before IK modifies them)
	var left_foot_world := _get_bone_world_position(_left_foot_idx)
	var right_foot_world := _get_bone_world_position(_right_foot_idx)
	
	# Raycast for each foot
	_left_ground_offset = _raycast_ground_offset(left_foot_world)
	_right_ground_offset = _raycast_ground_offset(right_foot_world)
	
	# Compute hip offset (drop pelvis to accommodate lowest foot)
	var target_hip_offset := minf(_left_ground_offset, _right_ground_offset)
	target_hip_offset = clampf(target_hip_offset, -config.max_hip_drop, 0.0)
	_current_hip_offset = lerpf(_current_hip_offset, target_hip_offset, config.hip_smooth_speed * delta)
	
	# Apply hip offset to pelvis bone
	# NOTE: Disabled - was causing -Z drift with UEFN skeleton
	# TODO: Investigate proper way to apply hip drop without interfering with root motion
	#if _pelvis_idx != -1:
	#	var pelvis_pos := _skeleton.get_bone_pose_position(_pelvis_idx)
	#	pelvis_pos.y += _current_hip_offset
	#	_skeleton.set_bone_pose_position(_pelvis_idx, pelvis_pos)
	
	# Position IK targets (animated position + ground correction - hip compensation)
	if _left_target:
		_left_target.global_position = left_foot_world + Vector3.UP * (
			_left_ground_offset - _current_hip_offset + config.foot_height_offset
		)
		_left_target.basis = _compute_foot_rotation(_left_ground_normal)
	
	if _right_target:
		_right_target.global_position = right_foot_world + Vector3.UP * (
			_right_ground_offset - _current_hip_offset + config.foot_height_offset
		)
		_right_target.basis = _compute_foot_rotation(_right_ground_normal)
	
	# Update IK influence on the solver nodes
	_apply_influence()


func _update_influence(delta: float) -> void:
	var grounded := _visuals.is_grounded()
	var target_influence: float
	
	if not grounded:
		target_influence = 0.0  # No foot IK in air
	else:
		# Blend influence based on speed
		var speed := _visuals.get_velocity().length()
		var speed_factor := clampf(speed / 3.0, 0.0, 1.0)  # 0 at idle, 1 at 3m/s+
		target_influence = lerpf(config.idle_influence, config.locomotion_influence, speed_factor)
	
	_current_influence = lerpf(_current_influence, target_influence, config.influence_blend_speed * delta)


func _apply_influence() -> void:
	# TwoBoneIK3D inherits from SkeletonModifier3D which has .influence
	if _left_ik and _left_ik.has_method("set"):
		_left_ik.set("influence", _current_influence)
	if _right_ik and _right_ik.has_method("set"):
		_right_ik.set("influence", _current_influence)


func _get_bone_world_position(bone_idx: int) -> Vector3:
	var bone_global_pose := _skeleton.get_bone_global_pose(bone_idx)
	return _skeleton.global_transform * bone_global_pose.origin


func _raycast_ground_offset(foot_world_pos: Vector3) -> float:
	var origin := foot_world_pos + Vector3.UP * config.ray_origin_height
	var end := foot_world_pos + Vector3.DOWN * config.ray_max_depth
	
	var query := PhysicsRayQueryParameters3D.create(origin, end)
	query.collision_mask = config.ground_layers
	# Exclude the character's own body
	if _visuals.controller:
		query.exclude = [_visuals.controller.get_rid()]
	
	var result := _space_state.intersect_ray(query)
	if result.is_empty():
		return 0.0
	
	# Store the ground normal for foot rotation
	var hit_normal: Vector3 = result.normal
	# Determine which foot this is for (compare positions)
	# This is a simplification — in practice we pass the normal out properly
	if foot_world_pos.distance_to(_get_bone_world_position(_left_foot_idx)) < 0.1:
		_left_ground_normal = hit_normal
	else:
		_right_ground_normal = hit_normal
	
	# Return the height difference: positive = ground is above animated position
	var hit_point: Vector3 = result.position
	return hit_point.y - foot_world_pos.y


func _compute_foot_rotation(ground_normal: Vector3) -> Basis:
	# Construct a basis aligned to the ground normal
	if ground_normal.is_equal_approx(Vector3.UP):
		return Basis.IDENTITY
	
	var angle := Vector3.UP.angle_to(ground_normal)
	angle = clampf(angle, 0.0, deg_to_rad(config.max_foot_angle))
	angle *= config.foot_rotation_weight
	
	var axis := Vector3.UP.cross(ground_normal).normalized()
	if axis.is_zero_approx():
		return Basis.IDENTITY
	
	return Basis(axis, angle)
