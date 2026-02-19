## Plays a sequence of splash screens at game boot.
## Each splash is defined by a SplashEntry resource.
class_name SplashSequence extends Control


## Emitted when the entire splash sequence finishes.
signal sequence_completed


#region Sequence Settings
@export_group("Sequence")
## Ordered list of splash screens to display.
@export var entries: Array[SplashEntry] = []

## Whether the player can skip the splash sequence by pressing any key.
@export var skippable: bool = true
#endregion


var _current_index: int = 0
var _is_playing: bool = false


## Start playing the splash sequence from the beginning.
func play() -> void:
	pass


## Skip the remaining splash screens and emit sequence_completed.
func skip() -> void:
	pass


## Display the next splash entry in the sequence.
func _show_next_entry() -> void:
	pass


func _input(event: InputEvent) -> void:
	if skippable and _is_playing and event.is_pressed():
		skip()
