## Procedural stride wheel for walk IK.
## Drives Marker3D foot targets in a phase-based gait cycle: feet plant on the ground
## during stance phase and swing through an arc to the next plant position.
## Also handles hip bob and ground-following hip drop.
class_name StrideWheelComponent
extends Node

@export var config: StrideWheelConfig:
	set(value):
		config = value
		if config:
			_sync_from_config()

@export_group("Stride")
## Base stride length at walk speed. Stride scales up with speed.
@export var stride_length: float = 0.5:
	set(value):
		stride_length = value
		if config:
			config.stride_length = value
## Maximum stride length at run speed.
@export var max_stride_length: float = 2.2:
	set(value):
		max_stride_length = value
		if config:
			config.max_stride_length = value
## Speed considered "walking" (uses stride_length).
@export var walk_speed: float = 1.8:
	set(value):
		walk_speed = value
		if config:
			config.walk_speed = value
## Speed considered "running" (uses max_stride_length).
@export var run_speed: float = 5.0:
	set(value):
		run_speed = value
		if config:
			config.run_speed = value
## Peak height of foot arc during swing phase at run speed.
@export var step_height: float = 0.2:
	set(value):
		step_height = value
		if config:
			config.step_height = value
## Minimum step height at slow walk (shuffling). Scales up to step_height at run speed.
@export var min_step_height: float = 0.1:
	set(value):
		min_step_height = value
		if config:
			config.min_step_height = value
## Lateral offset from character center for foot placement.
@export var foot_lateral_offset: float = 0.1:
	set(value):
		foot_lateral_offset = value
		if config:
			config.foot_lateral_offset = value
## Height from ankle bone to sole of foot. Raises foot target so sole sits on ground.
@export var foot_height: float = 0.12:
	set(value):
		foot_height = value
		if config:
			config.foot_height = value
## How far ahead of character to plant foot (as fraction of stride). 0.5 = centered, <0.5 = behind, >0.5 = ahead.
@export_range(0.0, 1.0) var plant_ahead_ratio: float = 0.55:
	set(value):
		plant_ahead_ratio = value
		if config:
			config.plant_ahead_ratio = value
## How much feet cross toward centerline when walking. 0 = normal, 1 = inline/runway walk.
@export_range(0.0, 1.5) var crossover_amount: float = 0.4:
	set(value):
		crossover_amount = value
		if config:
			config.crossover_amount = value
## Base stance ratio at walk speed (fraction of cycle foot is planted). Higher = more grounded.
@export_range(0.3, 0.7) var stance_ratio: float = 0.60:
	set(value):
		stance_ratio = value
		if config:
			config.stance_ratio = value
## Minimum stance ratio at run speed. Feet spend less time planted when running.
@export_range(0.2, 0.5) var min_stance_ratio: float = 0.35:
	set(value):
		min_stance_ratio = value
		if config:
			config.min_stance_ratio = value

@export_group("Hip")
## Enable hip bob and rock motion during walking.
@export var hip_motion_enabled: bool = true:
	set(value):
		hip_motion_enabled = value
		if config:
			config.hip_motion_enabled = value
## Show debug visualization for hip motion.
@export var debug_hip: bool = true:
	set(value):
		debug_hip = value
		if config:
			config.debug_hip = value
## Vertical pelvis bob amplitude during walk cycle.
@export var hip_bob_amount: float = 0.1:
	set(value):
		hip_bob_amount = value
		if config:
			config.hip_bob_amount = value
## Side-to-side hip rock on X axis (degrees). Hip drops on swing leg side.
@export_range(0.0, 15.0) var hip_rock_x: float = 15.0:
	set(value):
		hip_rock_x = value
		if config:
			config.hip_rock_x = value
## Hip twist on Y axis (degrees). Hip rotates toward swing leg.
@export_range(0.0, 15.0) var hip_rock_y: float = 15.0:
	set(value):
		hip_rock_y = value
		if config:
			config.hip_rock_y = value
## Forward/back hip rock on Z axis (degrees). Hip tilts with gait.
@export_range(0.0, 15.0) var hip_rock_z: float = 15.0:
	set(value):
		hip_rock_z = value
		if config:
			config.hip_rock_z = value
## Hip offset (negative = lower hips, causes knee bend). -0.05 to -0.15 typical.
@export_range(-0.3, 0.1) var hip_offset: float = 0.02:
	set(value):
		hip_offset = value
		if config:
			config.hip_offset = value
## Body offset along movement direction. Positive = body trails (feet lead), Negative = body leads.
@export_range(-0.5, 0.5) var body_trail_distance: float = 0.1:
	set(value):
		body_trail_distance = value
		if config:
			config.body_trail_distance = value
## Spine lean angle (degrees) during locomotion. Tilts torso forward into movement.
@export_range(-30.0, 45.0) var spine_lean_angle: float = 8.0:
	set(value):
		spine_lean_angle = value
		if config:
			config.spine_lean_angle = value
## Smoothing speed for torso (hip and spine) movements. Higher = snappier response.
@export_range(1.0, 30.0) var torso_smooth_speed: float = 10.0:
	set(value):
		torso_smooth_speed = value
		if config:
			config.torso_smooth_speed = value

@export_group("Shoulder Counter-Rotation")
## Enable shoulder and spine counter-rotation opposite to hips.
@export var shoulder_rotation_enabled: bool = false:
	set(value):
		shoulder_rotation_enabled = value
		if config:
			config.shoulder_rotation_enabled = value
## Show debug visualization for shoulder/spine rotation.
@export var debug_shoulder: bool = false:
	set(value):
		debug_shoulder = value
		if config:
			config.debug_shoulder = value
## How much shoulders twist opposite to hips (0 = none, 1 = equal and opposite).
@export_range(0.0, 1.5) var shoulder_counter_rotation: float = 0.7:
	set(value):
		shoulder_counter_rotation = value
		if config:
			config.shoulder_counter_rotation = value
## Additional spine twist cascading up from hips (fraction of hip_rock_y applied to each spine bone).
@export_range(0.0, 1.0) var spine_twist_cascade: float = 0.3:
	set(value):
		spine_twist_cascade = value
		if config:
			config.spine_twist_cascade = value
## Shoulder rotation amplitude in degrees. Controls how much shoulders twist during walk cycle.
@export_range(0.0, 45.0) var shoulder_rotation_amount: float = 15.0:
	set(value):
		shoulder_rotation_amount = value
		if config:
			config.shoulder_rotation_amount = value

@export_group("Ground Detection")
## Show debug visualization for ground detection raycasts.
@export var debug_ground: bool = false:
	set(value):
		debug_ground = value
		if config:
			config.debug_ground = value
## How far above the foot to start the raycast.
@export_range(0.1, 2.0) var ray_height: float = 0.5:
	set(value):
		ray_height = value
		if config:
			config.ray_height = value
## How far below the foot to cast the ray.
@export_range(0.1, 3.0) var ray_depth: float = 1.0:
	set(value):
		ray_depth = value
		if config:
			config.ray_depth = value
## Physics layers for ground detection.
@export_flags_3d_physics var ground_layers: int = 1:
	set(value):
		ground_layers = value
		if config:
			config.ground_layers = value

@export_group("Blending")
## Speed below which the stride wheel is inactive.
@export_range(0.01, 1.0) var idle_threshold: float = 0.1:
	set(value):
		idle_threshold = value
		if config:
			config.idle_threshold = value
## Speed at which IK influence blends in/out (feet and arms).
@export_range(1.0, 20.0) var ik_blend_speed: float = 10.0:
	set(value):
		ik_blend_speed = value
		if config:
			config.ik_blend_speed = value
## Smoothing speed for foot IK target positions (higher = snappier, lower = smoother).
@export_range(5.0, 50.0) var foot_smooth_speed: float = 10.0:
	set(value):
		foot_smooth_speed = value
		if config:
			config.foot_smooth_speed = value

@export_group("Soft IK")
## Enable soft IK to prevent knee snapping at full leg extension.
@export var soft_ik_enabled: bool = true:
	set(value):
		soft_ik_enabled = value
		if config:
			config.soft_ik_enabled = value
## How much to pull foot target closer when near max reach (0 = none, 1 = max).
@export_range(0.0, 1.0) var ik_softness: float = 0.3:
	set(value):
		ik_softness = value
		if config:
			config.ik_softness = value
## Fraction of max leg reach where softening begins (0.8 = starts at 80% reach).
@export_range(0.5, 1.0) var ik_soft_start: float = 0.85:
	set(value):
		ik_soft_start = value
		if config:
			config.ik_soft_start = value

@export_group("Turn In Place")
## Enable procedural foot stepping when turning in place.
@export var turn_in_place_enabled: bool = true:
	set(value):
		turn_in_place_enabled = value
		if config:
			config.turn_in_place_enabled = value
## Show debug visualization for turn-in-place stepping.
@export var debug_turn_in_place: bool = false:
	set(value):
		debug_turn_in_place = value
		if config:
			config.debug_turn_in_place = value
## Foot drift threshold as fraction of stride_length. Step triggers when foot drifts this far.
@export_range(0.1, 1.0) var turn_drift_threshold: float = 0.3:
	set(value):
		turn_drift_threshold = value
		if config:
			config.turn_drift_threshold = value
## Maximum rotation (degrees) before forcing a step. Feet step if body turns past this angle.
@export_range(15.0, 180.0) var max_turn_angle: float = 90.0:
	set(value):
		max_turn_angle = value
		if config:
			config.max_turn_angle = value
## Speed at which feet step to new positions during turn-in-place.
@export_range(1.0, 20.0) var turn_step_speed: float = 6.0:
	set(value):
		turn_step_speed = value
		if config:
			config.turn_step_speed = value
## Arc height multiplier for turn-in-place (relative to step_height).
@export_range(1.0, 4.0) var turn_step_height_mult: float = 2.5:
	set(value):
		turn_step_height_mult = value
		if config:
			config.turn_step_height_mult = value
## How much the hip lowers during turn-in-place (causes knee bend).
@export_range(0.0, 0.2) var turn_crouch_amount: float = 0.05:
	set(value):
		turn_crouch_amount = value
		if config:
			config.turn_crouch_amount = value
## Forward/back stagger for idle stance (one foot forward, one back). Set to 0 to use rest pose.
@export_range(0.0, 0.3) var stance_stagger: float = 0.0:
	set(value):
		stance_stagger = value
		if config:
			config.stance_stagger = value
## Maximum leg reach as multiplier of stride length. Prevents over-stretching.
@export_range(0.8, 2.0) var max_leg_reach: float = 1.2:
	set(value):
		max_leg_reach = value
		if config:
			config.max_leg_reach = value

@export_group("Foot Rotation")
## Enable foot rotation to match ground normal and swing pitch.
@export var foot_rotation_enabled: bool = false:
	set(value):
		foot_rotation_enabled = value
		if config:
			config.foot_rotation_enabled = value
## Show debug visualization for foot rotation.
@export var debug_foot_rotation: bool = false:
	set(value):
		debug_foot_rotation = value
		if config:
			config.debug_foot_rotation = value
## How much the foot rotates to match ground normal (0-1).
@export_range(0.0, 1.0) var foot_rotation_weight: float = 0.7:
	set(value):
		foot_rotation_weight = value
		if config:
			config.foot_rotation_weight = value
## Maximum foot rotation angle in degrees.
@export_range(0.0, 60.0) var max_foot_angle: float = 30.0:
	set(value):
		max_foot_angle = value
		if config:
			config.max_foot_angle = value
## Maximum toe-down pitch during swing lift-off (degrees). Creates "peel off" effect.
@export_range(0.0, 60.0) var swing_pitch_angle: float = 20.0:
	set(value):
		swing_pitch_angle = value
		if config:
			config.swing_pitch_angle = value

@export_group("Heel-to-Toe Roll")
## Enable heel-strike to toe-off roll during stance phase.
@export var heel_toe_roll_enabled: bool = false:
	set(value):
		heel_toe_roll_enabled = value
		if config:
			config.heel_toe_roll_enabled = value
## Show debug visualization for heel-toe roll.
@export var debug_heel_toe: bool = false:
	set(value):
		debug_heel_toe = value
		if config:
			config.debug_heel_toe = value
## Heel-down angle at initial contact (degrees, negative = heel down).
@export_range(-30.0, 0.0) var heel_strike_angle: float = -15.0:
	set(value):
		heel_strike_angle = value
		if config:
			config.heel_strike_angle = value
## Toe-down angle at push-off (degrees, positive = toe down).
@export_range(0.0, 45.0) var toe_off_angle: float = 25.0:
	set(value):
		toe_off_angle = value
		if config:
			config.toe_off_angle = value
## How quickly foot rolls from heel to flat to toe (higher = faster roll).
@export_range(1.0, 10.0) var stance_roll_speed: float = 3.0:
	set(value):
		stance_roll_speed = value
		if config:
			config.stance_roll_speed = value

@export_group("Knee Tracking")
## Enable knee pole targets to track movement direction.
@export var knee_tracking_enabled: bool = false:
	set(value):
		knee_tracking_enabled = value
		if config:
			config.knee_tracking_enabled = value
## Show debug visualization for knee pole tracking.
@export var debug_knee: bool = false:
	set(value):
		debug_knee = value
		if config:
			config.debug_knee = value
## How much knees point toward movement direction (0 = forward, 1 = fully track movement).
@export_range(0.0, 1.0) var knee_direction_weight: float = 0.3:
	set(value):
		knee_direction_weight = value
		if config:
			config.knee_direction_weight = value
## Smoothing speed for knee direction changes.
@export_range(1.0, 20.0) var knee_smooth_speed: float = 8.0:
	set(value):
		knee_smooth_speed = value
		if config:
			config.knee_smooth_speed = value

@export_group("Slope Adaptation")
## Enable body lean when walking on slopes.
@export var slope_adaptation_enabled: bool = false:
	set(value):
		slope_adaptation_enabled = value
		if config:
			config.slope_adaptation_enabled = value
## Show debug visualization for slope detection.
@export var debug_slope: bool = false:
	set(value):
		debug_slope = value
		if config:
			config.debug_slope = value
## How much the body leans into slopes (0 = none, 1 = match slope angle).
@export_range(0.0, 1.0) var slope_lean_amount: float = 0.5:
	set(value):
		slope_lean_amount = value
		if config:
			config.slope_lean_amount = value
## Distance ahead to raycast for slope detection (meters).
@export_range(0.1, 2.0) var slope_detect_distance: float = 0.5:
	set(value):
		slope_detect_distance = value
		if config:
			config.slope_detect_distance = value
## Smoothing speed for slope lean changes.
@export_range(1.0, 15.0) var slope_smooth_speed: float = 6.0:
	set(value):
		slope_smooth_speed = value
		if config:
			config.slope_smooth_speed = value

@export_group("Start/Stop Motion")
## Enable special footwork when starting/stopping movement.
@export var start_stop_enabled: bool = false:
	set(value):
		start_stop_enabled = value
		if config:
			config.start_stop_enabled = value
## Show debug visualization for start/stop motion.
@export var debug_start_stop: bool = false:
	set(value):
		debug_start_stop = value
		if config:
			config.debug_start_stop = value
## How quickly the first step accelerates when starting (higher = snappier start).
@export_range(1.0, 10.0) var start_acceleration: float = 4.0:
	set(value):
		start_acceleration = value
		if config:
			config.start_acceleration = value
## How far ahead to plant the stopping foot (fraction of stride).
@export_range(0.2, 0.8) var stop_plant_distance: float = 0.4:
	set(value):
		stop_plant_distance = value
		if config:
			config.stop_plant_distance = value
## Deceleration threshold - speed change per second that triggers stop animation.
@export_range(0.5, 10.0) var stop_decel_threshold: float = 3.0:
	set(value):
		stop_decel_threshold = value
		if config:
			config.stop_decel_threshold = value

@export_group("IK Nodes")
## TwoBoneIK3D solver for the left leg.
@export var left_leg_ik: NodePath
## TwoBoneIK3D solver for the right leg.
@export var right_leg_ik: NodePath

