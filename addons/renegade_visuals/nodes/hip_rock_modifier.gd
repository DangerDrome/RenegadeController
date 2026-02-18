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
var _head_idx: int = -1
var _clavicle_l_idx: int = -1
var _clavicle_r_idx: int = -1

## Rest bases for bones.
var _pelvis_rest_basis: Basis = Basis.IDENTITY
var _spine_01_rest_basis: Basis = Basis.IDENTITY
var _spine_02_rest_basis: Basis = Basis.IDENTITY
var _spine_03_rest_basis: Basis = Basis.IDENTITY
var _clavicle_l_rest_basis: Basis = Basis.IDENTITY
var _clavicle_r_rest_basis: Basis = Basis.IDENTITY

## Smoothed lean axis to prevent snap on 180 turns.
var _current_lean_axis: Vector3 = Vector3.RIGHT
## Lean blend factor - fades out during direction changes.
var _lean_blend: float = 1.0
## Smoothed spine counter-twists to prevent jitter.
var _spine_01_twist: float = 0.0
var _spine_02_twist: float = 0.0
var _spine_03_twist: float = 0.0


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

	_head_idx = skeleton.find_bone("head")
	if _head_idx == -1:
		_head_idx = skeleton.find_bone("Head")

	_clavicle_l_idx = skeleton.find_bone("clavicle_l")
	_clavicle_r_idx = skeleton.find_bone("clavicle_r")

	# Cache rest bases
	if _pelvis_idx != -1:
		_pelvis_rest_basis = skeleton.get_bone_rest(_pelvis_idx).basis
	if _spine_01_idx != -1:
		_spine_01_rest_basis = skeleton.get_bone_rest(_spine_01_idx).basis
	if _spine_02_idx != -1:
		_spine_02_rest_basis = skeleton.get_bone_rest(_spine_02_idx).basis
	if _spine_03_idx != -1:
		_spine_03_rest_basis = skeleton.get_bone_rest(_spine_03_idx).basis
	if _clavicle_l_idx != -1:
		_clavicle_l_rest_basis = skeleton.get_bone_rest(_clavicle_l_idx).basis
	if _clavicle_r_idx != -1:
		_clavicle_r_rest_basis = skeleton.get_bone_rest(_clavicle_r_idx).basis


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

	# AAA features
	var bank_angle: float = values.get("bank_angle", 0.0)
	var sway_tilt: float = values.get("sway_tilt", 0.0)
	var breath_offset: float = values.get("breath_offset", 0.0)
	var chest_impact_offset: float = values.get("chest_impact_offset", 0.0)
	var head_impact_offset: float = values.get("head_impact_offset", 0.0)
	# Note: sway_offset is applied via _visuals.position in stride_wheel_component

	if not hip_motion_enabled:
		return

	# Apply hip rock to pelvis (gait-driven motion only, no banking here)
	# hip_rock: X=lateral tilt (roll), Y=twist (yaw), Z=forward tilt (pitch)
	if hip_rock.length() > 0.01:
		_apply_hip_rock(_pelvis_idx, hip_rock)

	# Apply turn banking and twist to SPINE (not pelvis)
	# This avoids affecting leg IK while still giving visible upper body motion
	var turn_twist: float = values.get("turn_twist", 0.0)
	var debug_banking: bool = values.get("debug_banking", false)
	if absf(bank_angle) > 0.001 or absf(turn_twist) > 0.001:
		_apply_turn_banking(bank_angle, turn_twist, debug_banking)

	# Apply idle sway tilt to SPINE (not pelvis) so leg IK stays unaffected
	# Pelvis rotation would move the entire leg chain after IK has solved
	if absf(sway_tilt) > 0.001 and _spine_01_idx != -1:
		_apply_local_sway(_spine_01_idx, sway_tilt)

	# Apply breathing as vertical offset to spine bones
	if breath_offset > 0.001:
		_apply_breath_expansion(breath_offset)

	# Apply footfall impacts as DOWNWARD offset to chest and head
	if absf(chest_impact_offset) > 0.001 or absf(head_impact_offset) > 0.001:
		# Debug output
		if debug_banking:  # Reuse existing debug flag
			print("[HIP_ROCK_MODIFIER] Applying footfall: chest=%.5f m, head=%.5f m" % [chest_impact_offset, head_impact_offset])
		_apply_footfall_impacts(chest_impact_offset, head_impact_offset)

	# Apply clavicle motion (runs after AnimationTree so it won't be overwritten)
	var clavicle_l_rot: Vector3 = values.get("clavicle_l_rotation", Vector3.ZERO)
	var clavicle_r_rot: Vector3 = values.get("clavicle_r_rotation", Vector3.ZERO)
	_apply_clavicle_rotation(clavicle_l_rot, clavicle_r_rot)

	# Apply spine counter-rotation if enabled
	# shoulder_twist is the base rotation from stride phase (in radians)
	# spine_twist_cascade controls how much twist builds up through the spine
	# shoulder_counter_rotation controls the final shoulder twist
	if shoulder_rotation_enabled:
		var delta := get_process_delta_time()
		var twist_smooth := 1.0 - exp(-2.0 * delta)  # Very slow to prevent jitter

		# Spine counter-rotation using GLOBAL pose to ensure world-space yaw
		# Work in skeleton's global space, then convert back to local

		# Spine_01: lean + small counter-twist
		if _spine_01_idx != -1:
			var target_twist := -shoulder_twist * spine_twist_cascade
			_spine_01_twist = lerpf(_spine_01_twist, target_twist, twist_smooth)
			_apply_global_yaw_and_lean(_spine_01_idx, _spine_01_twist, lean_angle, move_direction)

		# Spine_02: more counter-twist (building up through spine)
		if _spine_02_idx != -1:
			var target_twist := -shoulder_twist * spine_twist_cascade * 2.0
			_spine_02_twist = lerpf(_spine_02_twist, target_twist, twist_smooth)
			_apply_global_yaw_and_lean(_spine_02_idx, _spine_02_twist, 0.0, move_direction)

		# Spine_03: full shoulder counter-rotation
		if _spine_03_idx != -1:
			var target_twist := -shoulder_twist * shoulder_counter_rotation
			_spine_03_twist = lerpf(_spine_03_twist, target_twist, twist_smooth)
			_apply_global_yaw_and_lean(_spine_03_idx, _spine_03_twist, 0.0, move_direction)



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

	# Apply forward lean around the character's RIGHT axis (perpendicular to facing)
	# This avoids axis flip issues during 180 turns - lean is always relative to character facing
	if lean_angle != 0.0:
		# Use skeleton's right vector as lean axis (character always leans forward/back relative to facing)
		var char_right := skeleton.global_transform.basis.x.normalized()
		var lean_axis_in_skeleton := skeleton.global_transform.basis.inverse() * char_right

		if absf(lean_angle) > 0.001:
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


