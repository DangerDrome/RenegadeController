## Manages save slots, auto-save, and save file validation.
## Handles reading/writing SaveData resources to disk.
class_name SaveManager extends Node


## Emitted when a save operation completes successfully.
signal save_completed(slot: int)

## Emitted when a load operation completes successfully.
signal load_completed(slot: int)

## Emitted when a save file fails validation (corruption detected).
signal save_corrupted(slot: int)


#region Settings
@export_group("Settings")
## Directory where save files are stored.
@export var save_directory: String = "user://saves/"

## Maximum number of save slots.
@export var max_slots: int = 10

## File extension for save files.
@export var save_extension: String = ".tres"
#endregion


## Save the game to the specified slot.
func save_game(slot: int) -> void:
	pass


## Load the game from the specified slot. Returns the loaded SaveData or null.
func load_game(slot: int) -> SaveData:
	return null


## Perform an auto-save to the auto-save slot.
func auto_save() -> void:
	pass


## Returns an array of dictionaries with info about all save slots.
## Each dict contains: slot, save_name, timestamp, play_time, exists.
func get_all_save_info() -> Array[Dictionary]:
	return []


## Validate a save file for corruption. Returns true if valid.
func validate_save(slot: int) -> bool:
	return false


## Attempt to recover a corrupted save file.
func _recover_corrupted_save(slot: int) -> SaveData:
	return null


## Returns the file path for a given slot.
func _get_save_path(slot: int) -> String:
	return save_directory + "save_" + str(slot) + save_extension
