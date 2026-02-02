## A world pickup that integrates with the Cursor3D interactable system.
## Add to "interactable" group automatically. Click to pick up (or walk-to-then-pickup).
class_name WorldPickup extends Area3D

signal picked_up(item: ItemDefinition, quantity: int)

@export_group("Item Data")
@export var item: ItemDefinition
@export var quantity: int = 1

@export_group("Visuals")
@export var bob_height: float = 0.1
@export var rotation_speed: float = 1.0
@export var highlight_color: Color = Color(1.0, 1.0, 0.5, 1.0)

var _mesh: MeshInstance3D
var _original_y: float
var _time: float = 0.0
var _original_material: Material


func _ready() -> void:
	add_to_group("interactable")

	# Find or create the mesh child.
	_mesh = _find_or_create_mesh()
	_original_y = global_position.y

	if _mesh:
		_original_material = _mesh.get_surface_override_material(0)


func _process(delta: float) -> void:
	_time += delta
	global_position.y = _original_y + sin(_time * 2.0) * bob_height
	rotate_y(rotation_speed * delta)


## Cursor3D callback — mouse hovering over this pickup.
func on_cursor_enter() -> void:
	if _mesh:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = highlight_color
		mat.emission_enabled = true
		mat.emission = highlight_color * 0.3
		_mesh.set_surface_override_material(0, mat)


## Cursor3D callback — mouse left this pickup.
func on_cursor_exit() -> void:
	if _mesh:
		_mesh.set_surface_override_material(0, _original_material)


## Cursor3D callback — player clicked / arrived at this pickup.
func on_interact(interactor: Node) -> void:
	var inv := _find_inventory(interactor)
	if not inv:
		push_warning("WorldPickup: No inventory found on interactor %s" % interactor.name)
		return

	var remainder := inv.add_item(item, quantity)
	if remainder < quantity:
		picked_up.emit(item, quantity - remainder)
		if remainder <= 0:
			queue_free()
		else:
			quantity = remainder


## Returns an interaction prompt string for UI display.
func get_interaction_prompt() -> String:
	if not item:
		return "Pick up"
	if quantity > 1:
		return "Pick up %s (x%d)" % [item.display_name, quantity]
	return "Pick up %s" % item.display_name


func _find_inventory(node: Node) -> Inventory:
	# Check if the interactor has an Inventory child directly.
	if node.has_node("Inventory"):
		return node.get_node("Inventory") as Inventory
	# Walk up to parent (in case interactor is a controller, not the character).
	if node.get_parent() and node.get_parent().has_node("Inventory"):
		return node.get_parent().get_node("Inventory") as Inventory
	return null


func _find_or_create_mesh() -> MeshInstance3D:
	# Use existing MeshInstance3D child if present.
	for child in get_children():
		if child is MeshInstance3D:
			return child

	# Otherwise create one from the item's world_mesh.
	if item and item.world_mesh:
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.mesh = item.world_mesh
		add_child(mesh_instance)
		return mesh_instance

	# Fallback: a small sphere so the pickup is visible.
	var mesh_instance := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.2
	sphere.height = 0.4
	mesh_instance.mesh = sphere
	add_child(mesh_instance)
	return mesh_instance
