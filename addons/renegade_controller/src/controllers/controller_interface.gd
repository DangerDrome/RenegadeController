## Base class for all character controllers.
## Both PlayerController and AIController extend this.
## The character body reads from this interface and never knows what's driving it.
class_name ControllerInterface extends Node

## Emitted when the controller wants to interact with something.
signal interact_requested(target: Node3D)

## Emitted when the controller wants to move to a position.
signal move_to_requested(position: Vector3)


## Returns the 2D movement input vector (normalized).
## X = left/right, Y = forward/back.
func get_movement() -> Vector2:
	return Vector2.ZERO


## Returns the 3D world position the character should aim toward.
func get_aim_target() -> Vector3:
	return Vector3.ZERO


## Returns true if the aim target is valid (cursor hit something).
func has_aim_target() -> bool:
	return false


## Returns true if the given action is currently held.
func is_action_pressed(action: String) -> bool:
	return false


## Returns true if the given action was just pressed this frame.
func is_action_just_pressed(action: String) -> bool:
	return false


## Returns true if the given action was just released this frame.
func is_action_just_released(action: String) -> bool:
	return false


## Returns the look delta for first-person mouse look (mouse motion).
func get_look_delta() -> Vector2:
	return Vector2.ZERO


## Returns true if this controller is player-driven (has camera/cursor).
func is_player() -> bool:
	return false
