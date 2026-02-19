@tool
extends EditorPlugin


func _enter_tree() -> void:
	# Lifecycle
	add_custom_type("GameDirector", "Node", preload("src/lifecycle/game_director.gd"), null)

	# State
	add_custom_type("GameStateManager", "Node", preload("src/state/game_state_manager.gd"), null)

	# Levels
	add_custom_type("LevelManager", "Node", preload("src/levels/level_manager.gd"), null)

	# Transitions
	add_custom_type("TransitionZone", "Area3D", preload("src/transitions/transition_zone.gd"), null)

	# Save
	add_custom_type("SaveManager", "Node", preload("src/save/save_manager.gd"), null)
	add_custom_type("CheckpointZone", "Area3D", preload("src/save/checkpoint_zone.gd"), null)

	# Menus
	add_custom_type("MainMenu", "Control", preload("src/menu/main_menu.gd"), null)
	add_custom_type("PauseMenu", "Control", preload("src/menu/pause_menu.gd"), null)

	# Splash
	add_custom_type("SplashSequence", "Control", preload("src/splash/splash_sequence.gd"), null)

	# Cutscene
	add_custom_type("CutsceneManager", "Node", preload("src/cutscene/cutscene_manager.gd"), null)

	# Overlay
	add_custom_type("ScreenOverlay", "CanvasLayer", preload("src/overlay/screen_overlay.gd"), null)

	# Settings
	add_custom_type("SettingsManager", "Node", preload("src/settings/settings_manager.gd"), null)

	# Audio
	add_custom_type("AudioManager", "Node", preload("src/audio/audio_manager.gd"), null)

	# Input
	add_custom_type("InputManager", "Node", preload("src/input/input_manager.gd"), null)


func _exit_tree() -> void:
	remove_custom_type("GameDirector")
	remove_custom_type("GameStateManager")
	remove_custom_type("LevelManager")
	remove_custom_type("TransitionZone")
	remove_custom_type("SaveManager")
	remove_custom_type("CheckpointZone")
	remove_custom_type("MainMenu")
	remove_custom_type("PauseMenu")
	remove_custom_type("SplashSequence")
	remove_custom_type("CutsceneManager")
	remove_custom_type("ScreenOverlay")
	remove_custom_type("SettingsManager")
	remove_custom_type("AudioManager")
	remove_custom_type("InputManager")
