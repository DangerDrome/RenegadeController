## Tuning parameters for locomotion, root motion, and animation blending.
class_name LocomotionConfig
extends Resource

@export_group("Root Motion")
## Use root_motion_local to fix crossfade drift (Godot 4.4+).
@export var use_root_motion_local: bool = true
## Gravity applied when airborne.
@export var gravity: float = 9.8

@export_group("BlendSpace")
## Smoothing speed for blend position changes. Higher = more responsive.
@export_range(1.0, 30.0) var blend_smooth_speed: float = 10.0
## Maximum movement speed for normalizing blend position.
@export var max_speed: float = 6.0
## Speed threshold below which character is considered idle.
@export var idle_threshold: float = 0.1

@export_group("Turn In Place")
## Yaw delta threshold (degrees) to trigger turn-in-place.
@export_range(15.0, 120.0) var turn_threshold_degrees: float = 60.0
## Speed at which facing catches up to movement direction.
@export_range(1.0, 20.0) var turn_speed: float = 8.0

@export_group("Foot Slide Mitigation")
## Enable basic playback rate clamping to reduce foot slide.
@export var enable_stride_rate_clamping: bool = true
## Max speedup from base playback rate (1.0 + this value).
@export_range(0.0, 0.5) var max_rate_speedup: float = 0.2
## Max slowdown from base playback rate (1.0 - this value).
@export_range(0.0, 0.5) var max_rate_slowdown: float = 0.2
