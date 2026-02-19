## Loads, applies, and persists game settings.
## Reads from user://settings.tres on startup and writes changes back.
class_name SettingsManager extends Node


#region Settings
@export_group("Settings")
## Path to the settings file.
@export var settings_path: String = "user://settings.tres"

## Default settings resource to use when no saved settings exist.
@export var default_settings: SettingsData
#endregion


## The currently active settings.
var current_settings: SettingsData


func _ready() -> void:
	_load_settings()


## Apply all current settings to the engine (window mode, audio buses, etc.).
func apply_settings() -> void:
	pass


## Save current settings to disk.
func save_settings() -> void:
	pass


## Reset to default settings and apply.
func reset_to_defaults() -> void:
	pass


## Load settings from disk or create defaults.
func _load_settings() -> void:
	pass
