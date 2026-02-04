@tool
@icon("res://addons/universal_door/icon_door.svg")
class_name UniversalDoor
extends Node3D
## Universal Door Component with Teleporter Support
## Handles: Normal, Sliding, Garage, Elevator, and Custom door types
## Uses built-in Godot nodes: AnimatableBody3D, Area3D, AnimationPlayer

signal door_opened
signal door_closed
signal teleport_triggered(target_door: UniversalDoor)
signal player_entered_zone
signal player_exited_zone

enum DoorType {
	NORMAL,      ## Hinged door - rotates on Y axis
	SLIDING,     ## Slides horizontally
	GARAGE,      ## Rolls up vertically
	ELEVATOR,    ## Two panels slide apart
	CUSTOM       ## Use your own AnimationPlayer anims
}

enum DoorState { CLOSED, OPENING, OPEN, CLOSING }

@export_group("Door Configuration")
@export var door_type: DoorType = DoorType.NORMAL:
	set(v):
		door_type = v
		_update_configuration()
		notify_property_list_changed()

@export var open_amount: float = 90.0:  ## Degrees for NORMAL, units for others
	set(v):
		open_amount = v
		if Engine.is_editor_hint():
			_preview_open_position()

@export var open_duration: float = 0.5
@export var auto_close: bool = false
@export var auto_close_delay: float = 3.0
@export var locked: bool = false

@export_group("Interaction")
@export var auto_open_on_enter: bool = false
@export var interaction_enabled: bool = true
@export_flags_3d_physics var detection_layer: int = 1  ## Which layers trigger detection

@export_group("Teleporter")
@export var teleport_enabled: bool = false
@export var teleport_target: UniversalDoor  ## Direct reference to target door
@export var teleport_target_group: StringName = &""  ## Or use group name for loose coupling
@export var teleport_offset: Vector3 = Vector3(0, 0, 2)  ## Spawn offset from target door

@export_group("Audio")
@export var open_sound: AudioStream
@export var close_sound: AudioStream
@export var locked_sound: AudioStream

@export_group("Custom Animation")
@export var custom_open_anim: StringName = &"open"
@export var custom_close_anim: StringName = &"close"

@export_group("Editor")
@export var preview_open: bool = false:
	set(v):
		preview_open = v
		if Engine.is_editor_hint():
			_preview_open_position()

var state: DoorState = DoorState.CLOSED
var _tween: Tween
var _auto_close_timer: Timer
var _initial_transform: Transform3D
var _door_body: AnimatableBody3D
var _detection_zone: Area3D
var _audio_player: AudioStreamPlayer3D
var _animation_player: AnimationPlayer


func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	
	if not _find_door_body():
		warnings.append("Missing DoorBody (AnimatableBody3D) child node.")
	
	if not _find_detection_zone():
		warnings.append("Missing DetectionZone (Area3D) child node for auto-open feature.")
	
	if door_type == DoorType.ELEVATOR:
		var body := _find_door_body()
		if body and (not body.has_node("LeftPanel") or not body.has_node("RightPanel")):
			warnings.append("Elevator door type requires LeftPanel and RightPanel children under DoorBody.")
	
	if door_type == DoorType.CUSTOM and not _find_animation_player():
		warnings.append("Custom door type requires an AnimationPlayer child node.")
	
	if teleport_enabled and not teleport_target and teleport_target_group.is_empty():
		warnings.append("Teleporter enabled but no target or target group set.")
	
	return warnings


func _ready() -> void:
	_cache_node_references()
	
	if Engine.is_editor_hint():
		return
	
	_initial_transform = _door_body.transform if _door_body else Transform3D.IDENTITY
	_setup_detection_zone()
	_setup_auto_close_timer()


func _cache_node_references() -> void:
	_door_body = _find_door_body()
	_detection_zone = _find_detection_zone()
	_audio_player = _find_audio_player()
	_animation_player = _find_animation_player()
	
	if _door_body and _initial_transform == Transform3D():
		_initial_transform = _door_body.transform


func _find_door_body() -> AnimatableBody3D:
	for child in get_children():
		if child is AnimatableBody3D:
			return child
	return null


