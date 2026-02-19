## Finite state machine for the overall game state.
## Tracks whether the game is in menus, loading, gameplay, paused, in a cutscene, or game over.
class_name GameStateManager extends Node


enum GameState {
	MENU,
	LOADING,
	GAMEPLAY,
	PAUSE,
	CUTSCENE,
	GAME_OVER,
}


## Emitted when the game state changes. Provides both the old and new state.
signal state_changed(old_state: GameState, new_state: GameState)


## The current game state.
var current_state: GameState = GameState.MENU


## Transition to a new game state. Calls exit/enter handlers and emits state_changed.
func transition_to(new_state: GameState) -> void:
	pass


## Called when entering a state. Override or extend for state-specific setup.
func _enter_state(_state: GameState) -> void:
	pass


## Called when exiting a state. Override or extend for state-specific teardown.
func _exit_state(_state: GameState) -> void:
	pass
