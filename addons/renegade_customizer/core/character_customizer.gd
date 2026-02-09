## Main controller for the character customizer system.
## Bridges the inventory plugin (renegade_controller) with the customizer UI and visuals.
## Attach as a child of your game scene or UI root and call setup methods.
class_name CharacterCustomizer
extends Node

## Emitted when the customizer screen opens.
signal customizer_opened
## Emitted when the customizer screen closes.
signal customizer_closed

@export_group("Input")
## Input action name that toggles the customizer. Create this in Project → Input Map.
@export var toggle_action: StringName = &"toggle_customizer"

@export_group("References")
## The customizer screen UI scene. Will be instanced on first open if not already in tree.
@export var customizer_screen_scene: PackedScene

## Runtime references — set via connect_* methods or @export if in same scene tree.
var _equipment_manager: Node
var _inventory: Node
var _customizer_screen: Control
var _is_open := false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(toggle_action):
		toggle()
		get_viewport().set_input_as_handled()


## Wire up the external EquipmentManager (from renegade_controller plugin).
func connect_to_equipment_manager(manager: Node) -> void:
	_equipment_manager = manager


## Wire up the external Inventory (from renegade_controller plugin).
func connect_to_inventory(inventory: Node) -> void:
	_inventory = inventory


## Toggle customizer open/closed.
func toggle() -> void:
	if _is_open:
		close()
	else:
		open()


## Open the customizer screen.
func open() -> void:
	if _is_open:
		return

	_ensure_screen_exists()
	if not _customizer_screen:
		push_warning("CharacterCustomizer: No customizer screen available.")
		return

	_customizer_screen.visible = true
	_is_open = true

	# Wire connections if not already done.
	if _equipment_manager and _customizer_screen.has_method("connect_to_equipment_manager"):
		_customizer_screen.connect_to_equipment_manager(_equipment_manager)
	if _inventory and _customizer_screen.has_method("connect_to_inventory"):
		_customizer_screen.connect_to_inventory(_inventory)
	if _customizer_screen.has_method("refresh"):
		_customizer_screen.refresh()

	customizer_opened.emit()


## Close the customizer screen.
func close() -> void:
	if not _is_open:
		return

	if _customizer_screen:
		_customizer_screen.visible = false

	_is_open = false
	customizer_closed.emit()


func _ensure_screen_exists() -> void:
	if _customizer_screen and is_instance_valid(_customizer_screen):
		return

	if customizer_screen_scene:
		_customizer_screen = customizer_screen_scene.instantiate() as Control
		# Add to the CanvasLayer or UI root. Default: add to self.
		add_child(_customizer_screen)
		_customizer_screen.visible = false