## Apply hip rock using BONE-LOCAL rest axes (like clavicle rotation).
## hip_rock: X=roll (lateral tilt), Y=yaw (twist), Z=pitch (forward tilt)
##
## UEFN Pelvis bone orientation (from skeleton_reference.md):
##   Local X -> Back, Local Y -> Up, Local Z -> Left
## Correct axes: Use pelvis REST basis axes, not world axes.
##   - Roll (lateral tilt): rotate around pelvis local X (forward/back axis)
##   - Yaw (twist): rotate around pelvis local Y (up axis)
##   - Pitch (forward tilt): rotate around pelvis local Z (left/right axis)
func _apply_hip_rock(bone_idx: int, hip_rock: Vector3) -> void:
	var skeleton := get_skeleton()
	if skeleton == null:
		return

	if bone_idx == -1:
		return

	# Get rest basis axes for stable rotation regardless of animation pose
	var rest_forward := -_pelvis_rest_basis.x.normalized()  # -X = forward (X points back)
	var rest_up := _pelvis_rest_basis.y.normalized()        # Y = up
	var rest_right := -_pelvis_rest_basis.z.normalized()    # -Z = right (Z points left)

	# Get current pose and apply rotations additively
	var current_pose := skeleton.get_bone_pose(bone_idx)
	var rot_basis := current_pose.basis

	# hip_rock: X=roll (lateral tilt), Y=yaw (twist), Z=pitch (forward tilt)

	if hip_rock.y != 0.0:  # Yaw (twist around up axis)
		rot_basis = rot_basis.rotated(rest_up, hip_rock.y)

	if hip_rock.x != 0.0:  # Roll (lateral tilt) - around forward/back axis
		rot_basis = rot_basis.rotated(rest_forward, hip_rock.x)

	if hip_rock.z != 0.0:  # Pitch (forward tilt) - around left/right axis
		rot_basis = rot_basis.rotated(rest_right, hip_rock.z)

	skeleton.set_bone_pose(bone_idx, Transform3D(rot_basis, current_pose.origin))


