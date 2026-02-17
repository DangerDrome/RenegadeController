## SkeletonModifier3D that applies procedural hip rock AFTER animation.
## This runs in the skeleton modifier chain, so it won't be overwritten by AnimationTree.
class_name HipRockModifier
extends SkeletonModifier3D

## The StrideWheelComponent that provides hip rock values.
var stride_wheel: Node

## Cached bone indices.
var _pelvis_idx: int = -1
var _spine_01_idx: int = -1
var _spine_02_idx: int = -1
var _spine_03_idx: int = -1

## Rest bases for bones.
var _pelvis_rest_basis: Basis = Basis.IDENTITY
var _spine_01_rest_basis: Basis = Basis.IDENTITY
var _spine_02_rest_basis: Basis = Basis.IDENTITY
var _spine_03_rest_basis: Basis = Basis.IDENTITY


func _ready() -> void:
	# Find stride wheel component - it's a sibling of CharacterVisuals root
	# Navigate up: Skeleton3D -> UEFN -> CharacterVisuals
	var char_visuals := _find_character_visuals()
	if char_visuals:
		for child in char_visuals.get_children():
			if child.has_method("get_hip_rock_values"):
				stride_wheel = child
				break

	# Cache bone indices
	var skeleton := get_skeleton()
	if skeleton:
		_cache_bones(skeleton)


func _find_character_visuals() -> Node:
	# Navigate up to find the CharacterVisuals node
	var current := get_parent()
	while current:
		if current.get_script() and current.has_method("get_skeleton"):
			return current
		# Also check if this is the CharacterVisuals by checking for StrideWheel child
		for child in current.get_children():
			if child.has_method("get_hip_rock_values"):
				return current
		current = current.get_parent()
	return null


func _cache_bones(skeleton: Skeleton3D) -> void:
	# Try common bone names
	_pelvis_idx = skeleton.find_bone("pelvis")
	if _pelvis_idx == -1:
		_pelvis_idx = skeleton.find_bone("Hips")
	if _pelvis_idx == -1:
		_pelvis_idx = skeleton.find_bone("hips")

	_spine_01_idx = skeleton.find_bone("spine_01")
	if _spine_01_idx == -1:
		_spine_01_idx = skeleton.find_bone("Spine")

	_spine_02_idx = skeleton.find_bone("spine_02")
	_spine_03_idx = skeleton.find_bone("spine_03")

	# Cache rest bases
	if _pelvis_idx != -1:
		_pelvis_rest_basis = skeleton.get_bone_rest(_pelvis_idx).basis
	if _spine_01_idx != -1:
		_spine_01_rest_basis = skeleton.get_bone_rest(_spine_01_idx).basis
	if _spine_02_idx != -1:
		_spine_02_rest_basis = skeleton.get_bone_rest(_spine_02_idx).basis
	if _spine_03_idx != -1:
		_spine_03_rest_basis = skeleton.get_bone_rest(_spine_03_idx).basis


func _process_modification() -> void:
	if stride_wheel == null:
		# Try to find stride wheel again (might not have been ready before)
		var char_visuals := _find_character_visuals()
		if char_visuals:
			for child in char_visuals.get_children():
				if child.has_method("get_hip_rock_values"):
					stride_wheel = child
					break
		if stride_wheel == null:
			return

	if _pelvis_idx == -1:
		var skeleton := get_skeleton()
		if skeleton:
			_cache_bones(skeleton)
		if _pelvis_idx == -1:
			return

	var skeleton := get_skeleton()
	if skeleton == null:
		return

	# Get values from stride wheel
	if not stride_wheel.has_method("get_hip_rock_values"):
		return

	var values: Dictionary = stride_wheel.get_hip_rock_values()
	var hip_rock: Vector3 = values.get("hip_rock", Vector3.ZERO)
	var hip_motion_enabled: bool = values.get("hip_motion_enabled", true)

	var shoulder_rotation_enabled: bool = values.get("shoulder_rotation_enabled", false)
	var spine_twist_cascade: float = values.get("spine_twist_cascade", 0.3)
	var shoulder_counter_rotation: float = values.get("shoulder_counter_rotation", 0.7)
	var shoulder_twist: float = values.get("shoulder_twist", 0.0)  # Pre-calculated, in radians
	var lean_angle: float = values.get("lean_angle", 0.0)
	var move_direction: Vector3 = values.get("move_direction", Vector3.ZERO)

	if not hip_motion_enabled:
		return

	# Apply hip rock to pelvis using world-space axes
	# hip_rock: X=lateral tilt (roll), Y=twist (yaw), Z=forward tilt (pitch)
	if hip_rock != Vector3.ZERO:
		_apply_hip_rock(_pelvis_idx, hip_rock)

	# Apply spine counter-rotation if enabled
	# shoulder_twist is the base rotation from stride phase (in radians)
	# spine_twist_cascade controls how much twist builds up through the spine
	# shoulder_counter_rotation controls the final shoulder twist
	if shoulder_rotation_enabled and shoulder_twist != 0.0:

		# Spine counter-rotation using GLOBAL pose to ensure world-space yaw
		# Work in skeleton's global space, then convert back to local

		# Spine_01: lean + small counter-twist
		if _spine_01_idx != -1:
			var counter_twist := -shoulder_twist * spine_twist_cascade
			_apply_global_yaw_and_lean(_spine_01_idx, counter_twist, lean_angle, move_direction)

		# Spine_02: more counter-twist (building up through spine)
		if _spine_02_idx != -1:
			var counter_twist := -shoulder_twist * spine_twist_cascade * 2.0
			_apply_global_yaw_and_lean(_spine_02_idx, counter_twist, 0.0, move_direction)

		# Spine_03: full shoulder counter-rotation
		if _spine_03_idx != -1:
			var counter_twist := -shoulder_twist * shoulder_counter_rotation
			_apply_global_yaw_and_lean(_spine_03_idx, counter_twist, 0.0, move_direction)


