@tool
extends EditorPlugin


func _enter_tree() -> void:
	add_custom_type(
		"OutlineSetup",
		"Node",
		preload("res://addons/pixel_outline/outline_setup.gd"),
		preload("res://addons/pixel_outline/colorLens.png")
	)
	print("Pixel Outline v2 plugin enabled")


func _exit_tree() -> void:
	remove_custom_type("OutlineSetup")
	print("Pixel Outline v2 plugin disabled")
