## Unified character body that works for both player and NPC.
## Movement is driven entirely by a ControllerInterface (player input or AI).
class_name RenegadeCharacter extends CharacterBody3D

@export_group("References")
@export var controller: ControllerInterface:
	set(value):
		# Disconnect old controller signals.
		if controller:
			if controller.move_to_requested.is_connected(_on_move_to_requested):
				controller.move_to_requested.disconnect(_on_move_to_requested)
			if controller.interact_requested.is_connected(_on_interact_requested):
				controller.interact_requested.disconnect(_on_interact_requested)
		controller = value
		if controller:
			controller.move_to_requested.connect(_on_move_to_requested)
			controller.interact_requested.connect(_on_interact_requested)
@export var camera_rig: CameraRig

@export_group("Movement")
@export var move_speed: float = 8.0
@export var acceleration: float = 25.0
@export var deceleration: float = 30.0
@export var rotation_speed: float = 10.0

@export_group("Sprint")
@export var sprint_multiplier: float = 1.6
@export var sprint_action: String = "sprint"

@export_group("Jump")
@export var jump_velocity: float = 6.0
@export var jump_action: String = "jump"

@export_group("Aim / Strafe")
@export var aim_action: String = "aim"
@export var aim_speed_multiplier: float = 0.6

@export_group("Gravity")
@export var gravity_multiplier: float = 1.0
@export var terminal_velocity: float = 50.0

@export_group("Rotation")
@export var visual_root: Node3D

@export_group("Navigation (Move-To)")
## How close the character gets to a move-to destination (ground click).
@export var arrival_distance: float = 0.2
## How close the character needs to be to interact with a target.
@export var interact_distance: float = 0.8
## Show a visual marker at the move-to destination.
@export var show_move_marker: bool = true
## Size of the move-to marker cube.
@export var move_marker_size: float = 0.25
## Color of the move-to marker.
@export var move_marker_color: Color = Color(0.2, 0.6, 1.0, 0.8)

var move_direction: Vector3 = Vector3.ZERO
var aim_direction: Vector3 = Vector3.FORWARD
var is_sprinting: bool = false
var is_aiming: bool = false

var _nav_target: Vector3 = Vector3.ZERO
var _nav_active: bool = false
var _nav_interact_target: Node3D = null
var _nav_arrival_dist: float = 1.5
var _move_marker: MeshInstance3D
var _was_on_floor: bool = true
var _fall_velocity: float = 0.0
var _was_aiming: bool = false

signal arrived_at_destination()
signal ready_to_interact(target: Node3D)
signal landed(fall_velocity: float)
signal aim_started()
signal aim_ended()


func _ready() -> void:
	_create_move_marker()


func _physics_process(delta: float) -> void:
	if not controller:
		return
	_update_aim_state()
	_update_movement(delta)
	_update_navigation(delta)
	_update_rotation(delta)
	_apply_gravity(delta)
	_update_jump()
	move_and_slide()


#region Movement

func _update_aim_state() -> void:
	is_aiming = controller.is_action_pressed(aim_action)
	if is_aiming and not _was_aiming:
		aim_started.emit()
	elif not is_aiming and _was_aiming:
		aim_ended.emit()
	_was_aiming = is_aiming


func _update_movement(delta: float) -> void:
	var input := controller.get_movement()
	if _nav_active and input.length_squared() > 0.01:
		_cancel_navigation()
	if _nav_active:
		return
	if camera_rig:
		move_direction = camera_rig.calculate_move_direction(input)
	else:
		move_direction = Vector3(input.x, 0.0, input.y).normalized() if input.length() > 0.01 else Vector3.ZERO
	is_sprinting = not is_aiming and controller.is_action_pressed(sprint_action) and move_direction.length() > 0.01
	var speed_mult := 1.0
	if is_aiming:
		speed_mult = aim_speed_multiplier
	elif is_sprinting:
		speed_mult = sprint_multiplier
	_apply_horizontal_movement(move_direction, move_speed * speed_mult, delta)
	if controller.has_aim_target():
		var to_target := controller.get_aim_target() - global_position
		to_target.y = 0.0
		if to_target.length_squared() > 0.01:
			aim_direction = to_target.normalized()
	elif move_direction.length() > 0.01:
		aim_direction = move_direction


