## Root node for the Renegade Visuals animation system.
## Add as a child of CharacterBody3D. Auto-discovers controller and skeleton.
## Child components (LocomotionComponent, FootIKComponent, etc.) connect via signals.
@tool
class_name CharacterVisuals
extends Node3D

## Emitted each physics frame with movement data for components.
signal movement_updated(velocity: Vector3, grounded: bool, facing: Basis)
## Emitted when a hit is received. Components handle their own reactions.
signal hit_received(bone_name: StringName, direction: Vector3, force: float)
## Emitted when full ragdoll should activate (death, big knockdown).
signal ragdoll_requested(direction: Vector3, force: float)
## Emitted when ragdoll recovery should begin.
signal recovery_requested(face_up: bool)
## Emitted when flinch state changes (for other components to pause)
signal flinch_state_changed(is_flinching: bool)

## True while hit reaction flinch is active (other components should pause)
var is_flinching: bool = false

## The CharacterBody3D this visual system drives. Auto-detected from parent if null.
@export var controller: CharacterBody3D
## The character model scene to instance. Expects Skeleton3D + AnimationPlayer inside.
@export var character_scene: PackedScene
## Bone name mappings for the skeleton.
@export var skeleton_config: SkeletonConfig

## Cached references — available to child components via get_parent().
var skeleton: Skeleton3D
var animation_player: AnimationPlayer
var animation_tree: AnimationTree
var mesh_instance: MeshInstance3D

var _character_instance: Node3D
var _previous_velocity: Vector3 = Vector3.ZERO
var _acceleration: Vector3 = Vector3.ZERO


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	
	_auto_discover_controller()
	_setup_character()
	
	if skeleton_config == null:
		skeleton_config = SkeletonConfig.new()
		push_warning("CharacterVisuals: No SkeletonConfig assigned, using defaults.")


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if controller == null:
		return
	
	# Calculate acceleration for lean component
	_acceleration = (controller.velocity - _previous_velocity) / delta
	_previous_velocity = controller.velocity
	
	# Broadcast movement state to all child components
	movement_updated.emit(
		controller.velocity,
		controller.is_on_floor(),
		controller.global_basis,
	)


## Returns current acceleration vector. Used by ProceduralLeanComponent.
func get_acceleration() -> Vector3:
	return _acceleration


## Returns current velocity. Convenience for components.
func get_velocity() -> Vector3:
	if controller:
		return controller.velocity
	return Vector3.ZERO


## Returns whether character is grounded.
func is_grounded() -> bool:
	if controller:
		return controller.is_on_floor()
	return true


## Returns the ground normal under the character (for pelvis tilt).
func get_ground_normal() -> Vector3:
	if controller and controller.is_on_floor():
		return controller.get_floor_normal()
	return Vector3.UP


## Trigger a hit reaction. Call this from your combat system.
func apply_hit(bone_name: StringName, direction: Vector3, force: float) -> void:
	hit_received.emit(bone_name, direction, force)


## Trigger full ragdoll. Call this for deaths or heavy knockdowns.
func trigger_ragdoll(direction: Vector3, force: float) -> void:
	ragdoll_requested.emit(direction, force)


## Begin recovery from ragdoll state.
func begin_recovery(face_up: bool) -> void:
	recovery_requested.emit(face_up)


func _auto_discover_controller() -> void:
	if controller != null:
		return
	
	var parent := get_parent()
	if parent is CharacterBody3D:
		controller = parent as CharacterBody3D
	else:
		push_error("CharacterVisuals: No controller assigned and parent is not CharacterBody3D.")


func _setup_character() -> void:
	if character_scene == null:
		# Look for existing skeleton in children (manual setup)
		skeleton = _find_child_of_type(self, "Skeleton3D") as Skeleton3D
		if skeleton:
			_cache_anim_nodes()
		else:
			push_warning("CharacterVisuals: No character_scene assigned and no Skeleton3D found in children.")
		return

	_character_instance = character_scene.instantiate()
	add_child(_character_instance)

	skeleton = _find_child_of_type(_character_instance, "Skeleton3D") as Skeleton3D
	if skeleton == null:
		push_error("CharacterVisuals: character_scene has no Skeleton3D.")
		return

	_cache_anim_nodes()


func _cache_anim_nodes() -> void:
	animation_player = _find_child_of_type(skeleton.get_parent(), "AnimationPlayer") as AnimationPlayer
	animation_tree = _find_child_of_type(skeleton.get_parent(), "AnimationTree") as AnimationTree

	# Find mesh for later use (material swaps, visibility, etc.)
	mesh_instance = _find_child_of_type(skeleton, "MeshInstance3D") as MeshInstance3D


## Recursive typed child finder.
static func _find_child_of_type(node: Node, type_name: String) -> Node:
	for child: Node in node.get_children():
		if child.get_class() == type_name:
			return child
	# Recurse one level
	for child: Node in node.get_children():
		var found := _find_child_of_type(child, type_name)
		if found:
			return found
	return null
