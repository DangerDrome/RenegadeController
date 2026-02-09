## Full-screen customizer overlay.
## Layout: equipment slots (left) | turntable preview (center) | inventory (right).
## Connects to EquipmentManager and Inventory from renegade_controller via signals.
## CassettePunk aesthetic: dark charcoal background, amber/teal accents.
class_name CustomizerScreen
extends Control

## Emitted when an equipment change is requested (forward to EquipmentManager).
signal equip_requested(slot_name: StringName, item: Resource)
## Emitted when an unequip is requested.
signal unequip_requested(slot_name: StringName)

@export_group("Character")
## PackedScene of the character model to display in the turntable.
## Should contain a Skeleton3D with body group MeshInstance3D nodes.
@export var character_scene: PackedScene

@export_group("Equipment Slots")
## Define which equipment slots to show in the UI and their order.
@export var slot_definitions: Array[EquipmentSlotVisualConfig] = []

@onready var _turntable: TurntablePreview = %TurntablePreview
@onready var _equipment_container: VBoxContainer = %EquipmentContainer
@onready var _stat_panel: StatComparisonPanel = %StatComparisonPanel
@onready var _close_button: Button = %CloseButton
@onready var _front_btn: Button = %FrontButton
@onready var _back_btn: Button = %BackButton
@onready var _reset_btn: Button = %ResetButton

## External references — set via connect_* methods.
var _equipment_manager: Node
var _inventory: Node
var _visual_manager: EquipmentVisualManager

## Maps slot_name → EquipmentSlotUI for quick lookup.
var _slot_uis: Dictionary = {}


func _ready() -> void:
	visible = false

	# Hook up view buttons.
	if _close_button:
		_close_button.pressed.connect(func() -> void: visible = false)
	if _front_btn:
		_front_btn.pressed.connect(func() -> void: _turntable.snap_to_angle(0.0))
	if _back_btn:
		_back_btn.pressed.connect(func() -> void: _turntable.snap_to_angle(180.0))
	if _reset_btn:
		_reset_btn.pressed.connect(func() -> void: _turntable.reset_view())


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		visible = false
		get_viewport().set_input_as_handled()


## Connect to the external EquipmentManager from renegade_controller.
func connect_to_equipment_manager(manager: Node) -> void:
	_equipment_manager = manager

	# Create the visual manager for the turntable model.
	if not _visual_manager:
		_visual_manager = EquipmentVisualManager.new()
		_visual_manager.name = "VisualManager"
		add_child(_visual_manager)

	_visual_manager.connect_to_equipment_manager(manager)


## Connect to the external Inventory from renegade_controller.
func connect_to_inventory(inventory: Node) -> void:
	_inventory = inventory


## Refresh the entire display — call when opening the customizer.
func refresh() -> void:
	_setup_turntable()
	_setup_equipment_slots()
	_sync_equipment_state()
	if _turntable:
		_turntable.set_rendering_enabled(true)
		_turntable.request_render()


## Build equipment slot UIs from slot_definitions.
func _setup_equipment_slots() -> void:
	if not _equipment_container:
		return

	# Clear existing slots.
	for child in _equipment_container.get_children():
		child.queue_free()
	_slot_uis.clear()

	# Create a slot UI for each definition.
	var slot_scene := preload("res://addons/renegade_customizer/ui/equipment_slot_ui.tscn")

	for config in slot_definitions:
		var slot_ui: EquipmentSlotUI = slot_scene.instantiate() as EquipmentSlotUI
		slot_ui.slot_name = config.slot_name
		_equipment_container.add_child(slot_ui)
		_slot_uis[config.slot_name] = slot_ui

		# Connect slot signals.
		slot_ui.item_dropped.connect(_on_slot_item_dropped)
		slot_ui.item_removed.connect(_on_slot_item_removed)
		slot_ui.item_hovered.connect(_on_slot_item_hovered)
		slot_ui.hover_ended.connect(_on_slot_hover_ended)


## Load the character model into the turntable.
func _setup_turntable() -> void:
	if not _turntable or not character_scene:
		return

	var model := _turntable.load_character(character_scene)
	if not model:
		return

	# Find skeleton and configure visual manager.
	var skeleton := _turntable.find_skeleton()
	if skeleton and _visual_manager:
		_visual_manager.skeleton = skeleton
		_visual_manager.slot_configs = slot_definitions


## Sync slot UIs with current equipment state.
func _sync_equipment_state() -> void:
	if not _equipment_manager:
		return

	# Read current equipment from the manager.
	var equipped: Dictionary = {}
	if _equipment_manager.get("equipped"):
		equipped = _equipment_manager.equipped

	for slot_name in _slot_uis:
		var slot_ui: EquipmentSlotUI = _slot_uis[slot_name]
		var item: Resource = equipped.get(slot_name, null)
		slot_ui.set_item_silent(item)

	# Sync visuals.
	if _visual_manager:
		_visual_manager.sync_from_equipment(equipped)


# -- Signal handlers ---------------------------------------------------------

func _on_slot_item_dropped(slot_name: StringName, item: Resource) -> void:
	equip_requested.emit(slot_name, item)

	# Forward to equipment manager if connected.
	if _equipment_manager and _equipment_manager.has_method("equip"):
		_equipment_manager.equip(slot_name, item)

	# Update turntable visuals.
	if _visual_manager:
		_visual_manager.apply_equipment(slot_name, item)
		_turntable.request_render()


func _on_slot_item_removed(slot_name: StringName, _item: Resource) -> void:
	unequip_requested.emit(slot_name)

	if _equipment_manager and _equipment_manager.has_method("unequip"):
		_equipment_manager.unequip(slot_name)

	if _visual_manager:
		_visual_manager.apply_equipment(slot_name, null)
		_turntable.request_render()


func _on_slot_item_hovered(
	slot_name: StringName,
	incoming: Resource,
	current: Resource
) -> void:
	if _stat_panel:
		_stat_panel.show_comparison(incoming, current)


func _on_slot_hover_ended() -> void:
	if _stat_panel:
		_stat_panel.hide_comparison()
