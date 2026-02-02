## Smooth position offset using a critically damped spring.
## Use for dynamic framing adjustments like peeking around corners,
## focusing on targets of interest, or cinematic camera shifts.
class_name FramingModifier extends CameraModifier

## Smoothing speed (higher = faster response).
@export var smooth_speed: float = 6.0

## Target offset to move toward.
var target_offset: Vector3 = Vector3.ZERO
## Current interpolated offset.
var current_offset: Vector3 = Vector3.ZERO


## Set a new target offset. Enables the modifier if offset is non-zero.
func set_offset(new_offset: Vector3) -> void:
	target_offset = new_offset
	if new_offset.length_squared() > 0.001:
		enable()


## Clear the offset (ease back to zero and auto-disable).
func clear() -> void:
	target_offset = Vector3.ZERO


func get_position_offset(delta: float) -> Vector3:
	_update_smoothing(delta)

	# Auto-disable when returned to zero.
	if target_offset.length_squared() < 0.001 and current_offset.length_squared() < 0.001:
		disable()

	return current_offset


func get_rotation_offset(_delta: float) -> Vector3:
	return Vector3.ZERO


func get_fov_offset(_delta: float) -> float:
	return 0.0


func _update_smoothing(delta: float) -> void:
	# Simple exponential smoothing (stable).
	current_offset = current_offset.lerp(target_offset, 1.0 - exp(-smooth_speed * delta))

	# Clamp to prevent extreme values.
	current_offset = current_offset.clamp(Vector3(-5, -5, -5), Vector3(5, 5, 5))
