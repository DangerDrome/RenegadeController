## Specialized camera zone that toggles first-person mode.
## When the player enters, camera transitions to first-person.
## When the player exits, camera returns to previous mode.
@tool
class_name FirstPersonZone extends CameraZone

## Hide the player's visual mesh when in first-person.
@export var hide_player_mesh: bool = true

## Path to the mesh node on the player (relative to the CharacterBody3D root).
## Supports common setups like "Mesh", "Model", "Visual".
@export var mesh_node_path: String = "Mesh"


func _on_body_entered(body: Node3D) -> void:
	if Engine.is_editor_hint():
		return
	if body.is_in_group("player"):
		if hide_player_mesh:
			_set_mesh_visible(body, false)
		zone_entered.emit(self)


func _on_body_exited(body: Node3D) -> void:
	if Engine.is_editor_hint():
		return
	if body.is_in_group("player"):
		if hide_player_mesh:
			_set_mesh_visible(body, true)
		zone_exited.emit(self)


func _set_mesh_visible(body: Node3D, visible: bool) -> void:
	if body.has_node(mesh_node_path):
		var mesh_node := body.get_node(mesh_node_path)
		if mesh_node is Node3D:
			mesh_node.visible = visible
