## Tuning parameters for procedural stride wheel walk IK.
class_name StrideWheelConfig
extends Resource

@export_group("Stride")
## Base stride length at walk speed. Stride scales up with speed.
@export var stride_length: float = 0.5
## Maximum stride length at run speed.
@export var max_stride_length: float = 2.2
## Speed considered "walking" (uses stride_length).
@export var walk_speed: float = 1.8
## Speed considered "running" (uses max_stride_length).
@export var run_speed: float = 5.0
## Peak height of foot arc during swing phase at run speed.
@export var step_height: float = 0.2
## Minimum step height at slow walk (shuffling). Scales up to step_height at run speed.
@export var min_step_height: float = 0.1
## Lateral offset from character center for foot placement.
@export var foot_lateral_offset: float = 0.1
## Height from ankle bone to sole of foot. Raises foot target so sole sits on ground.
@export var foot_height: float = 0.12
## How far ahead of character to plant foot (as fraction of stride). 0.5 = centered, <0.5 = behind, >0.5 = ahead.
@export_range(0.0, 1.0) var plant_ahead_ratio: float = 0.55
## How much feet cross toward centerline when walking. 0 = normal, 1 = inline/runway walk.
@export_range(0.0, 1.5) var crossover_amount: float = 0.4
## Base stance ratio at walk speed (fraction of cycle foot is planted). Higher = more grounded.
@export_range(0.3, 0.7) var stance_ratio: float = 0.60
## Minimum stance ratio at run speed. Feet spend less time planted when running.
@export_range(0.2, 0.5) var min_stance_ratio: float = 0.35

@export_group("Hip")
## Enable hip bob and rock motion during walking.
@export var hip_motion_enabled: bool = true
## Show debug visualization for hip motion.
@export var debug_hip: bool = true
## Vertical pelvis bob amplitude during walk cycle.
@export var hip_bob_amount: float = 0.1
## Side-to-side hip rock on X axis (degrees). Hip drops on swing leg side.
@export_range(0.0, 15.0) var hip_rock_x: float = 0.0
## Hip twist on Y axis (degrees). Hip rotates toward swing leg.
@export_range(0.0, 15.0) var hip_rock_y: float = 0.0
## Forward/back hip rock on Z axis (degrees). Hip tilts with gait.
@export_range(0.0, 15.0) var hip_rock_z: float = 0.0
## Hip offset (negative = lower hips, causes knee bend). -0.05 to -0.15 typical.
@export_range(-0.3, 0.1) var hip_offset: float = 0.02
## Body offset along movement direction. Positive = body trails (feet lead), Negative = body leads.
@export_range(-0.5, 0.5) var body_trail_distance: float = 0.1
## Spine lean angle (degrees) during locomotion. Tilts torso forward into movement.
@export_range(-30.0, 45.0) var spine_lean_angle: float = 45.0
## Smoothing speed for torso (hip and spine) movements. Higher = snappier response.
@export_range(1.0, 30.0) var torso_smooth_speed: float = 15.0

@export_group("Shoulder Counter-Rotation")
## Enable shoulder and spine counter-rotation opposite to hips.
@export var shoulder_rotation_enabled: bool = true
## Show debug visualization for shoulder/spine rotation.
@export var debug_shoulder: bool = false
## How much shoulders twist opposite to hips (0 = none, 1 = equal and opposite).
@export_range(0.0, 1.5) var shoulder_counter_rotation: float = 1.5
## Additional spine twist cascading up from hips (fraction of hip_rock_y applied to each spine bone).
@export_range(0.0, 1.0) var spine_twist_cascade: float = 1.0
## Shoulder rotation amplitude in degrees. Controls how much shoulders twist during walk cycle.
@export_range(0.0, 45.0) var shoulder_rotation_amount: float = 2.0

@export_group("Ground Detection")
## Show debug visualization for ground detection raycasts.
@export var debug_ground: bool = false
## How far above the foot to start the raycast.
@export_range(0.1, 2.0) var ray_height: float = 0.5
## How far below the foot to cast the ray.
@export_range(0.1, 3.0) var ray_depth: float = 1.0
## Physics layers for ground detection.
@export_flags_3d_physics var ground_layers: int = 1

