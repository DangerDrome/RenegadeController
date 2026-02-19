## Title screen / main menu.
## Provides signals for menu actions; GameDirector listens and responds.
class_name MainMenu extends Control


## Emitted when the player selects "New Game".
signal new_game_requested
## Emitted when the player selects "Continue" (load most recent save).
signal continue_requested
## Emitted when the player selects "Load Game".
signal load_requested
## Emitted when the player opens settings.
signal settings_requested
## Emitted when the player selects "Quit".
signal quit_requested


#region Buttons
@export_group("Buttons")
## New game button.
@export var new_game_button: Button
## Continue button.
@export var continue_button: Button
## Load game button.
@export var load_button: Button
## Settings button.
@export var settings_button: Button
## Quit button.
@export var quit_button: Button
#endregion


## Show the main menu.
func show_menu() -> void:
	pass


## Hide the main menu.
func hide_menu() -> void:
	pass
