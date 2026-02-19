## Manages cutscene lifecycle: starting, ending, letterbox, and input blocking.
## Does not implement a cutscene editor — works with AnimationPlayer or scripted sequences.
class_name CutsceneManager extends Node


## Emitted when a cutscene begins.
signal cutscene_started(cutscene_id: String)

## Emitted when a cutscene ends.
signal cutscene_ended(cutscene_id: String)


#region References
@export_group("References")
## Screen overlay for letterbox and fade effects.
@export var screen_overlay: ScreenOverlay:
	set(value):
		screen_overlay = value
#endregion


## The currently playing cutscene ID, or empty string if none.
var _current_cutscene: String = ""


## Returns true if a cutscene is currently playing.
func is_playing() -> bool:
	return not _current_cutscene.is_empty()


## Start a cutscene with the given ID. Enables letterbox and blocks gameplay input.
func start_cutscene(cutscene_id: String) -> void:
	pass


## End the current cutscene. Disables letterbox and restores gameplay input.
func end_cutscene() -> void:
	pass
