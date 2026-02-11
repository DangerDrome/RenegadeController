## Places hands on nearby walls using raycasts + HandIKComponent.
## Add as child of CharacterVisuals alongside HandIKComponent.
class_name WallHandPlacement
extends Node

@export var enabled: bool = true

@export_group("Detection")
## Maximum distance to detect walls.
@export var detection_distance: float = 0.8
## Offset from wall surface (prevents hand clipping).
@export var surface_offset: float = 0.05
## Physics layers for wall detection.
@export_flags_3d_physics var collision_mask: int = 1
## How often to update raycasts (seconds).
@export var update_interval: float = 0.05

@export_group("Reach Settings")
## Minimum forward component of velocity to enable wall reach (prevents reaching while stationary).
@export var min_forward_speed: float = 0.5
## Angle from forward to cast rays (degrees). 45 = diagonal forward-side.
@export_range(0.0, 90.0) var ray_angle: float = 45.0

var _visuals: CharacterVisuals
var _skeleton: Skeleton3D
var _hand_ik: HandIKComponent

var _left_shoulder_idx: int = -1
var _right_shoulder_idx: int = -1

var _update_timer: float = 0.0
var _left_reaching: bool = false
var _right_reaching: bool = false


func _ready() -> void:
	_visuals = get_parent() as CharacterVisuals
	if _visuals == null:
		push_error("WallHandPlacement: Parent must be CharacterVisuals.")
		return

	_visuals.ready.connect(_setup, CONNECT_ONE_SHOT | CONNECT_DEFERRED)


func _setup() -> void:
	_skeleton = _visuals.skeleton
	if _skeleton == null:
		return

	# Find HandIKComponent sibling
	for sibling in _visuals.get_children():
		if sibling is HandIKComponent:
			_hand_ik = sibling
			break

	if _hand_ik == null:
		push_warning("WallHandPlacement: No HandIKComponent sibling found.")
		return

	# Cache shoulder bone indices
	var config := _visuals.skeleton_config
	if config:
		_left_shoulder_idx = _skeleton.find_bone(config.left_upperarm)
		_right_shoulder_idx = _skeleton.find_bone(config.right_upperarm)
	else:
		_left_shoulder_idx = _skeleton.find_bone("upperarm_l")
		_right_shoulder_idx = _skeleton.find_bone("upperarm_r")


func _physics_process(delta: float) -> void:
	if not enabled or _skeleton == null or _hand_ik == null:
		return

	_update_timer += delta
	if _update_timer < update_interval:
		return
	_update_timer = 0.0

	# Only reach while moving forward
	var velocity := _visuals.get_velocity()
	var forward := -_visuals.controller.global_basis.z if _visuals.controller else Vector3.FORWARD
	var forward_speed := velocity.dot(forward)

	if forward_speed < min_forward_speed:
		_release_both_if_needed()
		return

	var space_state := _skeleton.get_world_3d().direct_space_state
	if space_state == null:
		return

	# Check left side
	_check_side(space_state, true, forward)
	# Check right side
	_check_side(space_state, false, forward)


func _check_side(space_state: PhysicsDirectSpaceState3D, is_left: bool, forward: Vector3) -> void:
	var shoulder_idx := _left_shoulder_idx if is_left else _right_shoulder_idx
	if shoulder_idx < 0:
		return

	# Get shoulder world position
	var shoulder_global := _skeleton.global_transform * _skeleton.get_bone_global_pose(shoulder_idx)
	var shoulder_pos: Vector3 = shoulder_global.origin

	# Calculate ray direction - forward + side at angle
	var side := -_visuals.controller.global_basis.x if is_left else _visuals.controller.global_basis.x
	var angle_rad := deg_to_rad(ray_angle)
	var ray_dir := (forward * cos(angle_rad) + side * sin(angle_rad)).normalized()

	var ray_end := shoulder_pos + ray_dir * detection_distance

	var query := PhysicsRayQueryParameters3D.create(shoulder_pos, ray_end)
	query.collision_mask = collision_mask

	var result := space_state.intersect_ray(query)

	if not result.is_empty():
		var hit_pos: Vector3 = result["position"]
		var hit_normal: Vector3 = result["normal"]

		# Offset hand position from wall
		var hand_pos := hit_pos + hit_normal * surface_offset

		if is_left:
			_hand_ik.reach_left(hand_pos)
			_left_reaching = true
		else:
			_hand_ik.reach_right(hand_pos)
			_right_reaching = true
	else:
		# No wall - release
		if is_left and _left_reaching:
			_hand_ik.release_left()
			_left_reaching = false
		elif not is_left and _right_reaching:
			_hand_ik.release_right()
			_right_reaching = false


func _release_both_if_needed() -> void:
	if _left_reaching:
		_hand_ik.release_left()
		_left_reaching = false
	if _right_reaching:
		_hand_ik.release_right()
		_right_reaching = false
