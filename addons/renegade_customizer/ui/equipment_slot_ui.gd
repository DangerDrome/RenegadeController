## A single equipment slot in the customizer UI.
## Accepts drag-and-drop from inventory slots, shows equipped item icon,
## highlights valid/invalid during drag, and emits signals for equip/unequip.
class_name EquipmentSlotUI
extends PanelContainer

## Emitted when an item is dropped into this slot.
signal item_dropped(slot_name: StringName, item: Resource)
## Emitted when an item is dragged out of this slot.
signal item_removed(slot_name: StringName, item: Resource)
## Emitted when the user hovers this slot with an item (for stat comparison).
signal item_hovered(slot_name: StringName, incoming: Resource, current: Resource)
## Emitted when hover ends.
signal hover_ended

@export_group("Slot Identity")
## Must match the slot name in EquipmentManager (e.g., &"primary", &"head", &"torso").
@export var slot_name: StringName
## Item types accepted by this slot (e.g., [&"weapon"], [&"gear"]).
@export var accepted_item_types: Array[StringName] = []

@export_group("Visuals")
## Icon shown when the slot is empty — a silhouette outline of the expected item type.
@export var empty_icon: Texture2D
## Size of the slot in pixels.
@export var slot_size := Vector2(80, 80)

## The currently equipped item Resource (ItemDefinition or subclass).
var _current_item: Resource = null

@onready var _icon: TextureRect = %SlotIcon
@onready var _highlight: ColorRect = %Highlight
@onready var _rarity_border: ColorRect = %RarityBorder


func _ready() -> void:
	custom_minimum_size = slot_size
	_update_display()
	if _highlight:
		_highlight.visible = false


func _process(_delta: float) -> void:
	_update_drag_highlight()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.is_pressed():
		match event.button_index:
			MOUSE_BUTTON_RIGHT:
				if _current_item:
					_unequip_item()
			MOUSE_BUTTON_LEFT:
				if event.double_click and _current_item:
					_unequip_item()


# -- Drag and drop -----------------------------------------------------------

func _get_drag_data(_at_position: Vector2) -> Variant:
	if _current_item == null:
		return null

	# Create drag preview.
	var preview := TextureRect.new()
	if _current_item.get("icon"):
		preview.texture = _current_item.icon
	preview.modulate = Color(1, 1, 1, 0.7)
	preview.custom_minimum_size = Vector2(64, 64)
	preview.size = Vector2(64, 64)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	set_drag_preview(preview)

	var data := {
		"item": _current_item,
		"source_slot": self,
		"source_type": "equipment",
		"source_slot_name": slot_name,
	}
	return data


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if data is not Dictionary or not data.has("item"):
		return false
	var item: Resource = data["item"]
	return _is_item_compatible(item)


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	var incoming: Resource = data["item"]
	var source: Control = data.get("source_slot")

	# If slot already has an item, send it back to the source (swap).
	if _current_item != null and source:
		var displaced := _current_item
		_current_item = null
		if source.has_method("receive_item"):
			source.receive_item(displaced)
		else:
			# Fallback: emit removal so inventory can pick it up.
			item_removed.emit(slot_name, displaced)

	# Clear the source slot.
	if source and source.has_method("clear_slot"):
		source.clear_slot()

	# Equip the incoming item.
	_equip_item(incoming)


# -- Public API --------------------------------------------------------------

## Set the displayed item without triggering signals (used for initial sync).
func set_item_silent(item: Resource) -> void:
	_current_item = item
	_update_display()


## Receive an item from a swap operation.
func receive_item(item: Resource) -> void:
	_equip_item(item)


## Clear this slot without emitting signals (used by drag source cleanup).
func clear_slot() -> void:
	_current_item = null
	_update_display()


## Get the current item in this slot.
func get_item() -> Resource:
	return _current_item


## Check if this slot is empty.
func is_empty() -> bool:
	return _current_item == null


# -- Private -----------------------------------------------------------------

func _equip_item(item: Resource) -> void:
	_current_item = item
	_update_display()
	item_dropped.emit(slot_name, item)


func _unequip_item() -> void:
	var item := _current_item
	_current_item = null
	_update_display()
	item_removed.emit(slot_name, item)


func _is_item_compatible(item: Resource) -> bool:
	if accepted_item_types.is_empty():
		return true  # Accept anything if no restrictions.

	# Check item_type enum name against accepted types.
	if item.get("item_type") != null:
		var type_name := StringName(str(item.item_type))
		if type_name in accepted_item_types:
			return true

	# Check slot_restrictions on the item itself.
	if item.get("slot_restrictions") and item.slot_restrictions is Array:
		for restriction in item.slot_restrictions:
			if restriction == slot_name:
				return true

	return false


func _update_display() -> void:
	if not _icon:
		return

	if _current_item and _current_item.get("icon"):
		_icon.texture = _current_item.icon
		_icon.modulate = Color.WHITE
	elif empty_icon:
		_icon.texture = empty_icon
		_icon.modulate = Color(1, 1, 1, 0.3)  # Dim silhouette.
	else:
		_icon.texture = null

	_update_rarity_border()


func _update_rarity_border() -> void:
	if not _rarity_border:
		return

	if _current_item == null:
		_rarity_border.visible = false
		return

	# CassettePunk rarity colors.
	var rarity_colors := {
		0: Color("#D4C5A9"),  # Common — beige/cardboard
		1: Color("#2EC4B6"),  # Uncommon — Miami Vice teal
		2: Color("#FF3366"),  # Rare — hot pink
		3: Color("#C0C0C0"),  # Epic — chrome silver
		4: Color("#FFD700"),  # Legendary — gold foil
	}

	var rarity: int = _current_item.get("rarity", 0) if _current_item else 0
	_rarity_border.visible = rarity > 0
	_rarity_border.color = rarity_colors.get(rarity, Color.WHITE)


func _update_drag_highlight() -> void:
	if not _highlight:
		return

	var vp := get_viewport()
	if not vp:
		_highlight.visible = false
		return

	if vp.gui_is_dragging():
		var data: Variant = vp.gui_get_drag_data()
		if data is Dictionary and data.has("item"):
			_highlight.visible = true
			var compatible := _is_item_compatible(data["item"])
			_highlight.color = (
				Color(0.4, 1.0, 0.4, 0.15) if compatible
				else Color(1.0, 0.3, 0.3, 0.08)
			)
			return

	_highlight.visible = false


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_MOUSE_ENTER:
			if _current_item:
				# Trigger stat comparison on hover.
				var vp := get_viewport()
				if vp and vp.gui_is_dragging():
					var data: Variant = vp.gui_get_drag_data()
					if data is Dictionary and data.has("item"):
						item_hovered.emit(slot_name, data["item"], _current_item)
		NOTIFICATION_MOUSE_EXIT:
			hover_ended.emit()
