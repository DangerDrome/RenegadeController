## Utility tool to analyze skeleton bone orientations and save to reference file.
## Attach to a Skeleton3D node and run analyze() to dump bone data.
## Usage: Call from editor or add to scene temporarily.
@tool
class_name SkeletonAnalyzer
extends Node

## The skeleton to analyze.
@export var skeleton: Skeleton3D

## Output path for the reference file.
@export_file("*.md") var output_path: String = "res://addons/renegade_visuals/docs/skeleton_reference.md"

## Analyze skeleton and print to console.
@export var analyze_now: bool = false:
	set(value):
		if value and skeleton:
			var output := analyze()
			print(output)
			analyze_now = false

## Analyze and save to file.
@export var save_to_file: bool = false:
	set(value):
		if value and skeleton:
			var output := analyze()
			save_reference(output)
			print("Saved skeleton reference to: ", output_path)
			save_to_file = false

## Print detailed bone axes to console (for quick runtime debugging).
@export var print_bone_axes: bool = false:
	set(value):
		if value and skeleton:
			_print_bone_axes()
			print_bone_axes = false


func analyze() -> String:
	if skeleton == null:
		return "ERROR: No skeleton assigned"

	var lines: PackedStringArray = []
	lines.append("# Skeleton Bone Reference")
	lines.append("")
	lines.append("Generated from: %s" % skeleton.name)
	lines.append("Bone count: %d" % skeleton.get_bone_count())
	lines.append("")
	lines.append("## Axis Convention")
	lines.append("")
	lines.append("For each bone, we show:")
	lines.append("- **Rest Transform**: Position and rotation in parent bone space")
	lines.append("- **Local Axes**: Which direction each axis points (X=red, Y=green, Z=blue)")
	lines.append("- **Bone Direction**: Which axis the bone points along (toward child)")
	lines.append("- **Twist Axis**: Which axis to rotate around for twist/roll")
	lines.append("")
	lines.append("## Important Bones for IK")
	lines.append("")

	# Key bones we care about for procedural animation
	var key_bones := [
		"root", "pelvis", "spine_01", "spine_02", "spine_03", "spine_04", "spine_05",
		"neck_01", "neck_02", "head",
		"clavicle_l", "upperarm_l", "lowerarm_l", "hand_l",
		"clavicle_r", "upperarm_r", "lowerarm_r", "hand_r",
		"thigh_l", "calf_l", "foot_l", "ball_l",
		"thigh_r", "calf_r", "foot_r", "ball_r",
		# Alternative naming conventions
		"Hips", "Spine", "Spine1", "Spine2", "Chest", "UpperChest",
		"Neck", "Head",
		"LeftShoulder", "LeftUpperArm", "LeftLowerArm", "LeftHand",
		"RightShoulder", "RightUpperArm", "RightLowerArm", "RightHand",
		"LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "LeftToes",
		"RightUpperLeg", "RightLowerLeg", "RightFoot", "RightToes",
	]

	# First pass: collect all bone names
	var all_bones: Array[String] = []
	for i in range(skeleton.get_bone_count()):
		all_bones.append(skeleton.get_bone_name(i))

	# Analyze key bones first
	lines.append("### Key Bones")
	lines.append("")
	for bone_name in key_bones:
		var idx := skeleton.find_bone(bone_name)
		if idx != -1:
			lines.append(_analyze_bone(idx))
			lines.append("")

	# Full bone list
	lines.append("## All Bones")
	lines.append("")
	lines.append("| Index | Name | Parent | Position | Rotation (Euler°) | Bone Dir | Twist Axis |")
	lines.append("|-------|------|--------|----------|-------------------|----------|------------|")

	for i in range(skeleton.get_bone_count()):
		lines.append(_analyze_bone_row(i))

	lines.append("")
	lines.append("## Bone Hierarchy")
	lines.append("")
	lines.append("```")
	lines.append(_build_hierarchy_tree())
	lines.append("```")

	lines.append("")
	lines.append("## Rotation Axis Guide")
	lines.append("")
	lines.append("Based on analysis, use these axes for procedural animation:")
	lines.append("")
	lines.append(_generate_axis_guide())

	return "\n".join(lines)


