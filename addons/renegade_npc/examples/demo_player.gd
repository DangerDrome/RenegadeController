## DemoPlayer: Minimal WASD + mouse-look player for testing the NPC system.
## Attach to a CharacterBody3D. Adds itself to the "player" group automatically.
extends CharacterBody3D

const SPEED: float = 6.0
const SPRINT_SPEED: float = 12.0
const MOUSE_SENSITIVITY: float = 0.003
const JUMP_VELOCITY: float = 5.0

var _camera_pivot: Node3D
var _camera: Camera3D


func _ready() -> void:
	add_to_group("player")
	
	# Build camera rig
	_camera_pivot = Node3D.new()
	_camera_pivot.name = "CameraPivot"
	_camera_pivot.position.y = 1.6
	add_child(_camera_pivot)
	
	_camera = Camera3D.new()
	_camera.name = "Camera3D"
	_camera.current = true
	_camera_pivot.add_child(_camera)
	
	# Add collision
	var col := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.8
	col.shape = capsule
	col.position.y = 0.9
	add_child(col)
	
	# Add a simple mesh so NPCs have something to see
	var mesh_inst := MeshInstance3D.new()
	var capsule_mesh := CapsuleMesh.new()
	capsule_mesh.radius = 0.35
	capsule_mesh.height = 1.8
	mesh_inst.mesh = capsule_mesh
	mesh_inst.position.y = 0.9
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.6, 1.0)
	mesh_inst.material_override = mat
	add_child(mesh_inst)
	
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		_camera_pivot.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
		_camera_pivot.rotation.x = clampf(_camera_pivot.rotation.x, -1.4, 1.4)
	
	if event.is_action_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	# Gravity
	if not is_on_floor():
		velocity.y -= 9.8 * delta

	# Jump
	if Input.is_key_pressed(KEY_SPACE) and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Movement
	var input_dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_W): input_dir.y -= 1
	if Input.is_key_pressed(KEY_S): input_dir.y += 1
	if Input.is_key_pressed(KEY_A): input_dir.x -= 1
	if Input.is_key_pressed(KEY_D): input_dir.x += 1
	input_dir = input_dir.normalized()

	var speed := SPRINT_SPEED if Input.is_key_pressed(KEY_SHIFT) else SPEED
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, speed * 5.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, speed * 5.0 * delta)

	move_and_slide()


func get_faction() -> String:
	return "player"
