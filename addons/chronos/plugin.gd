@tool
extends EditorPlugin


func _enter_tree() -> void:
	var icon: Texture2D = null
	if FileAccess.file_exists("res://addons/chronos/icon.svg"):
		icon = load("res://addons/chronos/icon.svg")
	add_custom_type("Chronos", "Node3D", preload("chronos.gd"), icon)


func _exit_tree() -> void:
	remove_custom_type("Chronos")
