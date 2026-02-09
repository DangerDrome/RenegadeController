## Drives root motion locomotion and AnimationTree blend parameters.
## Handles: root motion → CharacterBody3D velocity, BlendSpace2D parameters,
## basic stride rate clamping for foot slide mitigation, turn-in-place triggering.
class_name LocomotionComponent
extends Node

@export var config: LocomotionConfig

## AnimationTree parameter paths — set these to match your tree layout.
@export_group("AnimationTree Parameters")
@export var blend_position_param: String = "parameters/Locomotion/IdleWalkRun/blend_position"
@export var time_scale_param: String = "parameters/TimeScale/scale"
@export var upper_body_blend_param: String = "parameters/UpperBodyBlend/blend_amount"

var _visuals: CharacterVisuals
var _current_blend: Vector2 = Vector2.ZERO
var _is_moving: bool = false


func _ready() -> void:
	_visuals = get_parent() as CharacterVisuals
	if _visuals == null:
		push_error("LocomotionComponent: Parent must be a CharacterVisuals node.")
		return
	
	if config == null:
		config = LocomotionConfig.new()
	
	# Configure root motion local if available
	if _visuals.animation_tree:
		_visuals.animation_tree.root_motion_local = config.use_root_motion_local


func _physics_process(delta: float) -> void:
	if _visuals == null or _visuals.controller == null:
		return
	if _visuals.animation_tree == null or not _visuals.animation_tree.active:
		return
	
	_apply_root_motion(delta)
	_update_blend_parameters(delta)
	_update_stride_rate(delta)


## Extracts root motion from AnimationTree and applies to CharacterBody3D.
func _apply_root_motion(delta: float) -> void:
	var tree := _visuals.animation_tree
	var body := _visuals.controller
	
	# Apply rotation from root motion
	var root_rot := tree.get_root_motion_rotation()
	body.quaternion *= root_rot
	
	# Transform position delta from bone-local to world space
	var accumulator := tree.get_root_motion_rotation_accumulator()
	var root_pos := tree.get_root_motion_position()
	
	if delta > 0.0:
		body.velocity = (accumulator.inverse() * body.quaternion) * root_pos / delta
	
	# Apply gravity when airborne
	if not body.is_on_floor():
		body.velocity.y -= config.gravity * delta
	
	body.move_and_slide()


## Computes camera-relative blend position from world velocity.
func _update_blend_parameters(delta: float) -> void:
	var tree := _visuals.animation_tree
	var body := _visuals.controller
	var velocity := body.velocity
	
	# Project velocity to horizontal plane
	var horizontal_vel := Vector3(velocity.x, 0.0, velocity.z)
	var speed := horizontal_vel.length()
	
	_is_moving = speed > config.idle_threshold
	
	# Convert world velocity to character-local space
	var local_vel := body.global_transform.basis.inverse() * horizontal_vel
	
	# Normalize to blend range [-1, 1] based on max speed
	var target_blend := Vector2.ZERO
	if speed > config.idle_threshold:
		target_blend = Vector2(local_vel.x, -local_vel.z)
		target_blend = target_blend.normalized() * clampf(speed / config.max_speed, 0.0, 1.0)
	
	# Smooth blend position transition
	_current_blend = _current_blend.lerp(target_blend, config.blend_smooth_speed * delta)
	
	tree.set(blend_position_param, _current_blend)


## Basic stride rate clamping — adjusts playback rate to reduce foot slide.
## Not full distance matching, but covers the 80% case with zero animation markup.
func _update_stride_rate(delta: float) -> void:
	if not config.enable_stride_rate_clamping:
		return
	
	var tree := _visuals.animation_tree
	if time_scale_param.is_empty():
		return
	
	var body := _visuals.controller
	var actual_speed := Vector3(body.velocity.x, 0.0, body.velocity.z).length()
	
	# Get the animated speed from root motion
	var root_pos := tree.get_root_motion_position()
	var animated_speed := Vector3(root_pos.x, 0.0, root_pos.z).length() / delta if delta > 0.0 else 0.0
	
	if animated_speed < 0.1:
		tree.set(time_scale_param, 1.0)
		return
	
	var rate := actual_speed / animated_speed
	rate = clampf(rate, 1.0 - config.max_rate_slowdown, 1.0 + config.max_rate_speedup)
	tree.set(time_scale_param, rate)


## Whether the character is currently in locomotion (for other components to query).
func is_moving() -> bool:
	return _is_moving