## Apply yaw and lean rotation in TRUE world space (accounting for skeleton rotation)
## Lean is applied around the axis perpendicular to movement direction.
func _apply_global_yaw_and_lean(bone_idx: int, yaw_angle: float, lean_angle: float, move_dir: Vector3) -> void:
	var skeleton := get_skeleton()
	if skeleton == null:
		return

	# Get world UP in skeleton's local coordinate system
	# This accounts for any rotation on the skeleton node itself
	var world_up_in_skeleton := skeleton.global_transform.basis.inverse() * Vector3.UP

	# Get current global pose (in skeleton space)
	var global_pose := skeleton.get_bone_global_pose(bone_idx)

	# Create yaw rotation around WORLD up (converted to skeleton space)
	var yaw_rotation := Basis(world_up_in_skeleton.normalized(), yaw_angle)

	# Apply yaw in skeleton-global space
	var new_global_basis := yaw_rotation * global_pose.basis

	# Apply forward lean around axis perpendicular to movement direction
	# Lean axis = cross product of UP and move_dir (gives us the "right" relative to movement)
	if lean_angle != 0.0 and move_dir.length_squared() > 0.001:
		# Calculate lean axis: perpendicular to both UP and movement direction
		var lean_axis_world := Vector3.UP.cross(move_dir).normalized()
		var lean_axis_in_skeleton := skeleton.global_transform.basis.inverse() * lean_axis_world
		var lean_rotation := Basis(lean_axis_in_skeleton.normalized(), lean_angle)
		new_global_basis = lean_rotation * new_global_basis

	# Convert back to local pose relative to parent
	var parent_idx := skeleton.get_bone_parent(bone_idx)
	var parent_global: Transform3D
	if parent_idx != -1:
		parent_global = skeleton.get_bone_global_pose(parent_idx)
	else:
		parent_global = Transform3D.IDENTITY

	# Compute local pose from new global pose
	var new_local := parent_global.affine_inverse() * Transform3D(new_global_basis, global_pose.origin)
	skeleton.set_bone_pose(bone_idx, new_local)


## Apply hip rock using TRUE world-space axes (accounting for skeleton rotation)
## hip_rock: X=roll (lateral tilt), Y=yaw (twist), Z=pitch (forward tilt)
func _apply_hip_rock(bone_idx: int, hip_rock: Vector3) -> void:
	var skeleton := get_skeleton()
	if skeleton == null:
		return

	# Get world axes in skeleton's local coordinate system
	var world_up := skeleton.global_transform.basis.inverse() * Vector3.UP
	var world_right := skeleton.global_transform.basis.inverse() * Vector3.RIGHT
	var world_forward := skeleton.global_transform.basis.inverse() * Vector3.FORWARD

	# Get current global pose
	var global_pose := skeleton.get_bone_global_pose(bone_idx)

	# Build rotation from hip_rock components using world axes
	# X = roll (around forward axis), Y = yaw (around up axis), Z = pitch (around right axis)
	var result_basis := global_pose.basis

	if hip_rock.y != 0.0:  # Yaw (twist) - most important for walk
		var yaw_rotation := Basis(world_up.normalized(), hip_rock.y)
		result_basis = yaw_rotation * result_basis

	if hip_rock.x != 0.0:  # Roll (lateral tilt)
		var roll_rotation := Basis(world_forward.normalized(), hip_rock.x)
		result_basis = roll_rotation * result_basis

	if hip_rock.z != 0.0:  # Pitch (forward tilt)
		var pitch_rotation := Basis(world_right.normalized(), hip_rock.z)
		result_basis = pitch_rotation * result_basis

	# Convert back to local pose
	var parent_idx := skeleton.get_bone_parent(bone_idx)
	var parent_global: Transform3D
	if parent_idx != -1:
		parent_global = skeleton.get_bone_global_pose(parent_idx)
	else:
		parent_global = Transform3D.IDENTITY

	var new_local := parent_global.affine_inverse() * Transform3D(result_basis, global_pose.origin)
	skeleton.set_bone_pose(bone_idx, new_local)