@export_group("Blending")
## Speed below which the stride wheel is inactive.
@export_range(0.01, 1.0) var idle_threshold: float = 0.1
## Speed at which IK influence blends in/out (feet and arms).
@export_range(1.0, 20.0) var ik_blend_speed: float = 10.0
## Smoothing speed for foot IK target positions (higher = snappier, lower = smoother).
@export_range(5.0, 50.0) var foot_smooth_speed: float = 16.0

@export_group("Soft IK")
## Enable soft IK to prevent knee snapping at full leg extension.
@export var soft_ik_enabled: bool = false
## How much to pull foot target closer when near max reach (0 = none, 1 = max).
@export_range(0.0, 1.0) var ik_softness: float = 0.62
## Fraction of max leg reach where softening begins (0.8 = starts at 80% reach).
@export_range(0.5, 1.0) var ik_soft_start: float = 1.0

@export_group("Turn In Place")
## Enable procedural foot stepping when turning in place.
@export var turn_in_place_enabled: bool = true
## Show debug visualization for turn-in-place stepping.
@export var debug_turn_in_place: bool = false
## Foot drift threshold as fraction of stride_length. Step triggers when foot drifts this far from ideal position.
@export_range(0.1, 1.0) var turn_drift_threshold: float = 0.3
## Maximum rotation (degrees) before forcing a step. Feet step if body turns past this angle.
@export_range(15.0, 180.0) var max_turn_angle: float = 90.0
## Speed at which feet step to new positions during turn-in-place.
@export_range(1.0, 20.0) var turn_step_speed: float = 6.0
## Arc height multiplier for turn-in-place (relative to step_height).
@export_range(1.0, 4.0) var turn_step_height_mult: float = 2.5
## How much the hip lowers during turn-in-place (causes knee bend).
@export_range(0.0, 0.2) var turn_crouch_amount: float = 0.05
## Forward/back stagger for idle stance (one foot forward, one back). Set to 0 to use rest pose.
@export_range(0.0, 0.3) var stance_stagger: float = 0.0
## Maximum leg reach as multiplier of stride length. Prevents over-stretching.
@export_range(0.8, 2.0) var max_leg_reach: float = 0.95

@export_group("Foot Rotation")
## Enable foot rotation to match ground normal and swing pitch.
@export var foot_rotation_enabled: bool = true
## Show debug visualization for foot rotation.
@export var debug_foot_rotation: bool = false
## How much the foot rotates to match ground normal (0-1).
@export_range(0.0, 1.0) var foot_rotation_weight: float = 1.0
## Maximum foot rotation angle in degrees.
@export_range(0.0, 60.0) var max_foot_angle: float = 30.0
## Maximum toe-down pitch during swing lift-off (degrees). Creates "peel off" effect.
@export_range(0.0, 60.0) var swing_pitch_angle: float = 20.0

@export_group("Heel-to-Toe Roll")
## Enable heel-strike to toe-off roll during stance phase.
@export var heel_toe_roll_enabled: bool = false
## Show debug visualization for heel-toe roll.
@export var debug_heel_toe: bool = false
## Heel-down angle at initial contact (degrees, negative = heel down).
@export_range(-30.0, 0.0) var heel_strike_angle: float = -15.0
## Toe-down angle at push-off (degrees, positive = toe down).
@export_range(0.0, 45.0) var toe_off_angle: float = 25.0
## How quickly foot rolls from heel to flat to toe (higher = faster roll).
@export_range(1.0, 10.0) var stance_roll_speed: float = 3.0

@export_group("Knee Tracking")
## Enable knee pole targets to track movement direction.
@export var knee_tracking_enabled: bool = true
## Show debug visualization for knee pole tracking.
@export var debug_knee: bool = false
## How much knees point toward movement direction (0 = forward, 1 = fully track movement).
@export_range(0.0, 1.0) var knee_direction_weight: float = 0.3
## Smoothing speed for knee direction changes.
@export_range(1.0, 20.0) var knee_smooth_speed: float = 8.0

@export_group("Slope Adaptation")
## Enable body lean when walking on slopes.
@export var slope_adaptation_enabled: bool = true
## Show debug visualization for slope detection.
@export var debug_slope: bool = false
## How much the body leans into slopes (0 = none, 1 = match slope angle).
@export_range(0.0, 1.0) var slope_lean_amount: float = 0.2
## Distance ahead to raycast for slope detection (meters).
@export_range(0.1, 2.0) var slope_detect_distance: float = 0.5
## Smoothing speed for slope lean changes.
@export_range(1.0, 15.0) var slope_smooth_speed: float = 6.0

