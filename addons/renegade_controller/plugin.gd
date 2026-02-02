@tool
extends EditorPlugin
var _camera_zone_inspector: EditorInspectorPlugin
var _default_camera_inspector: EditorInspectorPlugin
var _selection: EditorSelection
func _enter_tree() -> void:
	# Track selection to update camera zone colors.
	_selection = get_editor_interface().get_selection()
	_selection.selection_changed.connect(_on_selection_changed)
	# Inspector plugins.
	_camera_zone_inspector = preload("src/editor/camera_zone_inspector.gd").new()
	add_inspector_plugin(_camera_zone_inspector)
	_default_camera_inspector = preload("src/editor/default_camera_inspector.gd").new()
	add_inspector_plugin(_default_camera_inspector)
	# Controllers
	add_custom_type("PlayerController", "Node", preload("src/controllers/player_controller.gd"), null)
	add_custom_type("AIController", "Node", preload("src/controllers/ai_controller.gd"), null)
	
	# Character
	add_custom_type("RenegadeCharacter", "CharacterBody3D", preload("src/character/character_body.gd"), null)
	
	# Camera
	add_custom_type("CameraSystem", "Node3D", preload("src/camera/camera_system.gd"), null)
	add_custom_type("CameraRig", "Node3D", preload("src/camera/camera_rig.gd"), null)
	add_custom_type("CameraModifierStack", "Node3D", preload("src/camera/modifiers/camera_modifier_stack.gd"), null)
	add_custom_type("DefaultCameraMarker", "Marker3D", preload("src/camera/default_camera_marker.gd"), null)
	
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
	# Disconnect selection signal.
	if _selection and _selection.selection_changed.is_connected(_on_selection_changed):
		_selection.selection_changed.disconnect(_on_selection_changed)
	# Inspector plugins.
	if _camera_zone_inspector:
		remove_inspector_plugin(_camera_zone_inspector)
		_camera_zone_inspector = null
	if _default_camera_inspector:
		remove_inspector_plugin(_default_camera_inspector)
		_default_camera_inspector = null
	remove_custom_type("PlayerController")
	remove_custom_type("AIController")
	remove_custom_type("RenegadeCharacter")
	remove_custom_type("CameraSystem")
	remove_custom_type("CameraRig")
	remove_custom_type("CameraModifierStack")
	remove_custom_type("DefaultCameraMarker")
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
func _on_selection_changed() -> void:
	var selected := _selection.get_selected_nodes()
	# Find all camera zones in the current scene.
	var root := get_editor_interface().get_edited_scene_root()
	if not root:
		return
	var zones := _find_camera_zones(root)
	# Update each zone's selection state.
	for zone in zones:
		var is_selected := _is_zone_or_child_selected(zone, selected)
		zone.set_editor_selected(is_selected)
	# Update default camera markers.
	var markers := _find_default_camera_markers(root)
	for marker in markers:
		var is_selected := marker in selected
		marker.set_editor_selected(is_selected)
func _find_camera_zones(node: Node) -> Array[Node]:
	var result: Array[Node] = []
	if node is CameraZone:
		result.append(node)
	for child in node.get_children():
		result.append_array(_find_camera_zones(child))
	return result
func _find_default_camera_markers(node: Node) -> Array[Node]:
	var result: Array[Node] = []
	if node is DefaultCameraMarker:
		result.append(node)
	for child in node.get_children():
		result.append_array(_find_default_camera_markers(child))
	return result
func _is_zone_or_child_selected(zone: CameraZone, selected: Array[Node]) -> bool:
	# Check if zone itself is selected.
	if zone in selected:
		return true
	# Check if camera marker is selected.
	if zone.camera_marker and zone.camera_marker in selected:
		return true
	# Check if look-at marker is selected.
	if zone.look_at_marker and zone.look_at_marker in selected:
		return true
	# Check if look-at target is selected.
	if zone.look_at_target and zone.look_at_target in selected:
		return true
	return false