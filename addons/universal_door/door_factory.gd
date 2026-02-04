class_name DoorFactory
extends RefCounted
## Helper for creating pre-configured door instances at runtime
## Usage: var door = DoorFactory.create_sliding_door(mesh, collision_shape)

const DOOR_SCENE_PATH := "res://addons/universal_door/universal_door.tscn"


static func create_normal_door(
	door_mesh: Mesh = null,
	door_collision: Shape3D = null,
	open_degrees: float = 90.0,
	opens_inward: bool = true
) -> UniversalDoor:
	var door := _create_base_door(door_mesh, door_collision)
	door.door_type = UniversalDoor.DoorType.NORMAL
	door.open_amount = -open_degrees if opens_inward else open_degrees
	return door


static func create_sliding_door(
	door_mesh: Mesh = null,
	door_collision: Shape3D = null,
	slide_distance: float = 2.0,
	slide_left: bool = true
) -> UniversalDoor:
	var door := _create_base_door(door_mesh, door_collision)
	door.door_type = UniversalDoor.DoorType.SLIDING
	door.open_amount = -slide_distance if slide_left else slide_distance
	return door


static func create_garage_door(
	door_mesh: Mesh = null,
	door_collision: Shape3D = null,
	roll_height: float = 3.0
) -> UniversalDoor:
	var door := _create_base_door(door_mesh, door_collision)
	door.door_type = UniversalDoor.DoorType.GARAGE
	door.open_amount = roll_height
	return door


static func create_elevator_door(
	left_mesh: Mesh = null,
	right_mesh: Mesh = null,
	panel_collision: Shape3D = null,
	total_opening: float = 2.0
) -> UniversalDoor:
	var door := _load_door_scene()
	door.door_type = UniversalDoor.DoorType.ELEVATOR
	door.open_amount = total_opening
	
	var door_body: Node3D = door.get_node("DoorBody")
	
	# Setup left panel
	var left_panel: Node3D = door_body.get_node("LeftPanel")
	left_panel.visible = true
	if left_mesh:
		var left_mesh_node := MeshInstance3D.new()
		left_mesh_node.mesh = left_mesh
		left_panel.add_child(left_mesh_node)
	if panel_collision:
		var left_col := CollisionShape3D.new()
		left_col.shape = panel_collision.duplicate()
		left_panel.add_child(left_col)
	
	# Setup right panel
	var right_panel: Node3D = door_body.get_node("RightPanel")
	right_panel.visible = true
	if right_mesh:
		var right_mesh_node := MeshInstance3D.new()
		right_mesh_node.mesh = right_mesh
		right_panel.add_child(right_mesh_node)
	if panel_collision:
		var right_col := CollisionShape3D.new()
		right_col.shape = panel_collision.duplicate()
		right_panel.add_child(right_col)
	
	return door


static func create_teleport_pair(
	door_a: UniversalDoor,
	door_b: UniversalDoor,
	bidirectional: bool = true
) -> void:
	door_a.teleport_enabled = true
	door_a.teleport_target = door_b
	
	if bidirectional:
		door_b.teleport_enabled = true
		door_b.teleport_target = door_a


static func create_teleport_network(doors: Array[UniversalDoor], group_name: StringName) -> void:
	## Links multiple doors via group - each door teleports to the next one in the array
	for door in doors:
		door.teleport_enabled = true
		door.teleport_target_group = group_name
		door.add_to_group(group_name)


static func _load_door_scene() -> UniversalDoor:
	if not ResourceLoader.exists(DOOR_SCENE_PATH):
		push_error("DoorFactory: Scene not found at " + DOOR_SCENE_PATH)
		return null
	var scene: PackedScene = load(DOOR_SCENE_PATH)
	return scene.instantiate() as UniversalDoor


static func _create_base_door(door_mesh: Mesh, door_collision: Shape3D) -> UniversalDoor:
	var door := _load_door_scene()
	if not door:
		return null
	
	var door_body: Node3D = door.get_node("DoorBody")
	
	if door_mesh:
		var mesh_node: MeshInstance3D = door_body.get_node("MeshInstance3D")
		mesh_node.mesh = door_mesh
	
	if door_collision:
		var col_node: CollisionShape3D = door_body.get_node("CollisionShape3D")
		col_node.shape = door_collision
	
	return door