@export_group("IK Targets")
## Marker3D target the left leg IK solver points at.
@export var left_foot_target: NodePath
## Marker3D target the right leg IK solver points at.
@export var right_foot_target: NodePath
## Marker3D pole target for left knee direction. Updated to track movement.
@export var left_knee_target: NodePath
## Marker3D pole target for right knee direction. Updated to track movement.
@export var right_knee_target: NodePath
@export_group("Head Look-At")
## Marker3D target the head LookAt modifier points at. Updated to follow cursor.
@export var head_target: NodePath
## The LookAtModifier3D node for head rotation. Influence is controlled based on state.
@export var head_look_modifier: NodePath
## Time (seconds) before head returns to forward when cursor is idle.
@export_range(0.5, 10.0) var head_idle_timeout: float = 2.0
## How fast the head tracks the cursor. Higher = snappier.
@export_range(1.0, 20.0) var head_track_speed: float = 8.0
## How fast the head returns to forward when idle. Lower = more natural.
@export_range(1.0, 10.0) var head_return_speed: float = 3.0
## Enable head anticipation - head looks toward movement/turn direction.
@export var head_anticipation_enabled: bool = true
## How fast the head responds to movement direction changes. Higher = snappier anticipation.
@export_range(10.0, 50.0) var head_anticipation_speed: float = 25.0
## How far ahead to look when moving (meters). Scales with speed.
@export_range(2.0, 15.0) var head_look_distance: float = 5.0
## How much the head anticipates turns (0 = none, 1 = full turn anticipation).
@export_range(0.0, 1.0) var head_turn_anticipation: float = 0.5

@export_group("Arm Swing")
## Enable procedural arm swing during walking.
@export var arm_swing_enabled: bool = false
## Marker3D target for left hand IK. Leave empty to disable arm swing.
@export var left_hand_target: NodePath
## Marker3D target for right hand IK. Leave empty to disable arm swing.
@export var right_hand_target: NodePath
## Forward/back swing amplitude (meters). Arms swing opposite to legs.
@export_range(0.0, 2.0) var arm_swing_amount: float = 1.5
## Forward offset added to arm swing - shifts arms forward during movement (meters).
@export_range(0.0, 0.5) var arm_forward_bias: float = 0.15
## Phase offset to align arm swing with opposite leg (0.25 = arm forward when opposite foot plants).
## 0.0 = arms at center when foot plants, 0.25 = correct natural timing, 0.5 = arms opposite.
@export_range(0.0, 0.5) var arm_phase_offset: float = 0.25
## Arm looseness/lag. Lower = stiffer, higher = looser with more follow-through.
@export_range(1.0, 30.0) var arm_smoothing: float = 20.0
## Vertical lift at swing extremes (meters). Creates natural arc.
@export_range(0.0, 0.5) var arm_swing_lift: float = 0.03
## How far to drop hands from T-pose rest position (meters). Creates natural hanging arms.
@export_range(0.0, 2.5) var arm_rest_drop: float = 2.0
## How far to raise hands from dropped position (meters). Creates elbow bend.
@export_range(0.0, 0.5) var arm_rest_raise: float = 0.0
## Move hands up in world space (meters).
@export_range(0.0, 0.5) var arm_rest_up: float = 0.0
## Maximum reach from shoulder to hand (fraction of full arm length). Less than 1.0 forces elbow bend.
@export_range(0.5, 1.0) var arm_max_reach: float = 0.987

@export_group("Debug")
## Enable debug visualization.
@export var debug_enabled: bool = false
## Show planted foot positions (green = left, blue = right).
@export var debug_show_plant_pos: bool = true
## Show predicted plant positions (yellow).
@export var debug_show_predicted: bool = true
## Show character reference point (white).
@export var debug_show_char_pos: bool = false
## Show movement direction (magenta arrow).
@export var debug_show_move_dir: bool = false
## Show stride wheel circles and phase indicators.
@export var debug_show_stride_wheel: bool = false
## Size of debug spheres.
@export var debug_sphere_size: float = 0.05
## Print bone axis reference to console on startup (for IK debugging).
@export var debug_bone_axes: bool = false

var _visuals: CharacterVisuals
var _skeleton: Skeleton3D

# IK node references
var _left_ik: Node
var _right_ik: Node
var _left_target: Marker3D
var _right_target: Marker3D

# Arm IK targets (optional - for arm swing)
var _left_hand: Marker3D
var _right_hand: Marker3D
var _left_hand_rest: Vector3 = Vector3.ZERO  # Rest position (captured at start)
var _right_hand_rest: Vector3 = Vector3.ZERO
var _arm_influence: float = 0.0  # Current arm swing influence

# Knee pole targets (for knee direction tracking)
var _left_knee: Marker3D
var _right_knee: Marker3D
var _left_knee_rest: Vector3 = Vector3.ZERO  # Rest position relative to thigh
var _right_knee_rest: Vector3 = Vector3.ZERO

# Head look-at target (updated to follow cursor and movement direction)
var _head_target: Marker3D
var _head_look_mod: LookAtModifier3D  # The LookAtModifier3D to control influence
var _head_influence: float = 0.0  # Current head look influence (smoothed)
var _head_target_goal: Vector3 = Vector3.ZERO  # Smoothed head target position
var _last_cursor_pos: Vector3 = Vector3.ZERO   # Previous cursor position for movement detection
var _cursor_idle_time: float = 999.0           # Time since cursor last moved (start high = inactive)
var _cursor_has_moved: bool = false            # True only after cursor has actually moved
var _head_is_idle: bool = false                # True when head has returned to forward
var _head_look_direction: Vector3 = Vector3.ZERO  # Smoothed movement direction for head anticipation
var _prev_yaw_for_head: float = 0.0            # Previous yaw for turn detection
var _head_yaw_delta: float = 0.0               # Current frame yaw change for turn detection

# Feet rotation modifier (toggled based on walk/idle state)
var _feet_xform: Node

# Bone indices
var _pelvis_idx: int = -1
var _spine_01_idx: int = -1
var _spine_02_idx: int = -1
var _spine_03_idx: int = -1
var _left_foot_idx: int = -1
var _right_foot_idx: int = -1
var _left_upperarm_idx: int = -1
var _right_upperarm_idx: int = -1

# Arm lengths (calculated at setup)
var _left_arm_length: float = 0.0
var _right_arm_length: float = 0.0

# Leg lengths (calculated at setup for soft IK)
var _left_leg_length: float = 0.0
var _right_leg_length: float = 0.0

# Arm swing randomness (regenerated periodically)
var _left_arm_phase_offset: float = 0.0
var _right_arm_phase_offset: float = 0.0
var _left_arm_amp_scale: float = 1.0
var _right_arm_amp_scale: float = 1.0
var _arm_random_timer: float = 0.0

# Smoothed arm positions (for loose/laggy feel)
var _left_hand_current: Vector3 = Vector3.ZERO
var _right_hand_current: Vector3 = Vector3.ZERO
var _arms_initialized: bool = false
# Phase accumulator — one full TAU = two steps (left + right)
var _phase: float = 0.0

# Per-foot state (position locked in world space, yaw stored for planted rotation)
var _left_plant_pos: Vector3 = Vector3.ZERO
var _right_plant_pos: Vector3 = Vector3.ZERO
var _left_plant_yaw: float = 0.0  # Stored Y rotation when foot planted
var _right_plant_yaw: float = 0.0
var _left_prev_cycle: float = 0.0   # Previous cycle value (0–1) for transition detection
var _right_prev_cycle: float = 0.0
var _left_swing_target: Vector3 = Vector3.ZERO  # Smoothed swing landing target
var _right_swing_target: Vector3 = Vector3.ZERO
var _left_swing_t: float = 0.0  # Current swing phase (0 = just lifted, 1 = landing)
var _right_swing_t: float = 0.0
var _left_ground_normal: Vector3 = Vector3.UP
var _right_ground_normal: Vector3 = Vector3.UP

# Hip
var _current_hip_offset: float = 0.0
var _current_hip_forward: Vector3 = Vector3.ZERO  # Torso lag offset (world space)
var _current_lean_angle: float = 0.0  # Forward tilt in radians
var _current_hip_rock: Vector3 = Vector3.ZERO  # Hip rock on all 3 axes in radians
var _current_move_dir: Vector3 = Vector3.ZERO  # Current movement direction (for lean axis)
var _pelvis_rest_basis: Basis = Basis.IDENTITY  # Pelvis rest pose

# Acceleration tracking for dynamic motion scaling
var _prev_velocity: Vector3 = Vector3.ZERO
var _current_acceleration: float = 0.0  # Smoothed forward acceleration (m/s²)
var _accel_factor: float = 0.0  # Normalized acceleration factor (-0.3 to 1.0)
var _current_pelvis_basis: Basis = Basis.IDENTITY  # Smoothed pelvis rotation

# Spine (cascading counter-rotation)
var _spine_01_rest_basis: Basis = Basis.IDENTITY
var _spine_02_rest_basis: Basis = Basis.IDENTITY
var _spine_03_rest_basis: Basis = Basis.IDENTITY
var _current_spine_01_basis: Basis = Basis.IDENTITY
var _current_spine_02_basis: Basis = Basis.IDENTITY
var _current_spine_03_basis: Basis = Basis.IDENTITY
var _current_shoulder_twist: float = 0.0  # Smoothed shoulder twist in radians

# Influence
var _current_influence: float = 0.0

# Physics
var _space_state: PhysicsDirectSpaceState3D

# Rest positions (bind pose feet in world space, cached each frame)
var _left_rest_pos: Vector3 = Vector3.ZERO
var _right_rest_pos: Vector3 = Vector3.ZERO

# Turn-in-place state
var _prev_yaw: float = 0.0
var _was_moving: bool = false  # Track previous frame movement state
var _is_walking: bool = false  # True only during active walking (not idle/turn)
var _is_turning_in_place: bool = false
var _turn_step_progress: float = 0.0  # 0–1 for step animation
var _left_step_start: Vector3 = Vector3.ZERO
var _left_step_end: Vector3 = Vector3.ZERO
var _right_step_start: Vector3 = Vector3.ZERO
var _right_step_end: Vector3 = Vector3.ZERO
var _stepping_foot: int = 0  # 0 = left, 1 = right

# Foot rotation is now applied directly in _apply_foot_bone_rotations() after IK runs

# Foot bone rest orientation (captured at setup to preserve skeleton's foot direction)
var _left_foot_rest_basis: Basis = Basis.IDENTITY
var _right_foot_rest_basis: Basis = Basis.IDENTITY
var _initial_char_yaw: float = 0.0  # Character yaw when rest basis was captured

# Smoothed foot target state (lerped each frame to avoid snapping)
var _left_current_pos: Vector3 = Vector3.ZERO
var _right_current_pos: Vector3 = Vector3.ZERO
var _left_current_quat: Quaternion = Quaternion.IDENTITY
var _right_current_quat: Quaternion = Quaternion.IDENTITY
var _left_foot_initialized: bool = false
var _right_foot_initialized: bool = false

# Heel-to-toe roll state (stance phase progress 0-1 for each foot)
var _left_stance_progress: float = 0.0
var _right_stance_progress: float = 0.0

# Knee tracking state
var _current_knee_direction: Vector3 = Vector3.FORWARD  # Smoothed direction knees point
var _left_thigh_idx: int = -1
var _right_thigh_idx: int = -1

# Slope adaptation state
var _current_slope_angle: float = 0.0  # Smoothed slope angle in radians
var _slope_normal: Vector3 = Vector3.UP  # Detected ground slope ahead

# Start/stop motion state
var _prev_speed: float = 0.0  # Last frame's speed for acceleration detection
var _motion_state: int = 0  # 0 = idle, 1 = starting, 2 = walking, 3 = stopping
var _start_timer: float = 0.0  # Time since motion start
var _stop_timer: float = 0.0  # Time since stop initiated
var _stop_foot_planted: bool = false  # Whether stopping foot has been planted

# Debug visualization
var _debug_container: Node3D
var _debug_left_plant: MeshInstance3D
var _debug_right_plant: MeshInstance3D
var _debug_left_predicted: MeshInstance3D
var _debug_right_predicted: MeshInstance3D
var _debug_char_pos: MeshInstance3D
var _debug_move_dir: MeshInstance3D
var _debug_left_target: MeshInstance3D
var _debug_right_target: MeshInstance3D
var _debug_left_wheel: MeshInstance3D
var _debug_right_wheel: MeshInstance3D
var _debug_left_phase: MeshInstance3D
var _debug_right_phase: MeshInstance3D
var _debug_left_markers: Array[MeshInstance3D] = []
var _debug_right_markers: Array[MeshInstance3D] = []
var _debug_left_spokes: Array[MeshInstance3D] = []
var _debug_right_spokes: Array[MeshInstance3D] = []
var _debug_overhead_left_label: Label3D
var _debug_overhead_right_label: Label3D
# Per-section debug visuals
var _debug_ground_left_ray: MeshInstance3D
var _debug_ground_right_ray: MeshInstance3D
var _debug_ground_left_hit: MeshInstance3D
var _debug_ground_right_hit: MeshInstance3D
var _debug_knee_left: MeshInstance3D
var _debug_knee_right: MeshInstance3D
var _debug_slope_ray: MeshInstance3D
var _debug_slope_hit: MeshInstance3D
var _debug_hip_marker: MeshInstance3D
var _debug_motion_label: Label3D

# Cache for debug - store last predicted positions
var _debug_left_predicted_pos: Vector3 = Vector3.ZERO
var _debug_right_predicted_pos: Vector3 = Vector3.ZERO
var _debug_move_dir_vec: Vector3 = Vector3.ZERO


## Sync local @export properties from the config resource.
func _sync_from_config() -> void:
	if config == null:
		return
	# Use direct assignment to avoid setter triggering back
	stride_length = config.stride_length
	max_stride_length = config.max_stride_length
	walk_speed = config.walk_speed
	run_speed = config.run_speed
	step_height = config.step_height
	min_step_height = config.min_step_height
	foot_lateral_offset = config.foot_lateral_offset
	foot_height = config.foot_height
	plant_ahead_ratio = config.plant_ahead_ratio
	crossover_amount = config.crossover_amount
	stance_ratio = config.stance_ratio
	min_stance_ratio = config.min_stance_ratio
	# Hip
	hip_motion_enabled = config.hip_motion_enabled
	debug_hip = config.debug_hip
	hip_bob_amount = config.hip_bob_amount
	hip_rock_x = config.hip_rock_x
	hip_rock_y = config.hip_rock_y
	hip_rock_z = config.hip_rock_z
	hip_offset = config.hip_offset
	body_trail_distance = config.body_trail_distance
	spine_lean_angle = config.spine_lean_angle
	torso_smooth_speed = config.torso_smooth_speed
	# Shoulder counter-rotation
	shoulder_rotation_enabled = config.shoulder_rotation_enabled
	debug_shoulder = config.debug_shoulder
	shoulder_counter_rotation = config.shoulder_counter_rotation
	spine_twist_cascade = config.spine_twist_cascade
	shoulder_rotation_amount = config.shoulder_rotation_amount
	# Ground detection
	debug_ground = config.debug_ground
	ray_height = config.ray_height
	ray_depth = config.ray_depth
	ground_layers = config.ground_layers
	idle_threshold = config.idle_threshold
	ik_blend_speed = config.ik_blend_speed
	foot_smooth_speed = config.foot_smooth_speed
	# Soft IK
	soft_ik_enabled = config.soft_ik_enabled
	ik_softness = config.ik_softness
	ik_soft_start = config.ik_soft_start
	# Turn in place
	turn_in_place_enabled = config.turn_in_place_enabled
	debug_turn_in_place = config.debug_turn_in_place
	turn_drift_threshold = config.turn_drift_threshold
	max_turn_angle = config.max_turn_angle
	turn_step_speed = config.turn_step_speed
	turn_step_height_mult = config.turn_step_height_mult
	turn_crouch_amount = config.turn_crouch_amount
	stance_stagger = config.stance_stagger
	max_leg_reach = config.max_leg_reach
	# Foot rotation
	foot_rotation_enabled = config.foot_rotation_enabled
	debug_foot_rotation = config.debug_foot_rotation
	foot_rotation_weight = config.foot_rotation_weight
	max_foot_angle = config.max_foot_angle
	swing_pitch_angle = config.swing_pitch_angle
	# Heel-to-toe roll
	heel_toe_roll_enabled = config.heel_toe_roll_enabled
	debug_heel_toe = config.debug_heel_toe
	heel_strike_angle = config.heel_strike_angle
	toe_off_angle = config.toe_off_angle
	stance_roll_speed = config.stance_roll_speed
	# Knee tracking
	knee_tracking_enabled = config.knee_tracking_enabled
	debug_knee = config.debug_knee
	knee_direction_weight = config.knee_direction_weight
	knee_smooth_speed = config.knee_smooth_speed
	# Slope adaptation
	slope_adaptation_enabled = config.slope_adaptation_enabled
	debug_slope = config.debug_slope
	slope_lean_amount = config.slope_lean_amount
	slope_detect_distance = config.slope_detect_distance
	slope_smooth_speed = config.slope_smooth_speed
	# Start/stop motion
	start_stop_enabled = config.start_stop_enabled
	debug_start_stop = config.debug_start_stop
	start_acceleration = config.start_acceleration
	stop_plant_distance = config.stop_plant_distance
	stop_decel_threshold = config.stop_decel_threshold


