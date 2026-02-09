## Tuning parameters for foot IK ground adaptation.
class_name FootIKConfig
extends Resource

@export_group("Raycasting")
## How far above the animated foot position to start the ray.
@export var ray_origin_height: float = 0.5
## Maximum ray distance downward (total = origin_height + this).
@export var ray_max_depth: float = 1.0
## Physics layers for ground detection.
@export_flags_3d_physics var ground_layers: int = 1

@export_group("Hip Offset")
## Maximum distance the pelvis can drop to accommodate foot reach.
@export var max_hip_drop: float = 0.4
## Smoothing speed for hip offset changes. Higher = more responsive.
@export_range(1.0, 30.0) var hip_smooth_speed: float = 10.0

@export_group("Foot Placement")
## Small offset above ground to prevent clipping.
@export var foot_height_offset: float = 0.05
## IK influence during locomotion (0-1). Lower preserves animation more.
@export_range(0.0, 1.0) var locomotion_influence: float = 0.8
## IK influence at idle (0-1). Higher gives better grounding when still.
@export_range(0.0, 1.0) var idle_influence: float = 1.0
## Speed at which IK influence transitions.
@export_range(1.0, 20.0) var influence_blend_speed: float = 8.0

@export_group("Foot Rotation")
## How much the foot rotates to match ground normal (0-1).
@export_range(0.0, 1.0) var foot_rotation_weight: float = 0.8
## Maximum foot rotation angle in degrees.
@export_range(0.0, 60.0) var max_foot_angle: float = 35.0
