@tool
extends EditorPlugin


func _enter_tree() -> void:
	add_custom_type(
		"DitherOverlay",
		"CanvasLayer",
		preload("res://addons/dither_shader/src/dither_overlay.gd"),
		preload("res://addons/dither_shader/icon.png")
	)


func _exit_tree() -> void:
	remove_custom_type("DitherOverlay")
