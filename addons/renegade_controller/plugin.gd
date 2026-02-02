@tool
extends EditorPlugin


func _enter_tree() -> void:
	# Controllers
	add_custom_type("PlayerController", "Node", preload("src/controllers/player_controller.gd"), null)
	add_custom_type("AIController", "Node", preload("src/controllers/ai_controller.gd"), null)
	
	# Character
	add_custom_type("RenegadeCharacter", "CharacterBody3D", preload("src/character/character_body.gd"), null)
	
	# Camera
	add_custom_type("CameraRig", "Node3D", preload("src/camera/camera_rig.gd"), null)
	
	# Cursor
	add_custom_type("Cursor3D", "Node3D", preload("src/cursor/cursor_3d.gd"), null)
	
	# Zones
	add_custom_type("CameraZone", "Area3D", preload("src/zones/camera_zone.gd"), null)
	add_custom_type("FirstPersonZone", "Area3D", preload("src/zones/first_person_zone.gd"), null)
	add_custom_type("CameraZoneManager", "Node", preload("src/zones/camera_zone_manager.gd"), null)


func _exit_tree() -> void:
	remove_custom_type("PlayerController")
	remove_custom_type("AIController")
	remove_custom_type("RenegadeCharacter")
	remove_custom_type("CameraRig")
	remove_custom_type("Cursor3D")
	remove_custom_type("CameraZone")
	remove_custom_type("FirstPersonZone")
	remove_custom_type("CameraZoneManager")
