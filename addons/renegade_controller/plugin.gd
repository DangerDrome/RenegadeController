@tool
extends EditorPlugin

var _camera_zone_inspector: EditorInspectorPlugin


func _enter_tree() -> void:
	# Inspector plugins.
	_camera_zone_inspector = preload("src/editor/camera_zone_inspector.gd").new()
	add_inspector_plugin(_camera_zone_inspector)

	# Controllers
	add_custom_type("PlayerController", "Node", preload("src/controllers/player_controller.gd"), null)
	add_custom_type("AIController", "Node", preload("src/controllers/ai_controller.gd"), null)

	# Character
	add_custom_type("RenegadeCharacter", "CharacterBody3D", preload("src/character/character_body.gd"), null)

	# Camera
	add_custom_type("CameraSystem", "Node3D", preload("src/camera/camera_system.gd"), null)
	add_custom_type("CameraRig", "Node3D", preload("src/camera/camera_rig.gd"), null)
	add_custom_type("CameraModifierStack", "Node3D", preload("src/camera/modifiers/camera_modifier_stack.gd"), null)

	# Cursor
	add_custom_type("Cursor3D", "Node3D", preload("src/cursor/cursor_3d.gd"), null)

	# Zones
	add_custom_type("CameraZone", "Area3D", preload("src/zones/camera_zone.gd"), null)
	add_custom_type("FirstPersonZone", "Area3D", preload("src/zones/first_person_zone.gd"), null)
	add_custom_type("CameraZoneManager", "Node", preload("src/zones/camera_zone_manager.gd"), null)

	# Inventory
	add_custom_type("Inventory", "Node", preload("src/inventory/inventory.gd"), null)
	add_custom_type("EquipmentManager", "Node", preload("src/inventory/equipment_manager.gd"), null)
	add_custom_type("WeaponManager", "Node3D", preload("src/inventory/weapon_manager.gd"), null)
	add_custom_type("ItemSlots", "Node3D", preload("src/inventory/item_slots.gd"), null)
	add_custom_type("WorldPickup", "Area3D", preload("src/inventory/world_pickup.gd"), null)
	add_custom_type("LootDropper", "Node", preload("src/inventory/loot_dropper.gd"), null)


func _exit_tree() -> void:
	# Inspector plugins.
	if _camera_zone_inspector:
		remove_inspector_plugin(_camera_zone_inspector)
		_camera_zone_inspector = null

	remove_custom_type("PlayerController")
	remove_custom_type("AIController")
	remove_custom_type("RenegadeCharacter")
	remove_custom_type("CameraSystem")
	remove_custom_type("CameraRig")
	remove_custom_type("CameraModifierStack")
	remove_custom_type("Cursor3D")
	remove_custom_type("CameraZone")
	remove_custom_type("FirstPersonZone")
	remove_custom_type("CameraZoneManager")
	remove_custom_type("Inventory")
	remove_custom_type("EquipmentManager")
	remove_custom_type("WeaponManager")
	remove_custom_type("ItemSlots")
	remove_custom_type("WorldPickup")
	remove_custom_type("LootDropper")
