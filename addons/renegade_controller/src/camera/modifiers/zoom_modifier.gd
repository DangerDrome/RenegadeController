## FOV zoom pulse modifier with attack/sustain/decay envelope.
## Use for impact effects, gunshots, explosions, etc.
## Call trigger() to activate the zoom pulse.
class_name ZoomModifier extends CameraModifier

## Maximum FOV change at peak of envelope.
@export var fov_change: float = 5.0
## Time to reach peak FOV (attack phase).
@export var attack_time: float = 0.04
## Time to hold at peak FOV (sustain phase).
@export var sustain_time: float = 0.02
## Time to return to base FOV (decay phase).
@export var decay_time: float = 0.15

var _timer: float = 0.0
var _total_duration: float = 0.0


func _init() -> void:
	_total_duration = attack_time + sustain_time + decay_time


## Trigger the zoom pulse. Resets timer and enables the modifier.
func trigger() -> void:
	_timer = 0.0
	_total_duration = attack_time + sustain_time + decay_time
	enable()


func get_position_offset(_delta: float) -> Vector3:
	return Vector3.ZERO


func get_rotation_offset(_delta: float) -> Vector3:
	return Vector3.ZERO


func get_fov_offset(delta: float) -> float:
	if _timer >= _total_duration:
		disable()
		return 0.0

	_timer += delta
	var envelope := _calculate_envelope()

	return fov_change * envelope


func _calculate_envelope() -> float:
	# Attack phase: ramp up.
	if _timer < attack_time:
		return _timer / attack_time if attack_time > 0.0 else 1.0

	# Sustain phase: hold at peak.
	var sustain_start := attack_time
	if _timer < sustain_start + sustain_time:
		return 1.0

	# Decay phase: ramp down.
	var decay_start := sustain_start + sustain_time
	var decay_progress := (_timer - decay_start) / decay_time if decay_time > 0.0 else 1.0
	return 1.0 - clampf(decay_progress, 0.0, 1.0)