## Apply sway tilt as LOCAL bone rotation (avoids gimbal coupling from world-space)
## Sway is a lateral roll that rocks the hips side-to-side during idle.
func _apply_local_sway(bone_idx: int, sway_angle: float) -> void:
	var skeleton := get_skeleton()
	if skeleton == null:
		return

	# Get current local pose
	var local_pose := skeleton.get_bone_pose(bone_idx)

	# Apply roll rotation in LOCAL bone space (around local Z axis for pelvis)
	# This avoids gimbal coupling because we're not converting through world space
	var sway_rotation := Basis(Vector3.FORWARD, sway_angle)
	var new_basis := local_pose.basis * sway_rotation

	skeleton.set_bone_pose(bone_idx, Transform3D(new_basis, local_pose.origin))


## Apply breathing expansion as vertical offset distributed across spine bones.
## For UEFN skeleton, bone-local Y axis points along the spine (toward next bone).
func _apply_breath_expansion(breath_amount: float) -> void:
	var skeleton := get_skeleton()
	if skeleton == null:
		return

	# Use bone-local Y axis (along spine direction) for expansion
	# This creates chest rise effect without lateral drift
	# Distribute breath across spine bones (more expansion higher up the spine)
	if _spine_01_idx != -1:
		var pose := skeleton.get_bone_pose(_spine_01_idx)
		var new_origin := pose.origin + Vector3(0.0, breath_amount * 0.3, 0.0)
		skeleton.set_bone_pose(_spine_01_idx, Transform3D(pose.basis, new_origin))

	if _spine_02_idx != -1:
		var pose := skeleton.get_bone_pose(_spine_02_idx)
		var new_origin := pose.origin + Vector3(0.0, breath_amount * 0.4, 0.0)
		skeleton.set_bone_pose(_spine_02_idx, Transform3D(pose.basis, new_origin))

	if _spine_03_idx != -1:
		var pose := skeleton.get_bone_pose(_spine_03_idx)
		var new_origin := pose.origin + Vector3(0.0, breath_amount * 0.3, 0.0)
		skeleton.set_bone_pose(_spine_03_idx, Transform3D(pose.basis, new_origin))


## Apply footfall impact offsets to chest and head bones.
## This creates the signature AAA weight sensation - chest/head drop on foot plants.
func _apply_footfall_impacts(chest_impact: float, head_impact: float) -> void:
	var skeleton := get_skeleton()
	if skeleton == null:
		print("[HIP_ROCK_MODIFIER] ERROR: No skeleton!")
		return

	# Apply chest impact to upper spine (spine_02 and spine_03)
	# Negative offset = downward drop
	if absf(chest_impact) > 0.001:
		if _spine_02_idx != -1:
			var pose := skeleton.get_bone_pose(_spine_02_idx)
			var new_origin := pose.origin + Vector3(0.0, chest_impact * 0.5, 0.0)
			skeleton.set_bone_pose(_spine_02_idx, Transform3D(pose.basis, new_origin))
		else:
			print("[HIP_ROCK_MODIFIER] WARNING: spine_02_idx not found!")

		if _spine_03_idx != -1:
			var pose := skeleton.get_bone_pose(_spine_03_idx)
			var new_origin := pose.origin + Vector3(0.0, chest_impact * 0.5, 0.0)
			skeleton.set_bone_pose(_spine_03_idx, Transform3D(pose.basis, new_origin))
		else:
			print("[HIP_ROCK_MODIFIER] WARNING: spine_03_idx not found!")

	# Apply head impact to head bone
	# Negative offset = downward drop
	if absf(head_impact) > 0.001 and _head_idx != -1:
		var pose := skeleton.get_bone_pose(_head_idx)
		var new_origin := pose.origin + Vector3(0.0, head_impact, 0.0)
		skeleton.set_bone_pose(_head_idx, Transform3D(pose.basis, new_origin))
	elif absf(head_impact) > 0.001:
		print("[HIP_ROCK_MODIFIER] WARNING: head_idx not found!")


