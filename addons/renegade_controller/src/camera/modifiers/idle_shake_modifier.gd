## Subtle camera sway when the player is idle.
## Creates a gentle breathing/drifting effect for a cinematic feel.
## CameraRig calls update_idle() each physics frame to drive the effect.
class_name IdleShakeModifier extends CameraModifier

## Maximum position offset in each axis (very subtle).
@export var max_offset: Vector3 = Vector3(0.02, 0.015, 0.01)
## Maximum rotation offset in degrees (pitch, yaw, roll).
@export var max_rotation: Vector3 = Vector3(0.3, 0.5, 0.2)
## Frequency of oscillation (lower = slower, more gentle).
@export var frequency: float = 0.3
## Delay before shake starts after becoming idle.
@export var idle_delay: float = 0.1

var _time: float = 0.0
var _idle_time: float = 0.0
var _is_idle: bool = false


func _init() -> void:
	# Slower fade times for gentle effect.
	alpha_in_time = 1.0
	alpha_out_time = 0.3


## Update idle state. Called by CameraRig each physics frame.
func update_idle(delta: float, is_idle: bool) -> void:
	_is_idle = is_idle

	if is_idle:
		_idle_time += delta
		if _idle_time >= idle_delay:
			enable()
	else:
		_idle_time = 0.0
		disable()


func get_position_offset(delta: float) -> Vector3:
	if alpha < 0.001:
		return Vector3.ZERO

	_time += delta
	var freq := frequency * TAU

	# Use sine waves with different phases per axis for organic feel.
	var offset := Vector3(
		sin(_time * freq) * max_offset.x,
		sin(_time * freq * 0.7 + 1.0) * max_offset.y,
		sin(_time * freq * 0.5 + 2.0) * max_offset.z
	)

	return offset * alpha * influence


func get_rotation_offset(delta: float) -> Vector3:
	if alpha < 0.001:
		return Vector3.ZERO

	var freq := frequency * TAU

	# Different phases for each rotation axis.
	var rotation := Vector3(
		sin(_time * freq * 0.8 + 0.5) * max_rotation.x,   # Pitch
		sin(_time * freq * 0.6 + 1.5) * max_rotation.y,   # Yaw
		sin(_time * freq * 0.4 + 2.5) * max_rotation.z    # Roll
	)

	return rotation * alpha * influence


func get_fov_offset(_delta: float) -> float:
	return 0.0
