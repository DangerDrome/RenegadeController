## Three-tier hit reaction system with hitstop.
## Tier 1: Procedural flinch (additive spine rotation, zero physics).
## Tier 2: Partial ragdoll (PhysicalBoneSimulator3D with influence tween).
## Tier 3: Full ragdoll (death/knockdown with recovery support).
class_name HitReactionComponent
extends Node

enum HitTier {
	FLINCH,         ## Quick procedural bone offset
	PARTIAL_RAGDOLL, ## Physics on hit area with influence blend
	FULL_RAGDOLL,    ## Full body ragdoll (death/knockdown)
}

## Emitted when ragdoll settles and recovery can begin.
signal ragdoll_settled(face_up: bool)

@export var config: HitReactionConfig

## Path to PhysicalBoneSimulator3D on the skeleton.
@export var physical_bone_sim: NodePath

var _visuals: CharacterVisuals
var _skeleton: Skeleton3D
var _phys_sim: Node  # PhysicalBoneSimulator3D
var _animation_tree: AnimationTree

# Flinch state
var _flinch_offset: Vector3 = Vector3.ZERO  # Euler angles
var _flinch_active: bool = false

# Hitstop state
var _hitstop_timer: float = 0.0
var _hitstop_active: bool = false
var _cached_tree_speed: float = 1.0

# Ragdoll state
var _ragdoll_active: bool = false
var _ragdoll_timer: float = 0.0

# Spine bone indices for flinch
var _spine_bones: PackedInt32Array = PackedInt32Array()


func _ready() -> void:
	_visuals = get_parent() as CharacterVisuals
	if _visuals == null:
		push_error("HitReactionComponent: Parent must be a CharacterVisuals node.")
		return
	
	if config == null:
		config = HitReactionConfig.new()
	
	# Connect signals
	_visuals.hit_received.connect(_on_hit_received)
	_visuals.ragdoll_requested.connect(_on_ragdoll_requested)
	_visuals.recovery_requested.connect(_on_recovery_requested)
	
	_visuals.ready.connect(_setup, CONNECT_ONE_SHOT | CONNECT_DEFERRED)


func _setup() -> void:
	_skeleton = _visuals.skeleton
	_animation_tree = _visuals.animation_tree
	
	if _skeleton == null:
		return
	
	if not physical_bone_sim.is_empty():
		_phys_sim = get_node_or_null(physical_bone_sim)
	
	# Cache spine bone indices for flinch
	var skel_config := _visuals.skeleton_config
	if skel_config:
		for bone_name: StringName in [skel_config.spine_01, skel_config.spine_02, skel_config.spine_03]:
			var idx := _skeleton.find_bone(bone_name)
			if idx != -1:
				_spine_bones.append(idx)


func _physics_process(delta: float) -> void:
	if _skeleton == null:
		return
	
	_process_hitstop(delta)
	_process_flinch(delta)
	_process_ragdoll_timer(delta)


func _process_hitstop(delta: float) -> void:
	if not _hitstop_active:
		return
	
	_hitstop_timer -= delta
	if _hitstop_timer <= 0.0:
		_hitstop_active = false
		# Restore animation playback
		if _animation_tree:
			_animation_tree.set("parameters/TimeScale/scale", _cached_tree_speed)


func _process_flinch(delta: float) -> void:
	if not _flinch_active:
		return
	
	# Decay flinch offset back to zero
	_flinch_offset = _flinch_offset.lerp(Vector3.ZERO, config.flinch_decay_speed * delta)
	
	if _flinch_offset.length() < 0.01:
		_flinch_offset = Vector3.ZERO
		_flinch_active = false
		return
	
	# Apply additive rotation to spine bones
	var per_bone_offset := _flinch_offset / float(_spine_bones.size()) if _spine_bones.size() > 0 else Vector3.ZERO
	for bone_idx: int in _spine_bones:
		var current_rot := _skeleton.get_bone_pose_rotation(bone_idx)
		var offset_quat := Quaternion.from_euler(per_bone_offset)
		_skeleton.set_bone_pose_rotation(bone_idx, current_rot * offset_quat)


func _process_ragdoll_timer(delta: float) -> void:
	if not _ragdoll_active:
		return
	
	_ragdoll_timer += delta
	if _ragdoll_timer >= config.ragdoll_settle_time:
		# Determine orientation for recovery
		var face_up := _is_face_up()
		ragdoll_settled.emit(face_up)


## Determine hit tier based on force magnitude.
func _determine_tier(force: float) -> HitTier:
	if force < 3.0:
		return HitTier.FLINCH
	elif force < 10.0:
		return HitTier.PARTIAL_RAGDOLL
	else:
		return HitTier.FULL_RAGDOLL


func _on_hit_received(bone_name: StringName, direction: Vector3, force: float) -> void:
	var tier := _determine_tier(force)
	
	# Hitstop first (applies to all tiers)
	if config.enable_hitstop:
		_start_hitstop()
	
	match tier:
		HitTier.FLINCH:
			_apply_flinch(direction, force)
		HitTier.PARTIAL_RAGDOLL:
			_apply_partial_ragdoll(bone_name, direction, force)
		HitTier.FULL_RAGDOLL:
			_apply_full_ragdoll(direction, force)


