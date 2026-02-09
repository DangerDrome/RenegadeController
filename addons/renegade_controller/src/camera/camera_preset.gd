## Camera configuration preset.
## Create .tres files for each camera setup: over-shoulder, side-scroller, top-down, first-person, etc.
## The CameraRig transitions smoothly between these presets.
@tool
class_name CameraPreset extends Resource

@export var preset_name: String = "Default"

@export_group("Mode")
## When true, camera locks to the character's head for first-person view.
@export var is_first_person: bool = false
## Offset from character origin to head/eye position (used in first-person).
@export var head_offset: Vector3 = Vector3(0.0, 1.7, 0.0)

@export_group("Position")
## Offset from the follow target (character). Applied in the rig's local space.
@export var offset: Vector3 = Vector3(0.5, 2.0, 0.0)
## Distance from pivot to camera along spring arm.
@export var spring_length: float = 5.0
## Enable collision detection on spring arm.
@export var use_collision: bool = false

@export_group("Rotation")
## Horizontal rotation offset in degrees (yaw). 0 = behind character.
@export_range(-180.0, 180.0, 0.1) var yaw_offset: float = 0.0
## Vertical angle in degrees (pitch). Negative = looking down.
@export_range(-89.0, 89.0, 0.1) var pitch: float = -15.0
## If true, camera rotation is fixed (doesn't follow character rotation).
## Good for side-scroller and top-down modes.
@export var fixed_rotation: bool = false
## Fixed yaw in degrees when fixed_rotation is true.
@export_range(-180.0, 180.0, 0.1) var fixed_yaw: float = 0.0

@export_group("Follow Behavior")
## When true, camera follows the player (marker position is relative offset).
## When false, camera stays at fixed world position (default for zone cameras).
@export var follow_target: bool = false
## How fast the rig follows the character position (higher = snappier).
@export_range(1.0, 50.0, 0.1) var follow_speed: float = 8.0
## How fast the rig rotates to match (ignored when fixed_rotation is true).
@export_range(1.0, 50.0, 0.1) var rotation_speed: float = 6.0

@export_group("Transition")
## Duration of the transition to this preset in seconds.
@export_range(0.05, 3.0, 0.05) var transition_duration: float = 0.5
## Curve for transitioning INTO this preset. If not set, uses CameraSystem's curve or default.
@export var transition_curve_in: Curve
## Curve for transitioning OUT OF this preset. If not set, uses CameraSystem's curve or default.
@export var transition_curve_out: Curve

@export_group("FOV")
@export_range(30.0, 120.0, 0.5) var fov: float = 70.0

@export_group("Input Mapping")
## How character movement input is interpreted relative to the camera.
## CAMERA_RELATIVE: standard third-person (input relative to camera forward).
## FIXED_AXIS: side-scroller style (input mapped to fixed world axes).
## WORLD: top-down style (input maps directly to world X/Z).
@export_enum("CAMERA_RELATIVE", "FIXED_AXIS", "WORLD") var input_mode: String = "CAMERA_RELATIVE"
## For FIXED_AXIS mode: the world-space forward direction.
@export var fixed_forward: Vector3 = Vector3(0, 0, -1)
## For FIXED_AXIS mode: the world-space right direction.
@export var fixed_right: Vector3 = Vector3(1, 0, 0)

@export_group("Mouse Look (First Person)")
## Mouse sensitivity for first-person look.
@export_range(0.01, 1.0, 0.01) var mouse_sensitivity: float = 0.15
## Minimum pitch in degrees (looking up limit).
@export_range(-89.0, 0.0, 0.1) var min_pitch: float = -80.0
## Maximum pitch in degrees (looking down limit).
@export_range(0.0, 89.0, 0.1) var max_pitch: float = 80.0
