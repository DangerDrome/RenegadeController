## Player input controller.
## Reads from InputMap for movement and actions.
## Receives aim target from Cursor3D.
class_name PlayerController extends ControllerInterface

## The Cursor3D node that provides aim targeting.
@export var cursor: Cursor3D:
	set(value):
		# Disconnect old cursor signals.
		if cursor and cursor.interactable_clicked.is_connected(_on_interactable_clicked):
			cursor.interactable_clicked.disconnect(_on_interactable_clicked)
			cursor.ground_clicked.disconnect(_on_ground_clicked)
		cursor = value
		# Connect new cursor signals.
		if cursor:
			cursor.interactable_clicked.connect(_on_interactable_clicked)
			cursor.ground_clicked.connect(_on_ground_clicked)

var _look_delta: Vector2 = Vector2.ZERO
var _first_person_active: bool = false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and _first_person_active:
		_look_delta = event.relative


func _physics_process(_delta: float) -> void:
	# Reset look delta each physics frame (consumed by character).
	_look_delta = Vector2.ZERO


func get_movement() -> Vector2:
	return Input.get_vector("move_left", "move_right", "move_forward", "move_back")


func get_aim_target() -> Vector3:
	if cursor and cursor.has_hit:
		return cursor.world_position
	return Vector3.ZERO


func has_aim_target() -> bool:
	return cursor != null and cursor.has_hit


func is_action_pressed(action: String) -> bool:
	return Input.is_action_pressed(action)


func is_action_just_pressed(action: String) -> bool:
	return Input.is_action_just_pressed(action)


func is_action_just_released(action: String) -> bool:
	return Input.is_action_just_released(action)


func get_look_delta() -> Vector2:
	return _look_delta


func is_player() -> bool:
	return true


## Called by CameraManager when entering/exiting first person.
func set_first_person(enabled: bool) -> void:
	_first_person_active = enabled
	if cursor:
		cursor.set_active(not enabled)
	if enabled:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _on_interactable_clicked(target: Node3D) -> void:
	interact_requested.emit(target)


func _on_ground_clicked(position: Vector3) -> void:
	move_to_requested.emit(position)
