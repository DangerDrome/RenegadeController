## Visual item slots for attaching picked up items to the player.
## Finds Marker3D children named "Slot_0", "Slot_1", etc. and attaches item meshes to them.
## Add this node as a child containing Marker3D slot positions, or let it find them automatically.
class_name ItemSlots extends Node3D

signal slot_filled(slot_index: int, item: ItemDefinition)
signal slot_cleared(slot_index: int)
signal slots_full

@export var item_scale: float = 0.15

var _slots: Array[Marker3D] = []
var _attached_meshes: Array[MeshInstance3D] = []
var _slot_items: Array[ItemDefinition] = []


func _ready() -> void:
	_find_slots()


func _find_slots() -> void:
	_slots.clear()
	_attached_meshes.clear()
	_slot_items.clear()

	# Find all Marker3D children named "Slot_N".
	for child in get_children():
		if child is Marker3D and child.name.begins_with("Slot_"):
			_slots.append(child)

	# Sort by name to ensure correct order.
	_slots.sort_custom(func(a, b): return a.name.naturalcasecmp_to(b.name) < 0)

	# Initialize parallel arrays.
	for i in _slots.size():
		_attached_meshes.append(null)
		_slot_items.append(null)



## Get total slot count.
var slot_count: int:
	get:
		return _slots.size()


## Check if there's at least one free slot.
func has_free_slot() -> bool:
	for item in _slot_items:
		if item == null:
			return true
	return false


## Get the number of free slots.
func get_free_slot_count() -> int:
	var count := 0
	for item in _slot_items:
		if item == null:
			count += 1
	return count


## Get the number of occupied slots.
func get_occupied_slot_count() -> int:
	return _slots.size() - get_free_slot_count()


## Attach an item visually to the next free slot. Returns slot index or -1 if full.
func attach_item(item: ItemDefinition, _quantity: int = 1) -> int:
	if _slots.is_empty():
		push_warning("ItemSlots: No slots found!")
		return -1

	# Find first free slot.
	var slot_index := -1
	for i in _slot_items.size():
		if _slot_items[i] == null:
			slot_index = i
			break

	if slot_index == -1:
		slots_full.emit()
		return -1

	_slot_items[slot_index] = item

	# Create visual mesh as child of the slot marker.
	var mesh := MeshInstance3D.new()
	mesh.name = "AttachedItem"
	var box := BoxMesh.new()
	box.size = Vector3(item_scale, item_scale, item_scale)
	mesh.mesh = box

	var mat := StandardMaterial3D.new()
	var color := _get_item_color(item)
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color * 0.3
	mesh.set_surface_override_material(0, mat)

	_slots[slot_index].add_child(mesh)
	_attached_meshes[slot_index] = mesh

	slot_filled.emit(slot_index, item)

	if not has_free_slot():
		slots_full.emit()

	return slot_index


## Remove an item from a specific slot. Returns the item or null.
func detach_slot(slot_index: int) -> ItemDefinition:
	if slot_index < 0 or slot_index >= _slots.size():
		return null

	var item := _slot_items[slot_index]
	if item == null:
		return null

	_slot_items[slot_index] = null

	# Remove visual.
	var mesh := _attached_meshes[slot_index]
	if mesh and is_instance_valid(mesh):
		mesh.queue_free()
	_attached_meshes[slot_index] = null

	slot_cleared.emit(slot_index)
	return item


## Remove the first slot containing a specific item type. Returns true if found.
func detach_item(item: ItemDefinition) -> bool:
	for i in _slot_items.size():
		if _slot_items[i] and _slot_items[i].id == item.id:
			detach_slot(i)
			return true
	return false


## Clear all slots.
func clear_all() -> void:
	for i in _slots.size():
		detach_slot(i)


## Get the item in a specific slot.
func get_slot_item(slot_index: int) -> ItemDefinition:
	if slot_index < 0 or slot_index >= _slots.size():
		return null
	return _slot_items[slot_index]


## Get all attached items (non-null entries).
func get_all_items() -> Array[ItemDefinition]:
	var result: Array[ItemDefinition] = []
	for item in _slot_items:
		if item:
			result.append(item)
	return result


func _get_item_color(item: ItemDefinition) -> Color:
	if not item:
		return Color(0.5, 0.5, 0.5)

	match item.item_type:
		ItemDefinition.ItemType.WEAPON:
			return Color(0.9, 0.5, 0.2)  # Orange
		ItemDefinition.ItemType.GEAR:
			return Color(0.3, 0.7, 0.9)  # Cyan
		ItemDefinition.ItemType.CONSUMABLE:
			return Color(0.2, 0.8, 0.3)  # Green
		ItemDefinition.ItemType.KEY_ITEM:
			return Color(0.9, 0.9, 0.2)  # Yellow
	return Color(0.5, 0.5, 0.5)
