## Tuning parameters for procedural stride wheel walk IK.
class_name StrideWheelConfig
extends Resource

@export_group("Stride")
## Distance per step (half-cycle). Larger = longer strides.
@export var stride_length: float = 0.7
## Peak height of foot arc during swing phase.
@export var step_height: float = 0.15
## Lateral offset from character center for foot placement.
@export var foot_lateral_offset: float = 0.15
## Height from ankle bone to sole of foot. Raises foot target so sole sits on ground.
@export var foot_height: float = 0.08

@export_group("Hip")
## Vertical pelvis bob amplitude during walk cycle.
@export var hip_bob_amount: float = 0.03
## Hip offset (negative = lower hips, causes knee bend).
@export var hip_offset: float = 0.0
## Smoothing speed for hip offset changes.
@export_range(1.0, 30.0) var hip_smooth_speed: float = 10.0

@export_group("Ground Detection")
## How far above the foot to start the raycast.
@export var ray_height: float = 0.5
## How far below the foot to cast the ray.
@export var ray_depth: float = 1.0
## Physics layers for ground detection.
@export_flags_3d_physics var ground_layers: int = 1

@export_group("Blending")
## Speed below which the stride wheel is inactive.
@export var idle_threshold: float = 0.1
## Speed at which IK influence blends in/out.
@export_range(1.0, 20.0) var influence_blend_speed: float = 8.0

@export_group("Turn In Place")
## Foot drift threshold as fraction of stride_length. Step triggers when foot drifts this far from ideal position.
@export_range(0.1, 0.6) var turn_drift_threshold: float = 0.2
## Speed at which feet step to new positions during turn-in-place.
@export_range(1.0, 20.0) var turn_step_speed: float = 8.0
## Arc height for step during turn-in-place.
@export var turn_step_height: float = 0.08
## How much the hip lowers during turn-in-place (causes knee bend).
@export var turn_crouch_amount: float = 0.05
## Forward/back stagger for idle stance (one foot forward, one back). Set to 0 to use rest pose.
@export var stance_stagger: float = 0.0

@export_group("Foot Rotation")
## How much the foot rotates to match ground normal (0-1).
@export_range(0.0, 1.0) var foot_rotation_weight: float = 0.8
## Maximum foot rotation angle in degrees.
@export_range(0.0, 60.0) var max_foot_angle: float = 35.0
