## DetectionSystem: Handles line-of-sight, hearing, and last known position tracking.
## Each RealizedNPC has one of these to track awareness of threats/targets.
## Used by ThreatModule and future modules (Pursuit, Investigate) for LOS-based decisions.
class_name DetectionSystem
extends RefCounted

## The NPC this detection system belongs to.
var npc: Node3D = null

## Current tracked target (usually player or hostile).
var target: Node3D = null

## Whether we currently have unobstructed line of sight to target.
var has_line_of_sight: bool = false

## Last position where we saw the target (for pursuit/investigation).
var last_known_position: Vector3 = Vector3.ZERO

## Seconds since we last had visual on target.
var time_since_visual: float = INF

## Last heard sound position (for investigation).
var last_heard_position: Vector3 = Vector3.ZERO

## Time since last heard sound.
var time_since_sound: float = INF

## Internal timer for raycast throttling.
var _los_check_timer: float = 0.0

## Eye offset from NPC position for raycasts.
var eye_height: float = 1.6


func _init(p_npc: Node3D) -> void:
	npc = p_npc


## Update detection state. Call every frame from RealizedNPC._physics_process().
func update(delta: float, p_target: Node3D = null) -> void:
	if p_target != target:
		target = p_target
		# Reset LOS when target changes
		has_line_of_sight = false
		time_since_visual = INF

	if not npc or not target or not is_instance_valid(target):
		has_line_of_sight = false
		time_since_visual += delta
		time_since_sound += delta
		return

	time_since_sound += delta

	# Throttle LOS checks for performance
	_los_check_timer += delta
	if _los_check_timer >= NPCConfig.Detection.LOS_CHECK_INTERVAL:
		_los_check_timer = 0.0
		_check_line_of_sight()


func _check_line_of_sight() -> void:
	if not target or not is_instance_valid(target):
		has_line_of_sight = false
		return

	var space_state: PhysicsDirectSpaceState3D = npc.get_world_3d().direct_space_state
	if not space_state:
		return

	var from: Vector3 = npc.global_position + Vector3(0, eye_height, 0)
	var to: Vector3 = _get_target_center(target)

	# Check distance first
	var distance: float = from.distance_to(to)
	if distance > NPCConfig.Detection.SIGHT_RANGE:
		_lose_visual()
		return

	# Check field of view
	var to_target: Vector3 = (to - from).normalized()
	var forward: Vector3 = -npc.global_transform.basis.z.normalized()
	var angle_deg: float = rad_to_deg(acos(clampf(forward.dot(to_target), -1.0, 1.0)))
	if angle_deg > NPCConfig.Detection.FOV_DEGREES * 0.5:
		_lose_visual()
		return

	# Raycast for occlusion
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 1  # Default physics layer (walls, geometry)
	query.exclude = [npc.get_rid()]
	# Exclude target from collision so we can see them
	if target is CollisionObject3D:
		query.exclude.append(target.get_rid())

	var result: Dictionary = space_state.intersect_ray(query)

	if result.is_empty():
		# No obstruction — we have LOS
		_gain_visual()
	else:
		_lose_visual()


func _gain_visual() -> void:
	has_line_of_sight = true
	time_since_visual = 0.0
	if target and is_instance_valid(target):
		last_known_position = target.global_position


func _lose_visual() -> void:
	if has_line_of_sight and target and is_instance_valid(target):
		# Record last known position when losing sight
		last_known_position = target.global_position
	has_line_of_sight = false
	time_since_visual += NPCConfig.Detection.LOS_CHECK_INTERVAL


func _get_target_center(t: Node3D) -> Vector3:
	# Target center is roughly chest height
	return t.global_position + Vector3(0, 1.2, 0)


## Check if a position is within hearing range.
func can_hear(position: Vector3) -> bool:
	if not npc:
		return false
	var distance: float = npc.global_position.distance_to(position)
	return distance <= NPCConfig.Detection.HEARING_RANGE


## Notify of a sound event (gunfire, explosion, etc).
func notify_sound(position: Vector3, loudness: float = 1.0) -> void:
	var effective_range: float = NPCConfig.Detection.HEARING_RANGE * loudness
	if not npc:
		return
	var distance: float = npc.global_position.distance_to(position)
	if distance <= effective_range:
		last_heard_position = position
		time_since_sound = 0.0


## Returns true if we had visual recently (within grace period).
func had_recent_visual(grace_seconds: float = 3.0) -> bool:
	return time_since_visual < grace_seconds


## Returns true if we heard something recently.
func heard_recently(grace_seconds: float = 5.0) -> bool:
	return time_since_sound < grace_seconds


## Get distance to last known position (for pursuit scoring).
func get_distance_to_last_known() -> float:
	if not npc or last_known_position == Vector3.ZERO:
		return INF
	return npc.global_position.distance_to(last_known_position)