func _analyze_bone(idx: int) -> String:
	var name := skeleton.get_bone_name(idx)
	var rest := skeleton.get_bone_rest(idx)
	var parent_idx := skeleton.get_bone_parent(idx)
	var parent_name := skeleton.get_bone_name(parent_idx) if parent_idx != -1 else "(root)"

	var pos := rest.origin
	var basis := rest.basis
	var euler := basis.get_euler() * (180.0 / PI)  # Convert to degrees

	# Determine which axis the bone points along (toward child)
	var bone_dir := _get_bone_direction(idx)
	var twist_axis := _get_twist_axis(idx)

	var lines: PackedStringArray = []
	lines.append("#### %s (index %d)" % [name, idx])
	lines.append("- Parent: %s" % parent_name)
	lines.append("- Position: (%.3f, %.3f, %.3f)" % [pos.x, pos.y, pos.z])
	lines.append("- Rotation: (%.1f°, %.1f°, %.1f°)" % [euler.x, euler.y, euler.z])
	lines.append("- Local X axis (red): %s" % _vec_to_dir(basis.x))
	lines.append("- Local Y axis (green): %s" % _vec_to_dir(basis.y))
	lines.append("- Local Z axis (blue): %s" % _vec_to_dir(basis.z))
	lines.append("- **Bone direction**: %s" % bone_dir)
	lines.append("- **Twist axis**: %s" % twist_axis)

	return "\n".join(lines)


func _analyze_bone_row(idx: int) -> String:
	var name := skeleton.get_bone_name(idx)
	var rest := skeleton.get_bone_rest(idx)
	var parent_idx := skeleton.get_bone_parent(idx)
	var parent_name := skeleton.get_bone_name(parent_idx) if parent_idx != -1 else "-"

	var pos := rest.origin
	var euler := rest.basis.get_euler() * (180.0 / PI)

	var bone_dir := _get_bone_direction(idx)
	var twist_axis := _get_twist_axis(idx)

	return "| %d | %s | %s | (%.2f, %.2f, %.2f) | (%.0f, %.0f, %.0f) | %s | %s |" % [
		idx, name, parent_name,
		pos.x, pos.y, pos.z,
		euler.x, euler.y, euler.z,
		bone_dir, twist_axis
	]


func _get_bone_direction(idx: int) -> String:
	# Find child bones to determine bone direction
	var children: Array[int] = []
	for i in range(skeleton.get_bone_count()):
		if skeleton.get_bone_parent(i) == idx:
			children.append(i)

	if children.is_empty():
		return "leaf"

	# Get direction to first child in rest pose
	var rest := skeleton.get_bone_rest(idx)
	var child_rest := skeleton.get_bone_rest(children[0])
	var child_pos := child_rest.origin

	# Determine which local axis points toward child
	var basis := rest.basis
	var to_child := child_pos.normalized()

	var dots := [
		absf(to_child.dot(Vector3.RIGHT)),   # X
		absf(to_child.dot(Vector3.UP)),      # Y
		absf(to_child.dot(Vector3.FORWARD)), # Z
	]

	var max_idx := dots.find(dots.max())
	var sign_val := 1.0 if to_child[max_idx] > 0 else -1.0

	match max_idx:
		0: return "+X" if sign_val > 0 else "-X"
		1: return "+Y" if sign_val > 0 else "-Y"
		2: return "+Z" if sign_val > 0 else "-Z"

	return "?"


func _get_twist_axis(idx: int) -> String:
	# Twist axis is typically the bone direction axis
	var bone_dir := _get_bone_direction(idx)
	if bone_dir == "leaf":
		# For leaf bones, inherit from parent or assume Y
		var parent_idx := skeleton.get_bone_parent(idx)
		if parent_idx != -1:
			return _get_twist_axis(parent_idx)
		return "Y"

	# Twist axis is the same as bone direction
	return bone_dir.replace("+", "").replace("-", "")


func _vec_to_dir(v: Vector3) -> String:
	# Convert a basis vector to a readable direction
	var dirs := []
	if absf(v.x) > 0.5:
		dirs.append("+X" if v.x > 0 else "-X")
	if absf(v.y) > 0.5:
		dirs.append("+Y" if v.y > 0 else "-Y")
	if absf(v.z) > 0.5:
		dirs.append("+Z" if v.z > 0 else "-Z")

	if dirs.is_empty():
		return "(%.2f, %.2f, %.2f)" % [v.x, v.y, v.z]
	return ", ".join(dirs)


