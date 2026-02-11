## Active ragdoll component - bones follow animation but react to physics on hit.
## Requires PhysicalBoneSimulator3D as sibling under Skeleton3D.
class_name ActiveRagdollComponent
extends Node

## Enable/disable the component.
@export var enabled: bool = true
## Force multiplier for hit impulses.
@export var impulse_strength: float = 1.5
## How long physics simulation runs after a hit (seconds).
@export var hit_duration: float = 0.2
## Collision layer for physical bones (should not overlap with player/NPC layer).
@export var bone_collision_layer: int = 128  # Layer 8
## Collision mask for physical bones (world geometry, other ragdoll bones).
@export var bone_collision_mask: int = 129   # Layer 1 (world) + Layer 8 (bones)

var _skeleton: Skeleton3D
var _simulator: PhysicalBoneSimulator3D
var _physical_bones: Dictionary = {}  # bone_name -> PhysicalBone3D
var _hit_timer: float = 0.0
var _is_reacting: bool = false


func _ready() -> void:
	if not enabled:
		return

	# Find skeleton (should be parent)
	var parent := get_parent()
	if parent is Skeleton3D:
		_skeleton = parent
	else:
		push_error("ActiveRagdollComponent must be a child of Skeleton3D")
		return

	# Find PhysicalBoneSimulator3D sibling
	for sibling in _skeleton.get_children():
		if sibling is PhysicalBoneSimulator3D:
			_simulator = sibling
			break

	if _simulator == null:
		push_error("ActiveRagdollComponent requires PhysicalBoneSimulator3D as sibling")
		return

	# Cache physical bones and configure collision
	_setup_physical_bones()

	# Start with simulation OFF (animation controls)
	_simulator.physical_bones_stop_simulation()

	# Connect to CharacterVisuals hit signal
	var char_visuals := _find_character_visuals()
	if char_visuals:
		char_visuals.hit_received.connect(_on_hit_received)
		print("[ActiveRagdoll] Connected to CharacterVisuals.hit_received")
	else:
		push_warning("[ActiveRagdoll] No CharacterVisuals found")


func _physics_process(delta: float) -> void:
	if _is_reacting:
		_hit_timer -= delta
		if _hit_timer <= 0.0:
			_stop_reaction()


func _setup_physical_bones() -> void:
	var count: int = 0
	for child in _simulator.get_children():
		if child is PhysicalBone3D:
			var bone: PhysicalBone3D = child

			# Configure collision to avoid player/NPC capsules
			bone.collision_layer = bone_collision_layer
			bone.collision_mask = bone_collision_mask

			# Cache by bone name (strip "Physical Bone " prefix if present)
			var bone_name: String = bone.name.replace("Physical Bone ", "")
			_physical_bones[bone_name] = bone
			count += 1

	print("[ActiveRagdoll] Configured %d physical bones (layer %d, mask %d)" % [count, bone_collision_layer, bone_collision_mask])


func _on_hit_received(bone_name: StringName, direction: Vector3, force: float) -> void:
	print("[ActiveRagdoll] Hit: bone=%s, dir=%s, force=%s" % [bone_name, direction, force])

	# Find the physical bone
	var phys_bone: PhysicalBone3D = _physical_bones.get(String(bone_name))

	if phys_bone == null:
		# Try to find a nearby bone in the chain
		phys_bone = _find_nearest_physical_bone(String(bone_name))

	if phys_bone == null:
		print("[ActiveRagdoll] No physical bone found for: ", bone_name)
		return

	# Start physics simulation if not already reacting
	if not _is_reacting:
		_simulator.physical_bones_start_simulation()
		_is_reacting = true
		print("[ActiveRagdoll] Started physics simulation - is_simulating: ", _simulator.is_simulating_physics())

	# Reset timer (extends reaction if hit again)
	_hit_timer = hit_duration

	# Apply impulse
	var impulse: Vector3 = direction.normalized() * force * impulse_strength
	impulse.y += force * impulse_strength * 0.1  # Small upward component

	print("[ActiveRagdoll] Applying impulse: ", impulse, " to bone: ", phys_bone.name)
	phys_bone.apply_central_impulse(impulse)

	# Also apply to connected bones for more natural reaction
	_apply_chain_impulse(phys_bone, impulse * 0.5)


func _stop_reaction() -> void:
	_is_reacting = false
	_simulator.physical_bones_stop_simulation()
	print("[ActiveRagdoll] Stopped physics simulation, returning to animation")


## Apply diminishing impulse to connected bones.
func _apply_chain_impulse(start_bone: PhysicalBone3D, impulse: Vector3) -> void:
	# Get the skeleton bone index
	var bone_name: String = start_bone.name.replace("Physical Bone ", "")
	var bone_idx: int = _skeleton.find_bone(bone_name)
	if bone_idx == -1:
		return

	# Apply to parent bone
	var parent_idx: int = _skeleton.get_bone_parent(bone_idx)
	if parent_idx != -1:
		var parent_name: String = _skeleton.get_bone_name(parent_idx)
		var parent_phys: PhysicalBone3D = _physical_bones.get(parent_name)
		if parent_phys:
			parent_phys.apply_central_impulse(impulse * 0.5)

	# Apply to child bones
	for i in range(_skeleton.get_bone_count()):
		if _skeleton.get_bone_parent(i) == bone_idx:
			var child_name: String = _skeleton.get_bone_name(i)
			var child_phys: PhysicalBone3D = _physical_bones.get(child_name)
			if child_phys:
				child_phys.apply_central_impulse(impulse * 0.3)


## Find nearest physical bone if exact match not found.
func _find_nearest_physical_bone(bone_name: String) -> PhysicalBone3D:
	# Check for partial matches (e.g., "spine" matches "spine_01", "spine_02", etc.)
	for key in _physical_bones.keys():
		if key.begins_with(bone_name) or bone_name.begins_with(key):
			return _physical_bones[key]

	# Default to spine_03 (center mass) if nothing found
	if _physical_bones.has("spine_03"):
		return _physical_bones["spine_03"]

	return null


## Public method to apply a hit directly.
func apply_hit(direction: Vector3, force: float, bone_name: String = "spine_03") -> void:
	_on_hit_received(StringName(bone_name), direction, force)


## Find CharacterVisuals ancestor.
func _find_character_visuals() -> CharacterVisuals:
	var node := get_parent()
	while node:
		if node is CharacterVisuals:
			return node
		node = node.get_parent()
	return null
