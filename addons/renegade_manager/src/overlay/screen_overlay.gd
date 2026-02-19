## Full-screen visual overlay for fades, transitions, letterboxing, and loading screens.
## Uses a CanvasLayer so it renders above all game content.
## process_mode is ALWAYS so it works during pause.
class_name ScreenOverlay extends CanvasLayer


## Emitted when a fade or transition finishes.
signal transition_finished


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


## Fade the screen to black over the given duration.
func fade_to_black(duration: float = 0.5) -> void:
	pass


## Fade the screen from black to clear over the given duration.
func fade_from_black(duration: float = 0.5) -> void:
	pass


## Play a full transition effect (fade out, hold, fade in).
func play_transition(effect: TransitionEffect) -> void:
	pass


## Show the loading screen with optional progress display.
func show_loading_screen() -> void:
	pass


## Hide the loading screen.
func hide_loading_screen() -> void:
	pass


## Enable or disable cinematic letterbox bars.
func set_letterbox(enabled: bool, duration: float = 0.3) -> void:
	pass
