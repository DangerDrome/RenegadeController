## Root orchestrator for the game lifecycle.
## Owns references to all managers and menus, wires their signals, and provides
## the public API for game flow: new game, load, save, pause, quit, etc.
class_name GameDirector extends Node


#region Manager References
@export_group("Managers")
## Game state FSM.
@export var game_state_manager: GameStateManager:
	set(value):
		if game_state_manager and game_state_manager.state_changed.is_connected(_on_state_changed):
			game_state_manager.state_changed.disconnect(_on_state_changed)
		game_state_manager = value
		if game_state_manager:
			game_state_manager.state_changed.connect(_on_state_changed)

## Level loading manager.
@export var level_manager: LevelManager:
	set(value):
		if level_manager:
			if level_manager.level_loaded.is_connected(_on_level_loaded):
				level_manager.level_loaded.disconnect(_on_level_loaded)
			if level_manager.level_unloaded.is_connected(_on_level_unloaded):
				level_manager.level_unloaded.disconnect(_on_level_unloaded)
		level_manager = value
		if level_manager:
			level_manager.level_loaded.connect(_on_level_loaded)
			level_manager.level_unloaded.connect(_on_level_unloaded)

## Save/load manager.
@export var save_manager: SaveManager

## Settings manager.
@export var settings_manager: SettingsManager

## Audio manager.
@export var audio_manager: AudioManager

## Input device manager.
@export var input_manager: InputManager

## Cutscene manager.
@export var cutscene_manager: CutsceneManager
#endregion


#region UI References
@export_group("UI")
## Screen overlay for fades and transitions.
@export var screen_overlay: ScreenOverlay

## Main menu control.
@export var main_menu: MainMenu:
	set(value):
		if main_menu:
			if main_menu.new_game_requested.is_connected(_on_new_game_requested):
				main_menu.new_game_requested.disconnect(_on_new_game_requested)
			if main_menu.continue_requested.is_connected(_on_continue_requested):
				main_menu.continue_requested.disconnect(_on_continue_requested)
			if main_menu.quit_requested.is_connected(_on_quit_requested):
				main_menu.quit_requested.disconnect(_on_quit_requested)
		main_menu = value
		if main_menu:
			main_menu.new_game_requested.connect(_on_new_game_requested)
			main_menu.continue_requested.connect(_on_continue_requested)
			main_menu.quit_requested.connect(_on_quit_requested)

## Pause menu control.
@export var pause_menu: PauseMenu:
	set(value):
		if pause_menu:
			if pause_menu.resume_requested.is_connected(_on_resume_requested):
				pause_menu.resume_requested.disconnect(_on_resume_requested)
			if pause_menu.save_requested.is_connected(_on_save_requested):
				pause_menu.save_requested.disconnect(_on_save_requested)
			if pause_menu.return_to_menu_requested.is_connected(_on_return_to_menu_requested):
				pause_menu.return_to_menu_requested.disconnect(_on_return_to_menu_requested)
			if pause_menu.quit_requested.is_connected(_on_quit_requested):
				pause_menu.quit_requested.disconnect(_on_quit_requested)
		pause_menu = value
		if pause_menu:
			pause_menu.resume_requested.connect(_on_resume_requested)
			pause_menu.save_requested.connect(_on_save_requested)
			pause_menu.return_to_menu_requested.connect(_on_return_to_menu_requested)
			pause_menu.quit_requested.connect(_on_quit_requested)
#endregion


## Total play time in seconds for the current session.
var _play_time: float = 0.0


#region Public API

## Start a new game. Loads the first level.
func new_game() -> void:
	pass


## Continue from the most recent save.
func continue_game() -> void:
	pass


## Load a game from the specified save slot.
func load_game(slot: int) -> void:
	pass


## Save the game to the specified slot.
func save_game(slot: int) -> void:
	pass


## Pause the game and show the pause menu.
func pause() -> void:
	pass


## Resume gameplay from pause.
func resume() -> void:
	pass


## Return to the main menu from gameplay.
func return_to_menu() -> void:
	pass


## Quit the application.
func quit_game() -> void:
	pass


## Build a SaveData resource from the current game state.
func build_save_data() -> SaveData:
	return null

#endregion


#region Signal Handlers

func _on_state_changed(_old_state: GameStateManager.GameState, _new_state: GameStateManager.GameState) -> void:
	pass


func _on_level_loaded(_path: String) -> void:
	pass


func _on_level_unloaded(_path: String) -> void:
	pass


func _on_new_game_requested() -> void:
	new_game()


func _on_continue_requested() -> void:
	continue_game()


func _on_resume_requested() -> void:
	resume()


func _on_save_requested() -> void:
	pass


func _on_return_to_menu_requested() -> void:
	return_to_menu()


func _on_quit_requested() -> void:
	quit_game()

#endregion


func _process(delta: float) -> void:
	if game_state_manager and game_state_manager.current_state == GameStateManager.GameState.GAMEPLAY:
		_play_time += delta
