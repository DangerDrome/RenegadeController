## Handles dynamic camera zoom based on player movement speed.
## Zooms out when moving, zooms out more when sprinting, zooms in when idle.
class_name CameraIdleEffects extends RefCounted


#region Constants
const VELOCITY_IDLE_THRESHOLD := 0.1
const VELOCITY_SPRINT_THRESHOLD := 6.0  # Approximate sprint speed.
#endregion


#region Movement Zoom Settings
## Enable dynamic zoom based on movement.
var zoom_enabled: bool = true
## How much to zoom out when walking (negative = further from player).
var walk_zoom_amount: float = -2.0
## How much to zoom out when sprinting (negative = further from player).
var sprint_zoom_amount: float = -4.0
## How much to zoom in when idle (positive = closer to player).
var idle_zoom_amount: float = 0.0
## How long to wait after stopping before applying idle zoom.
var idle_zoom_delay: float = 0.5
## How fast to transition between zoom levels.
var zoom_speed: float = 3.0
#endregion


#region State
var _current_zoom: float = 0.0
var _target_zoom: float = 0.0
var _idle_time: float = 0.0
#endregion


## Configure movement zoom settings.
func configure(
	p_enabled: bool,
	p_walk_amount: float,
	p_sprint_amount: float,
	p_idle_amount: float,
	p_idle_delay: float,
	p_speed: float
) -> void:
	zoom_enabled = p_enabled
	walk_zoom_amount = p_walk_amount
	sprint_zoom_amount = p_sprint_amount
	idle_zoom_amount = p_idle_amount
	idle_zoom_delay = p_idle_delay
	zoom_speed = p_speed


## Get the current zoom offset.
func get_zoom_offset() -> float:
	return _current_zoom


## Get the current idle time.
func get_idle_time() -> float:
	return _idle_time


## Check if player is currently idle (past the delay threshold).
func is_idle_active() -> bool:
	return _idle_time >= idle_zoom_delay


## Reset zoom state.
func reset() -> void:
	_current_zoom = 0.0
	_target_zoom = 0.0
	_idle_time = 0.0


## Update movement zoom. Call this every physics frame.
## Returns true if the player is currently idle (not moving).
func update(delta: float, target: CharacterBody3D) -> bool:
	if not zoom_enabled or not target:
		_current_zoom = lerpf(_current_zoom, 0.0, 1.0 - exp(-zoom_speed * delta))
		_idle_time = 0.0
		return true

	var velocity := target.velocity
	var speed := Vector2(velocity.x, velocity.z).length()  # Horizontal speed only.

	# Check if sprinting (either via property or speed threshold).
	var is_sprinting := false
	if "is_sprinting" in target:
		is_sprinting = target.is_sprinting
	else:
		is_sprinting = speed > VELOCITY_SPRINT_THRESHOLD

	# Determine target zoom based on movement state.
	if speed < VELOCITY_IDLE_THRESHOLD:
		# Idle - apply idle zoom after delay.
		_idle_time += delta
		if _idle_time >= idle_zoom_delay:
			_target_zoom = idle_zoom_amount
	elif is_sprinting:
		# Sprinting - zoom out more.
		_target_zoom = sprint_zoom_amount
		_idle_time = 0.0
	else:
		# Walking - zoom out.
		_target_zoom = walk_zoom_amount
		_idle_time = 0.0

	# Smoothly interpolate toward target zoom.
	_current_zoom = lerpf(_current_zoom, _target_zoom, 1.0 - exp(-zoom_speed * delta))

	return speed < VELOCITY_IDLE_THRESHOLD