## Update acceleration tracking for dynamic motion scaling.
## Must be called early in _physics_process before other systems use _accel_factor.
func _update_acceleration(delta: float) -> void:
	var current_velocity := Vector3.ZERO
	if _visuals.controller:
		current_velocity = _visuals.controller.velocity

	# Use velocity direction for acceleration calc (not input direction)
	# This ensures deceleration is detected even after input stops
	var velocity_dir := current_velocity.normalized() if current_velocity.length_squared() > 0.01 else _prev_velocity.normalized()

	# Calculate forward acceleration (velocity change in velocity direction)
	var velocity_change := current_velocity - _prev_velocity
	var forward_accel := 0.0
	if velocity_dir.length_squared() > 0.01 and delta > 0.0:
		forward_accel = velocity_change.dot(velocity_dir) / delta
	_prev_velocity = current_velocity

	# Smooth the acceleration heavily to avoid jitter
	var accel_smooth := 1.0 - exp(-5.0 * delta)
	_current_acceleration = lerpf(_current_acceleration, forward_accel, accel_smooth)

	# Convert to normalized factor: ~10 m/s² = full acceleration (1.0)
	# Clamp negative to -0.3 for slight backswing on deceleration
	_accel_factor = clampf(_current_acceleration / 10.0, -0.3, 1.0)


## Calculate effective stride length based on current speed.
## Interpolates between stride_length (at walk_speed) and max_stride_length (at run_speed).
func _get_effective_stride(speed: float) -> float:
	if speed <= walk_speed:
		return stride_length
	elif speed >= run_speed:
		return max_stride_length
	else:
		# Lerp between walk and run stride
		var t := (speed - walk_speed) / (run_speed - walk_speed)
		return lerpf(stride_length, max_stride_length, t)


## Calculate effective stance ratio based on current speed.
## Higher speeds = less time on ground (more airborne). Based on biomechanics research.
func _get_effective_stance_ratio(speed: float) -> float:
	if speed <= walk_speed:
		return stance_ratio
	elif speed >= run_speed:
		return min_stance_ratio
	else:
		var t := (speed - walk_speed) / (run_speed - walk_speed)
		return lerpf(stance_ratio, min_stance_ratio, t)


## Calculate effective step height based on current speed.
## Shuffling at slow speeds, full step height at run speed.
func _get_effective_step_height(speed: float) -> float:
	if speed <= idle_threshold:
		return min_step_height
	elif speed >= run_speed:
		return step_height
	else:
		var t := (speed - idle_threshold) / (run_speed - idle_threshold)
		# Use smoothstep for more natural transition
		t = t * t * (3.0 - 2.0 * t)
		return lerpf(min_step_height, step_height, t)


## Calculate foot pitch for heel-to-toe roll during stance phase.
## Returns pitch angle in radians based on stance progress (0-1).
func _get_stance_roll_pitch(stance_progress: float) -> float:
	if not heel_toe_roll_enabled:
		return 0.0

	# Stance phases:
	# 0.0-0.2: Heel strike (heel down, toe up)
	# 0.2-0.5: Foot flat (rolling through)
	# 0.5-1.0: Toe off (heel up, toe down)

	var heel_rad := deg_to_rad(heel_strike_angle)
	var toe_rad := deg_to_rad(toe_off_angle)

	if stance_progress < 0.2:
		# Heel strike phase - foot angled heel-down
		var t := stance_progress / 0.2
		return lerpf(heel_rad, 0.0, t * t)  # Ease out
	elif stance_progress < 0.5:
		# Foot flat phase
		return 0.0
	else:
		# Toe off phase - foot rolls to toe-down
		var t := (stance_progress - 0.5) / 0.5
		t = t * t  # Ease in for gradual push-off
		return lerpf(0.0, toe_rad, t)


## Returns current hip rock values for HipRockModifier to apply.
## This method is called by the SkeletonModifier3D that runs AFTER AnimationTree.
func get_hip_rock_values() -> Dictionary:
	return {
		"hip_rock": _current_hip_rock,
		"hip_motion_enabled": hip_motion_enabled,
		"shoulder_rotation_enabled": shoulder_rotation_enabled,
		"spine_twist_cascade": spine_twist_cascade,
		"shoulder_counter_rotation": shoulder_counter_rotation,
		"shoulder_twist": _current_shoulder_twist,
		"lean_angle": _current_lean_angle,
		"move_direction": _current_move_dir,
		# Head look data
		"head_target": _head_target_goal,
		"head_look_enabled": head_anticipation_enabled and _head_target_goal != Vector3.ZERO,
		"head_anticipation_speed": head_anticipation_speed,
	}


## Detect slope angle ahead of character for body lean.
## Returns slope angle in radians (positive = uphill, negative = downhill).
func _detect_slope(move_dir: Vector3) -> float:
	if _space_state == null or _visuals.controller == null:
		return 0.0

	if move_dir.length_squared() < 0.01:
		return 0.0

	var char_pos := _visuals.controller.global_position
	var ahead_pos := char_pos + move_dir.normalized() * slope_detect_distance

	# Raycast from above to below at position ahead
	var ray_start := ahead_pos + Vector3.UP * ray_height
	var ray_end := ahead_pos - Vector3.UP * ray_depth

	var query := PhysicsRayQueryParameters3D.create(ray_start, ray_end, ground_layers)
	var result := _space_state.intersect_ray(query)

	if result.is_empty():
		return 0.0

	_slope_normal = result.normal
	var ground_ahead: Vector3 = result.position

	# Also raycast at current position
	ray_start = char_pos + Vector3.UP * ray_height
	ray_end = char_pos - Vector3.UP * ray_depth
	query = PhysicsRayQueryParameters3D.create(ray_start, ray_end, ground_layers)
	result = _space_state.intersect_ray(query)

	if result.is_empty():
		return 0.0

	var ground_here: Vector3 = result.position

	# Calculate slope angle from height difference
	var height_diff := ground_ahead.y - ground_here.y
	var horizontal_dist := Vector2(ground_ahead.x - ground_here.x, ground_ahead.z - ground_here.z).length()

	if horizontal_dist < 0.01:
		return 0.0

	return atan2(height_diff, horizontal_dist)


## Update motion state machine for start/stop footwork.
## Returns current motion state: 0=idle, 1=starting, 2=walking, 3=stopping
func _update_motion_state(speed: float, delta: float) -> int:
	if not start_stop_enabled:
		# Simple state: idle or walking
		if speed > idle_threshold:
			return 2  # walking
		return 0  # idle

	var acceleration := (speed - _prev_speed) / delta if delta > 0 else 0.0

	match _motion_state:
		0:  # Idle
			if speed > idle_threshold:
				_motion_state = 1  # Start starting
				_start_timer = 0.0
		1:  # Starting
			_start_timer += delta
			if _start_timer > 0.3:  # Transition to walking after initial step
				_motion_state = 2
			elif speed <= idle_threshold:
				_motion_state = 0
		2:  # Walking
			if speed <= idle_threshold:
				_motion_state = 0
			elif acceleration < -stop_decel_threshold:
				_motion_state = 3  # Start stopping
				_stop_timer = 0.0
				_stop_foot_planted = false
		3:  # Stopping
			_stop_timer += delta
			if speed <= idle_threshold or _stop_timer > 0.5:
				_motion_state = 0
			elif speed > _prev_speed + 0.5:  # Accelerating again
				_motion_state = 2

	_prev_speed = speed
	return _motion_state


func _ready() -> void:
	_visuals = get_parent() as CharacterVisuals
	if _visuals == null:
		push_error("StrideWheelComponent: Parent must be a CharacterVisuals node.")
		return

	if config == null:
		config = StrideWheelConfig.new()
	_sync_from_config()

	_visuals.ready.connect(_setup, CONNECT_ONE_SHOT | CONNECT_DEFERRED)


func _exit_tree() -> void:
	_cleanup_debug()


func _setup() -> void:
	_skeleton = _visuals.skeleton
	if _skeleton == null:
		push_error("StrideWheelComponent: No skeleton found on CharacterVisuals.")
		return

	var skel_config := _visuals.skeleton_config
	if skel_config == null:
		skel_config = SkeletonConfig.new()

	_pelvis_idx = _skeleton.find_bone(skel_config.pelvis_bone)
	_spine_01_idx = _skeleton.find_bone(skel_config.spine_01)
	_spine_02_idx = _skeleton.find_bone(skel_config.spine_02)
	_spine_03_idx = _skeleton.find_bone(skel_config.spine_03)
	_left_foot_idx = _skeleton.find_bone(skel_config.left_foot)
	_right_foot_idx = _skeleton.find_bone(skel_config.right_foot)
	_left_upperarm_idx = _skeleton.find_bone(skel_config.left_upperarm)
	_right_upperarm_idx = _skeleton.find_bone(skel_config.right_upperarm)
	# Thigh bones for knee tracking
	_left_thigh_idx = _skeleton.find_bone(skel_config.left_thigh)
	_right_thigh_idx = _skeleton.find_bone(skel_config.right_thigh)

	# Calculate arm lengths (upperarm + forearm + hand)
	var left_lowerarm_idx := _skeleton.find_bone(&"lowerarm_l")
	var left_hand_idx := _skeleton.find_bone(&"hand_l")
	var right_lowerarm_idx := _skeleton.find_bone(&"lowerarm_r")
	var right_hand_idx := _skeleton.find_bone(&"hand_r")

	if _left_upperarm_idx != -1 and left_lowerarm_idx != -1 and left_hand_idx != -1:
		var upper_len := _skeleton.get_bone_rest(left_lowerarm_idx).origin.length()
		var lower_len := _skeleton.get_bone_rest(left_hand_idx).origin.length()
		_left_arm_length = upper_len + lower_len

	if _right_upperarm_idx != -1 and right_lowerarm_idx != -1 and right_hand_idx != -1:
		var upper_len := _skeleton.get_bone_rest(right_lowerarm_idx).origin.length()
		var lower_len := _skeleton.get_bone_rest(right_hand_idx).origin.length()
		_right_arm_length = upper_len + lower_len

	# Calculate leg lengths (thigh + calf) for soft IK
	var left_calf_idx := _skeleton.find_bone(skel_config.left_calf)
	var right_calf_idx := _skeleton.find_bone(skel_config.right_calf)

	if _left_thigh_idx != -1 and left_calf_idx != -1 and _left_foot_idx != -1:
		var thigh_len := _skeleton.get_bone_rest(left_calf_idx).origin.length()
		var calf_len := _skeleton.get_bone_rest(_left_foot_idx).origin.length()
		_left_leg_length = thigh_len + calf_len

	if _right_thigh_idx != -1 and right_calf_idx != -1 and _right_foot_idx != -1:
		var thigh_len := _skeleton.get_bone_rest(right_calf_idx).origin.length()
		var calf_len := _skeleton.get_bone_rest(_right_foot_idx).origin.length()
		_right_leg_length = thigh_len + calf_len

	if _pelvis_idx == -1:
		push_warning("StrideWheelComponent: Pelvis bone '%s' not found." % skel_config.pelvis_bone)
	if _spine_01_idx == -1:
		push_warning("StrideWheelComponent: Spine_01 bone '%s' not found." % skel_config.spine_01)
	if _left_foot_idx == -1:
		push_warning("StrideWheelComponent: Left foot bone '%s' not found." % skel_config.left_foot)
	if _right_foot_idx == -1:
		push_warning("StrideWheelComponent: Right foot bone '%s' not found." % skel_config.right_foot)

	# Cache pelvis rest pose
	if _pelvis_idx != -1:
		_pelvis_rest_basis = _skeleton.get_bone_rest(_pelvis_idx).basis
		_current_pelvis_basis = _pelvis_rest_basis

	# Cache spine rest poses (for cascading counter-rotation)
	if _spine_01_idx != -1:
		_spine_01_rest_basis = _skeleton.get_bone_rest(_spine_01_idx).basis
		_current_spine_01_basis = _spine_01_rest_basis
	if _spine_02_idx != -1:
		_spine_02_rest_basis = _skeleton.get_bone_rest(_spine_02_idx).basis
		_current_spine_02_basis = _spine_02_rest_basis
	if _spine_03_idx != -1:
		_spine_03_rest_basis = _skeleton.get_bone_rest(_spine_03_idx).basis
		_current_spine_03_basis = _spine_03_rest_basis

	# Print bone axis reference if debug enabled
	if debug_bone_axes:
		_print_bone_axes()

	# Resolve IK solver nodes
	if not left_leg_ik.is_empty():
		_left_ik = get_node_or_null(left_leg_ik)
	if not right_leg_ik.is_empty():
		_right_ik = get_node_or_null(right_leg_ik)

	# Resolve target Marker3Ds
	if not left_foot_target.is_empty():
		_left_target = get_node_or_null(left_foot_target) as Marker3D
	if not right_foot_target.is_empty():
		_right_target = get_node_or_null(right_foot_target) as Marker3D

	# Resolve arm targets (optional - for arm swing)
	if not left_hand_target.is_empty():
		_left_hand = get_node_or_null(left_hand_target) as Marker3D
		if _left_hand:
			_left_hand_rest = _left_hand.position  # Local position in parent
	if not right_hand_target.is_empty():
		_right_hand = get_node_or_null(right_hand_target) as Marker3D
		if _right_hand:
			_right_hand_rest = _right_hand.position

	# Resolve head target (optional - for head look-at to follow cursor)
	if not head_target.is_empty():
		_head_target = get_node_or_null(head_target) as Marker3D

	# Resolve head look modifier (optional - for controlling influence)
	if not head_look_modifier.is_empty():
		_head_look_mod = get_node_or_null(head_look_modifier) as LookAtModifier3D

	# Resolve knee pole targets (optional - for knee direction tracking)
	if not left_knee_target.is_empty():
		_left_knee = get_node_or_null(left_knee_target) as Marker3D
		if _left_knee:
			_left_knee_rest = _left_knee.position  # Local position in parent
	if not right_knee_target.is_empty():
		_right_knee = get_node_or_null(right_knee_target) as Marker3D
		if _right_knee:
			_right_knee_rest = _right_knee.position

	# Capture foot bone rest orientations (before any IK modifies them)
	# This preserves the skeleton's intended foot direction
	_initial_char_yaw = _visuals.global_rotation.y
	if _left_foot_idx != -1:
		var left_bone_pose := _skeleton.get_bone_global_pose(_left_foot_idx)
		_left_foot_rest_basis = (_skeleton.global_transform * Transform3D(left_bone_pose)).basis
	if _right_foot_idx != -1:
		var right_bone_pose := _skeleton.get_bone_global_pose(_right_foot_idx)
		_right_foot_rest_basis = (_skeleton.global_transform * Transform3D(right_bone_pose)).basis

	# Initialize plant positions using raycasted ground positions
	# This ensures hip_offset creates proper knee bend from the start
	if _left_foot_idx != -1:
		var left_bone_pos := _get_bone_world_position(_left_foot_idx)
		_left_plant_pos = _raycast_ground(left_bone_pos, true, true)
	if _right_foot_idx != -1:
		var right_bone_pos := _get_bone_world_position(_right_foot_idx)
		_right_plant_pos = _raycast_ground(right_bone_pos, true, false)

	# Initialize plant yaw to current facing
	var initial_yaw := _visuals.global_rotation.y
	_left_plant_yaw = initial_yaw
	_right_plant_yaw = initial_yaw

	# Initialize yaw tracking for turn-in-place
	_prev_yaw = initial_yaw

	# Find feet_xform modifier (used for turn-in-place, disabled during walking)
	_feet_xform = _skeleton.get_node_or_null("feet_xform")

	# Setup rotation modifiers to copy Marker3D rotation to foot bones
	_setup_foot_rotation_modifiers(skel_config)

	# Setup debug visualization
	_setup_debug()


## Setup foot rotation - apply rotation directly to bones after IK runs.
func _setup_foot_rotation_modifiers(_skel_config: SkeletonConfig) -> void:
	if _skeleton and not _skeleton.skeleton_updated.is_connected(_apply_foot_bone_rotations):
		_skeleton.skeleton_updated.connect(_apply_foot_bone_rotations)