func _start_hitstop() -> void:
	_hitstop_active = true
	_hitstop_timer = config.hitstop_duration
	
	# Freeze animation
	if _animation_tree:
		_cached_tree_speed = _animation_tree.get("parameters/TimeScale/scale")
		_animation_tree.set("parameters/TimeScale/scale", 0.0)


func _apply_flinch(direction: Vector3, force: float) -> void:
	# Convert hit direction to local space rotation offset
	var local_dir := Vector3.ZERO
	if _skeleton:
		local_dir = _skeleton.global_transform.basis.inverse() * direction.normalized()
	
	var angle := deg_to_rad(config.flinch_max_angle) * minf(force / 5.0, 1.0)
	
	# Flinch away from the hit: rotate spine opposite to hit direction
	_flinch_offset = Vector3(
		-local_dir.z * angle,  # Pitch: hit from front → lean back
		local_dir.x * angle * 0.5,  # Yaw: subtle twist
		local_dir.x * angle,  # Roll: hit from side → lean away
	)
	_flinch_active = true


func _apply_partial_ragdoll(bone_name: StringName, direction: Vector3, force: float) -> void:
	if _phys_sim == null:
		# Fallback to flinch if no physics sim available
		_apply_flinch(direction, force)
		return
	
	# Determine which bone group to simulate
	var affected_bones: PackedStringArray
	if bone_name in config.upper_body_bones:
		affected_bones = config.upper_body_bones
	elif bone_name in config.lower_body_bones:
		affected_bones = config.lower_body_bones
	else:
		affected_bones = config.upper_body_bones  # Default to upper
	
	# Start partial simulation
	var bone_names_array: Array[StringName] = []
	for bn: String in affected_bones:
		bone_names_array.append(StringName(bn))
	
	_phys_sim.call("physical_bones_start_simulation", bone_names_array)
	_phys_sim.set("influence", config.partial_ragdoll_influence)
	
	# Apply impulse to the struck bone
	var phys_bone := _find_physical_bone(bone_name)
	if phys_bone:
		phys_bone.apply_central_impulse(direction.normalized() * force * config.impulse_multiplier)
	
	# Tween influence back to zero
	var tween := create_tween()
	tween.tween_property(
		_phys_sim, "influence", 0.0, config.partial_ragdoll_duration
	).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_callback(_phys_sim.call.bind("physical_bones_stop_simulation"))


func _on_ragdoll_requested(direction: Vector3, force: float) -> void:
	_apply_full_ragdoll(direction, force)


func _apply_full_ragdoll(direction: Vector3, force: float) -> void:
	if _phys_sim == null:
		push_warning("HitReactionComponent: No PhysicalBoneSimulator3D — cannot ragdoll.")
		return
	
	_ragdoll_active = true
	_ragdoll_timer = 0.0
	
	# Full body simulation
	_phys_sim.call("physical_bones_start_simulation")
	_phys_sim.set("influence", 1.0)
	
	# Disable animation tree during full ragdoll
	if _animation_tree:
		_animation_tree.active = false
	
	# Apply force to pelvis
	var skel_config := _visuals.skeleton_config
	if skel_config:
		var phys_bone := _find_physical_bone(skel_config.pelvis_bone)
		if phys_bone:
			phys_bone.apply_central_impulse(direction.normalized() * force * config.impulse_multiplier)


func _on_recovery_requested(face_up: bool) -> void:
	if _phys_sim == null or not _ragdoll_active:
		return
	
	_ragdoll_active = false
	
	# Re-enable animation tree with recovery animation
	if _animation_tree:
		_animation_tree.active = true
	
	# Tween influence from 1.0 to 0.0 over recovery duration
	var tween := create_tween()
	tween.tween_property(
		_phys_sim, "influence", 0.0, config.recovery_blend_duration
	).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_callback(_phys_sim.call.bind("physical_bones_stop_simulation"))
	
	# TODO: Trigger recovery animation based on face_up/face_down
	# animation_tree.set("parameters/Locomotion/travel", "GetUp_FaceUp" if face_up else "GetUp_FaceDown")


func _is_face_up() -> bool:
	if _skeleton == null:
		return true
	var skel_config := _visuals.skeleton_config
	if skel_config == null:
		return true
	
	var pelvis_idx := _skeleton.find_bone(skel_config.pelvis_bone)
	if pelvis_idx == -1:
		return true
	
	var pelvis_transform := _skeleton.global_transform * _skeleton.get_bone_global_pose(pelvis_idx)
	# If pelvis Y-axis points more upward than downward, character is face-up
	return pelvis_transform.basis.y.dot(Vector3.UP) > 0.0


func _find_physical_bone(bone_name: StringName) -> Node:
	# PhysicalBone3D nodes are typically named "Physical Bone <bone_name>"
	if _phys_sim == null:
		return null
	
	for child: Node in _phys_sim.get_children():
		if child.name.contains(str(bone_name)):
			return child
	
	# Try direct name match
	var direct := _phys_sim.get_node_or_null(NodePath(str(bone_name)))
	return direct
