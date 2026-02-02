## Demo scene wiring script.
## All nodes are placed in the editor (.tscn). This script just wires
## cross-references, connects signals, sets up patrol points, and bakes nav.
extends Node3D

@onready var player: RenegadeCharacter = $Player
@onready var player_ctrl: PlayerController = $Player/PlayerController
@onready var cam_rig: CameraRig = $CameraSystem/CameraRig
@onready var cursor_3d: Cursor3D = $CameraSystem/Cursor3D
@onready var zone_mgr: CameraZoneManager = $CameraSystem/CameraZoneManager
@onready var debug: CanvasLayer = $DebugOverlay
@onready var npc: RenegadeCharacter = $PatrolNPC
@onready var ai_ctrl: AIController = $PatrolNPC/AIController
@onready var patrol: Node = $PatrolNPC/PatrolBehavior

# Inventory system nodes (created at runtime).
var player_inventory: Inventory
var player_equipment: EquipmentManager
var player_weapons: WeaponManager
var player_item_slots: ItemSlots


func _ready() -> void:
	InputSetup.ensure_actions()

	# Player wiring.
	player.controller = player_ctrl
	player.camera_rig = cam_rig
	player.visual_root = $Player/Mesh

	# Camera wiring.
	cam_rig.target = player
	cam_rig.player_controller = player_ctrl

	# Zone manager.
	zone_mgr.camera_rig = cam_rig

	# NPC wiring.
	npc.controller = ai_ctrl
	npc.visual_root = $PatrolNPC/Mesh
	patrol.ai_controller = ai_ctrl
	patrol.character = npc
	patrol.set_patrol_points([
		Vector3(8, 0, -8),
		Vector3(8, 0, 5),
		Vector3(-3, 0, 5),
		Vector3(-3, 0, -8),
	] as Array[Vector3])

	# Cursor needs the camera — wait one frame for CameraRig to initialize.
	await get_tree().process_frame
	cursor_3d.camera = cam_rig.get_camera()
	cursor_3d.aim_line_origin = player
	player_ctrl.cursor = cursor_3d

	# Create inventory system nodes.
	_setup_inventory_system()

	# Debug overlay.
	debug.character = player
	debug.camera_rig = cam_rig
	debug.cursor = cursor_3d
	debug.zone_manager = zone_mgr
	debug.inventory = player_inventory
	debug.equipment_manager = player_equipment
	debug.weapon_manager = player_weapons
	debug.item_slots = player_item_slots

	# Interaction signal.
	player.ready_to_interact.connect(_on_interact)

	# Bake navigation mesh.
	$NavRegion.bake_navigation_mesh()


func _setup_inventory_system() -> void:
	# Create Inventory node.
	player_inventory = Inventory.new()
	player_inventory.name = "Inventory"
	player_inventory.max_slots = 20
	player.add_child(player_inventory)

	# Create WeaponManager node.
	player_weapons = WeaponManager.new()
	player_weapons.name = "WeaponManager"
	player.add_child(player_weapons)

	# Create EquipmentManager node.
	player_equipment = EquipmentManager.new()
	player_equipment.name = "EquipmentManager"
	player.add_child(player_equipment)

	# Find ItemSlots node from player's visual mesh.
	# Slots are Marker3D children defined in player.tscn.
	player_item_slots = player.visual_root.get_node_or_null("ItemSlots") as ItemSlots
	if not player_item_slots:
		push_warning("ItemSlots not found on player - pickups won't attach visually")

	# Wire equipment manager references.
	player_equipment.inventory = player_inventory
	player_equipment.weapon_manager = player_weapons


func _on_interact(target: Node3D) -> void:
	if target.has_method("on_interact"):
		# Check method signature — pass player if method accepts an argument.
		var method_list := target.get_method_list()
		for method in method_list:
			if method["name"] == "on_interact":
				if method["args"].size() > 0:
					target.on_interact(player)
				else:
					target.on_interact()
				return
		# Fallback if method list check fails.
		target.on_interact()