## Apply foot bone rotations directly after IK has run.
## This ensures our rotation takes effect after TwoBoneIK3D positions the legs.
func _apply_foot_bone_rotations() -> void:
	if _skeleton == null:
		return
	if _current_influence < 0.01:
		return
	# Skip rotation when not walking - keep feet locked during idle/turn
	if not _is_walking:
		return

	# Apply left foot rotation from Marker3D
	if _left_target and _left_foot_idx != -1:
		var target_basis := _left_target.global_transform.basis
		# Convert world basis to bone-local basis
		var parent_idx := _skeleton.get_bone_parent(_left_foot_idx)
		var parent_global: Transform3D
		if parent_idx != -1:
			parent_global = _skeleton.global_transform * Transform3D(_skeleton.get_bone_global_pose(parent_idx))
		else:
			parent_global = _skeleton.global_transform
		var local_basis := parent_global.basis.inverse() * target_basis
		# Blend with influence
		var current_pose := _skeleton.get_bone_pose(_left_foot_idx)
		var blended_basis := current_pose.basis.slerp(local_basis, _current_influence)
		_skeleton.set_bone_pose_rotation(_left_foot_idx, blended_basis.get_rotation_quaternion())

	# Apply right foot rotation from Marker3D
	if _right_target and _right_foot_idx != -1:
		var target_basis := _right_target.global_transform.basis
		var parent_idx := _skeleton.get_bone_parent(_right_foot_idx)
		var parent_global: Transform3D
		if parent_idx != -1:
			parent_global = _skeleton.global_transform * Transform3D(_skeleton.get_bone_global_pose(parent_idx))
		else:
			parent_global = _skeleton.global_transform
		var local_basis := parent_global.basis.inverse() * target_basis
		var current_pose := _skeleton.get_bone_pose(_right_foot_idx)
		var blended_basis := current_pose.basis.slerp(local_basis, _current_influence)
		_skeleton.set_bone_pose_rotation(_right_foot_idx, blended_basis.get_rotation_quaternion())


## Update head target marker to follow cursor and movement direction (for LookAtModifier3D).
## Priority: Active cursor tracking > Movement direction anticipation > Forward look
func _update_head_target(delta: float) -> void:
	if _head_target == null:
		return
	if _visuals.controller == null:
		return

	# Get the character body (RenegadeCharacter) and its controller
	var char_body := _visuals.controller as RenegadeCharacter
	if char_body == null or char_body.controller == null:
		return

	var head_pos := _visuals.global_position + Vector3.UP * 1.6  # Approximate head height
	var forward := -_visuals.global_basis.z
	var default_look := head_pos + forward * head_look_distance  # Default: look ahead

	# Calculate yaw delta for turn detection (used by both turn anticipation and cursor tracking)
	var current_yaw := _visuals.global_rotation.y
	_head_yaw_delta = angle_difference(_prev_yaw_for_head, current_yaw)
	_prev_yaw_for_head = current_yaw

	# === MOVEMENT DIRECTION ANTICIPATION ===
	var movement_goal := default_look
	var is_moving := false

	if head_anticipation_enabled:
		# Get INPUT direction from character (where player WANTS to go)
		# This is key for anticipation - input leads velocity
		var input_dir := Vector3.ZERO
		if char_body.move_direction.length_squared() > 0.01:
			input_dir = char_body.move_direction.normalized()
			input_dir.y = 0.0

		var velocity := _visuals.get_velocity()
		var horizontal_vel := Vector3(velocity.x, 0.0, velocity.z)
		var speed := horizontal_vel.length()

		# Use input direction for head look (anticipation), velocity for speed check
		var has_input := input_dir.length_squared() > 0.01

		if has_input or speed > idle_threshold:
			is_moving = true

			# Head looks DIRECTLY toward INPUT direction (no blending, no extra smoothing)
			# This is key for anticipation - head must respond instantly to input
			var look_target_dir := input_dir if has_input else horizontal_vel.normalized()

			# Look distance scales with speed
			var speed_factor := clampf(speed / run_speed, 0.5, 1.5)
			var look_dist := head_look_distance * speed_factor

			# Movement goal: look directly in input direction (single smooth on final target only)
			movement_goal = head_pos + look_target_dir * look_dist

		# === TURN ANTICIPATION ===
		# If turning significantly and not moving much, anticipate the turn
		if absf(_head_yaw_delta) > 0.01 and speed < walk_speed * 0.5:
			# Turn direction: positive = turning right, negative = turning left
			var turn_rate := _head_yaw_delta / delta if delta > 0 else 0.0
			# Anticipate by looking slightly in the turn direction
			var right_vec: Vector3 = -forward.cross(Vector3.UP)
			var turn_offset: Vector3 = right_vec * sign(turn_rate) * head_turn_anticipation * 2.0
			movement_goal = head_pos + (forward + turn_offset).normalized() * head_look_distance

	# === CURSOR TRACKING ===
	var cursor_goal := default_look
	var cursor_is_valid := false
	var cursor_is_active := false  # Actively being moved

	# Detect if character is turning (cursor world pos changes without mouse movement)
	var is_turning := absf(_head_yaw_delta) > 0.005

	if char_body.controller.has_aim_target():
		var cursor_pos := char_body.controller.get_aim_target()

		# Check if cursor is behind the player (more than 90 degrees from forward)
		var to_cursor := (cursor_pos - head_pos).normalized()
		to_cursor.y = 0.0  # Ignore vertical component for angle check
		if to_cursor.length_squared() > 0.001:
			to_cursor = to_cursor.normalized()
			var forward_flat := forward
			forward_flat.y = 0.0
			forward_flat = forward_flat.normalized()

			var dot := forward_flat.dot(to_cursor)
			if dot >= 0.0:  # Cursor is in front of player
				cursor_goal = cursor_pos
				cursor_is_valid = true

				# Check if cursor has moved (only when NOT turning - turning moves cursor without mouse input)
				if _last_cursor_pos != Vector3.ZERO and not is_turning:
					var cursor_moved := cursor_pos.distance_squared_to(_last_cursor_pos) > 0.01  # ~0.1m movement
					if cursor_moved:
						_cursor_idle_time = 0.0
						_cursor_has_moved = true  # Mark that user has actually moved cursor
						_head_is_idle = false
						cursor_is_active = true
					else:
						_cursor_idle_time += delta
				elif not is_turning:
					_cursor_idle_time += delta
				_last_cursor_pos = cursor_pos

	# === DETERMINE FINAL GOAL ===
	# Priority: Aiming > Cursor moving > Movement direction > Idle
	var goal := default_look
	var smooth_speed := head_return_speed

	# Check if player is actively aiming (holding right click)
	var is_aiming := char_body.is_aiming

	# Cursor is "active" if moved this frame OR within the idle timeout period
	var cursor_actively_moving := cursor_is_active or (cursor_is_valid and _cursor_has_moved and _cursor_idle_time < head_idle_timeout)

	if is_aiming and cursor_is_valid:
		# AIMING (right click held) - always look at cursor
		goal = cursor_goal
		smooth_speed = head_track_speed
		_head_is_idle = false
	elif cursor_actively_moving:
		# Cursor is being moved - look at cursor (even while walking)
		goal = cursor_goal
		smooth_speed = head_track_speed
		_head_is_idle = false
	elif is_moving and head_anticipation_enabled:
		# Moving (cursor not active) - look in direction of travel
		# But if cursor was recently used, transition slowly using head_return_speed
		if cursor_is_valid and _cursor_has_moved:
			goal = movement_goal
			smooth_speed = head_return_speed  # Slow transition from cursor to movement
		else:
			goal = movement_goal
			smooth_speed = head_anticipation_speed
		_head_is_idle = false
	else:
		# Idle - return to forward look
		_head_is_idle = true

	# Initialize goal position if not set
	if _head_target_goal == Vector3.ZERO:
		_head_target_goal = goal

	# Smoothly lerp toward goal (frame-rate independent)
	_head_target_goal = _head_target_goal.lerp(goal, 1.0 - exp(-smooth_speed * delta))
	_head_target.global_position = _head_target_goal

	# Keep LookAtModifier3D influence at 1.0 - the marker position handles smooth transitions
	if _head_look_mod != null:
		_head_look_mod.influence = 1.0


func _physics_process(delta: float) -> void:
	if _skeleton == null:
		return
	if _left_foot_idx == -1 or _right_foot_idx == -1:
		return

	_space_state = _skeleton.get_world_3d().direct_space_state
	if _space_state == null:
		return

	# Update head target to follow cursor (for LookAtModifier3D)
	_update_head_target(delta)

	var velocity := _visuals.get_velocity()
	var horizontal_vel := Vector3(velocity.x, 0.0, velocity.z)
	var speed := horizontal_vel.length()
	var is_moving: bool = speed > idle_threshold
	var move_dir: Vector3 = horizontal_vel.normalized() if is_moving else Vector3.ZERO

	# Update acceleration factor early - used by hip, arm, and shoulder systems
	_update_acceleration(delta)

	# Smooth move direction to prevent snap when stopping
	var dir_smooth := 1.0 - exp(-3.0 * delta)
	_current_move_dir = _current_move_dir.lerp(move_dir, dir_smooth)

	# Update influence
	_update_influence(delta, is_moving)

	# Update motion state machine (start/stop footwork)
	_update_motion_state(speed, delta)

	# Smooth knee direction toward movement (for knee pole tracking)
	if move_dir.length_squared() > 0.01:
		var knee_smooth := 1.0 - exp(-knee_smooth_speed * delta)
		_current_knee_direction = _current_knee_direction.lerp(move_dir.normalized(), knee_smooth)
		_current_knee_direction = _current_knee_direction.normalized()

	# Cache rest positions (skeleton bind pose in world)
	_left_rest_pos = _get_bone_world_position(_left_foot_idx)
	_right_rest_pos = _get_bone_world_position(_right_foot_idx)

	# Store for debug
	var char_pos := _visuals.controller.global_position if _visuals.controller else Vector3.ZERO
	_debug_move_dir_vec = move_dir

	if is_moving:
		# Walking mode - disable feet_xform so code handles rotation
		_is_walking = true
		_is_turning_in_place = false
		if _feet_xform:
			_feet_xform.active = false

		# Track yaw so _prev_yaw is up-to-date when we stop
		_prev_yaw = _visuals.global_rotation.y

		# Calculate effective stride based on speed (longer strides at higher speeds)
		var effective_stride := _get_effective_stride(speed)

		# Advance phase - use effective stride so faster = longer steps, not more steps
		var phase_speed := (speed / effective_stride) * PI
		# Boost phase speed during starting state for snappier first step
		if _motion_state == 1 and start_stop_enabled:
			phase_speed *= start_acceleration
		_phase += phase_speed * delta
		_phase = fmod(_phase, TAU)

		# Compute per-foot cycle values (0–1)
		var left_cycle := fmod(_phase / TAU, 1.0)
		var right_cycle := fmod((_phase + PI) / TAU, 1.0)

		# IMPORTANT: Update plant positions BEFORE processing feet
		# This prevents one-frame delay when foot plants at new position
		# Also update ground normal and yaw here since foot is planting
		var current_yaw := _visuals.global_rotation.y
		if _crossed_threshold(left_cycle, _left_prev_cycle, 0.0):
			_left_plant_pos = _predict_plant_position(move_dir, speed, -1.0)
			_left_plant_yaw = current_yaw
			# Raycast again with normal update to capture the planted ground normal
			_raycast_ground(_left_plant_pos, true, true)
		if _crossed_threshold(right_cycle, _right_prev_cycle, 0.0):
			_right_plant_pos = _predict_plant_position(move_dir, speed, 1.0)
			_right_plant_yaw = current_yaw
			# Raycast again with normal update to capture the planted ground normal
			_raycast_ground(_right_plant_pos, true, false)

		# Update debug predicted positions (always, not just on threshold)
		_debug_left_predicted_pos = _predict_plant_position(move_dir, speed, -1.0)
		_debug_right_predicted_pos = _predict_plant_position(move_dir, speed, 1.0)

		# Safety: clamp plant distance before processing
		_left_plant_pos = _clamp_plant_distance(_left_plant_pos, effective_stride * max_leg_reach)
		_right_plant_pos = _clamp_plant_distance(_right_plant_pos, effective_stride * max_leg_reach)

		# Process each foot with updated plant positions
		var left_pos := _process_foot(
			left_cycle, _left_prev_cycle,
			_left_plant_pos, _left_rest_pos,
			move_dir, speed, -1.0, delta  # left side
		)
		var right_pos := _process_foot(
			right_cycle, _right_prev_cycle,
			_right_plant_pos, _right_rest_pos,
			move_dir, speed, 1.0, delta  # right side
		)

		_left_prev_cycle = left_cycle
		_right_prev_cycle = right_cycle

		# Apply positions to targets
		# Planted foot: use stored yaw + ground normal (locked)
		# Swinging foot: use current yaw + pitch, no ground normal
		var left_yaw := _left_plant_yaw if _left_swing_t == 0.0 else current_yaw
		var right_yaw := _right_plant_yaw if _right_swing_t == 0.0 else current_yaw
		var left_normal := _left_ground_normal if _left_swing_t == 0.0 else Vector3.UP
		var right_normal := _right_ground_normal if _right_swing_t == 0.0 else Vector3.UP
		_apply_foot_target(_left_target, left_pos, left_yaw, left_normal, _left_foot_rest_basis, _left_swing_t, delta, true)
		_apply_foot_target(_right_target, right_pos, right_yaw, right_normal, _right_foot_rest_basis, _right_swing_t, delta, true)

		# Hip adjustment for natural knee bend:
		# 1. Bob: vertical oscillation during gait cycle (scaled by acceleration)
		# 2. Extension drop: hip lowers when legs are spread apart (Pythagorean theorem)
		# Acceleration scaling: more vigorous bob when accelerating into movement
		var accel_bob_scale := 1.0 + maxf(0.0, _accel_factor) * 0.5
		var hip_bob: float = -absf(sin(_phase)) * hip_bob_amount * accel_bob_scale

		# Calculate leg extension drop - when feet are spread apart, hip must drop
		# to maintain contact (otherwise legs would need to stretch)
		var foot_spread := left_pos.distance_to(right_pos)
		var max_spread := effective_stride * 1.2  # Maximum expected spread
		var spread_factor := clampf(foot_spread / max_spread, 0.0, 1.0)
		# Drop more when legs are spread (quadratic for more natural feel)
		var extension_drop := -spread_factor * spread_factor * step_height * 0.5

		# Hip rock: tilts toward stance leg (away from swing leg)
		# sin(_phase) gives smooth oscillation synced to gait
		# Y-axis (twist) scales with acceleration for more dynamic hip drive
		var phase_sin := sin(_phase)
		var accel_rock_scale := 1.0 + maxf(0.0, _accel_factor) * 0.5
		var hip_rock := Vector3(
			phase_sin * hip_rock_x,
			phase_sin * hip_rock_y * accel_rock_scale,  # Acceleration-scaled twist
			phase_sin * hip_rock_z
		)

		# Shoulder twist: follows stride phase with its own amplitude (opposite to hip twist)
		# Scales with acceleration for more vigorous arm/shoulder pump when starting
		var accel_shoulder_scale := 1.0 + maxf(0.0, _accel_factor) * 0.5
		var shoulder_twist := phase_sin * shoulder_rotation_amount * accel_shoulder_scale

		_update_hip(delta, hip_bob + extension_drop, hip_rock, move_dir, shoulder_twist)

		# Arm swing (counter-phase to legs)
		_update_arm_swing(delta, speed, move_dir, true)

		# Knee pole tracking (knees point toward movement)
		_update_knee_poles(delta, move_dir, true)
	else:
		# Idle mode - enable feet_xform so feet stay locked
		_is_walking = false
		if _feet_xform:
			_feet_xform.active = true
		_process_idle_or_turn(delta)

		# Blend arms back to rest
		_update_arm_swing(delta, 0.0, Vector3.ZERO, false)

		# Blend knee poles back to rest
		_update_knee_poles(delta, Vector3.ZERO, false)

	_apply_influence()

	# Track movement state for next frame transition detection
	_was_moving = is_moving

	# Update debug visualization
	_update_debug(char_pos, move_dir)


