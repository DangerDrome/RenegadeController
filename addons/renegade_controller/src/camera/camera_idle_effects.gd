## Handles idle camera zoom: zooms out when the player stops moving.
## Creates a cinematic feel when the player is stationary.
## Note: Idle shake is now handled by IdleShakeModifier.
class_name CameraIdleEffects extends RefCounted


#region Constants
const VELOCITY_MOVING_THRESHOLD := 0.1
#endregion


#region Idle Zoom Settings
## Enable zoom out when player stops moving.
var zoom_enabled: bool = true
## How much to zoom out when idle (negative = further from player).
var zoom_amount: float = -4.0
## Seconds to wait after stopping before starting to zoom out.
var zoom_delay: float = 0.1
## How fast to zoom out when idle (lower = slower, more cinematic).
var zoom_speed: float = 0.3
#endregion


#region State
var _idle_time: float = 0.0
var _idle_zoom: float = 0.0
var _idle_zoom_progress: float = 0.0
var _idle_zoom_start: float = 0.0
#endregion


## Configure idle zoom settings.
func configure(
	p_enabled: bool,
	p_amount: float,
	p_delay: float,
	p_speed: float
) -> void:
	zoom_enabled = p_enabled
	zoom_amount = p_amount
	zoom_delay = p_delay
	zoom_speed = p_speed


## Get the current idle zoom offset.
func get_zoom_offset() -> float:
	return _idle_zoom


## Get the current idle time (useful for coordinating with IdleShakeModifier).
func get_idle_time() -> float:
	return _idle_time


## Check if player is currently idle (past the delay threshold).
func is_idle_active() -> bool:
	return _idle_time >= zoom_delay


## Reset idle zoom state.
func reset() -> void:
	_idle_time = 0.0
	_idle_zoom = 0.0
	_idle_zoom_progress = 0.0
	_idle_zoom_start = 0.0


## Update idle zoom. Call this every physics frame.
## Returns true if the player is currently idle (not moving).
func update(delta: float, target: CharacterBody3D) -> bool:
	var is_moving := true
	if target:
		is_moving = target.velocity.length_squared() > VELOCITY_MOVING_THRESHOLD

	_update_idle_zoom(delta, is_moving, target != null)

	return not is_moving


func _update_idle_zoom(delta: float, is_moving: bool, has_target: bool) -> void:
	if not zoom_enabled or not has_target:
		_idle_zoom = lerpf(_idle_zoom, 0.0, 1.0 - exp(-zoom_speed * 4.0 * delta))
		_idle_time = 0.0
		_idle_zoom_progress = 0.0
		return

	if is_moving:
		# Player is moving - reset idle time and ease back in from current position.
		_idle_time = 0.0
		if _idle_zoom_progress > 0.0:
			# Store current zoom as new start for returning.
			_idle_zoom_start = _idle_zoom
		_idle_zoom_progress = 0.0
		_idle_zoom = lerpf(_idle_zoom, 0.0, 1.0 - exp(-zoom_speed * 4.0 * delta))
	else:
		# Player is idle - accumulate time.
		_idle_time += delta

		# After delay, start zooming out with ease-in-out from current position.
		if _idle_time >= zoom_delay:
			# Capture start position when we first begin idle zoom.
			if _idle_zoom_progress == 0.0:
				_idle_zoom_start = _idle_zoom

			# Progress from 0 to 1 over time.
			_idle_zoom_progress = minf(_idle_zoom_progress + zoom_speed * delta * 0.3, 1.0)

			# Apply smoothstep ease-in-out: slow start, fast middle, slow end.
			var t := _idle_zoom_progress
			var eased := t * t * (3.0 - 2.0 * t)

			# Lerp from start position to target.
			_idle_zoom = lerpf(_idle_zoom_start, zoom_amount, eased)
