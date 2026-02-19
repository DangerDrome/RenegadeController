## Detects input device changes and handles action remapping.
## Emits signals when the player switches between keyboard/mouse and gamepad.
class_name InputManager extends Node


enum DeviceType {
	KEYBOARD_MOUSE,
	GAMEPAD,
}


## Emitted when the active input device changes.
signal input_device_changed(device: DeviceType)


#region Settings
@export_group("Settings")
## Gamepad stick deadzone.
@export_range(0.01, 0.5, 0.01) var gamepad_deadzone: float = 0.15
#endregion


## The currently detected input device.
var current_device: DeviceType = DeviceType.KEYBOARD_MOUSE


func _input(event: InputEvent) -> void:
	pass


## Remap an input action to a new event.
func remap_action(action: String, event: InputEvent) -> void:
	pass


## Reset an action to its default mapping.
func reset_action(action: String) -> void:
	pass


## Returns the current device type.
func get_device_type() -> DeviceType:
	return current_device
