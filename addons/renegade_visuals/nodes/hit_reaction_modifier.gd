## Procedural hit reaction using SkeletonModifier3D.
## Applies rotational impulses to bones that decay over time.
class_name HitReactionModifier
extends SkeletonModifier3D

## How quickly the reaction decays (higher = faster recovery).
@export var decay_speed: float = 8.0
## Maximum rotation in radians for hit reactions.
@export var max_rotation: float = 0.3
## How much force translates to rotation (lower = subtler reactions).
@export var force_multiplier: float = 0.02

## Bone names that react to hits (spine chain for body hits).
@export var reactive_bones: Array[String] = [
	"spine_01", "spine_02", "spine_03", "spine_04", "spine_05"
]

# Current reaction state per bone: {bone_idx: Vector3 rotation offset}
var _bone_offsets: Dictionary = {}
var _skeleton: Skeleton3D


func _ready() -> void:
	# Find parent skeleton
	var parent := get_parent()
	if parent is Skeleton3D:
		_skeleton = parent
	else:
		push_error("HitReactionModifier must be a child of Skeleton3D")
		return

	# Ensure modifier is active
	active = true

	# Connect to CharacterVisuals signal if available
	var char_visuals := _find_character_visuals()
	if char_visuals:
		char_visuals.hit_received.connect(_on_hit_received)
		print("[HitReactionModifier] Connected to CharacterVisuals.hit_received")
	else:
		push_warning("[HitReactionModifier] No CharacterVisuals found - call apply_hit() directly")


func _process_modification() -> void:
	if _skeleton == null:
		return

	var dominated: bool = false

	# Apply and decay each bone offset
	var bones_to_remove: Array[int] = []
	for bone_idx: int in _bone_offsets.keys():
		var offset: Vector3 = _bone_offsets[bone_idx]

		# Apply rotation offset
		var bone_pose: Transform3D = _skeleton.get_bone_pose(bone_idx)
		var offset_basis := Basis.from_euler(offset)
		bone_pose.basis = bone_pose.basis * offset_basis
		_skeleton.set_bone_pose(bone_idx, bone_pose)

		# Decay the offset
		offset = offset.lerp(Vector3.ZERO, 1.0 - exp(-decay_speed * get_process_delta_time()))

		# Remove if negligible
		if offset.length_squared() < 0.0001:
			bones_to_remove.append(bone_idx)
		else:
			_bone_offsets[bone_idx] = offset
			dominated = true

	# Clean up finished reactions
	for bone_idx: int in bones_to_remove:
		_bone_offsets.erase(bone_idx)

	# Notify CharacterVisuals of flinch state
	var char_visuals := _find_character_visuals()
	if char_visuals and char_visuals.is_flinching != dominated:
		char_visuals.is_flinching = dominated
		char_visuals.flinch_state_changed.emit(dominated)


## Apply a hit reaction. Called by CharacterVisuals.hit_received signal.
func _on_hit_received(bone_name: StringName, direction: Vector3, force: float) -> void:
	if _skeleton == null:
		return

	print("[HitReactionModifier] Hit received: bone=%s, dir=%s, force=%s" % [bone_name, direction, force])

	# Clamp force
	var clamped_force: float = clampf(force * force_multiplier, 0.0, max_rotation)

	# Convert world direction to local
	var local_dir: Vector3 = _skeleton.global_transform.basis.inverse() * direction.normalized()

	# Calculate rotation axis (perpendicular to hit direction)
	var rotation_axis: Vector3 = local_dir.cross(Vector3.UP).normalized()
	if rotation_axis.length_squared() < 0.01:
		rotation_axis = Vector3.RIGHT

	# Create rotation offset (pitch back from hit)
	var offset := Vector3(
		-local_dir.z * clamped_force,  # Pitch
		local_dir.x * clamped_force * 0.3,  # Yaw (subtle)
		-local_dir.x * clamped_force * 0.5  # Roll
	)

	# Apply to reactive bones with falloff
	for i in range(reactive_bones.size()):
		var bone_name_str: String = reactive_bones[i]
		var bone_idx: int = _skeleton.find_bone(bone_name_str)
		if bone_idx == -1:
			continue

		# Falloff: upper spine reacts more
		var falloff: float = float(i + 1) / float(reactive_bones.size())
		var bone_offset: Vector3 = offset * falloff

		# Add to existing offset (allows overlapping hits)
		if _bone_offsets.has(bone_idx):
			var combined: Vector3 = _bone_offsets[bone_idx] + bone_offset
			combined.x = clampf(combined.x, -max_rotation, max_rotation)
			combined.y = clampf(combined.y, -max_rotation, max_rotation)
			combined.z = clampf(combined.z, -max_rotation, max_rotation)
			_bone_offsets[bone_idx] = combined
		else:
			_bone_offsets[bone_idx] = bone_offset


## Public method to apply a hit directly (for testing or direct use).
func apply_hit(direction: Vector3, force: float) -> void:
	_on_hit_received(&"spine_03", direction, force)


## Find CharacterVisuals ancestor.
func _find_character_visuals() -> CharacterVisuals:
	var node := get_parent()
	while node:
		if node is CharacterVisuals:
			return node
		node = node.get_parent()
	return null
