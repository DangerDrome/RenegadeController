@tool
extends EditorPlugin

const AUTOLOADS := {
	"NPCManager": "res://addons/renegade_npc/core/npc_manager.gd",
	"ReputationManager": "res://addons/renegade_npc/core/reputation_manager.gd",
	"GameClock": "res://addons/renegade_npc/core/game_clock.gd",
}


func _enter_tree() -> void:
	# Register autoloads
	for autoload_name in AUTOLOADS:
		add_autoload_singleton(autoload_name, AUTOLOADS[autoload_name])
	
	# Register custom types
	add_custom_type(
		"ActivityNode",
		"Marker3D",
		preload("res://addons/renegade_npc/nodes/activity_node.gd"),
		preload("res://addons/renegade_npc/ui/activity_node_icon.svg") if FileAccess.file_exists("res://addons/renegade_npc/ui/activity_node_icon.svg") else null
	)
	
	print("[RenegadeNPC] Plugin loaded v1.0.0")


func _exit_tree() -> void:
	for autoload_name in AUTOLOADS:
		remove_autoload_singleton(autoload_name)
	
	remove_custom_type("ActivityNode")
	print("[RenegadeNPC] Plugin unloaded")