## Apply clavicle rotation for shoulder blade motion during arm swing.
## left_rot/right_rot: X=protraction (forward rotation), Y=elevation (shoulder lift)
##
## UEFN Clavicle bone orientation (from skeleton_reference.md):
##   clavicle_l: Local X -> Forward, Local Y -> Up, Local Z -> Right
##   clavicle_r: Local X -> Forward, Local Y -> DOWN (mirrored), Local Z -> LEFT (mirrored)
##
## Correct axes: Use BONE-LOCAL axes, not world axes.
## Clavicle points outward from chest, so world axes don't map to anatomical motion.
##   - Protraction (shoulder forward/back): rotate around bone's local Z (lateral axis)
##   - Elevation (shoulder up/down): rotate around bone's local Y (up axis)
##   - Apply ADDITIVELY on top of current animation pose
func _apply_clavicle_rotation(left_rot: Vector3, right_rot: Vector3) -> void:
	var skeleton := get_skeleton()
	if skeleton == null:
		return

	# Skip if rotations are negligible
	if left_rot.length_squared() < 0.0001 and right_rot.length_squared() < 0.0001:
		return

	# Left clavicle - use REST basis axes for consistent rotation regardless of animation
	if _clavicle_l_idx != -1 and left_rot.length_squared() > 0.0001:
		var current_pose := skeleton.get_bone_pose(_clavicle_l_idx)
		# Use rest basis for stable axes (animation can skew current pose axes)
		var rest_up := _clavicle_l_rest_basis.y.normalized()      # Rest local Y = up
		var rest_right := _clavicle_l_rest_basis.z.normalized()   # Rest local Z = right

		var rot_basis := current_pose.basis
		rot_basis = rot_basis.rotated(rest_right, left_rot.x)  # Protraction around lateral axis
		rot_basis = rot_basis.rotated(rest_up, left_rot.y)     # Elevation around up axis
		skeleton.set_bone_pose(_clavicle_l_idx, Transform3D(rot_basis, current_pose.origin))

	# Right clavicle - phase calculation already makes it opposite, no negation needed
	if _clavicle_r_idx != -1 and right_rot.length_squared() > 0.0001:
		var current_pose := skeleton.get_bone_pose(_clavicle_r_idx)
		var rest_up := _clavicle_r_rest_basis.y.normalized()
		var rest_right := _clavicle_r_rest_basis.z.normalized()

		var rot_basis := current_pose.basis
		rot_basis = rot_basis.rotated(rest_right, right_rot.x)  # Protraction (phase handles opposition)
		rot_basis = rot_basis.rotated(rest_up, right_rot.y)     # Elevation
		skeleton.set_bone_pose(_clavicle_r_idx, Transform3D(rot_basis, current_pose.origin))