## Handle idle state with turn-in-place detection and foot stepping.
func _process_idle_or_turn(delta: float) -> void:
	_prev_yaw = _visuals.global_rotation.y

	# Calculate where feet SHOULD be based on current facing
	var left_target_pos := _calculate_ideal_foot_position(-1.0)
	var right_target_pos := _calculate_ideal_foot_position(1.0)

	# If we just stopped moving, update plant positions to where feet currently are
	# This prevents snapping back to old plant positions when stopping mid-swing
	if _was_moving:
		_left_plant_pos = _left_current_pos
		_right_plant_pos = _right_current_pos
		_left_plant_yaw = _visuals.global_rotation.y
		_right_plant_yaw = _visuals.global_rotation.y
		# Reset swing state
		_left_swing_t = 0.0
		_right_swing_t = 0.0
		# Immediately check for criss-cross on stop - don't lock feet in crossed position
		_clamp_feet_no_crossover(left_target_pos, right_target_pos)

	# Prevent criss-cross: snap feet if they cross sides (only when NOT actively stepping)
	if not _is_turning_in_place:
		_clamp_feet_no_crossover(left_target_pos, right_target_pos)

	# Process ongoing step
	if _is_turning_in_place:
		_process_turn_step(delta, left_target_pos, right_target_pos)
	else:
		# Check if either foot has drifted too far from ideal position
		var left_drift := _horizontal_distance(_left_plant_pos, left_target_pos)
		var right_drift := _horizontal_distance(_right_plant_pos, right_target_pos)
		var threshold := stride_length * turn_drift_threshold

		# Also check rotation angle - force step if body rotated too far from planted feet
		var current_yaw := _visuals.global_rotation.y
		var left_yaw_delta := absf(angle_difference(current_yaw, _left_plant_yaw))
		var right_yaw_delta := absf(angle_difference(current_yaw, _right_plant_yaw))
		var max_yaw_delta := maxf(left_yaw_delta, right_yaw_delta)
		var angle_threshold := deg_to_rad(max_turn_angle)
		var angle_exceeded := max_yaw_delta > angle_threshold

		if turn_in_place_enabled and (left_drift > threshold or right_drift > threshold or angle_exceeded):
			_start_turn_step(left_target_pos, right_target_pos, left_drift, right_drift)
		else:
			# Feet stay planted at current world positions with stored yaw - NO swing pitch
			# When turn-in-place is disabled, use ideal positions so hip_offset creates knee bend
			var use_left_pos := left_target_pos if not turn_in_place_enabled else _left_plant_pos
			var use_right_pos := right_target_pos if not turn_in_place_enabled else _right_plant_pos
			_apply_foot_target(_left_target, use_left_pos, _left_plant_yaw, _left_ground_normal, _left_foot_rest_basis, 0.0, delta, false)
			_apply_foot_target(_right_target, use_right_pos, _right_plant_yaw, _right_ground_normal, _right_foot_rest_basis, 0.0, delta, false)
			_update_hip(delta, 0.0)

	# Reset phase so next move starts cleanly
	_phase = 0.0
	_left_prev_cycle = 0.0
	_right_prev_cycle = 0.5


## Calculate ideal foot position based on character position and facing.
## side: -1.0 for left foot, +1.0 for right foot
func _calculate_ideal_foot_position(side: float) -> Vector3:
	if _visuals.controller == null:
		return Vector3.ZERO

	var char_pos := _visuals.controller.global_position
	var facing := _visuals.global_basis

	# Lateral offset perpendicular to facing direction
	var lateral: Vector3 = facing.x * side * foot_lateral_offset

	# Forward/back stagger: left foot forward, right foot back
	var forward: Vector3 = -facing.z * side * stance_stagger

	var target_pos: Vector3 = char_pos + lateral + forward
	# Don't update ground normal during ideal position calculation - it's done when foot plants
	return _raycast_ground(target_pos, false, side < 0)


## Horizontal distance between two points (ignoring Y).
func _horizontal_distance(a: Vector3, b: Vector3) -> float:
	var diff := a - b
	diff.y = 0.0
	return diff.length()


## Prevent feet from crossing to the wrong side. Called every frame during idle/turn.
## Snaps feet back to their targets if they've crossed to the opposite side.
func _clamp_feet_no_crossover(left_target: Vector3, right_target: Vector3) -> void:
	if _visuals.controller == null:
		return

	var char_right := _visuals.global_basis.x
	var char_pos := _visuals.controller.global_position
	var current_yaw := _visuals.global_rotation.y

	# Check current plant positions
	var left_offset := _left_plant_pos - char_pos
	var right_offset := _right_plant_pos - char_pos
	var left_lateral := left_offset.dot(char_right)   # Should be negative (left side)
	var right_lateral := right_offset.dot(char_right) # Should be positive (right side)

	# Minimum lateral distance from centerline (slightly inside normal stance)
	var min_lateral := foot_lateral_offset * 0.3

	# If left foot crossed to right side, snap it back
	if left_lateral > -min_lateral:
		_left_plant_pos = left_target
		_left_plant_yaw = current_yaw
		_raycast_ground(_left_plant_pos, true, true)

	# If right foot crossed to left side, snap it back
	if right_lateral < min_lateral:
		_right_plant_pos = right_target
		_right_plant_yaw = current_yaw
		_raycast_ground(_right_plant_pos, true, false)

	# Also check if feet are too close to each other (nearly overlapping)
	var foot_dist := _horizontal_distance(_left_plant_pos, _right_plant_pos)
	var min_foot_dist := foot_lateral_offset * 1.5  # At least 1.5x lateral offset apart
	if foot_dist < min_foot_dist:
		# Snap both feet to their targets
		_left_plant_pos = left_target
		_right_plant_pos = right_target
		_left_plant_yaw = current_yaw
		_right_plant_yaw = current_yaw
		_raycast_ground(_left_plant_pos, true, true)
		_raycast_ground(_right_plant_pos, true, false)


## Start a turn-in-place step.
func _start_turn_step(left_target: Vector3, right_target: Vector3, left_drift: float, right_drift: float) -> void:
	_is_turning_in_place = true
	_turn_step_progress = 0.0

	# Step the foot that's furthest from its target
	_stepping_foot = 0 if left_drift >= right_drift else 1

	# Set up step start/end positions
	_left_step_start = _left_plant_pos
	_left_step_end = left_target
	_right_step_start = _right_plant_pos
	_right_step_end = right_target


## Process ongoing turn-in-place step animation.
func _process_turn_step(delta: float, left_target: Vector3, right_target: Vector3) -> void:
	# Advance step progress
	_turn_step_progress += turn_step_speed * delta

	# Update targets in case character is still rotating
	_left_step_end = left_target
	_right_step_end = right_target

	# Get current yaw for stepping foot target
	var current_yaw := _visuals.global_rotation.y

	# Priority check: if the OTHER foot is now drifting more, switch to it immediately
	var left_drift := _horizontal_distance(_left_plant_pos, left_target)
	var right_drift := _horizontal_distance(_right_plant_pos, right_target)
	var stepping_drift := left_drift if _stepping_foot == 0 else right_drift
	var other_drift := right_drift if _stepping_foot == 0 else left_drift

	if other_drift > stepping_drift * 1.3 and _turn_step_progress < 0.7:
		# Other foot is significantly more out of place - switch to it
		if _stepping_foot == 0:
			_left_plant_pos = _left_step_end
			_left_plant_yaw = current_yaw
		else:
			_right_plant_pos = _right_step_end
			_right_plant_yaw = current_yaw
		_stepping_foot = 1 if _stepping_foot == 0 else 0
		_turn_step_progress = 0.0
		if _stepping_foot == 0:
			_left_step_start = _left_plant_pos
		else:
			_right_step_start = _right_plant_pos

	# Hard clamp: if legs are spread too far, snap the trailing foot immediately
	var foot_spread := _horizontal_distance(_left_plant_pos, _right_plant_pos)
	var max_spread := stride_length * max_leg_reach * 0.6  # Tighter limit for turn
	if foot_spread > max_spread:
		# Snap the non-stepping foot to its target immediately
		if _stepping_foot == 0:
			_right_plant_pos = right_target
			_right_plant_yaw = current_yaw
		else:
			_left_plant_pos = left_target
			_left_plant_yaw = current_yaw

	# Check if other foot needs to catch up early (at 30% through first step)
	if _turn_step_progress >= 0.3 and _turn_step_progress < 1.0:
		var other_foot := 1 if _stepping_foot == 0 else 0
		# Recompute drift (positions may have changed from snapping above)
		left_drift = _horizontal_distance(_left_plant_pos, left_target)
		right_drift = _horizontal_distance(_right_plant_pos, right_target)
		other_drift = right_drift if other_foot == 1 else left_drift
		var threshold := stride_length * turn_drift_threshold

		# If other foot is drifting too far, switch to it now (aggressive - same threshold)
		if other_drift > threshold:
			# Complete current step early
			if _stepping_foot == 0:
				_left_plant_pos = _left_step_end
				_left_plant_yaw = current_yaw
			else:
				_right_plant_pos = _right_step_end
				_right_plant_yaw = current_yaw
			# Start other foot
			_stepping_foot = other_foot
			_turn_step_progress = 0.0
			if _stepping_foot == 0:
				_left_step_start = _left_plant_pos
			else:
				_right_step_start = _right_plant_pos

	if _turn_step_progress >= 1.0:
		# First foot step complete — update plant position AND yaw
		if _stepping_foot == 0:
			_left_plant_pos = _left_step_end
			_left_plant_yaw = current_yaw
			# Update ground normal for planted foot
			_raycast_ground(_left_plant_pos, true, true)
		else:
			_right_plant_pos = _right_step_end
			_right_plant_yaw = current_yaw
			# Update ground normal for planted foot
			_raycast_ground(_right_plant_pos, true, false)

		# Check if other foot needs to step
		left_drift = _horizontal_distance(_left_plant_pos, left_target)
		right_drift = _horizontal_distance(_right_plant_pos, right_target)
		var threshold := stride_length * turn_drift_threshold

		var other_foot := 1 if _stepping_foot == 0 else 0
		other_drift = right_drift if other_foot == 1 else left_drift

		if other_drift > threshold:
			# Other foot needs to step
			_stepping_foot = other_foot
			_turn_step_progress = 0.0
			if _stepping_foot == 0:
				_left_step_start = _left_plant_pos
			else:
				_right_step_start = _right_plant_pos
		else:
			# Turn complete - update planted yaw to current facing
			_is_turning_in_place = false
			_left_plant_pos = _left_step_end
			_right_plant_pos = _right_step_end
			var final_yaw := _visuals.global_rotation.y
			_left_plant_yaw = final_yaw
			_right_plant_yaw = final_yaw
			# Update ground normals for both planted feet
			_raycast_ground(_left_plant_pos, true, true)
			_raycast_ground(_right_plant_pos, true, false)

		_apply_foot_target(_left_target, _left_plant_pos, _left_plant_yaw, _left_ground_normal, _left_foot_rest_basis, 0.0, delta, false)
		_apply_foot_target(_right_target, _right_plant_pos, _right_plant_yaw, _right_ground_normal, _right_foot_rest_basis, 0.0, delta, false)
		_update_hip(delta, 0.0)
		return

	# Animate the stepping foot
	var current_progress: float = _turn_step_progress
	var arc_height: float = step_height * turn_step_height_mult * sin(current_progress * PI)
	# Weight shift: planted foot lowers slightly, bending that knee via IK
	var plant_dip: float = -turn_crouch_amount * sin(current_progress * PI)
	var target_yaw := _visuals.global_rotation.y

	var left_pos: Vector3
	var right_pos: Vector3
	var left_yaw: float
	var right_yaw: float

	var left_swing_t: float = 0.0
	var right_swing_t: float = 0.0

	if _stepping_foot == 0:
		# Left is stepping — interpolate toward target yaw
		left_pos = _left_step_start.lerp(_left_step_end, current_progress)
		left_pos.y += arc_height
		left_yaw = lerp_angle(_left_plant_yaw, target_yaw, current_progress)
		left_swing_t = current_progress  # Foot is in swing
		# Right stays planted — lower it to bend knee (weight shift)
		right_pos = _right_plant_pos
		right_pos.y += plant_dip
		right_yaw = _right_plant_yaw
	else:
		# Right is stepping — interpolate toward target yaw
		right_pos = _right_step_start.lerp(_right_step_end, current_progress)
		right_pos.y += arc_height
		right_yaw = lerp_angle(_right_plant_yaw, target_yaw, current_progress)
		right_swing_t = current_progress  # Foot is in swing
		# Left stays planted — lower it to bend knee (weight shift)
		left_pos = _left_plant_pos
		left_pos.y += plant_dip
		left_yaw = _left_plant_yaw

	_apply_foot_target(_left_target, left_pos, left_yaw, _left_ground_normal, _left_foot_rest_basis, left_swing_t, delta, false)
	_apply_foot_target(_right_target, right_pos, right_yaw, _right_ground_normal, _right_foot_rest_basis, right_swing_t, delta, false)

	# Hip follows lowest foot
	_update_hip(delta, 0.0)


## Process one foot's position for the current cycle value.
func _process_foot(
	cycle: float, prev_cycle: float,
	plant_pos: Vector3, rest_pos: Vector3,
	move_dir: Vector3, speed: float, side: float, delta: float
) -> Vector3:
	# Dynamic stance ratio - feet spend less time on ground at higher speeds
	var effective_stance := _get_effective_stance_ratio(speed)

	if cycle < effective_stance:
		# Plant phase — foot stays at planted world position
		# Track stance progress for heel-to-toe roll (0-1 within stance)
		var stance_progress := cycle / effective_stance
		if side < 0:
			_left_swing_target = plant_pos
			_left_swing_t = 0.0
			_left_stance_progress = stance_progress
		else:
			_right_swing_target = plant_pos
			_right_swing_t = 0.0
			_right_stance_progress = stance_progress
		return plant_pos
	else:
		# Swing phase — arc from plant position toward next predicted plant
		var swing_t := (cycle - effective_stance) / (1.0 - effective_stance)  # 0–1 within swing

		# Store swing progress for foot rotation
		if side < 0:
			_left_swing_t = swing_t
		else:
			_right_swing_t = swing_t

		# Smoothstep for horizontal movement (ease-in lift, ease-out land)
		var eased_t := swing_t * swing_t * (3.0 - 2.0 * swing_t)

		# Target is recalculated each frame to track character movement
		var raw_target := _predict_plant_position(move_dir, speed, side)

		# Smooth the swing target (prevents snappy prediction changes)
		var target_smooth := 1.0 - exp(-8.0 * delta)
		var swing_target: Vector3
		if side < 0:
			# Just started swing - snap to target
			if prev_cycle < effective_stance:
				_left_swing_target = raw_target
			else:
				_left_swing_target = _left_swing_target.lerp(raw_target, target_smooth)
			swing_target = _left_swing_target
		else:
			if prev_cycle < effective_stance:
				_right_swing_target = raw_target
			else:
				_right_swing_target = _right_swing_target.lerp(raw_target, target_smooth)
			swing_target = _right_swing_target

		# Swing from where we lifted (plant_pos) to where we're landing (smoothed target)
		var ground_pos := plant_pos.lerp(swing_target, eased_t)

		# Arc height - quick lift, soft landing
		# pow(t, 0.6) lifts faster at start, settles slower at end
		# Step height scales with speed (shuffling at slow speeds, full height at run)
		var lift_t := pow(swing_t, 0.6)
		var effective_step_height := _get_effective_step_height(speed)
		var arc_height: float = effective_step_height * sin(lift_t * PI)
		ground_pos.y += arc_height

		return ground_pos


## Predict where the foot should plant next based on movement.
## Standard stride wheel: foot plants 0.5 stride ahead, ends 0.5 stride behind when lifting.
## This creates natural weight transfer as the body passes over the planted foot.
func _predict_plant_position(move_dir: Vector3, speed: float, side: float) -> Vector3:
	if _visuals.controller == null:
		return Vector3.ZERO

	var char_pos := _visuals.controller.global_position

	# Use effective stride (scales with speed)
	var effective_stride := _get_effective_stride(speed)

	# Forward offset: plant ahead of current position
	# Higher plant_ahead_ratio = foot lands further forward from body center
	# During stopping, plant foot further ahead to create braking stance
	var effective_plant_ratio := plant_ahead_ratio
	if _motion_state == 3 and start_stop_enabled and not _stop_foot_planted:
		effective_plant_ratio = stop_plant_distance
		_stop_foot_planted = true  # Only modify first plant during stop
	var forward_offset: Vector3 = move_dir * effective_stride * effective_plant_ratio

	# Lateral offset perpendicular to movement direction
	# Crossover reduces lateral offset: 0 = normal, 1 = inline (runway walk), >1 = cross over centerline
	var crossover_scale: float = 1.0 - crossover_amount
	var lateral: Vector3 = move_dir.cross(Vector3.UP).normalized() * side * foot_lateral_offset * crossover_scale
	if lateral.is_zero_approx() and crossover_amount < 1.0:
		# Fallback: use character's right vector (only if not intentionally zeroed by crossover)
		lateral = _visuals.controller.global_basis.x * side * foot_lateral_offset * crossover_scale

	var predicted: Vector3 = char_pos + forward_offset + lateral

	# Raycast to find actual ground
	return _raycast_ground(predicted)


