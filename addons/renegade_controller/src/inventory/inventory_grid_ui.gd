## Grid-based inventory UI. Bind to an Inventory node and it creates/updates
## InventorySlotUI children automatically.
class_name InventoryGridUI extends GridContainer

signal slot_clicked(slot_index: int, button: int)
signal slot_hovered(slot_index: int)

const SLOT_SCENE := preload("res://addons/renegade_controller/src/inventory/inventory_slot_ui.tscn")

@export_group("References")
@export var inventory: Inventory

@export_group("Layout")
@export var grid_columns: int = 5

var _slot_uis: Array[InventorySlotUI] = []
var _selected_index: int = -1


func _ready() -> void:
	columns = grid_columns
	if inventory:
		bind_to_inventory(inventory)


## Bind this grid to an inventory. Clears and rebuilds all slot UIs.
func bind_to_inventory(inv: Inventory) -> void:
	inventory = inv
	_clear_slots()
	_create_slots()
	inventory.slot_changed.connect(_on_slot_changed)


## Refresh all slot displays.
func refresh() -> void:
	for i in _slot_uis.size():
		if i < inventory.slots.size():
			_slot_uis[i].update_display(inventory.slots[i])


## Set which slot is visually selected.
func set_selected(index: int) -> void:
	if _selected_index >= 0 and _selected_index < _slot_uis.size():
		_slot_uis[_selected_index].set_selected(false)
	_selected_index = index
	if _selected_index >= 0 and _selected_index < _slot_uis.size():
		_slot_uis[_selected_index].set_selected(true)


func _clear_slots() -> void:
	for slot_ui in _slot_uis:
		slot_ui.queue_free()
	_slot_uis.clear()


func _create_slots() -> void:
	if not inventory:
		return
	for i in inventory.slots.size():
		var slot_ui := SLOT_SCENE.instantiate() as InventorySlotUI
		slot_ui.slot_index = i
		slot_ui.update_display(inventory.slots[i])
		slot_ui.clicked.connect(_on_slot_ui_clicked.bind(i))
		slot_ui.mouse_entered.connect(func(): slot_hovered.emit(i))
		add_child(slot_ui)
		_slot_uis.append(slot_ui)


func _on_slot_changed(slot_index: int) -> void:
	if slot_index >= 0 and slot_index < _slot_uis.size():
		_slot_uis[slot_index].update_display(inventory.slots[slot_index])


func _on_slot_ui_clicked(button: int, slot_index: int) -> void:
	slot_clicked.emit(slot_index, button)
