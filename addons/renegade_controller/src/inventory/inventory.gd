## Inventory container. Add as a child of RenegadeCharacter (or any node).
## Manages a fixed array of InventorySlots with stack-aware add/remove.
class_name Inventory extends Node

## Emitted when an item is added. Connect to update UI (HUD, inventory screen).
signal item_added(item: ItemDefinition, slot_index: int, quantity: int)
## Emitted when an item is removed. Connect to update UI.
signal item_removed(item: ItemDefinition, slot_index: int, quantity: int)
## Emitted when any slot's contents change. Connect for slot-specific UI updates.
signal slot_changed(slot_index: int)
## Emitted when inventory cannot accept more items. Connect for player feedback (sound, message).
signal inventory_full

@export_group("Configuration")
@export var max_slots: int = 20

var slots: Array[InventorySlot] = []


func _ready() -> void:
	_initialize_slots()


func _initialize_slots() -> void:
	slots.clear()
	for i in max_slots:
		var slot := InventorySlot.new()
		slot.slot_changed.connect(_on_slot_changed.bind(i))
		slots.append(slot)


func _on_slot_changed(_slot: InventorySlot, slot_index: int) -> void:
	slot_changed.emit(slot_index)


## Add an item to the inventory. Returns the quantity that didn't fit (0 = all added).
func add_item(item: ItemDefinition, quantity: int = 1) -> int:
	var remaining := quantity

	# First pass: stack with existing matching items.
	for i in slots.size():
		if remaining <= 0:
			break
		if slots[i].can_stack_with(item):
			var before := remaining
			remaining = slots[i].add(remaining)
			item_added.emit(item, i, before - remaining)

	# Second pass: fill empty slots.
	for i in slots.size():
		if remaining <= 0:
			break
		if slots[i].is_empty():
			var to_add := mini(remaining, item.max_stack_size)
			slots[i].set_contents(item, to_add)
			remaining -= to_add
			item_added.emit(item, i, to_add)

	if remaining > 0:
		inventory_full.emit()
	return remaining


## Remove a quantity of an item. Returns the amount that couldn't be removed.
func remove_item(item: ItemDefinition, quantity: int = 1) -> int:
	var remaining := quantity
	# Remove from last slot first so partial stacks drain before full ones.
	for i in range(slots.size() - 1, -1, -1):
		if remaining <= 0:
			break
		if slots[i].item and slots[i].item.id == item.id:
			var removed := slots[i].remove(remaining)
			remaining -= removed
			item_removed.emit(item, i, removed)
	return remaining


## Check if inventory contains at least [quantity] of an item.
func has_item(item: ItemDefinition, quantity: int = 1) -> bool:
	return get_item_count(item) >= quantity


## Get the total count of a specific item across all slots.
func get_item_count(item: ItemDefinition) -> int:
	var count := 0
	for slot in slots:
		if slot.item and slot.item.id == item.id:
			count += slot.quantity
	return count


## Get all non-empty slots matching a given item type.
func get_items_of_type(type: ItemDefinition.ItemType) -> Array[InventorySlot]:
	var result: Array[InventorySlot] = []
	for slot in slots:
		if slot.item and slot.item.item_type == type:
			result.append(slot)
	return result


## Get the first slot containing a specific item, or null.
func find_item(item: ItemDefinition) -> InventorySlot:
	for slot in slots:
		if slot.item and slot.item.id == item.id:
			return slot
	return null


## Swap the contents of two slots by index.
func swap_slots(from_index: int, to_index: int) -> void:
	if from_index == to_index:
		return
	if from_index < 0 or from_index >= slots.size():
		return
	if to_index < 0 or to_index >= slots.size():
		return

	var from_item := slots[from_index].item
	var from_qty := slots[from_index].quantity
	var to_item := slots[to_index].item
	var to_qty := slots[to_index].quantity

	# If same item type — try to merge stacks.
	if from_item and to_item and from_item.id == to_item.id:
		var space := to_item.max_stack_size - to_qty
		var transfer := mini(from_qty, space)
		slots[to_index].set_contents(to_item, to_qty + transfer)
		if from_qty - transfer <= 0:
			slots[from_index].clear()
		else:
			slots[from_index].set_contents(from_item, from_qty - transfer)
		return

	# Different items — plain swap.
	if from_item:
		slots[to_index].set_contents(from_item, from_qty)
	else:
		slots[to_index].clear()

	if to_item:
		slots[from_index].set_contents(to_item, to_qty)
	else:
		slots[from_index].clear()


## Returns true if every slot is occupied.
func is_full() -> bool:
	for slot in slots:
		if slot.is_empty():
			return false
	return true


## Returns the number of empty slots.
func get_empty_slot_count() -> int:
	var count := 0
	for slot in slots:
		if slot.is_empty():
			count += 1
	return count
