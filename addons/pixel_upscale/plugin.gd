@tool
extends EditorPlugin


func _enter_tree() -> void:
	add_custom_type(
		"PixelUpscaleDisplay",
		"SubViewportContainer",
		preload("res://addons/pixel_upscale/src/pixel_upscale_display.gd"),
		null
	)


func _exit_tree() -> void:
	remove_custom_type("PixelUpscaleDisplay")
