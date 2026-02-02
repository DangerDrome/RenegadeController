## Simple patrol behavior for demo NPC.
## Walks between waypoints using the AIController interface.
extends Node

@export var ai_controller: AIController
@export var character: RenegadeCharacter
@export var wait_time: float = 2.0

var patrol_points: Array[Vector3] = []
var current_index: int = 0
var _waiting: bool = false
var _arrival_threshold: float = 1.5

enum State { PATROL, WAITING, IDLE }
var state: State = State.IDLE


func _ready() -> void:
	if patrol_points.size() > 0:
		state = State.PATROL


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


func _do_patrol() -> void:
	if patrol_points.is_empty():
		state = State.IDLE
		return
	
	var target := patrol_points[current_index]
	var dist := character.global_position.distance_to(target)
	
	if dist <= _arrival_threshold:
		# Arrived at waypoint.
		ai_controller.stop()
		state = State.WAITING
		_start_wait()
		return
	
	# Move toward current waypoint.
	ai_controller.move_toward_position(target)


func _start_wait() -> void:
	await get_tree().create_timer(wait_time).timeout
	if not is_inside_tree():
		return
	# Advance to next waypoint.
	current_index = (current_index + 1) % patrol_points.size()
	state = State.PATROL
