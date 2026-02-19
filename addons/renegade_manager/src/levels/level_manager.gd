## Handles async additive level loading and unloading.
## Loads levels in the background, reports progress, and manages the active level scene.
class_name LevelManager extends Node


## Emitted when a level starts loading.
signal level_load_started(path: String)

## Emitted when a level finishes loading and is added to the tree.
signal level_loaded(path: String)

## Emitted when the current level is unloaded.
signal level_unloaded(path: String)

## Emitted periodically during loading with progress value (0.0 to 1.0).
signal load_progress_updated(progress: float)


## The currently loaded level scene root, or null.
var _current_level: Node = null

## Path of the currently loaded level scene.
var _current_level_path: String = ""

## Whether a level is currently being loaded.
var _is_loading: bool = false


## Begin async loading of a level scene. Optionally specify a spawn marker name.
func load_level(path: String, spawn_marker: String = "") -> void:
	pass


## Unload the current level scene from the tree.
func unload_current_level() -> void:
	pass


## Returns the currently loaded level root node, or null.
func get_current_level() -> Node:
	return _current_level


## Returns true if a level is currently being loaded.
func is_loading() -> bool:
	return _is_loading


## Polls ResourceLoader for async load progress. Called each frame during loading.
func _poll_loading(_delta: float) -> void:
	pass


## Bakes the navigation mesh after a level is loaded.
func _bake_navmesh() -> void:
	pass
