@tool
extends EditorPlugin


func _enter_tree() -> void:
	add_custom_type(
		"EquipmentVisualManager",
		"Node",
		preload("res://addons/renegade_customizer/core/equipment_visual_manager.gd"),
		null
	)
	add_custom_type(
		"CharacterCustomizer",
		"Node",
		preload("res://addons/renegade_customizer/core/character_customizer.gd"),
		null
	)


func _exit_tree() -> void:
	remove_custom_type("EquipmentVisualManager")
	remove_custom_type("CharacterCustomizer")
