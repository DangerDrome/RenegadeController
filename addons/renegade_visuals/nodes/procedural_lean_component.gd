## Procedural pelvis tilt to match ground slopes.
## IMPORTANT: This is now a SkeletonModifier3D to run in the correct pipeline.
## Acceleration-based lean is handled by StrideWheelComponent (spine_lean_angle).
class_name ProceduralLeanComponent
extends SkeletonModifier3D

@export var config: LeanConfig

var _visuals: CharacterVisuals

# Bone indices
var _pelvis_idx: int = -1

# Smoothed tilt state
var _current_pelvis_tilt: Quaternion = Quaternion.IDENTITY


func _ready() -> void:
	# Find CharacterVisuals parent (navigate up from Skeleton3D)
	var current := get_parent()
	while current:
		if current is CharacterVisuals:
			_visuals = current
			break
		current = current.get_parent()

	if _visuals == null:
		push_error("ProceduralLeanComponent: Could not find CharacterVisuals ancestor.")
		return

	if config == null:
		config = LeanConfig.new()

	# Cache bone index
	var skeleton := get_skeleton()
	if skeleton:
		var skel_config := _visuals.skeleton_config
		if skel_config == null:
			skel_config = SkeletonConfig.new()
		_pelvis_idx = skeleton.find_bone(skel_config.pelvis_bone)


func _process_modification() -> void:
	if not config or not config.enable_pelvis_tilt:
		return

	if _visuals == null:
		return

	var skeleton := get_skeleton()
	if skeleton == null or _pelvis_idx == -1:
		return

	# Skip updates while flinching (HitReactionComponent takes over)
	if _visuals.is_flinching:
		_current_pelvis_tilt = Quaternion.IDENTITY
		return

	_update_pelvis_tilt()


## Update pelvis tilt to match ground slope.
## This runs in the SkeletonModifier3D pipeline, so it won't fight with HipRockModifier.
func _update_pelvis_tilt() -> void:
	if _pelvis_idx == -1:
		return

	var skeleton := get_skeleton()
	var ground_normal := _visuals.get_ground_normal()
	var delta := get_process_delta_time()

	# Compute target tilt from ground normal
	var target_tilt := Quaternion.IDENTITY

	# Only apply tilt if ground is significantly non-flat
	# Skip when nearly vertical to avoid numerical instability in cross product
	var angle_from_up := Vector3.UP.angle_to(ground_normal)
	if angle_from_up > 0.05:  # ~3 degrees threshold
		var tilt_axis := Vector3.UP.cross(ground_normal)
		if tilt_axis.length_squared() > 0.001:  # Ensure valid axis
			tilt_axis = tilt_axis.normalized()
			var tilt_angle := angle_from_up * config.pelvis_tilt_weight
			target_tilt = Quaternion(tilt_axis, tilt_angle)

	# Smooth tilt using exponential damping (NOT raw lerp!)
	_current_pelvis_tilt = _current_pelvis_tilt.slerp(target_tilt, 1.0 - exp(-config.pelvis_tilt_speed * delta))

	# Apply rotation directly (SkeletonModifier3D processes in pipeline, no undo needed)
	var current_rot := skeleton.get_bone_pose_rotation(_pelvis_idx)
	skeleton.set_bone_pose_rotation(_pelvis_idx, current_rot * _current_pelvis_tilt)
