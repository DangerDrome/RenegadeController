## Manages equipped items across named slots (primary, secondary, throwable, armor).
## Pairs with Inventory for storage and WeaponManager for weapon instantiation.
class_name EquipmentManager extends Node

## Emitted when an item is equipped to a slot. Connect to update equipment UI or play equip sound.
signal item_equipped(item: ItemDefinition, slot: StringName)
## Emitted when an item is unequipped from a slot. Connect to update equipment UI or return item to inventory display.
signal item_unequipped(item: ItemDefinition, slot: StringName)
## Emitted when the active weapon changes (switch or equip). Connect to update HUD weapon display.
signal active_weapon_changed(weapon: WeaponDefinition)

@export_group("References")
@export var inventory: Inventory
@export var weapon_manager: WeaponManager

## Currently equipped items keyed by slot name.
var equipped: Dictionary = {
	&"primary": null,
	&"secondary": null,
	&"throwable": null,
	&"armor": null,
}

var _active_weapon_slot: StringName = &"primary"


## Check if an item is allowed in a given slot.
func can_equip(item: ItemDefinition, slot: StringName) -> bool:
	if slot not in equipped:
		return false
	if item.slot_restrictions.is_empty():
		return true
	return slot in item.slot_restrictions


## Equip an item to a slot. Returns true on success.
func equip(item: ItemDefinition, slot: StringName) -> bool:
	if not can_equip(item, slot):
		return false

	# Unequip whatever is in this slot first.
	var previous := equipped.get(slot) as ItemDefinition
	if previous:
		unequip(slot)

	equipped[slot] = item
	item_equipped.emit(item, slot)

	# If this is the active weapon slot, tell the weapon manager.
	if item is WeaponDefinition and slot == _active_weapon_slot:
		if weapon_manager:
			weapon_manager.set_weapon(item as WeaponDefinition)
		active_weapon_changed.emit(item as WeaponDefinition)

	return true


## Unequip whatever is in a slot. Returns the item that was removed (or null).
func unequip(slot: StringName) -> ItemDefinition:
	var item := equipped.get(slot) as ItemDefinition
	if not item:
		return null

	equipped[slot] = null
	item_unequipped.emit(item, slot)

	if slot == _active_weapon_slot and weapon_manager:
		weapon_manager.clear_weapon()

	return item


## Switch the active weapon between primary/secondary.
func switch_active_weapon(to_slot: StringName) -> void:
	if to_slot not in [&"primary", &"secondary"]:
		return
	if to_slot == _active_weapon_slot:
		return

	_active_weapon_slot = to_slot
	var weapon := equipped.get(to_slot) as WeaponDefinition

	if weapon_manager:
		weapon_manager.set_weapon(weapon)
	active_weapon_changed.emit(weapon)


## Get whichever weapon is currently active (may be null).
func get_active_weapon() -> WeaponDefinition:
	return equipped.get(_active_weapon_slot) as WeaponDefinition


## Get the active weapon slot name.
func get_active_weapon_slot() -> StringName:
	return _active_weapon_slot


## Get equipped item in a specific slot (or null).
func get_equipped(slot: StringName) -> ItemDefinition:
	return equipped.get(slot) as ItemDefinition


## Check if a specific slot has an item.
func has_equipped(slot: StringName) -> bool:
	return equipped.get(slot) != null
