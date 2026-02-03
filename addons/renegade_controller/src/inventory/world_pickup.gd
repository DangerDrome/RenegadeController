@tool
## A world pickup that integrates with the Cursor3D interactable system.
## Add to "interactable" group automatically. Click to pick up (or walk-to-then-pickup).
## Use @tool to preview in editor — change item property to see visual update.
class_name WorldPickup extends Area3D

## Emitted when item is picked up by a player. Connect for pickup sound, particle effect, or quest tracking.
signal picked_up(item: ItemDefinition, quantity: int)

@export_group("Item Data")
@export var item: ItemDefinition:
	set(value):
		item = value
		_update_visuals()
@export var quantity: int = 1:
	set(value):
		quantity = value
		_update_label()

@export_group("Visuals")
@export var bob_height: float = 0.1
@export var rotation_speed: float = 1.0
@export var highlight_color: Color = Color(1.0, 1.0, 0.5, 1.0)
@export var mesh_size: Vector3 = Vector3(0.3, 0.3, 0.3):
	set(value):
		mesh_size = value
		_update_visuals()

var _mesh: MeshInstance3D
var _label: Label3D
var _collision: CollisionShape3D
var _original_y: float
var _time: float = 0.0
var _original_material: Material
var _is_ready: bool = false


func _ready() -> void:
	_is_ready = true
	_ensure_children()
	_update_visuals()

	if not Engine.is_editor_hint():
		add_to_group("interactable")
		_original_y = global_position.y


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	_time += delta
	global_position.y = _original_y + sin(_time * 2.0) * bob_height
	rotate_y(rotation_speed * delta)


func _ensure_children() -> void:
	# Find or create collision shape.
	_collision = _find_child_of_type("CollisionShape3D") as CollisionShape3D
	if not _collision:
		_collision = CollisionShape3D.new()
		_collision.name = "CollisionShape3D"
		var shape := SphereShape3D.new()
		shape.radius = 0.5
		_collision.shape = shape
		add_child(_collision)
		if Engine.is_editor_hint():
			_collision.owner = get_tree().edited_scene_root

	# Find or create mesh.
	_mesh = _find_child_of_type("MeshInstance3D") as MeshInstance3D
	if not _mesh:
		_mesh = MeshInstance3D.new()
		_mesh.name = "Mesh"
		add_child(_mesh)
		if Engine.is_editor_hint():
			_mesh.owner = get_tree().edited_scene_root

	# Find or create label.
	_label = _find_child_of_type("Label3D") as Label3D
	if not _label:
		_label = Label3D.new()
		_label.name = "Label"
		_label.position = Vector3(0, 0.5, 0)
		_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_label.font_size = 18
		_label.outline_size = 6
		_label.modulate = Color(1, 1, 1, 0.9)
		add_child(_label)
		if Engine.is_editor_hint():
			_label.owner = get_tree().edited_scene_root


func _find_child_of_type(type_name: String) -> Node:
	for child in get_children():
		if child.get_class() == type_name:
			return child
	return null


func _update_visuals() -> void:
	if not _is_ready:
		return

	_ensure_children()

	# Update mesh.
	if _mesh:
		var box := BoxMesh.new()
		box.size = mesh_size
		_mesh.mesh = box

		var mat := StandardMaterial3D.new()
		mat.albedo_color = item.get_display_color() if item else ItemDefinition.get_default_color()
		_mesh.set_surface_override_material(0, mat)
		_original_material = mat

	# Update label.
	_update_label()


func _update_label() -> void:
	if not _label:
		return

	if item:
		if quantity > 1:
			_label.text = "%s x%d" % [item.display_name, quantity]
		else:
			_label.text = item.display_name
	else:
		_label.text = "[No Item]"


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
	var slots := _find_item_slots(interactor)
	if slots and not slots.has_free_slot():
		push_warning("WorldPickup: No free slots on %s" % interactor.name)
		return

	var inv := _find_inventory(interactor)
	if not inv:
		push_warning("WorldPickup: No inventory found on interactor %s" % interactor.name)
		return

	var remainder := inv.add_item(item, quantity)
	if remainder < quantity:
		var picked_qty := quantity - remainder
		picked_up.emit(item, picked_qty)

		# Attach visual to player slots.
		if slots:
			slots.attach_item(item, picked_qty)

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


func _find_item_slots(node: Node) -> ItemSlots:
	# Search for ItemSlots node by name in node and its children.
	if node.has_node("ItemSlots"):
		return node.get_node("ItemSlots") as ItemSlots
	# Check children (e.g., Player/Mesh/ItemSlots).
	for child in node.get_children():
		if child.has_node("ItemSlots"):
			return child.get_node("ItemSlots") as ItemSlots
	# Walk up to parent.
	if node.get_parent():
		if node.get_parent().has_node("ItemSlots"):
			return node.get_parent().get_node("ItemSlots") as ItemSlots
		for child in node.get_parent().get_children():
			if child.has_node("ItemSlots"):
				return child.get_node("ItemSlots") as ItemSlots
	return null
