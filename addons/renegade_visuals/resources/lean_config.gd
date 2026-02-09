## Tuning parameters for procedural lean into acceleration/turns.
class_name LeanConfig
extends Resource

@export_group("Lean")
## Maximum lean angle in degrees.
@export_range(0.0, 45.0) var max_lean_angle: float = 15.0
## Damped spring speed — lower = more floaty, higher = snappier.
@export_range(1.0, 30.0) var lean_speed: float = 8.0
## Multiplier for acceleration-to-lean mapping.
@export var lean_multiplier: float = 0.15

@export_group("Pelvis Tilt")
## Enable subtle pelvis rotation to match ground slope.
@export var enable_pelvis_tilt: bool = true
## Weight of pelvis tilt toward ground normal (0-1).
@export_range(0.0, 1.0) var pelvis_tilt_weight: float = 0.3
## Smoothing speed for pelvis tilt changes.
@export_range(1.0, 20.0) var pelvis_tilt_speed: float = 6.0