func _find_detection_zone() -> Area3D:
	for child in get_children():
		if child is Area3D:
			return child
	return null


func _find_audio_player() -> AudioStreamPlayer3D:
	for child in get_children():
		if child is AudioStreamPlayer3D:
			return child
	return null


func _find_animation_player() -> AnimationPlayer:
	for child in get_children():
		if child is AnimationPlayer:
			return child
	return null


func _setup_detection_zone() -> void:
	if not _detection_zone:
		return
	_detection_zone.collision_mask = detection_layer
	
	if not _detection_zone.body_entered.is_connected(_on_body_entered):
		_detection_zone.body_entered.connect(_on_body_entered)
	if not _detection_zone.body_exited.is_connected(_on_body_exited):
		_detection_zone.body_exited.connect(_on_body_exited)


func _setup_auto_close_timer() -> void:
	_auto_close_timer = Timer.new()
	_auto_close_timer.one_shot = true
	_auto_close_timer.timeout.connect(_on_auto_close_timeout)
	add_child(_auto_close_timer, false, Node.INTERNAL_MODE_BACK)


func _update_configuration() -> void:
	update_configuration_warnings()


func _preview_open_position() -> void:
	if not Engine.is_editor_hint():
		return
	
	_cache_node_references()
	if not _door_body:
		return
	
	if preview_open:
		match door_type:
			DoorType.NORMAL:
				_door_body.rotation.y = deg_to_rad(open_amount)
			DoorType.SLIDING:
				_door_body.position = _initial_transform.origin + Vector3(open_amount, 0, 0)
			DoorType.GARAGE:
				_door_body.position = _initial_transform.origin + Vector3(0, open_amount, 0)
			DoorType.ELEVATOR:
				_preview_elevator()
	else:
		_door_body.transform = _initial_transform
		if door_type == DoorType.ELEVATOR:
			_reset_elevator_panels()


func _preview_elevator() -> void:
	if not _door_body:
		return
	var half := open_amount / 2.0
	if _door_body.has_node("LeftPanel"):
		_door_body.get_node("LeftPanel").position = Vector3(-half, 0, 0)
	if _door_body.has_node("RightPanel"):
		_door_body.get_node("RightPanel").position = Vector3(half, 0, 0)


func _reset_elevator_panels() -> void:
	if not _door_body:
		return
	if _door_body.has_node("LeftPanel"):
		_door_body.get_node("LeftPanel").position = Vector3.ZERO
	if _door_body.has_node("RightPanel"):
		_door_body.get_node("RightPanel").position = Vector3.ZERO


#region Public API

func open() -> void:
	if locked:
		_play_sound(locked_sound)
		return
	if state == DoorState.OPEN or state == DoorState.OPENING:
		return
	
	state = DoorState.OPENING
	_play_sound(open_sound)
	_animate_door(true)


func close() -> void:
	if state == DoorState.CLOSED or state == DoorState.CLOSING:
		return
	
	state = DoorState.CLOSING
	_play_sound(close_sound)
	_animate_door(false)


func toggle() -> void:
	if state == DoorState.CLOSED or state == DoorState.CLOSING:
		open()
	else:
		close()


func interact() -> void:
	if not interaction_enabled:
		return
	toggle()


func teleport_entity(entity: Node3D) -> void:
	if not teleport_enabled:
		return
	
	var target := _get_teleport_target()
	if not target:
		push_warning("UniversalDoor: No teleport target found")
		return
	
	# Calculate spawn position relative to target door
	var spawn_pos := target.global_position + target.global_basis * teleport_offset
	entity.global_position = spawn_pos
	
	# Match target door's forward direction
	if entity.has_method("set_facing_direction"):
		entity.set_facing_direction(-target.global_basis.z)
	elif entity is Node3D:
		entity.global_rotation.y = target.global_rotation.y
	
	teleport_triggered.emit(target)


func unlock() -> void:
	locked = false


func lock() -> void:
	locked = true
	if state == DoorState.OPEN:
		close()


func is_open() -> bool:
	return state == DoorState.OPEN


func is_closed() -> bool:
	return state == DoorState.CLOSED

#endregion

#region Animation