## Raycast down from a position to find the ground point.
## update_normal: If true, store the hit normal for foot rotation. Only set true when foot plants.
func _raycast_ground(world_pos: Vector3, update_normal: bool = false, is_left: bool = true) -> Vector3:
	if _space_state == null:
		return world_pos

	var origin: Vector3 = world_pos + Vector3.UP * ray_height
	var end: Vector3 = world_pos + Vector3.DOWN * ray_depth

	var query := PhysicsRayQueryParameters3D.create(origin, end)
	query.collision_mask = ground_layers
	if _visuals.controller:
		query.exclude = [_visuals.controller.get_rid()]

	var result := _space_state.intersect_ray(query)
	if result.is_empty():
		return world_pos

	# Only update ground normal when explicitly requested (foot planting)
	if update_normal:
		var hit_normal: Vector3 = result.normal
		if is_left:
			_left_ground_normal = hit_normal
		else:
			_right_ground_normal = hit_normal

	# Raise hit position by foot_height so sole sits on ground (not ankle)
	return result.position + Vector3.UP * foot_height


## Detect if a cycle value crossed a threshold (handles wrap-around).
func _crossed_threshold(current: float, previous: float, threshold: float) -> bool:
	if previous <= current:
		# Normal progression
		return previous < threshold and current >= threshold
	else:
		# Wrapped around (1.0 → 0.0)
		return previous < threshold or current >= threshold


## Force re-plant if foot is too far from character. Returns clamped position.
func _clamp_plant_distance(plant_pos: Vector3, max_dist: float) -> Vector3:
	if _visuals.controller == null:
		return plant_pos

	var char_pos := _visuals.controller.global_position
	var offset := plant_pos - char_pos
	offset.y = 0.0
	if offset.length_squared() > max_dist * max_dist:
		var clamped := char_pos + offset.normalized() * max_dist
		clamped.y = plant_pos.y
		return clamped
	return plant_pos


## Update hip offset: base offset + sinusoidal bob + torso lag + forward lean + slope lean + hip rock + spine counter-rotation.
func _update_hip(delta: float, bob: float, rock: Vector3 = Vector3.ZERO, move_dir: Vector3 = Vector3.ZERO, shoulder_twist: float = 0.0) -> void:
	var smooth_factor := 1.0 - exp(-torso_smooth_speed * delta)

	# Apply hip bob only if hip motion is enabled
	var effective_bob := bob if hip_motion_enabled else 0.0
	var target_offset := hip_offset + effective_bob

	_current_hip_offset = lerpf(
		_current_hip_offset, target_offset,
		smooth_factor
	)

	# Torso lag: offset torso BEHIND movement direction so feet appear to lead
	# Acceleration scaling: more trail when accelerating (body lags), less when stopping (body catches up)
	# Use consistent slow smoothing to prevent snaps on direction changes
	var accel_trail_scale := 1.0 + _accel_factor * 0.5  # +50% at full accel, -15% at full decel
	var effective_trail := body_trail_distance * accel_trail_scale
	var target_lag := -move_dir * effective_trail if hip_motion_enabled else Vector3.ZERO
	var lag_smooth := 1.0 - exp(-3.0 * delta)  # Slow, consistent smoothing
	_current_hip_forward = _current_hip_forward.lerp(target_lag, lag_smooth)

	# Slope detection and lean (only if slope adaptation is enabled)
	var slope_angle := 0.0
	if slope_adaptation_enabled:
		slope_angle = _detect_slope(move_dir)
	var slope_smooth := 1.0 - exp(-slope_smooth_speed * delta)
	_current_slope_angle = lerpf(_current_slope_angle, slope_angle, slope_smooth)

	# Acceleration-based spine lean:
	# - Starting movement: lean forward (positive _accel_factor)
	# - Cruising: gradually straighten (zero _accel_factor)
	# - Stopping: lean back slightly (negative _accel_factor), then slowly return to upright
	# _accel_factor is calculated early in _update_acceleration() and shared across all systems
	var base_lean := deg_to_rad(spine_lean_angle) * _accel_factor if hip_motion_enabled else 0.0

	# Add slope lean
	var slope_lean := _current_slope_angle * slope_lean_amount if slope_adaptation_enabled else 0.0
	var target_lean := base_lean + slope_lean

	# Use consistent slow smoothing for lean to prevent snaps on direction change
	var lean_smooth := 1.0 - exp(-3.0 * delta)
	_current_lean_angle = lerpf(_current_lean_angle, target_lean, lean_smooth)

	# Hip rock: 3-axis rotation synced with gait (convert degrees to radians)
	# Use consistent slow smoothing to prevent snaps
	var effective_rock := rock if hip_motion_enabled else Vector3.ZERO
	var target_rock := Vector3(
		deg_to_rad(effective_rock.x),
		deg_to_rad(effective_rock.y),
		deg_to_rad(effective_rock.z)
	)
	var rock_smooth := 1.0 - exp(-5.0 * delta)  # Slightly faster for gait sync
	_current_hip_rock = _current_hip_rock.lerp(target_rock, rock_smooth)

	# Shoulder twist: smooth the phase-based twist (convert degrees to radians)
	var effective_shoulder_twist := shoulder_twist if shoulder_rotation_enabled else 0.0
	var target_shoulder_twist := deg_to_rad(effective_shoulder_twist)
	# Use slower smoothing to prevent jitter on direction changes
	var twist_smooth := 1.0 - exp(-3.0 * delta)
	_current_shoulder_twist = lerpf(_current_shoulder_twist, target_shoulder_twist, twist_smooth)

	# Apply position to visual root
	_visuals.position.y = _current_hip_offset
	_visuals.position.x = _current_hip_forward.x
	_visuals.position.z = _current_hip_forward.z

	# Hip rock and spine rotation are now applied by HipRockModifier (a SkeletonModifier3D)
	# This ensures they run AFTER AnimationTree and don't get overwritten.
	# The modifier calls get_hip_rock_values() to get the smoothed values.


## Update arm swing positions. Arms swing opposite to legs.
## Also applies arm_rest_drop to lower hands from T-pose for natural idle.
func _update_arm_swing(delta: float, speed: float, move_dir: Vector3, is_moving: bool) -> void:
	# Skip if no arm targets assigned or arm swing disabled
	if _left_hand == null and _right_hand == null:
		return
	if not arm_swing_enabled:
		return

	# Initialize smoothed positions on first run
	if not _arms_initialized:
		if _left_hand:
			_left_hand_current = _left_hand.position
		if _right_hand:
			_right_hand_current = _right_hand.position
		_arms_initialized = true

	# Update swing influence (blends swing in/out, not the drop)
	var target_influence := 1.0 if is_moving else 0.0
	_arm_influence = lerpf(_arm_influence, target_influence, 1.0 - exp(-ik_blend_speed * delta))

	# Scale swing with speed (faster = bigger swing) and acceleration (more pump when starting)
	var speed_factor := clampf(speed / run_speed, 0.3, 1.0) if is_moving else 0.0
	var accel_arm_scale := 1.0 + maxf(0.0, _accel_factor) * 0.5  # Up to 50% more swing when accelerating
	var swing_amp := arm_swing_amount * speed_factor * accel_arm_scale

	# Subtle arm randomness (updated every ~0.5 seconds)
	_arm_random_timer += delta
	if _arm_random_timer > 0.5:
		_arm_random_timer = 0.0
		_left_arm_phase_offset = randf_range(-0.15, 0.15)
		_right_arm_phase_offset = randf_range(-0.15, 0.15)
		_left_arm_amp_scale = randf_range(0.9, 1.1)
		_right_arm_amp_scale = randf_range(0.9, 1.1)

	# Arms swing opposite to legs: right arm forward when left leg plants, and vice versa
	# arm_phase_offset controls timing: 0.25 = arm peaks exactly when opposite foot plants
	var phase_offset_rad := arm_phase_offset * TAU  # 0.25 * TAU = PI/2
	var left_arm_phase := _phase - phase_offset_rad + _left_arm_phase_offset   # Peaks when RIGHT leg plants
	var right_arm_phase := _phase + phase_offset_rad + _right_arm_phase_offset # Peaks when LEFT leg plants

	# Calculate swing offset in movement direction
	var forward := move_dir if move_dir.length_squared() > 0.01 else -_visuals.global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()

	# Left arm
	if _left_hand:
		var parent := _left_hand.get_parent() as Node3D
		if parent:
			# Rest offset: drop down, raise for bend, world up adjustment
			var rest_offset_world: Vector3 = Vector3.DOWN * arm_rest_drop + Vector3.UP * (arm_rest_raise + arm_rest_up)
			var rest_offset_local: Vector3 = parent.global_transform.basis.inverse() * rest_offset_world

			# Swing offset (only when moving, with random amplitude)
			# Add forward bias to shift arms forward during movement
			var swing := sin(left_arm_phase) * swing_amp * _left_arm_amp_scale + arm_forward_bias
			var lift := absf(sin(left_arm_phase)) * arm_swing_lift * _left_arm_amp_scale
			var swing_world: Vector3 = forward * swing + Vector3.UP * lift
			var swing_local: Vector3 = parent.global_transform.basis.inverse() * swing_world

			# Calculate target position
			var target_pos: Vector3 = _left_hand_rest + rest_offset_local + swing_local * _arm_influence

			# Clamp reach to force elbow bend
			if _left_upperarm_idx != -1 and _left_arm_length > 0.0:
				var shoulder_world: Vector3 = (_skeleton.global_transform * _skeleton.get_bone_global_pose(_left_upperarm_idx)).origin
				var hand_world: Vector3 = parent.global_transform * Transform3D(Basis.IDENTITY, target_pos).origin
				var max_reach := _left_arm_length * arm_max_reach
				var to_hand := hand_world - shoulder_world
				if to_hand.length() > max_reach:
					hand_world = shoulder_world + to_hand.normalized() * max_reach
					target_pos = (parent.global_transform.inverse() * Transform3D(Basis.IDENTITY, hand_world)).origin

			# Smooth toward target for loose feel
			_left_hand_current = _left_hand_current.lerp(target_pos, 1.0 - exp(-arm_smoothing * delta))
			_left_hand.position = _left_hand_current

	# Right arm
	if _right_hand:
		var parent := _right_hand.get_parent() as Node3D
		if parent:
			# Rest offset: drop down, raise for bend, world up adjustment
			var rest_offset_world: Vector3 = Vector3.DOWN * arm_rest_drop + Vector3.UP * (arm_rest_raise + arm_rest_up)
			var rest_offset_local: Vector3 = parent.global_transform.basis.inverse() * rest_offset_world

			# Swing offset (only when moving, with random amplitude)
			# Add forward bias to shift arms forward during movement
			var swing := sin(right_arm_phase) * swing_amp * _right_arm_amp_scale + arm_forward_bias
			var lift := absf(sin(right_arm_phase)) * arm_swing_lift * _right_arm_amp_scale
			var swing_world: Vector3 = forward * swing + Vector3.UP * lift
			var swing_local: Vector3 = parent.global_transform.basis.inverse() * swing_world

			# Calculate target position
			var target_pos: Vector3 = _right_hand_rest + rest_offset_local + swing_local * _arm_influence

			# Clamp reach to force elbow bend
			if _right_upperarm_idx != -1 and _right_arm_length > 0.0:
				var shoulder_world: Vector3 = (_skeleton.global_transform * _skeleton.get_bone_global_pose(_right_upperarm_idx)).origin
				var hand_world: Vector3 = parent.global_transform * Transform3D(Basis.IDENTITY, target_pos).origin
				var max_reach := _right_arm_length * arm_max_reach
				var to_hand := hand_world - shoulder_world
				if to_hand.length() > max_reach:
					hand_world = shoulder_world + to_hand.normalized() * max_reach
					target_pos = (parent.global_transform.inverse() * Transform3D(Basis.IDENTITY, hand_world)).origin

			# Smooth toward target for loose feel
			_right_hand_current = _right_hand_current.lerp(target_pos, 1.0 - exp(-arm_smoothing * delta))
			_right_hand.position = _right_hand_current


## Update knee pole target positions to track movement direction.
## Knees point slightly toward movement when walking, return to rest when idle.
func _update_knee_poles(delta: float, move_dir: Vector3, is_moving: bool) -> void:
	# Skip if no knee targets assigned or knee tracking disabled
	if _left_knee == null and _right_knee == null:
		return
	if not knee_tracking_enabled:
		return

	# Knee offset direction: blend between forward (rest) and movement direction
	var target_dir: Vector3
	if is_moving and move_dir.length_squared() > 0.01:
		# Blend toward movement direction based on knee_direction_weight
		var forward := -_visuals.global_transform.basis.z
		forward.y = 0.0
		forward = forward.normalized()
		target_dir = forward.lerp(_current_knee_direction, knee_direction_weight)
	else:
		# Rest: knees point forward relative to character
		target_dir = -_visuals.global_transform.basis.z
		target_dir.y = 0.0
		target_dir = target_dir.normalized()

	# Distance in front of knee for pole target (roughly shin length)
	var pole_distance := 0.4

	# Update left knee pole
	if _left_knee:
		var parent := _left_knee.get_parent() as Node3D
		if parent and _left_thigh_idx != -1:
			# Get thigh bone world position
			var thigh_world: Vector3 = (_skeleton.global_transform * _skeleton.get_bone_global_pose(_left_thigh_idx)).origin
			# Pole target is in front of the knee (halfway down thigh + forward)
			var knee_approx := thigh_world + Vector3.DOWN * 0.25  # Approximate knee height
			var pole_world := knee_approx + target_dir * pole_distance
			# Convert to local space of parent
			var pole_local := parent.global_transform.inverse() * Transform3D(Basis.IDENTITY, pole_world)
			# Smooth toward target
			var smooth := 1.0 - exp(-knee_smooth_speed * delta)
			_left_knee.position = _left_knee.position.lerp(pole_local.origin, smooth)

	# Update right knee pole
	if _right_knee:
		var parent := _right_knee.get_parent() as Node3D
		if parent and _right_thigh_idx != -1:
			var thigh_world: Vector3 = (_skeleton.global_transform * _skeleton.get_bone_global_pose(_right_thigh_idx)).origin
			var knee_approx := thigh_world + Vector3.DOWN * 0.25
			var pole_world := knee_approx + target_dir * pole_distance
			var pole_local := parent.global_transform.inverse() * Transform3D(Basis.IDENTITY, pole_world)
			var smooth := 1.0 - exp(-knee_smooth_speed * delta)
			_right_knee.position = _right_knee.position.lerp(pole_local.origin, smooth)


## Blend IK influence up when moving, down at idle.
func _update_influence(delta: float, _is_moving: bool) -> void:
	var grounded := _visuals.is_grounded()
	# For procedural stride wheel, IK should be active whenever grounded
	# (feet need to stay planted whether moving, idle, or turning)
	var target: float = 1.0 if grounded else 0.0

	_current_influence = lerpf(
		_current_influence, target,
		1.0 - exp(-ik_blend_speed * delta)
	)


## Apply influence to both IK solvers.
func _apply_influence() -> void:
	if _left_ik and _left_ik.has_method("set"):
		_left_ik.set("influence", _current_influence)
	if _right_ik and _right_ik.has_method("set"):
		_right_ik.set("influence", _current_influence)


## Apply soft IK clamping to prevent knee snapping at full leg extension.
## Pulls foot target closer to hip when approaching max reach, creating smooth bend.
## Returns the adjusted world position.
func _apply_soft_ik(world_pos: Vector3, is_left: bool) -> Vector3:
	if not soft_ik_enabled or ik_softness <= 0.0:
		return world_pos

	# Get thigh (hip joint) world position
	var thigh_idx := _left_thigh_idx if is_left else _right_thigh_idx
	if thigh_idx == -1 or _skeleton == null:
		return world_pos

	var hip_pos := _get_bone_world_position(thigh_idx)

	# Use actual leg length calculated from skeleton bones
	var leg_length := _left_leg_length if is_left else _right_leg_length
	if leg_length <= 0.0:
		return world_pos  # Leg length not calculated, skip soft IK

	# Calculate current distance from hip to target
	var to_target := world_pos - hip_pos
	var distance := to_target.length()

	if distance < 0.001:
		return world_pos

	# Apply constant minimum bend + soft falloff near max reach
	# This ensures knee is never fully straight
	var max_reach := leg_length
	var soft_start_dist := max_reach * ik_soft_start

	# Base compression: always pull back slightly to maintain minimum knee bend
	# ik_softness controls how much minimum bend (0.3 = always 3% shorter than distance)
	var min_bend_factor := 1.0 - (ik_softness * 0.1)  # e.g., 0.3 softness = 0.97 factor

	# Additional compression near max reach
	var extra_compression := 0.0
	if distance > soft_start_dist:
		var excess_ratio := (distance - soft_start_dist) / (max_reach - soft_start_dist)
		excess_ratio = clampf(excess_ratio, 0.0, 2.0)
		extra_compression = excess_ratio * excess_ratio * ik_softness * 0.3

	var total_scale := min_bend_factor - extra_compression
	total_scale = clampf(total_scale, 0.5, 1.0)  # Never compress more than 50%

	var new_distance := distance * total_scale
	var direction := to_target.normalized()

	return hip_pos + direction * new_distance