func _build_hierarchy_tree() -> String:
	var lines: PackedStringArray = []

	# Find root bones (no parent)
	for i in range(skeleton.get_bone_count()):
		if skeleton.get_bone_parent(i) == -1:
			_add_bone_to_tree(i, 0, lines)

	return "\n".join(lines)


func _add_bone_to_tree(idx: int, depth: int, lines: PackedStringArray) -> void:
	var indent := "  ".repeat(depth)
	var name := skeleton.get_bone_name(idx)
	var twist := _get_twist_axis(idx)
	lines.append("%s├─ %s [twist: %s]" % [indent, name, twist])

	# Find and add children
	for i in range(skeleton.get_bone_count()):
		if skeleton.get_bone_parent(i) == idx:
			_add_bone_to_tree(i, depth + 1, lines)


func _generate_axis_guide() -> String:
	var lines: PackedStringArray = []

	# Check pelvis
	var pelvis_idx := skeleton.find_bone("pelvis")
	if pelvis_idx == -1:
		pelvis_idx = skeleton.find_bone("Hips")

	if pelvis_idx != -1:
		var twist := _get_twist_axis(pelvis_idx)
		lines.append("### Pelvis/Hips")
		lines.append("- Twist axis: **%s**" % twist)
		lines.append("- For hip rock Y (twist), rotate around: **%s**" % twist)
		lines.append("")

	# Check spine
	var spine_idx := skeleton.find_bone("spine_01")
	if spine_idx == -1:
		spine_idx = skeleton.find_bone("Spine")

	if spine_idx != -1:
		var twist := _get_twist_axis(spine_idx)
		lines.append("### Spine")
		lines.append("- Twist axis: **%s**" % twist)
		lines.append("- For shoulder counter-rotation, rotate around: **%s**" % twist)
		lines.append("")

	# Check thigh
	var thigh_idx := skeleton.find_bone("thigh_l")
	if thigh_idx == -1:
		thigh_idx = skeleton.find_bone("LeftUpperLeg")

	if thigh_idx != -1:
		var twist := _get_twist_axis(thigh_idx)
		var bone_dir := _get_bone_direction(thigh_idx)
		lines.append("### Legs")
		lines.append("- Bone direction: **%s** (points toward knee)" % bone_dir)
		lines.append("- Twist axis: **%s**" % twist)
		lines.append("")

	return "\n".join(lines)


func save_reference(content: String) -> void:
	var dir_path := output_path.get_base_dir()
	DirAccess.make_dir_recursive_absolute(dir_path.replace("res://", ""))

	var file := FileAccess.open(output_path, FileAccess.WRITE)
	if file:
		file.store_string(content)
		file.close()
	else:
		push_error("Failed to save skeleton reference to: %s" % output_path)


