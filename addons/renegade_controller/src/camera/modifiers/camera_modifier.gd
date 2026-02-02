## Base class for camera modifiers. Modifiers apply additive offsets to position, rotation, and FOV.
## Subclasses MUST implement get_position_offset, get_rotation_offset, and get_fov_offset.
## Modifiers automatically ease in/out based on alpha_in_time and alpha_out_time.
@abstract
class_name CameraModifier extends Resource

## Overall influence of this modifier (0.0 = no effect, 1.0 = full effect).
@export_range(0.0, 1.0) var influence: float = 1.0
## Processing priority. Lower values run first (0-255).
@export_range(0, 255) var priority: int = 128
## Time to fade in when enabled.
@export var alpha_in_time: float = 0.15
## Time to fade out when disabled.
@export var alpha_out_time: float = 0.25
## If true, this modifier blocks all lower-priority modifiers when alpha > 0.5.
@export var exclusive: bool = false
## If true, modifier is removed from stack when finished. If false, stays in standby.
@export var one_shot: bool = false

## Current blend alpha (0.0 = inactive, 1.0 = fully active).
var alpha: float = 0.0
var _target_alpha: float = 0.0
var _has_been_enabled: bool = false


## Enable this modifier (fade in).
func enable() -> void:
	_target_alpha = 1.0
	_has_been_enabled = true


## Disable this modifier (fade out).
func disable() -> void:
	_target_alpha = 0.0


## Returns true when this modifier should be removed from the stack.
## Only returns true for one_shot modifiers that have completed their effect.
func is_finished() -> bool:
	if not one_shot:
		return false
	return _has_been_enabled and _target_alpha == 0.0 and alpha < 0.001


## Update alpha blending toward target. Call once per frame.
func update_alpha(delta: float) -> void:
	if alpha < _target_alpha:
		var speed := 1.0 / alpha_in_time if alpha_in_time > 0.0 else 1000.0
		alpha = move_toward(alpha, _target_alpha, speed * delta)
	elif alpha > _target_alpha:
		var speed := 1.0 / alpha_out_time if alpha_out_time > 0.0 else 1000.0
		alpha = move_toward(alpha, _target_alpha, speed * delta)


## Returns the position offset to apply this frame.
@abstract
func get_position_offset(_delta: float) -> Vector3


## Returns the rotation offset in euler degrees to apply this frame.
@abstract
func get_rotation_offset(_delta: float) -> Vector3


## Returns the FOV offset to apply this frame.
@abstract
func get_fov_offset(_delta: float) -> float
