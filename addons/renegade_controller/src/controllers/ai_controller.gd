## AI input controller for NPCs.
## Receives movement intents and action commands from external AI systems (GOAP, BehaviorTree, etc).
## Translates AI decisions into the same interface the character body expects.
class_name AIController extends ControllerInterface

## Current movement intent set by the AI system.
var movement_intent: Vector2 = Vector2.ZERO

## Current aim target position in world space.
var aim_target: Vector3 = Vector3.ZERO
var _has_aim_target: bool = false

## Queued one-shot actions (consumed on read).
var _queued_actions: Dictionary = {}  # action_name -> true
## Held actions (persistent until released).
var _held_actions: Dictionary = {}  # action_name -> true


#region Movement

## Set the desired movement direction. Called by AI system.
func set_movement(direction: Vector2) -> void:
	movement_intent = direction.limit_length(1.0)


## Set movement toward a world position relative to the owner.
func move_toward_position(target_pos: Vector3) -> void:
	var body := get_parent() as Node3D
	if not body:
		return
	var direction: Vector3 = (target_pos - body.global_position)
	direction.y = 0.0
	if direction.length_squared() < 0.25:  # Close enough threshold.
		movement_intent = Vector2.ZERO
		return
	direction = direction.normalized()
	# Convert world direction to local input (forward = -Y in input space).
	movement_intent = Vector2(direction.x, direction.z)


## Stop all movement.
func stop() -> void:
	movement_intent = Vector2.ZERO

#endregion


#region Aim

## Set the aim target position. Called by AI system.
func set_aim_target(position: Vector3) -> void:
	aim_target = position
	_has_aim_target = true


## Clear the aim target.
func clear_aim_target() -> void:
	_has_aim_target = false

#endregion


#region Actions

## Queue a one-shot action (like pressing a button once).
func press_action(action: String) -> void:
	_queued_actions[action] = true


## Hold an action (like holding a button).
func hold_action(action: String) -> void:
	_held_actions[action] = true


## Release a held action.
func release_action(action: String) -> void:
	_held_actions.erase(action)


## Release all held actions and clear queue.
func clear_all_actions() -> void:
	_queued_actions.clear()
	_held_actions.clear()

#endregion


#region ControllerInterface overrides

func get_movement() -> Vector2:
	return movement_intent


func get_aim_target() -> Vector3:
	return aim_target


func has_aim_target() -> bool:
	return _has_aim_target


func is_action_pressed(action: String) -> bool:
	return _held_actions.has(action)


func is_action_just_pressed(action: String) -> bool:
	if _queued_actions.has(action):
		_queued_actions.erase(action)
		return true
	return false


func is_action_just_released(_action: String) -> bool:
	# AI doesn't really have "just released" — handled via release_action().
	return false


func is_player() -> bool:
	return false

#endregion
