## In-game pause menu.
## process_mode is WHEN_PAUSED so it stays responsive while the game is paused.
class_name PauseMenu extends Control


## Emitted when the player selects "Resume".
signal resume_requested
## Emitted when the player selects "Save Game".
signal save_requested
## Emitted when the player selects "Load Game".
signal load_requested
## Emitted when the player opens settings.
signal settings_requested
## Emitted when the player selects "Return to Main Menu".
signal return_to_menu_requested
## Emitted when the player selects "Quit".
signal quit_requested


#region Buttons
@export_group("Buttons")
@export var resume_button: Button
@export var save_button: Button
@export var load_button: Button
@export var settings_button: Button
@export var return_to_menu_button: Button
@export var quit_button: Button
#endregion


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		pass