func _apply_horizontal_movement(direction: Vector3, target_speed: float, delta: float) -> void:
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	if direction.length() > 0.01:
		horizontal = horizontal.move_toward(direction * target_speed, acceleration * delta)
	else:
		horizontal = horizontal.move_toward(Vector3.ZERO, deceleration * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z

#endregion


#region Rotation

func _update_rotation(delta: float) -> void:
	var rot_target: Node3D = visual_root if visual_root else self
	var face_dir: Vector3
	if is_aiming and controller.has_aim_target():
		face_dir = aim_direction
	elif move_direction.length() > 0.01:
		face_dir = move_direction
	else:
		return
	var target_angle := atan2(face_dir.x, face_dir.z)
	rot_target.rotation.y = lerp_angle(rot_target.rotation.y, target_angle, 1.0 - exp(-rotation_speed * delta))

#endregion


#region Jump & Gravity

func _apply_gravity(delta: float) -> void:
	var on_floor := is_on_floor()
	if on_floor:
		if not _was_on_floor and _fall_velocity < -2.0:
			landed.emit(absf(_fall_velocity))
		_fall_velocity = 0.0
		velocity.y = -0.1
		_was_on_floor = true
		return
	_fall_velocity = velocity.y
	_was_on_floor = false
	velocity.y += get_gravity().y * gravity_multiplier * delta
	velocity.y = maxf(velocity.y, -terminal_velocity)


func _update_jump() -> void:
	if is_on_floor() and controller.is_action_just_pressed(jump_action):
		velocity.y = jump_velocity

#endregion


#region Navigation (Move-To-Then-Interact)

func _on_move_to_requested(position: Vector3) -> void:
	_start_navigation(position, null, arrival_distance)


func _on_interact_requested(target: Node3D) -> void:
	if not target:
		return
	if global_position.distance_to(target.global_position) <= interact_distance:
		ready_to_interact.emit(target)
		return
	_start_navigation(target.global_position, target, interact_distance)


func _start_navigation(target_pos: Vector3, interact_target: Node3D, arrival_dist: float) -> void:
	_nav_target = target_pos
	_nav_active = true
	_nav_interact_target = interact_target
	_nav_arrival_dist = arrival_dist
	_show_move_marker(target_pos)


func _cancel_navigation() -> void:
	_nav_active = false
	_nav_interact_target = null
	_hide_move_marker()


func _update_navigation(delta: float) -> void:
	if not _nav_active:
		return
	if _nav_interact_target and not is_instance_valid(_nav_interact_target):
		_cancel_navigation()
		return
	if _nav_interact_target:
		_nav_target = _nav_interact_target.global_position
	var to_target := _nav_target - global_position
	to_target.y = 0.0
	if to_target.length() <= _nav_arrival_dist:
		_on_navigation_arrived()
		return
	move_direction = to_target.normalized()
	_apply_horizontal_movement(move_direction, move_speed, delta)
	aim_direction = move_direction


func _on_navigation_arrived() -> void:
	var interact_target := _nav_interact_target
	_cancel_navigation()
	move_direction = Vector3.ZERO
	velocity.x = 0.0
	velocity.z = 0.0
	if interact_target:
		ready_to_interact.emit(interact_target)
	else:
		arrived_at_destination.emit()

#endregion


#region Public API

func get_horizontal_speed() -> float:
	return Vector2(velocity.x, velocity.z).length()


func get_speed_ratio() -> float:
	return clampf(get_horizontal_speed() / (move_speed * sprint_multiplier), 0.0, 1.0)


func teleport(pos: Vector3) -> void:
	global_position = pos
	velocity = Vector3.ZERO
	_cancel_navigation()
	reset_physics_interpolation()


func navigate_to(pos: Vector3) -> void:
	_start_navigation(pos, null, arrival_distance)


func navigate_to_interact(target: Node3D) -> void:
	_on_interact_requested(target)

#endregion


#region Move Marker

func _create_move_marker() -> void:
	if not show_move_marker:
		return

	_move_marker = MeshInstance3D.new()
	_move_marker.name = "MoveMarker"

	var mesh := BoxMesh.new()
	mesh.size = Vector3(move_marker_size, move_marker_size, move_marker_size)
	_move_marker.mesh = mesh

	var mat := StandardMaterial3D.new()
	mat.albedo_color = move_marker_color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.disable_receive_shadows = true
	_move_marker.material_override = mat
	_move_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	_move_marker.top_level = true
	_move_marker.visible = false
	add_child(_move_marker)


func _show_move_marker(pos: Vector3) -> void:
	if _move_marker:
		_move_marker.global_position = pos
		_move_marker.visible = true


func _hide_move_marker() -> void:
	if _move_marker:
		_move_marker.visible = false

#endregion
