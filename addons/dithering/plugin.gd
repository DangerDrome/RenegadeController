@tool
extends EditorPlugin


func _enter_tree() -> void:
	add_custom_type(
		"DitheringOverlay",
		"CanvasLayer",
		preload("res://addons/dithering/src/dithering_overlay.gd"),
		preload("res://addons/dithering/icon.png")
	)
	add_custom_type(
		"WorldLabel",
		"Node3D",
		preload("res://addons/dithering/src/world_label.gd"),
		null
	)


func _exit_tree() -> void:
	remove_custom_type("DitheringOverlay")
	remove_custom_type("WorldLabel")