## Position and rotate a foot target Marker3D with smoothing.
## yaw: The Y rotation (facing direction) for the foot.
## ground_normal: The ground normal from raycast for slope adaptation.
## rest_basis: The foot bone's rest orientation (captured at setup).
## swing_t: Swing phase progress (0 = planted, >0 = in swing). Used for foot pitch during swing.
## delta: Frame delta for smoothing.
## apply_swing_pitch: If true, apply heel peel during swing. False = lock rotation (turn-in-place).
func _apply_foot_target(target: Marker3D, world_pos: Vector3, yaw: float, ground_normal: Vector3, rest_basis: Basis, swing_t: float, delta: float, apply_swing_pitch: bool = true) -> void:
	if target == null:
		return

	# Determine which foot and get stance progress for heel-to-toe roll
	var is_left := target == _left_target
	var stance_progress := _left_stance_progress if is_left else _right_stance_progress

	# Apply soft IK to prevent knee snapping at full extension
	world_pos = _apply_soft_ik(world_pos, is_left)

	# Build foot basis from rest pose + yaw delta + ground tilt + swing/stance pitch
	var target_basis := _compute_foot_basis(yaw, ground_normal, rest_basis, swing_t, stance_progress, apply_swing_pitch)
	var current_pos: Vector3 = _left_current_pos if is_left else _right_current_pos

	# Always smooth foot movement
	# Use consistent smoothing speed - no boost during swing
	# The arc shape comes from _process_foot(), not from faster smoothing
	var smooth_factor := 1.0 - exp(-foot_smooth_speed * delta)

	var target_quat := target_basis.get_rotation_quaternion()

	# Snap rotation for now to debug
	var rot_smooth := 1.0

	if is_left:
		if not _left_foot_initialized:
			_left_current_pos = world_pos
			_left_current_quat = target_quat
			_left_foot_initialized = true
		else:
			_left_current_pos = _left_current_pos.lerp(world_pos, smooth_factor)
			_left_current_quat = _left_current_quat.slerp(target_quat, rot_smooth)
	else:
		if not _right_foot_initialized:
			_right_current_pos = world_pos
			_right_current_quat = target_quat
			_right_foot_initialized = true
		else:
			_right_current_pos = _right_current_pos.lerp(world_pos, smooth_factor)
			_right_current_quat = _right_current_quat.slerp(target_quat, rot_smooth)

	# Apply smoothed values
	var final_pos: Vector3
	var final_quat: Quaternion
	if is_left:
		final_pos = _left_current_pos
		final_quat = _left_current_quat
	else:
		final_pos = _right_current_pos
		final_quat = _right_current_quat

	target.global_transform = Transform3D(Basis(final_quat), final_pos)


## Compute foot basis from yaw delta, ground normal, swing phase, and stance progress.
## Preserves the foot bone's rest orientation while rotating to face the target yaw.
## swing_t: 0 = planted, >0 = in swing.
## stance_progress: 0-1 progress through stance phase (for heel-to-toe roll).
## apply_pitch: If true, apply heel peel pitch during swing. If false and swinging, just release to rest.
func _compute_foot_basis(yaw: float, ground_normal: Vector3, rest_basis: Basis, swing_t: float, stance_progress: float, apply_pitch: bool = true) -> Basis:
	# If swinging and not applying pitch, return rest basis relative to current character yaw
	if swing_t > 0.0 and not apply_pitch:
		var delta_yaw := yaw - _initial_char_yaw
		var yaw_rotation := Basis(Vector3.UP, delta_yaw)
		return yaw_rotation * rest_basis

	# Compute how much we need to rotate from the initial character yaw
	var delta_yaw := yaw - _initial_char_yaw

	# Rotate the rest basis around Y by the delta
	var yaw_rotation := Basis(Vector3.UP, delta_yaw)
	var result := yaw_rotation * rest_basis

	# Heel-to-toe roll during stance phase (when planted)
	if swing_t == 0.0 and heel_toe_roll_enabled:
		var stance_pitch := _get_stance_roll_pitch(stance_progress)
		if stance_pitch != 0.0:
			var pitch_axis := result.x.normalized()
			result = Basis(pitch_axis, stance_pitch) * result

	# Swing phase pitch - toe points down at lift-off, levels at landing
	if foot_rotation_enabled and swing_t > 0.0 and swing_pitch_angle > 0.0:
		# Pitch curve: negative at start (toe down), approaches zero at landing
		var pitch_angle := -sin((1.0 - swing_t) * PI * 0.5) * deg_to_rad(swing_pitch_angle)
		if pitch_angle != 0.0:
			# Rotate around the foot's local lateral axis (not world X)
			var pitch_axis := result.x.normalized()
			result = Basis(pitch_axis, pitch_angle) * result

	# Apply ground normal tilt if not flat (only when planted, not during swing)
	if foot_rotation_enabled and swing_t == 0.0 and not ground_normal.is_equal_approx(Vector3.UP):
		var angle := Vector3.UP.angle_to(ground_normal)
		angle = clampf(angle, 0.0, deg_to_rad(max_foot_angle))
		angle *= foot_rotation_weight

		var tilt_axis := Vector3.UP.cross(ground_normal).normalized()
		if not tilt_axis.is_zero_approx():
			var tilt_basis := Basis(tilt_axis, angle)
			result = tilt_basis * result

	return result


## Get a bone's position in world space.
func _get_bone_world_position(bone_idx: int) -> Vector3:
	var bone_global_pose := _skeleton.get_bone_global_pose(bone_idx)
	return _skeleton.global_transform * bone_global_pose.origin


# =============================================================================
# DEBUG VISUALIZATION
# =============================================================================

## Create debug visualization meshes.
func _setup_debug() -> void:
	if _debug_container:
		_debug_container.queue_free()

	_debug_container = Node3D.new()
	_debug_container.name = "StrideWheelDebug"
	get_tree().root.add_child.call_deferred(_debug_container)

	# Left plant position - GREEN
	_debug_left_plant = _create_debug_sphere(Color.GREEN, "L PLANT")
	_debug_left_plant.name = "LeftPlant"

	# Right plant position - BLUE
	_debug_right_plant = _create_debug_sphere(Color.BLUE, "R PLANT")
	_debug_right_plant.name = "RightPlant"

	# Left predicted position - YELLOW
	_debug_left_predicted = _create_debug_sphere(Color.YELLOW, "L PRED")
	_debug_left_predicted.name = "LeftPredicted"

	# Right predicted position - ORANGE
	_debug_right_predicted = _create_debug_sphere(Color.ORANGE, "R PRED")
	_debug_right_predicted.name = "RightPredicted"

	# Character reference position - WHITE
	_debug_char_pos = _create_debug_sphere(Color.WHITE, "CHAR")
	_debug_char_pos.name = "CharPos"

	# Left foot target (actual IK target) - LIME
	_debug_left_target = _create_debug_sphere(Color.LIME, "L IK")
	_debug_left_target.name = "LeftTarget"

	# Right foot target (actual IK target) - CYAN
	_debug_right_target = _create_debug_sphere(Color.CYAN, "R IK")
	_debug_right_target.name = "RightTarget"

	# Movement direction - MAGENTA (use a stretched sphere as arrow)
	_debug_move_dir = _create_debug_sphere(Color.MAGENTA, "DIR")
	_debug_move_dir.name = "MoveDir"

	# Stride wheels - torus showing the wheel path
	_debug_left_wheel = _create_debug_wheel(Color.GREEN)
	_debug_left_wheel.name = "LeftWheel"
	_debug_right_wheel = _create_debug_wheel(Color.BLUE)
	_debug_right_wheel.name = "RightWheel"

	# Clock position markers (12, 3, 6, 9 o'clock)
	var marker_labels := ["12", "3", "6", "9"]
	_debug_left_markers.clear()
	_debug_right_markers.clear()
	for i in range(4):
		var left_marker := _create_debug_sphere(Color.GREEN_YELLOW, marker_labels[i])
		left_marker.name = "LeftMarker" + str(i)
		_debug_left_markers.append(left_marker)
		var right_marker := _create_debug_sphere(Color.DODGER_BLUE, marker_labels[i])
		right_marker.name = "RightMarker" + str(i)
		_debug_right_markers.append(right_marker)

	# Spokes on each wheel (4 spokes for visibility)
	_debug_left_spokes.clear()
	_debug_right_spokes.clear()
	for i in range(4):
		var left_spoke := _create_debug_spoke(Color.GREEN)
		left_spoke.name = "LeftSpoke" + str(i)
		_debug_left_spokes.append(left_spoke)
		var right_spoke := _create_debug_spoke(Color.BLUE)
		right_spoke.name = "RightSpoke" + str(i)
		_debug_right_spokes.append(right_spoke)

	# Phase indicators - small spheres showing current position on wheel (no label)
	_debug_left_phase = _create_debug_sphere(Color.GREEN, "")
	_debug_left_phase.name = "LeftPhase"
	_debug_right_phase = _create_debug_sphere(Color.BLUE, "")
	_debug_right_phase.name = "RightPhase"

	# Overhead labels above player's head
	_debug_overhead_left_label = _create_overhead_label(Color.GREEN)
	_debug_overhead_left_label.name = "OverheadLeftLabel"
	_debug_overhead_right_label = _create_overhead_label(Color.CYAN)
	_debug_overhead_right_label.name = "OverheadRightLabel"

	# Per-section debug visuals
	# Ground detection rays - YELLOW for rays
	_debug_ground_left_ray = _create_debug_ray(Color.YELLOW)
	_debug_ground_left_ray.name = "GroundLeftRay"
	_debug_ground_right_ray = _create_debug_ray(Color.YELLOW)
	_debug_ground_right_ray.name = "GroundRightRay"
	# Ground hit markers - RED for hits
	_debug_ground_left_hit = _create_debug_sphere(Color.RED, "")
	_debug_ground_left_hit.name = "GroundLeftHit"
	_debug_ground_right_hit = _create_debug_sphere(Color.RED, "")
	_debug_ground_right_hit.name = "GroundRightHit"
	# Knee pole markers - PURPLE
	_debug_knee_left = _create_debug_sphere(Color.PURPLE, "L KNEE")
	_debug_knee_left.name = "KneeLeft"
	_debug_knee_right = _create_debug_sphere(Color.PURPLE, "R KNEE")
	_debug_knee_right.name = "KneeRight"
	# Slope detection ray - ORANGE
	_debug_slope_ray = _create_debug_ray(Color.ORANGE)
	_debug_slope_ray.name = "SlopeRay"
	_debug_slope_hit = _create_debug_sphere(Color.ORANGE, "SLOPE")
	_debug_slope_hit.name = "SlopeHit"
	# Hip marker - PINK
	_debug_hip_marker = _create_debug_sphere(Color.HOT_PINK, "HIP")
	_debug_hip_marker.name = "HipMarker"
	# Motion state label
	_debug_motion_label = _create_overhead_label(Color.WHITE)
	_debug_motion_label.name = "MotionLabel"


## Create a debug ray (cylinder for line visualization).
func _create_debug_ray(color: Color) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.005
	cylinder.bottom_radius = 0.005
	cylinder.height = 1.0  # Will be scaled as needed
	mesh_instance.mesh = cylinder

	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh_instance.material_override = material

	_debug_container.add_child(mesh_instance)
	return mesh_instance


## Create a debug cog tooth (box pointing outward).
func _create_debug_spoke(color: Color) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.02, 0.15, 0.01)  # Longer rectangular spike
	mesh_instance.mesh = box

	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh_instance.material_override = material

	_debug_container.add_child(mesh_instance)
	return mesh_instance


## Create a debug wheel (torus) mesh.
func _create_debug_wheel(color: Color) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = stride_length * 0.48
	torus.outer_radius = stride_length * 0.52
	torus.rings = 32
	torus.ring_segments = 8
	mesh_instance.mesh = torus

	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.albedo_color.a = 0.3
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh_instance.material_override = material

	_debug_container.add_child(mesh_instance)
	return mesh_instance