func _animate_door(opening: bool) -> void:
	# Kill existing tween
	if _tween and _tween.is_valid():
		_tween.kill()
	
	_cache_node_references()
	
	# Use custom animations if available and door type is CUSTOM
	if door_type == DoorType.CUSTOM and _animation_player:
		var anim_name := custom_open_anim if opening else custom_close_anim
		if _animation_player.has_animation(anim_name):
			_animation_player.play(anim_name)
			await _animation_player.animation_finished
			_on_animation_complete(opening)
			return
	
	if not _door_body:
		push_warning("UniversalDoor: No DoorBody found for animation")
		return
	
	# Procedural animation using Tween
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_QUAD)
	_tween.set_ease(Tween.EASE_IN_OUT if opening else Tween.EASE_IN)
	
	match door_type:
		DoorType.NORMAL:
			_animate_normal_door(opening)
		DoorType.SLIDING:
			_animate_sliding_door(opening)
		DoorType.GARAGE:
			_animate_garage_door(opening)
		DoorType.ELEVATOR:
			_animate_elevator_door(opening)
		DoorType.CUSTOM:
			# Fallback to sliding if no AnimationPlayer
			_animate_sliding_door(opening)
	
	_tween.finished.connect(_on_animation_complete.bind(opening), CONNECT_ONE_SHOT)


func _animate_normal_door(opening: bool) -> void:
	var target_rotation := deg_to_rad(open_amount) if opening else 0.0
	_tween.tween_property(_door_body, "rotation:y", target_rotation, open_duration)


func _animate_sliding_door(opening: bool) -> void:
	var target_pos := _initial_transform.origin + Vector3(open_amount, 0, 0) if opening else _initial_transform.origin
	_tween.tween_property(_door_body, "position", target_pos, open_duration)


func _animate_garage_door(opening: bool) -> void:
	var target_pos := _initial_transform.origin + Vector3(0, open_amount, 0) if opening else _initial_transform.origin
	_tween.tween_property(_door_body, "position", target_pos, open_duration)


func _animate_elevator_door(opening: bool) -> void:
	var half_open := open_amount / 2.0
	if _door_body.has_node("LeftPanel") and _door_body.has_node("RightPanel"):
		var left: Node3D = _door_body.get_node("LeftPanel")
		var right: Node3D = _door_body.get_node("RightPanel")
		var left_target := Vector3(-half_open, 0, 0) if opening else Vector3.ZERO
		var right_target := Vector3(half_open, 0, 0) if opening else Vector3.ZERO
		_tween.tween_property(left, "position", left_target, open_duration)
		_tween.parallel().tween_property(right, "position", right_target, open_duration)
	else:
		# Fallback: single panel slides
		_animate_sliding_door(opening)


func _on_animation_complete(was_opening: bool) -> void:
	if was_opening:
		state = DoorState.OPEN
		door_opened.emit()
		if auto_close:
			_auto_close_timer.start(auto_close_delay)
	else:
		state = DoorState.CLOSED
		door_closed.emit()

#endregion

#region Detection & Events

func _on_body_entered(body: Node3D) -> void:
	player_entered_zone.emit()
	
	if auto_open_on_enter and not locked:
		open()
	
	# Auto-teleport on enter if configured
	if teleport_enabled and state == DoorState.OPEN:
		teleport_entity(body)


func _on_body_exited(_body: Node3D) -> void:
	player_exited_zone.emit()


func _on_auto_close_timeout() -> void:
	# Don't close if someone is still in the zone
	if _detection_zone and _detection_zone.has_overlapping_bodies():
		_auto_close_timer.start(auto_close_delay)
		return
	close()

#endregion

#region Helpers

func _get_teleport_target() -> UniversalDoor:
	if teleport_target:
		return teleport_target
	
	if teleport_target_group.is_empty():
		return null
	
	var doors := get_tree().get_nodes_in_group(teleport_target_group)
	for door in doors:
		if door is UniversalDoor and door != self:
			return door
	
	return null


func _play_sound(stream: AudioStream) -> void:
	if not stream:
		return
	
	if not _audio_player:
		_cache_node_references()
	
	if _audio_player:
		_audio_player.stream = stream
		_audio_player.play()

#endregion
