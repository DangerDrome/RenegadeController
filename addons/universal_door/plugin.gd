@tool
extends EditorPlugin

const UniversalDoorScript := preload("res://addons/universal_door/universal_door.gd")
const DoorFactoryScript := preload("res://addons/universal_door/door_factory.gd")

var _door_icon: Texture2D


func _enter_tree() -> void:
	# Load or create icon
	_door_icon = _get_or_create_icon()
	
	# Register custom types
	add_custom_type(
		"UniversalDoor",
		"Node3D",
		UniversalDoorScript,
		_door_icon
	)
	
	# Add autoload for factory (optional - can be used as static class too)
	# add_autoload_singleton("DoorFactory", "res://addons/universal_door/door_factory.gd")
	
	print("Universal Door plugin enabled")


func _exit_tree() -> void:
	# Clean up
	remove_custom_type("UniversalDoor")
	# remove_autoload_singleton("DoorFactory")
	
	print("Universal Door plugin disabled")


func _get_or_create_icon() -> Texture2D:
	# Try to load custom icon
	var icon_path := "res://addons/universal_door/icon_door.svg"
	if ResourceLoader.exists(icon_path):
		return load(icon_path)
	
	# Fallback to built-in icon
	return EditorInterface.get_editor_theme().get_icon("Node3D", "EditorIcons")


func _has_main_screen() -> bool:
	return false


func _get_plugin_name() -> String:
	return "Universal Door"