@export_group("Start/Stop Motion")
## Enable special footwork when starting/stopping movement.
@export var start_stop_enabled: bool = false
## Show debug visualization for start/stop motion.
@export var debug_start_stop: bool = false
## How quickly the first step accelerates when starting (higher = snappier start).
@export_range(1.0, 10.0) var start_acceleration: float = 4.0
## How far ahead to plant the stopping foot (fraction of stride).
@export_range(0.2, 0.8) var stop_plant_distance: float = 0.4
## Deceleration threshold - speed change per second that triggers stop animation.
@export_range(0.5, 10.0) var stop_decel_threshold: float = 3.0

@export_group("Turn Banking")
## Enable lateral body lean and twist when turning (like a motorcycle banking into turns).
@export var turn_banking_enabled: bool = true
## Show debug visualization for turn banking.
@export var debug_banking: bool = false
## Maximum bank angle in degrees (lateral lean left/right).
@export_range(0.0, 90.0) var max_bank_angle: float = 15.0
## Maximum twist angle in degrees (torso rotation into turn).
@export_range(0.0, 45.0) var max_turn_twist: float = 45.0
## How fast the bank/twist responds to turn rate. Higher = snappier.
@export_range(1.0, 30.0) var bank_smooth_speed: float = 1.5
## How fast bank/twist returns to neutral (multiplier). 1 = same as attack, 10 = instant, 0.5 = draggy.
@export_range(0.1, 10.0) var bank_decay_mult: float = 10.0
## Minimum speed required for banking (no banking at low speeds).
@export_range(0.0, 5.0) var bank_min_speed: float = 0.5
## Multiplier for turn rate to bank angle conversion. Higher = more aggressive banking.
@export_range(0.5, 10.0) var bank_sensitivity: float = 0.5

@export_group("Procedural Breathing")
## Enable subtle chest/shoulder breathing motion.
@export var breathing_enabled: bool = true
## Breaths per minute at rest.
@export_range(8.0, 20.0) var breath_rate_idle: float = 15.0
## Breaths per minute when running (exertion).
@export_range(20.0, 60.0) var breath_rate_exertion: float = 60.0
## Chest expansion amount (vertical rise in meters).
@export_range(0.0, 0.05) var breath_chest_amount: float = 0.05
## Shoulder rise amount (vertical in meters).
@export_range(0.0, 0.03) var breath_shoulder_amount: float = 0.0
## How quickly breathing rate changes with exertion.
@export_range(0.1, 2.0) var breath_rate_smooth: float = 0.5

@export_group("Idle Sway")
## Enable weight shifting and subtle sway when standing idle.
@export var idle_sway_enabled: bool = true
## Time between weight shifts (seconds).
@export_range(2.0, 8.0) var sway_period: float = 8.0
## Lateral hip shift amount (meters).
@export_range(0.0, 0.1) var sway_hip_shift: float = 0.036
## Hip tilt during weight shift (degrees).
@export_range(0.0, 10.0) var sway_hip_tilt: float = 3.0
## Upper body counter-sway (degrees).
@export_range(0.0, 5.0) var sway_torso_counter: float = 1.5

@export_group("Clavicle Motion")
## Enable clavicle/shoulder blade motion with arm swing.
@export var clavicle_enabled: bool = true
## How much clavicle rotates forward with arm swing (degrees).
@export_range(0.0, 45.0) var clavicle_swing_amount: float = 10.0
## How much clavicle elevates/depresses with arm swing (degrees).
@export_range(0.0, 30.0) var clavicle_elevation_amount: float = 3.0

@export_group("Gait Refinement")
## Use realistic gait curves instead of pure sine waves.
@export var gait_curves_enabled: bool = true
## Asymmetry between left and right sides (0 = symmetric, 1 = max variation).
@export_range(0.0, 1.0) var gait_asymmetry: float = 0.05
## Random timing variation per step (fraction of step duration).
@export_range(0.0, 0.5) var cadence_variation: float = 0.1
## Foot ground contact sharpness (higher = quicker plant, longer stance).
@export_range(1.0, 10.0) var stance_sharpness: float = 1.0
