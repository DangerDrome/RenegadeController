@tool
extends EditorPlugin


func _enter_tree() -> void:
	add_custom_type(
		"DitherOverlay",
		"CanvasLayer",
		preload("res://addons/dither_shader/src/dither_overlay.gd"),
		preload("res://addons/dither_shader/icon.png")
	)
	add_custom_type(
		"WorldLabel",
		"Node3D",
		preload("res://addons/dither_shader/src/world_label.gd"),
		null
	)


func _exit_tree() -> void:
	remove_custom_type("DitherOverlay")
	remove_custom_type("WorldLabel")
