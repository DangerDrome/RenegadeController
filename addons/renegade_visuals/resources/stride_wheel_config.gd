## Tuning parameters for procedural stride wheel walk IK.
class_name StrideWheelConfig
extends Resource

@export_group("Stride")
## Base stride length at walk speed. Stride scales up with speed.
@export var stride_length: float = 0.65
## Maximum stride length at run speed.
@export var max_stride_length: float = 1.6
## Speed considered "walking" (uses stride_length).
@export var walk_speed: float = 2.0
## Speed considered "running" (uses max_stride_length).
@export var run_speed: float = 5.0
## Peak height of foot arc during swing phase.
@export var step_height: float = 0.15
## Lateral offset from character center for foot placement.
@export var foot_lateral_offset: float = 0.12
## Height from ankle bone to sole of foot. Raises foot target so sole sits on ground.
@export var foot_height: float = 0.08
## How far ahead of character to plant foot (as fraction of stride). 0.5 = centered, <0.5 = behind, >0.5 = ahead.
@export_range(0.0, 1.0) var plant_ahead_ratio: float = 0.5
## How much feet cross toward centerline when walking. 0 = normal, 1 = inline/runway walk.
@export_range(0.0, 1.5) var crossover_amount: float = 0.0
## Fraction of gait cycle spent in stance (foot planted). Lower = foot lifts earlier.
@export_range(0.3, 0.6) var stance_ratio: float = 0.55

@export_group("Hip")
## Vertical pelvis bob amplitude during walk cycle.
@export var hip_bob_amount: float = 0.025
## Side-to-side hip rock on X axis (degrees). Hip drops on swing leg side.
@export_range(0.0, 15.0) var hip_rock_x: float = 3.0
## Hip twist on Y axis (degrees). Hip rotates toward swing leg.
@export_range(0.0, 15.0) var hip_rock_y: float = 0.0
## Forward/back hip rock on Z axis (degrees). Hip tilts with gait.
@export_range(0.0, 15.0) var hip_rock_z: float = 0.0
## Hip offset (negative = lower hips, causes knee bend). -0.05 to -0.15 typical.
@export var hip_offset: float = -0.06
## Body offset along movement direction. Positive = body trails (feet lead), Negative = body leads.
@export_range(-0.5, 0.5) var body_trail_distance: float = 0.08
## Forward lean angle (degrees) during locomotion. Tilts torso forward into movement.
@export_range(-90.0, 90.0) var forward_lean_angle: float = 5.0
## Smoothing speed for hip offset changes.
@export_range(1.0, 30.0) var hip_smooth_speed: float = 12.0
## Smoothing speed for spine lean rotation. Higher = snappier response.
@export_range(1.0, 30.0) var spine_smooth_speed: float = 4.0

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
@export_range(1.0, 20.0) var influence_blend_speed: float = 10.0
## Smoothing speed for foot IK target positions (higher = snappier, lower = smoother).
@export_range(5.0, 50.0) var foot_smooth_speed: float = 15.0

@export_group("Turn In Place")
## Foot drift threshold as fraction of stride_length. Step triggers when foot drifts this far from ideal position.
@export_range(0.1, 2.0) var turn_drift_threshold: float = 1.5
## Maximum rotation (degrees) before forcing a step. Feet step if body turns past this angle.
@export_range(15.0, 180.0) var max_turn_angle: float = 90.0
## Speed at which feet step to new positions during turn-in-place.
@export_range(1.0, 20.0) var turn_step_speed: float = 8.0
## Arc height for step during turn-in-place.
@export var turn_step_height: float = 0.08
## How much the hip lowers during turn-in-place (causes knee bend).
@export var turn_crouch_amount: float = 0.05
## Forward/back stagger for idle stance (one foot forward, one back). Set to 0 to use rest pose.
@export var stance_stagger: float = 0.0
## Maximum leg reach as multiplier of stride length. Prevents over-stretching.
@export_range(0.8, 2.0) var max_leg_reach: float = 1.2

@export_group("Foot Rotation")
## How much the foot rotates to match ground normal (0-1).
@export_range(0.0, 1.0) var foot_rotation_weight: float = 0.7
## Maximum foot rotation angle in degrees.
@export_range(0.0, 60.0) var max_foot_angle: float = 30.0
## Maximum toe-down pitch during swing lift-off (degrees). Creates "peel off" effect.
@export_range(0.0, 60.0) var swing_pitch_angle: float = 20.0
