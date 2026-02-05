## UI representation of a single inventory slot.
## Displays item icon, quantity badge, and selection highlight.
class_name InventorySlotUI extends PanelContainer

signal clicked(button_index: int)

@export var empty_color: Color = Color(0.15, 0.15, 0.15, 0.8)
@export var hover_color: Color = Color(0.25, 0.25, 0.25, 0.9)
@export var selected_color: Color = Color(0.4, 0.35, 0.1, 0.9)

var slot_index: int = -1
var _is_selected: bool = false

@onready var _icon: TextureRect = %Icon
@onready var _quantity_label: Label = %QuantityLabel
@onready var _bg: Panel = %Background


func _ready() -> void:
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	_set_bg_color(empty_color)


func update_display(slot: InventorySlot) -> void:
	if slot.is_empty():
		_icon.texture = null
		_icon.modulate = Color(1, 1, 1, 0.2)
		_quantity_label.visible = false
	else:
		_icon.texture = slot.item.icon
		_icon.modulate = Color.WHITE
		_quantity_label.visible = slot.quantity > 1
		_quantity_label.text = str(slot.quantity)


func set_selected(selected: bool) -> void:
	_is_selected = selected
	_set_bg_color(selected_color if selected else empty_color)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			clicked.emit(MOUSE_BUTTON_LEFT)
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			clicked.emit(MOUSE_BUTTON_RIGHT)


func _on_mouse_entered() -> void:
	if not _is_selected:
		_set_bg_color(hover_color)


func _on_mouse_exited() -> void:
	if not _is_selected:
		_set_bg_color(empty_color)


func _set_bg_color(color: Color) -> void:
	if _bg:
		var style := StyleBoxFlat.new()
		style.bg_color = color
		style.corner_radius_top_left = 4
		style.corner_radius_top_right = 4
		style.corner_radius_bottom_left = 4
		style.corner_radius_bottom_right = 4
		_bg.add_theme_stylebox_override("panel", style)