## Create a debug sphere mesh with a label.
func _create_debug_sphere(color: Color, label_text: String) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = debug_sphere_size
	sphere.height = debug_sphere_size * 2.0
	mesh_instance.mesh = sphere

	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color.a = 0.8
	mesh_instance.material_override = material

	# Add a label above the sphere
	var label := Label3D.new()
	label.text = label_text
	label.font_size = 32
	label.pixel_size = 0.002
	label.position = Vector3(0, 0.15, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.modulate = color
	label.outline_size = 8
	label.outline_modulate = Color.BLACK
	mesh_instance.add_child(label)

	_debug_container.add_child(mesh_instance)
	return mesh_instance


## Create an overhead label for displaying phase info above the player.
func _create_overhead_label(color: Color) -> Label3D:
	var label := Label3D.new()
	label.text = ""
	label.font_size = 24
	label.pixel_size = 0.002
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.modulate = color
	label.outline_size = 6
	label.outline_modulate = Color.BLACK
	_debug_container.add_child(label)
	return label


## Update debug visualization positions.
func _update_debug(char_pos: Vector3, move_dir: Vector3) -> void:
	if not debug_enabled or not _debug_container:
		if _debug_container:
			_debug_container.visible = false
		return

	_debug_container.visible = true

	# Update sphere sizes
	var size := debug_sphere_size
	_update_sphere_size(_debug_left_plant, size)
	_update_sphere_size(_debug_right_plant, size)
	_update_sphere_size(_debug_left_predicted, size * 0.7)
	_update_sphere_size(_debug_right_predicted, size * 0.7)
	_update_sphere_size(_debug_char_pos, size * 1.2)
	_update_sphere_size(_debug_left_target, size * 0.5)
	_update_sphere_size(_debug_right_target, size * 0.5)
	_update_sphere_size(_debug_move_dir, size * 0.5)

	# Plant positions
	if debug_show_plant_pos:
		_debug_left_plant.visible = true
		_debug_right_plant.visible = true
		_debug_left_plant.global_position = _left_plant_pos + Vector3.UP * 0.01
		_debug_right_plant.global_position = _right_plant_pos + Vector3.UP * 0.01
	else:
		_debug_left_plant.visible = false
		_debug_right_plant.visible = false

	# Predicted positions
	if debug_show_predicted:
		_debug_left_predicted.visible = true
		_debug_right_predicted.visible = true
		_debug_left_predicted.global_position = _debug_left_predicted_pos + Vector3.UP * 0.02
		_debug_right_predicted.global_position = _debug_right_predicted_pos + Vector3.UP * 0.02
	else:
		_debug_left_predicted.visible = false
		_debug_right_predicted.visible = false

	# Character position
	if debug_show_char_pos:
		_debug_char_pos.visible = true
		_debug_char_pos.global_position = char_pos + Vector3.UP * 0.03
	else:
		_debug_char_pos.visible = false

	# Movement direction
	if debug_show_move_dir and move_dir.length_squared() > 0.01:
		_debug_move_dir.visible = true
		_debug_move_dir.global_position = char_pos + move_dir * 0.5 + Vector3.UP * 0.05
	else:
		_debug_move_dir.visible = false

	# Actual IK target positions
	if _left_target:
		_debug_left_target.visible = true
		_debug_left_target.global_position = _left_target.global_position + Vector3.UP * 0.03
	else:
		_debug_left_target.visible = false

	if _right_target:
		_debug_right_target.visible = true
		_debug_right_target.global_position = _right_target.global_position + Vector3.UP * 0.03
	else:
		_debug_right_target.visible = false

	# Stride wheels and phase indicators
	if debug_show_stride_wheel and _debug_left_wheel and _debug_right_wheel:
		var wheel_radius := stride_length * 0.5
		var wheel_height := step_height

		# Position wheels at hip height, offset laterally
		var hip_pos := char_pos + Vector3.UP * 0.5  # Approximate hip height
		var facing := _visuals.global_basis if _visuals else Basis.IDENTITY
		# Push wheels further out to the sides for visibility
		var wheel_lateral := foot_lateral_offset + 0.4
		var left_offset := -facing.x * wheel_lateral
		var right_offset := facing.x * wheel_lateral

		# Determine wheel orientation basis
		var wheel_basis: Basis
		if move_dir.length_squared() > 0.01:
			wheel_basis = Basis.looking_at(move_dir, Vector3.UP)
		else:
			wheel_basis = facing

		# Left wheel - vertical plane (standing upright like a rolling wheel)
		# Torus default is XZ plane (flat). Rotate around Z to stand vertical, facing movement.
		_debug_left_wheel.visible = true
		_debug_left_wheel.global_position = hip_pos + left_offset
		_debug_left_wheel.global_basis = wheel_basis * Basis(Vector3.FORWARD, PI * 0.5)

		# Right wheel
		_debug_right_wheel.visible = true
		_debug_right_wheel.global_position = hip_pos + right_offset
		_debug_right_wheel.global_basis = wheel_basis * Basis(Vector3.FORWARD, PI * 0.5)

		# Update wheel sizes based on current stride
		if _debug_left_wheel.mesh is TorusMesh:
			var torus := _debug_left_wheel.mesh as TorusMesh
			torus.inner_radius = wheel_radius * 0.96
			torus.outer_radius = wheel_radius * 1.04
		if _debug_right_wheel.mesh is TorusMesh:
			var torus := _debug_right_wheel.mesh as TorusMesh
			torus.inner_radius = wheel_radius * 0.96
			torus.outer_radius = wheel_radius * 1.04

		# Clock position markers at 12, 3, 6, 9 o'clock
		# In wheel space: 12=top, 3=front, 6=bottom, 9=back
		var clock_angles: Array[float] = [0.0, PI * 0.5, PI, PI * 1.5]  # 12, 3, 6, 9
		for i in range(4):
			var angle: float = clock_angles[i]
			# Y = height (cos), Z = forward/back (sin) so 12 o'clock = top
			var marker_local := Vector3(0, cos(angle) * wheel_radius, sin(angle) * wheel_radius)

			if i < _debug_left_markers.size():
				_debug_left_markers[i].visible = true
				_debug_left_markers[i].global_position = hip_pos + left_offset + wheel_basis * marker_local
				_update_sphere_size(_debug_left_markers[i], debug_sphere_size * 0.6)

			if i < _debug_right_markers.size():
				_debug_right_markers[i].visible = true
				_debug_right_markers[i].global_position = hip_pos + right_offset + wheel_basis * marker_local
				_update_sphere_size(_debug_right_markers[i], debug_sphere_size * 0.6)

		# Phase indicators - position on wheel circumference
		var left_cycle := fmod(_phase / TAU, 1.0)
		var right_cycle := fmod((_phase + PI) / TAU, 1.0)

		# Convert cycle to wheel angle:
		# Invert cycle so wheel rolls forward visually
		var left_angle := (1.0 - left_cycle) * TAU
		var right_angle := (1.0 - right_cycle) * TAU

		# Calculate position on wheel (Y = height via cos, Z = forward/back via sin)
		var left_phase_local := Vector3(0, cos(left_angle) * wheel_radius, sin(left_angle) * wheel_radius)
		var right_phase_local := Vector3(0, cos(right_angle) * wheel_radius, sin(right_angle) * wheel_radius)

		_debug_left_phase.visible = true
		_debug_right_phase.visible = true
		_update_sphere_size(_debug_left_phase, debug_sphere_size * 0.8)
		_update_sphere_size(_debug_right_phase, debug_sphere_size * 0.8)

		_debug_left_phase.global_position = hip_pos + left_offset + wheel_basis * left_phase_local
		_debug_right_phase.global_position = hip_pos + right_offset + wheel_basis * right_phase_local

		# Update overhead labels with percentage and state
		var left_pct := int(left_cycle * 100)
		var right_pct := int(right_cycle * 100)
		var left_state := "SWING" if left_cycle >= 0.5 else "STANCE"
		var right_state := "SWING" if right_cycle >= 0.5 else "STANCE"

		# Position overhead labels above player's head
		var head_pos := char_pos + Vector3.UP * 2.2
		if _debug_overhead_left_label:
			_debug_overhead_left_label.visible = true
			_debug_overhead_left_label.global_position = head_pos
			_debug_overhead_left_label.text = "L %d%% %s" % [left_pct, left_state]
		if _debug_overhead_right_label:
			_debug_overhead_right_label.visible = true
			_debug_overhead_right_label.global_position = head_pos + Vector3.DOWN * 0.12
			_debug_overhead_right_label.text = "R %d%% %s" % [right_pct, right_state]

		# Position cog teeth on wheel rim, rotating with phase
		var tooth_count := _debug_left_spokes.size()
		for i in range(tooth_count):
			var tooth_base_angle: float = (float(i) / float(tooth_count)) * TAU
			# Add phase offset so teeth rotate with the gait cycle
			var left_tooth_angle: float = tooth_base_angle + left_angle
			var right_tooth_angle: float = tooth_base_angle + right_angle

			# Position on the wheel rim (cos for Y, sin for Z so 0 angle = top)
			var left_tooth_pos := Vector3(0, cos(left_tooth_angle) * wheel_radius, sin(left_tooth_angle) * wheel_radius)
			var right_tooth_pos := Vector3(0, cos(right_tooth_angle) * wheel_radius, sin(right_tooth_angle) * wheel_radius)

			if i < _debug_left_spokes.size():
				_debug_left_spokes[i].visible = true
				var left_rim_pos: Vector3 = hip_pos + left_offset + wheel_basis * left_tooth_pos
				var left_center: Vector3 = hip_pos + left_offset
				var left_outward: Vector3 = (left_rim_pos - left_center).normalized()
				# Offset by half spike height so base sits on rim
				var left_world_pos: Vector3 = left_rim_pos + left_outward * 0.075
				_debug_left_spokes[i].global_position = left_world_pos
				_debug_left_spokes[i].global_basis = _basis_from_y(left_outward)

			if i < _debug_right_spokes.size():
				_debug_right_spokes[i].visible = true
				var right_rim_pos: Vector3 = hip_pos + right_offset + wheel_basis * right_tooth_pos
				var right_center: Vector3 = hip_pos + right_offset
				var right_outward: Vector3 = (right_rim_pos - right_center).normalized()
				var right_world_pos: Vector3 = right_rim_pos + right_outward * 0.075
				_debug_right_spokes[i].global_position = right_world_pos
				_debug_right_spokes[i].global_basis = _basis_from_y(right_outward)

	else:
		if _debug_left_wheel:
			_debug_left_wheel.visible = false
		if _debug_right_wheel:
			_debug_right_wheel.visible = false
		if _debug_left_phase:
			_debug_left_phase.visible = false
		if _debug_right_phase:
			_debug_right_phase.visible = false
		for marker in _debug_left_markers:
			marker.visible = false
		for marker in _debug_right_markers:
			marker.visible = false
		for spoke in _debug_left_spokes:
			spoke.visible = false
		for spoke in _debug_right_spokes:
			spoke.visible = false
		if _debug_overhead_left_label:
			_debug_overhead_left_label.visible = false
		if _debug_overhead_right_label:
			_debug_overhead_right_label.visible = false

	# Per-section debug visualizations (always update, controlled by individual toggles)
	_update_section_debug(char_pos, move_dir)


## Update per-section debug visualizations based on individual debug toggles.
func _update_section_debug(char_pos: Vector3, move_dir: Vector3) -> void:
	if not _debug_container:
		return

	var size := debug_sphere_size

	# Ground detection debug
	if debug_ground:
		# Show raycast from left foot
		if _debug_ground_left_ray and _left_target:
			_debug_ground_left_ray.visible = true
			var ray_start := _left_target.global_position + Vector3.UP * ray_height
			var ray_end := _left_target.global_position - Vector3.UP * ray_depth
			_position_ray(_debug_ground_left_ray, ray_start, ray_end)
		if _debug_ground_right_ray and _right_target:
			_debug_ground_right_ray.visible = true
			var ray_start := _right_target.global_position + Vector3.UP * ray_height
			var ray_end := _right_target.global_position - Vector3.UP * ray_depth
			_position_ray(_debug_ground_right_ray, ray_start, ray_end)
		# Show ground hit points
		if _debug_ground_left_hit:
			_debug_ground_left_hit.visible = true
			_debug_ground_left_hit.global_position = _left_plant_pos
			_update_sphere_size(_debug_ground_left_hit, size * 0.8)
		if _debug_ground_right_hit:
			_debug_ground_right_hit.visible = true
			_debug_ground_right_hit.global_position = _right_plant_pos
			_update_sphere_size(_debug_ground_right_hit, size * 0.8)
	else:
		if _debug_ground_left_ray:
			_debug_ground_left_ray.visible = false
		if _debug_ground_right_ray:
			_debug_ground_right_ray.visible = false
		if _debug_ground_left_hit:
			_debug_ground_left_hit.visible = false
		if _debug_ground_right_hit:
			_debug_ground_right_hit.visible = false

	# Knee tracking debug
	if debug_knee and _left_knee and _right_knee:
		if _debug_knee_left:
			_debug_knee_left.visible = true
			_debug_knee_left.global_position = _left_knee.global_position
			_update_sphere_size(_debug_knee_left, size)
		if _debug_knee_right:
			_debug_knee_right.visible = true
			_debug_knee_right.global_position = _right_knee.global_position
			_update_sphere_size(_debug_knee_right, size)
	else:
		if _debug_knee_left:
			_debug_knee_left.visible = false
		if _debug_knee_right:
			_debug_knee_right.visible = false

	# Slope adaptation debug
	if debug_slope:
		if _debug_slope_ray and move_dir.length_squared() > 0.01:
			_debug_slope_ray.visible = true
			var slope_start := char_pos + Vector3.UP * 0.3
			var slope_end := slope_start + move_dir * slope_detect_distance - Vector3.UP * 0.5
			_position_ray(_debug_slope_ray, slope_start, slope_end)
		else:
			if _debug_slope_ray:
				_debug_slope_ray.visible = false
		if _debug_slope_hit:
			_debug_slope_hit.visible = false  # Only show on hit, updated in _detect_slope
	else:
		if _debug_slope_ray:
			_debug_slope_ray.visible = false
		if _debug_slope_hit:
			_debug_slope_hit.visible = false

	# Hip motion debug
	if debug_hip and _pelvis_idx >= 0:
		if _debug_hip_marker:
			_debug_hip_marker.visible = true
			var hip_pos := _get_bone_world_position(_pelvis_idx)
			_debug_hip_marker.global_position = hip_pos
			_update_sphere_size(_debug_hip_marker, size * 1.5)
	else:
		if _debug_hip_marker:
			_debug_hip_marker.visible = false

	# Start/stop motion state debug
	if debug_start_stop:
		if _debug_motion_label:
			_debug_motion_label.visible = true
			_debug_motion_label.global_position = char_pos + Vector3.UP * 2.5
			var state_names: Array[String] = ["IDLE", "START", "WALK", "STOP"]
			_debug_motion_label.text = "Motion: %s" % state_names[_motion_state]
	else:
		if _debug_motion_label:
			_debug_motion_label.visible = false


## Position a debug ray (cylinder) between two points.
func _position_ray(ray: MeshInstance3D, start: Vector3, end: Vector3) -> void:
	if ray == null:
		return
	var dir := end - start
	var length := dir.length()
	if length < 0.001:
		ray.visible = false
		return
	# Scale the cylinder to match the distance
	ray.scale = Vector3(1.0, length, 1.0)
	# Position at midpoint
	ray.global_position = (start + end) * 0.5
	# Orient Y axis along the direction
	ray.global_basis = _basis_from_y(dir.normalized())


## Update a sphere mesh size.
func _update_sphere_size(mesh_instance: MeshInstance3D, size: float) -> void:
	if mesh_instance and mesh_instance.mesh is SphereMesh:
		var sphere := mesh_instance.mesh as SphereMesh
		sphere.radius = size
		sphere.height = size * 2.0


## Update label text on a debug sphere.
func _update_debug_label(mesh_instance: MeshInstance3D, text: String) -> void:
	if mesh_instance == null:
		return
	for child in mesh_instance.get_children():
		if child is Label3D:
			child.text = text
			return


## Create a basis with Y axis pointing in the given direction.
func _basis_from_y(y_dir: Vector3) -> Basis:
	var up := y_dir.normalized()
	var right := up.cross(Vector3.FORWARD).normalized()
	if right.is_zero_approx():
		right = up.cross(Vector3.RIGHT).normalized()
	var forward := right.cross(up).normalized()
	return Basis(right, up, forward)


## Cleanup debug meshes.
func _cleanup_debug() -> void:
	if _debug_container:
		_debug_container.queue_free()
		_debug_container = null


## Print bone axis reference to console for IK debugging.
## Shows which local axes map to world directions for key bones.
func _print_bone_axes() -> void:
	if _skeleton == null:
		print("ERROR: No skeleton to analyze")
		return

	print("=" .repeat(70))
	print("BONE AXIS REFERENCE (for IK rotations)")
	print("See: addons/renegade_visuals/docs/skeleton_reference.md")
	print("=" .repeat(70))

	# Core bones to analyze
	var bones_to_check: Array = [
		["pelvis", _pelvis_idx],
		["spine_01", _spine_01_idx],
		["spine_02", _spine_02_idx],
		["spine_03", _spine_03_idx],
		["left_foot", _left_foot_idx],
		["right_foot", _right_foot_idx],
		["left_thigh", _left_thigh_idx],
		["right_thigh", _right_thigh_idx],
	]

	# Add more bones dynamically
	var extra_bones := ["calf_l", "calf_r", "upperarm_l", "upperarm_r", "lowerarm_l", "lowerarm_r", "hand_l", "hand_r"]
	for bone_name in extra_bones:
		var idx := _skeleton.find_bone(bone_name)
		if idx != -1:
			bones_to_check.append([bone_name, idx])

	for bone_info in bones_to_check:
		var bone_name: String = bone_info[0]
		var idx: int = bone_info[1]
		if idx == -1:
			print("\n%s: NOT FOUND" % bone_name)
			continue

		var rest := _skeleton.get_bone_rest(idx)
		var basis := rest.basis
		var euler := basis.get_euler() * (180.0 / PI)

		var bone_dir := _get_bone_direction(idx)

		print("")
		print("%s (idx=%d):" % [_skeleton.get_bone_name(idx), idx])
		print("  Rest euler: (%.1f°, %.1f°, %.1f°)" % [euler.x, euler.y, euler.z])
		print("  Local X -> %s" % _basis_axis_to_world_dir(basis.x))
		print("  Local Y -> %s" % _basis_axis_to_world_dir(basis.y))
		print("  Local Z -> %s" % _basis_axis_to_world_dir(basis.z))
		print("  Bone points along: %s" % bone_dir)
		print("  TWIST AXIS: Y (rotate around local Y for yaw)" if basis.y.dot(Vector3.UP) > 0.9 else "  TWIST AXIS: Check orientation!")

	print("")
	print("=" .repeat(70))
	print("KEY: For this skeleton, Local Y = World Up for torso/spine bones.")
	print("     Use Y axis (Euler component 1) for twist/yaw rotations.")
	print("=" .repeat(70))


## Get bone direction by checking child position.
func _get_bone_direction(idx: int) -> String:
	for i in range(_skeleton.get_bone_count()):
		if _skeleton.get_bone_parent(i) == idx:
			var child_rest := _skeleton.get_bone_rest(i)
			var child_pos := child_rest.origin.normalized()

			var abs_x := absf(child_pos.x)
			var abs_y := absf(child_pos.y)
			var abs_z := absf(child_pos.z)

			if abs_x > abs_y and abs_x > abs_z:
				return "+X" if child_pos.x > 0 else "-X"
			elif abs_y > abs_x and abs_y > abs_z:
				return "+Y" if child_pos.y > 0 else "-Y"
			else:
				return "+Z" if child_pos.z > 0 else "-Z"
	return "leaf"


## Convert a basis axis vector to human-readable world direction.
func _basis_axis_to_world_dir(axis: Vector3) -> String:
	var abs_x := absf(axis.x)
	var abs_y := absf(axis.y)
	var abs_z := absf(axis.z)

	var parts: PackedStringArray = []
	if abs_x > 0.3:
		parts.append("%.0f%% %s" % [abs_x * 100, "Right" if axis.x > 0 else "Left"])
	if abs_y > 0.3:
		parts.append("%.0f%% %s" % [abs_y * 100, "Up" if axis.y > 0 else "Down"])
	if abs_z > 0.3:
		parts.append("%.0f%% %s" % [abs_z * 100, "Back" if axis.z > 0 else "Forward"])

	if parts.is_empty():
		return "(%.2f, %.2f, %.2f)" % [axis.x, axis.y, axis.z]
	return ", ".join(parts)
