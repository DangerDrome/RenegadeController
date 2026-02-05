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
## If remove_from_inventory is true and inventory is set, removes the item from inventory.
func equip(item: ItemDefinition, slot: StringName, remove_from_inventory: bool = true) -> bool:
	if not can_equip(item, slot):
		return false

	# Unequip whatever is in this slot first.
	var previous := equipped.get(slot) as ItemDefinition
	if previous:
		unequip(slot)

	# Remove from inventory to prevent item duplication
	if remove_from_inventory and inventory and inventory.has_item(item):
		inventory.remove_item(item, 1)

	equipped[slot] = item
	item_equipped.emit(item, slot)

	# If this is the active weapon slot, tell the weapon manager.
	if item is WeaponDefinition and slot == _active_weapon_slot:
		if weapon_manager:
			weapon_manager.set_weapon(item as WeaponDefinition)
		active_weapon_changed.emit(item as WeaponDefinition)

	return true


## Unequip whatever is in a slot. Returns the item that was removed (or null).
## If return_to_inventory is true and inventory is set, adds the item back to inventory.
func unequip(slot: StringName, return_to_inventory: bool = true) -> ItemDefinition:
	var item := equipped.get(slot) as ItemDefinition
	if not item:
		return null

	equipped[slot] = null
	item_unequipped.emit(item, slot)

	if slot == _active_weapon_slot and weapon_manager:
		weapon_manager.clear_weapon()

	# Return item to inventory to prevent item loss
	if return_to_inventory and inventory:
		inventory.add_item(item, 1)

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


## Get total armor value from all equipped gear.
func get_total_armor() -> float:
	var total := 0.0
	for item in equipped.values():
		if item is GearDefinition:
			total += item.armor_value
	return total


## Get total damage reduction from all equipped gear.
func get_total_damage_reduction() -> float:
	var total := 0.0
	for item in equipped.values():
		if item is GearDefinition:
			total += item.damage_reduction
	return clampf(total, 0.0, 1.0)  # Cap at 100% reduction


## Get total speed modifier from all equipped gear (additive percentage).
func get_speed_modifier() -> float:
	var total := 0.0
	for item in equipped.values():
		if item is GearDefinition:
			total += item.speed_modifier
	return total


## Get total stealth modifier from all equipped gear (additive percentage).
func get_stealth_modifier() -> float:
	var total := 0.0
	for item in equipped.values():
		if item is GearDefinition:
			total += item.stealth_modifier
	return total