## Print detailed bone axes to console (runtime debugging version).
## Moved from StrideWheelComponent to centralize skeleton analysis tools.
func _print_bone_axes() -> void:
	if skeleton == null:
		print("ERROR: No skeleton to analyze")
		return

	print("=" .repeat(70))
	print("COMPLETE BONE AXIS REFERENCE (for IK/procedural rotations)")
	print("See: addons/renegade_visuals/docs/skeleton_reference.md")
	print("=" .repeat(70))

	# Core bones to analyze
	var key_bones := [
		# Spine chain
		"root", "pelvis", "spine_01", "spine_02", "spine_03",
		# Neck and head
		"neck_01", "neck_02", "head",
		# Left arm chain
		"clavicle_l", "upperarm_l", "upperarm_twist_01_l", "lowerarm_l", "lowerarm_twist_01_l", "hand_l",
		# Right arm chain
		"clavicle_r", "upperarm_r", "upperarm_twist_01_r", "lowerarm_r", "lowerarm_twist_01_r", "hand_r",
		# Left leg chain
		"thigh_l", "thigh_twist_01_l", "calf_l", "calf_twist_01_l", "foot_l", "ball_l",
		# Right leg chain
		"thigh_r", "thigh_twist_01_r", "calf_r", "calf_twist_01_r", "foot_r", "ball_r",
		# Fingers (just index for reference)
		"index_01_l", "index_01_r",
	]

	for bone_name in key_bones:
		var idx := skeleton.find_bone(bone_name)
		if idx == -1:
			continue

		var rest := skeleton.get_bone_rest(idx)
		var basis := rest.basis
		var euler := basis.get_euler() * (180.0 / PI)

		var bone_dir := _get_bone_direction(idx)

		print("")
		print("%s (idx=%d):" % [skeleton.get_bone_name(idx), idx])
		print("  Rest euler: (%.1f°, %.1f°, %.1f°)" % [euler.x, euler.y, euler.z])
		print("  Local X -> %s" % _basis_axis_to_world_dir(basis.x))
		print("  Local Y -> %s" % _basis_axis_to_world_dir(basis.y))
		print("  Local Z -> %s" % _basis_axis_to_world_dir(basis.z))
		print("  Bone points along: %s" % bone_dir)

		# Provide rotation recommendations based on bone orientation
		var twist_axis := _get_twist_axis_recommendation(basis)
		var pitch_axis := _get_pitch_axis_recommendation(basis)
		var roll_axis := _get_roll_axis_recommendation(basis)
		print("  TWIST (yaw): %s" % twist_axis)
		print("  PITCH (nod): %s" % pitch_axis)
		print("  ROLL (tilt): %s" % roll_axis)

	print("")
	print("=" .repeat(70))
	print("ROTATION AXIS GUIDE:")
	print("  TWIST = rotation around vertical (world up) axis")
	print("  PITCH = rotation around lateral (world right) axis")
	print("  ROLL  = rotation around forward (world forward) axis")
	print("")
	print("Use Vector3.UP/RIGHT/FORWARD with Basis.rotated() for world-aligned rotation")
	print("=" .repeat(70))


## Get recommended axis for twist/yaw rotation (around world up).
func _get_twist_axis_recommendation(basis: Basis) -> String:
	var x_up := absf(basis.x.dot(Vector3.UP))
	var y_up := absf(basis.y.dot(Vector3.UP))
	var z_up := absf(basis.z.dot(Vector3.UP))

	if y_up > x_up and y_up > z_up:
		return "Vector3.UP (local Y ≈ world up, %.0f%%)" % [y_up * 100]
	elif x_up > y_up and x_up > z_up:
		return "Vector3.RIGHT (local X ≈ world up, %.0f%%)" % [x_up * 100]
	else:
		return "Vector3.FORWARD (local Z ≈ world up, %.0f%%)" % [z_up * 100]


## Get recommended axis for pitch rotation (around world right).
func _get_pitch_axis_recommendation(basis: Basis) -> String:
	var x_right := absf(basis.x.dot(Vector3.RIGHT))
	var y_right := absf(basis.y.dot(Vector3.RIGHT))
	var z_right := absf(basis.z.dot(Vector3.RIGHT))

	if x_right > y_right and x_right > z_right:
		return "Vector3.RIGHT (local X ≈ world right, %.0f%%)" % [x_right * 100]
	elif y_right > x_right and y_right > z_right:
		return "Vector3.UP (local Y ≈ world right, %.0f%%)" % [y_right * 100]
	else:
		return "Vector3.FORWARD (local Z ≈ world right, %.0f%%)" % [z_right * 100]


## Get recommended axis for roll rotation (around world forward).
func _get_roll_axis_recommendation(basis: Basis) -> String:
	# Note: Godot uses -Z as forward, so we check against BACK (positive Z)
	var x_fwd := absf(basis.x.dot(Vector3.BACK))
	var y_fwd := absf(basis.y.dot(Vector3.BACK))
	var z_fwd := absf(basis.z.dot(Vector3.BACK))

	if z_fwd > x_fwd and z_fwd > y_fwd:
		return "Vector3.FORWARD (local Z ≈ world forward, %.0f%%)" % [z_fwd * 100]
	elif x_fwd > y_fwd and x_fwd > z_fwd:
		return "Vector3.RIGHT (local X ≈ world forward, %.0f%%)" % [x_fwd * 100]
	else:
		return "Vector3.UP (local Y ≈ world forward, %.0f%%)" % [y_fwd * 100]


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
