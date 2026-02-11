## Procedural hit reaction using SkeletonModifier3D.
## Applies additive rotation to spine bones when hit.
## SkeletonModifier3D processes AFTER animation, preventing accumulation.
class_name HitReactionComponent
extends SkeletonModifier3D

## Emitted when ragdoll settles and recovery can begin.
signal ragdoll_settled(face_up: bool)

@export var config: HitReactionConfig

var _visuals: CharacterVisuals
var _animation_tree: AnimationTree

# Spine bone indices
var _spine_01_idx: int = -1
var _spine_02_idx: int = -1
var _spine_03_idx: int = -1

# Hit reaction state - these are the CURRENT applied offsets
var _current_offset: Vector3 = Vector3.ZERO  # Euler angles (pitch, yaw, roll)
# Target offset that we're lerping toward (set on hit, decays to zero)
var _target_offset: Vector3 = Vector3.ZERO

# Hitstop state
var _hitstop_timer: float = 0.0
var _hitstop_active: bool = false
var _cached_tree_speed: float = 1.0

# Visual feedback
var _original_material: Material
var _flash_material: StandardMaterial3D

# Recovery timing
var _is_recovering: bool = false


func _ready() -> void:
	# Find CharacterVisuals - we should be a child of the skeleton, which is under CharacterVisuals
	var node := get_parent()
	while node != null:
		if node is CharacterVisuals:
			_visuals = node
			break
		node = node.get_parent()

	if _visuals == null:
		push_error("HitReactionComponent: Could not find CharacterVisuals in parent chain.")
		return

	if config == null:
		config = HitReactionConfig.new()

	# Connect signals
	_visuals.hit_received.connect(_on_hit_received)

	# Setup after visuals are ready
	_visuals.ready.connect(_setup, CONNECT_ONE_SHOT | CONNECT_DEFERRED)


func _setup() -> void:
	var skel := get_skeleton()
	if skel == null:
		push_error("HitReactionComponent: No skeleton found!")
		return

	_animation_tree = _visuals.animation_tree

	var skel_config := _visuals.skeleton_config
	if skel_config == null:
		skel_config = SkeletonConfig.new()

	# Cache bone indices
	_spine_01_idx = skel.find_bone(skel_config.spine_01)
	_spine_02_idx = skel.find_bone(skel_config.spine_02)
	_spine_03_idx = skel.find_bone(skel_config.spine_03)

	# Create red flash material for hit feedback
	_flash_material = StandardMaterial3D.new()
	_flash_material.albedo_color = Color(1.0, 0.3, 0.3, 1.0)
	_flash_material.emission_enabled = true
	_flash_material.emission = Color(1.0, 0.0, 0.0, 1.0)
	_flash_material.emission_energy_multiplier = 0.3

	# Enable this modifier
	active = true


func _physics_process(delta: float) -> void:
	_process_hitstop(delta)
	_update_offsets(delta)


func _process_hitstop(delta: float) -> void:
	if not _hitstop_active:
		return

	_hitstop_timer -= delta
	if _hitstop_timer <= 0.0:
		_hitstop_active = false
		# Restore animation playback
		if _animation_tree:
			_animation_tree.set("parameters/TimeScale/scale", _cached_tree_speed)


func _update_offsets(delta: float) -> void:
	# Lerp current offset toward target (for smooth attack)
	var attack_speed := 15.0  # How fast we reach the target offset
	_current_offset = _current_offset.lerp(_target_offset, 1.0 - exp(-attack_speed * delta))

	# Decay target back to zero (recovery)
	_target_offset = _target_offset.lerp(Vector3.ZERO, 1.0 - exp(-config.flinch_decay_speed * delta))

	# Check if we're done recovering
	if _is_recovering and _current_offset.length() < 0.01 and _target_offset.length() < 0.01:
		_is_recovering = false
		_restore_material()
		_visuals.is_flinching = false
		_visuals.flinch_state_changed.emit(false)


## Called by SkeletonModifier3D after animation updates.
## This is the key - we apply our offset AFTER animation, so no accumulation.
func _process_modification() -> void:
	var skel := get_skeleton()
	if skel == null:
		return

	# Skip if no offset to apply
	if _current_offset.length_squared() < 0.0001:
		return

	# Create rotation quaternion from our offset
	var offset_quat := Quaternion.from_euler(_current_offset)

	# Apply to spine bones (distribute the rotation)
	# Each spine gets a portion of the total rotation
	if _spine_02_idx != -1:
		var bone_rot := skel.get_bone_pose_rotation(_spine_02_idx)
		skel.set_bone_pose_rotation(_spine_02_idx, bone_rot * offset_quat)

	# Apply smaller portion to spine_01 and spine_03 for natural distribution
	var secondary_quat := Quaternion.from_euler(_current_offset * 0.5)

	if _spine_01_idx != -1:
		var bone_rot := skel.get_bone_pose_rotation(_spine_01_idx)
		skel.set_bone_pose_rotation(_spine_01_idx, bone_rot * secondary_quat)

	if _spine_03_idx != -1:
		var bone_rot := skel.get_bone_pose_rotation(_spine_03_idx)
		skel.set_bone_pose_rotation(_spine_03_idx, bone_rot * secondary_quat)


func _on_hit_received(bone_name: StringName, direction: Vector3, force: float) -> void:
	# Hitstop first
	if config.enable_hitstop:
		_start_hitstop()

	# Flash red
	_apply_flash_material()

	# Calculate hit offset based on direction
	# Convert world direction to local space
	var local_dir := Vector3.ZERO
	if _visuals.controller:
		local_dir = _visuals.controller.global_transform.basis.inverse() * direction
	else:
		local_dir = direction

	# Calculate rotation offset - lean away from hit direction
	var max_angle := deg_to_rad(config.flinch_max_angle)
	var force_scale := clampf(force / 5.0, 0.3, 1.0)  # Scale by force, min 30%

	# Pitch (lean forward/back) based on Z direction
	# Roll (lean left/right) based on X direction
	var pitch := clampf(local_dir.z * max_angle * force_scale, -max_angle, max_angle)
	var roll := clampf(-local_dir.x * max_angle * force_scale, -max_angle, max_angle)

	# Set target offset (this is what we lerp toward)
	_target_offset = Vector3(pitch, 0.0, roll)

	# Mark as recovering (will clear flinch state when done)
	_is_recovering = true
	_visuals.is_flinching = true
	_visuals.flinch_state_changed.emit(true)


func _start_hitstop() -> void:
	_hitstop_active = true
	_hitstop_timer = config.hitstop_duration

	# Freeze animation
	if _animation_tree:
		_cached_tree_speed = _animation_tree.get("parameters/TimeScale/scale")
		_animation_tree.set("parameters/TimeScale/scale", 0.0)


func _apply_flash_material() -> void:
	var mesh := _visuals.mesh_instance
	if mesh == null or _flash_material == null:
		return
	if _original_material == null and mesh.material_override != _flash_material:
		_original_material = mesh.material_override
	mesh.material_override = _flash_material


func _restore_material() -> void:
	var mesh := _visuals.mesh_instance
	if mesh == null:
		return
	if mesh.material_override == _flash_material:
		mesh.material_override = _original_material
	_original_material = null
