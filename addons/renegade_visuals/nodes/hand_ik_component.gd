## Hand IK for interactions (doors, pickups, pushing, leaning).
## Lerps TwoBoneIK3D targets toward interaction points with influence ramping.
## Designed to be triggered by interaction system signals.
class_name HandIKComponent
extends Node

## How fast IK influence ramps up when reaching for something.
@export_range(1.0, 20.0) var reach_speed: float = 6.0
## How fast IK influence ramps down when releasing.
@export_range(1.0, 20.0) var release_speed: float = 8.0
## Maximum reach distance before IK kicks in.
@export var max_reach_distance: float = 1.5

@export_group("IK Nodes")
@export var left_arm_ik: NodePath
@export var right_arm_ik: NodePath

@export_group("IK Targets")
@export var left_hand_target: NodePath
@export var right_hand_target: NodePath

var _visuals: CharacterVisuals
var _skeleton: Skeleton3D

# IK references
var _left_ik: Node
var _right_ik: Node
var _left_target: Marker3D
var _right_target: Marker3D

# Bone indices
var _left_hand_idx: int = -1
var _right_hand_idx: int = -1

# Active interaction targets
var _left_interact_pos: Vector3 = Vector3.ZERO
var _right_interact_pos: Vector3 = Vector3.ZERO
var _left_active: bool = false
var _right_active: bool = false
var _left_influence: float = 0.0
var _right_influence: float = 0.0


func _ready() -> void:
	_visuals = get_parent() as CharacterVisuals
	if _visuals == null:
		push_error("HandIKComponent: Parent must be a CharacterVisuals node.")
		return
	
	_visuals.ready.connect(_setup, CONNECT_ONE_SHOT | CONNECT_DEFERRED)


func _setup() -> void:
	_skeleton = _visuals.skeleton
	if _skeleton == null:
		return
	
	var skel_config := _visuals.skeleton_config
	if skel_config == null:
		skel_config = SkeletonConfig.new()
	
	_left_hand_idx = _skeleton.find_bone(skel_config.left_hand)
	_right_hand_idx = _skeleton.find_bone(skel_config.right_hand)
	
	if not left_arm_ik.is_empty():
		_left_ik = get_node_or_null(left_arm_ik)
	if not right_arm_ik.is_empty():
		_right_ik = get_node_or_null(right_arm_ik)
	if not left_hand_target.is_empty():
		_left_target = get_node_or_null(left_hand_target) as Marker3D
	if not right_hand_target.is_empty():
		_right_target = get_node_or_null(right_hand_target) as Marker3D


func _physics_process(delta: float) -> void:
	if _skeleton == null:
		return
	
	_update_hand(_left_ik, _left_target, _left_hand_idx, _left_interact_pos, _left_active, delta, true)
	_update_hand(_right_ik, _right_target, _right_hand_idx, _right_interact_pos, _right_active, delta, false)


func _update_hand(
	ik_node: Node,
	target: Marker3D,
	bone_idx: int,
	interact_pos: Vector3,
	active: bool,
	delta: float,
	is_left: bool,
) -> void:
	if ik_node == null or target == null or bone_idx == -1:
		return
	
	# Get current influence
	var influence: float = _left_influence if is_left else _right_influence
	
	# Ramp influence
	var target_influence: float = 0.0
	if active:
		# Check distance — only IK if within reach
		var hand_world := _skeleton.global_transform * _skeleton.get_bone_global_pose(bone_idx).origin
		var dist := hand_world.distance_to(interact_pos)
		if dist < max_reach_distance:
			target_influence = 1.0
	
	var speed := reach_speed if target_influence > influence else release_speed
	influence = lerpf(influence, target_influence, speed * delta)
	
	# Store influence back
	if is_left:
		_left_influence = influence
	else:
		_right_influence = influence
	
	# Apply
	ik_node.set("influence", influence)
	
	if active and influence > 0.01:
		target.global_position = interact_pos


## Start reaching left hand toward a world position.
func reach_left(world_position: Vector3) -> void:
	_left_interact_pos = world_position
	_left_active = true


## Start reaching right hand toward a world position.
func reach_right(world_position: Vector3) -> void:
	_right_interact_pos = world_position
	_right_active = true


## Release left hand IK — blend back to animation.
func release_left() -> void:
	_left_active = false


## Release right hand IK — blend back to animation.
func release_right() -> void:
	_right_active = false


## Convenience: reach both hands (e.g., pushing an object).
func reach_both(left_pos: Vector3, right_pos: Vector3) -> void:
	reach_left(left_pos)
	reach_right(right_pos)


## Release both hands.
func release_both() -> void:
	release_left()
	release_right()