## Apply turn banking (lateral lean) and twist (torso rotation) to spine bones.
## Banking = lean INTO turns (like a motorcycle). Twist = rotate torso into turn.
## Applied to spine bones, not pelvis, to avoid affecting leg IK.
func _apply_turn_banking(bank_angle: float, turn_twist: float, debug: bool) -> void:
	var skeleton := get_skeleton()
	if skeleton == null:
		return

	# Skeleton-space axes for rotation (swapped based on testing)
	# BACK = yaw/twist, UP = lateral lean (roll)
	var twist_axis := Vector3.BACK  # Z axis for twist
	var bank_axis := Vector3.UP     # Y axis for lateral lean

	# Distribute across spine bones (more effect higher up)
	var spine_weights := [0.3, 0.4, 0.3]  # spine_01, spine_02, spine_03
	var spine_indices := [_spine_01_idx, _spine_02_idx, _spine_03_idx]

	for i in range(3):
		var bone_idx: int = spine_indices[i]
		if bone_idx == -1:
			continue

		var weight: float = spine_weights[i]

		# Get current global pose
		var global_pose := skeleton.get_bone_global_pose(bone_idx)
		var new_global_basis := global_pose.basis

		# Apply TWIST (rotation around UP axis = yaw)
		if absf(turn_twist) > 0.001:
			var bone_twist: float = turn_twist * weight
			var twist_rotation := Basis(twist_axis, bone_twist)
			new_global_basis = twist_rotation * new_global_basis

		# Apply BANK (rotation around Z axis = roll/lateral lean)
		if absf(bank_angle) > 0.001:
			var bone_bank: float = bank_angle * weight
			var bank_rotation := Basis(bank_axis, bone_bank)
			new_global_basis = bank_rotation * new_global_basis

		# Convert back to local pose
		var parent_idx := skeleton.get_bone_parent(bone_idx)
		var parent_global: Transform3D
		if parent_idx != -1:
			parent_global = skeleton.get_bone_global_pose(parent_idx)
		else:
			parent_global = Transform3D.IDENTITY

		var new_local := parent_global.affine_inverse() * Transform3D(new_global_basis, global_pose.origin)
		skeleton.set_bone_pose(bone_idx, new_local)

	# Debug visualization
	if debug and _spine_02_idx != -1:
		_draw_bank_debug(bank_angle, turn_twist)


## Debug visualization for turn banking.
var _bank_debug_node: Node3D = null
var _bank_debug_mesh: MeshInstance3D = null

func _draw_bank_debug(bank_angle: float, turn_twist: float) -> void:
	var skeleton := get_skeleton()
	if skeleton == null:
		return

	# Create debug node as child of skeleton - it will be positioned at spine each frame
	if _bank_debug_node == null:
		_bank_debug_node = Node3D.new()
		_bank_debug_node.name = "BankDebug"
		skeleton.get_parent().add_child(_bank_debug_node)

		_bank_debug_mesh = MeshInstance3D.new()
		var im := ImmediateMesh.new()
		_bank_debug_mesh.mesh = im
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.vertex_color_use_as_albedo = true
		mat.no_depth_test = true
		_bank_debug_mesh.material_override = mat
		_bank_debug_node.add_child(_bank_debug_mesh)

	# Position debug node at spine_02 world position, facing character forward
	var spine_global := skeleton.global_transform * skeleton.get_bone_global_pose(_spine_02_idx)
	_bank_debug_node.global_position = spine_global.origin
	# Match character rotation so local Z is forward
	_bank_debug_node.global_rotation.y = skeleton.global_rotation.y

	# Draw in local space - Z is forward, X is right, Y is up
	var im := _bank_debug_mesh.mesh as ImmediateMesh
	im.clear_surfaces()
	im.surface_begin(Mesh.PRIMITIVE_LINES)

	# Vertical reference line (green) - local up
	im.surface_set_color(Color.GREEN)
	im.surface_add_vertex(Vector3.ZERO)
	im.surface_add_vertex(Vector3.UP * 0.5)

	# Bank indicator (cyan) - shows lateral lean
	# Rotated around forward axis, negate for correct direction
	var bank_dir := Vector3.UP.rotated(Vector3.BACK, -bank_angle)
	im.surface_set_color(Color.CYAN)
	im.surface_add_vertex(Vector3.ZERO)
	im.surface_add_vertex(bank_dir * 0.5)

	# Twist indicator (magenta) - shows forward direction rotated by twist
	# Rotated around up axis
	var twist_dir := Vector3.BACK.rotated(Vector3.UP, turn_twist)
	im.surface_set_color(Color.MAGENTA)
	im.surface_add_vertex(Vector3.ZERO)
	im.surface_add_vertex(twist_dir * 0.4)

	# Forward reference (white) - shows unrotated forward
	im.surface_set_color(Color.WHITE)
	im.surface_add_vertex(Vector3.ZERO)
	im.surface_add_vertex(Vector3.BACK * 0.3)

	# Horizontal reference (red) - shows left/right
	im.surface_set_color(Color.RED)
	im.surface_add_vertex(Vector3.LEFT * 0.3)
	im.surface_add_vertex(Vector3.RIGHT * 0.3)

	im.surface_end()
