## Simple patrol behavior for demo NPC.
## Uses NavigationAgent3D for pathfinding around obstacles.
extends Node

@export var ai_controller: AIController
@export var character: RenegadeCharacter
@export var wait_time: float = 2.0

var patrol_points: Array[Vector3] = []
var current_index: int = 0
var _arrival_threshold: float = 1.0
## Stuck detection: if NPC makes no progress for this many seconds, skip to next point.
var _stuck_timeout: float = 5.0
var _last_distance_sq: float = INF
var _stuck_timer: float = 0.0
## Minimum progress per second (squared) to not be considered stuck.
var _min_progress_sq: float = 0.1
## How many times we've been stuck in a row - triggers teleport after threshold.
var _consecutive_stucks: int = 0
## After this many consecutive stucks, teleport to next waypoint.
var _max_consecutive_stucks: int = 2

## Navigation agent for pathfinding.
var _nav_agent: NavigationAgent3D

enum State { PATROL, WAITING, IDLE }
var state: State = State.IDLE


func _ready() -> void:
	# Find or wait for NavigationAgent3D.
	await get_tree().process_frame  # Wait for scene to be ready.
	_nav_agent = character.get_node_or_null("NavigationAgent3D") as NavigationAgent3D
	if not _nav_agent:
		push_warning("NPC patrol: No NavigationAgent3D found, using direct movement")
	if patrol_points.size() > 0:
		state = State.PATROL
		_set_nav_target(patrol_points[current_index])


func _physics_process(_delta: float) -> void:
	if not ai_controller or not character:
		return

	match state:
		State.PATROL:
			_do_patrol()
		State.WAITING:
			pass  # Timer handles transition.
		State.IDLE:
			ai_controller.stop()


func set_patrol_points(points: Array[Vector3]) -> void:
	patrol_points = points
	if patrol_points.size() > 0:
		current_index = 0
		state = State.PATROL
		_stuck_timer = 0.0
		_last_distance_sq = INF
		_consecutive_stucks = 0
		_set_nav_target(patrol_points[current_index])


func _set_nav_target(target: Vector3) -> void:
	if _nav_agent:
		_nav_agent.target_position = target


func _do_patrol() -> void:
	if patrol_points.is_empty():
		state = State.IDLE
		return

	var final_target := patrol_points[current_index]

	# Check if we've reached the final waypoint.
	var to_final := final_target - character.global_position
	to_final.y = 0.0
	var dist_to_final_sq := to_final.length_squared()

	if dist_to_final_sq <= _arrival_threshold * _arrival_threshold:
		_arrive_at_waypoint()
		return

	# Get next movement position (from nav agent or direct).
	var move_target: Vector3
	if _nav_agent and _nav_agent.is_navigation_finished() == false:
		move_target = _nav_agent.get_next_path_position()
	else:
		move_target = final_target

	# Calculate distance to current movement target for stuck detection.
	var to_target := move_target - character.global_position
	to_target.y = 0.0
	var dist_sq := to_target.length_squared()

	# Stuck detection: if we're not making progress, handle it.
	if dist_to_final_sq >= _last_distance_sq - _min_progress_sq:
		_stuck_timer += get_physics_process_delta_time()
		if _stuck_timer >= _stuck_timeout:
			_consecutive_stucks += 1
			if _consecutive_stucks >= _max_consecutive_stucks:
				push_warning("NPC patrol stuck %d times, teleporting to waypoint %d" % [_consecutive_stucks, (current_index + 1) % patrol_points.size()])
				_teleport_to_next_waypoint()
			else:
				push_warning("NPC patrol stuck at waypoint %d, skipping to next" % current_index)
				_arrive_at_waypoint()
			return
	else:
		_stuck_timer = 0.0
		_consecutive_stucks = 0
	_last_distance_sq = dist_to_final_sq

	# Move toward next path position.
	ai_controller.move_toward_position(move_target)


func _arrive_at_waypoint() -> void:
	ai_controller.stop()
	state = State.WAITING
	_stuck_timer = 0.0
	_last_distance_sq = INF
	_start_wait()


func _teleport_to_next_waypoint() -> void:
	ai_controller.stop()
	current_index = (current_index + 1) % patrol_points.size()
	var target := patrol_points[current_index]
	# Teleport the character to the next waypoint.
	character.global_position = target + Vector3(0, 0.5, 0)
	character.velocity = Vector3.ZERO
	_consecutive_stucks = 0
	_stuck_timer = 0.0
	_last_distance_sq = INF
	state = State.WAITING
	_set_nav_target(target)
	_start_wait()


## Force unstick the NPC by teleporting to the next waypoint.
func force_unstick() -> void:
	if patrol_points.is_empty():
		return
	push_warning("Force unsticking NPC patrol")
	_teleport_to_next_waypoint()


func _start_wait() -> void:
	var timer := get_tree().create_timer(wait_time)
	await timer.timeout
	if not is_inside_tree():
		return
	# Advance to next waypoint.
	current_index = (current_index + 1) % patrol_points.size()
	_set_nav_target(patrol_points[current_index])
	state = State.PATROL
