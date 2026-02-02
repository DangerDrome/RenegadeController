## A single inventory slot. Holds an item reference and a quantity.
## Emits slot_changed whenever the contents are modified.
class_name InventorySlot extends Resource

signal slot_changed(slot: InventorySlot)

@export var item: ItemDefinition
@export var quantity: int = 0


func set_contents(new_item: ItemDefinition, new_quantity: int = 1) -> void:
	item = new_item
	quantity = new_quantity
	slot_changed.emit(self)


## Add to this stack. Returns the leftover that didn't fit.
func add(amount: int) -> int:
	if item == null:
		return amount
	var space := item.max_stack_size - quantity
	var added := mini(amount, space)
	quantity += added
	slot_changed.emit(self)
	return amount - added


## Remove from this stack. Returns the amount actually removed.
func remove(amount: int) -> int:
	var removed := mini(amount, quantity)
	quantity -= removed
	if quantity <= 0:
		clear()
	else:
		slot_changed.emit(self)
	return removed


func clear() -> void:
	item = null
	quantity = 0
	slot_changed.emit(self)


func is_empty() -> bool:
	return item == null or quantity <= 0


func can_stack_with(other: ItemDefinition) -> bool:
	return (
		item != null
		and other != null
		and item.id == other.id
		and quantity < item.max_stack_size
	)
