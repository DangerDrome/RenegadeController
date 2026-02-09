## Demo scene wiring script.
## All nodes are placed in the editor (.tscn). This script just wires
## cross-references, connects signals, sets up patrol points, and bakes nav.
extends Node3D

# World3D is inside SubViewport for hybrid rendering (pixel art 3D + crisp UI).
const WORLD_PATH := "SubViewportContainer/SubViewport/World3D"

@onready var world_3d: Node3D = get_node(WORLD_PATH)
@onready var player: RenegadeCharacter = get_node(WORLD_PATH + "/Player")
@onready var player_ctrl: PlayerController = get_node(WORLD_PATH + "/Player/PlayerController")
@onready var cam_system: CameraSystem = get_node(WORLD_PATH + "/CameraSystem")
@onready var cam_rig: CameraRig = get_node(WORLD_PATH + "/CameraSystem/CameraRig")
@onready var cursor_3d: Cursor3D = get_node(WORLD_PATH + "/CameraSystem/Cursor3D")
@onready var zone_mgr: CameraZoneManager = get_node(WORLD_PATH + "/CameraSystem/CameraZoneManager")
@onready var game_hud: CanvasLayer = $GameHUD
@onready var npc: RenegadeCharacter = get_node(WORLD_PATH + "/PatrolNPC")
@onready var ai_ctrl: AIController = get_node(WORLD_PATH + "/PatrolNPC/AIController")
@onready var patrol: Node = get_node(WORLD_PATH + "/PatrolNPC/PatrolBehavior")

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
	player.visual_root = get_node(WORLD_PATH + "/Player/Mesh")

	# Camera wiring - configure through CameraSystem (bubbles down to CameraRig).
	cam_system.target = player
	cam_system.player_controller = player_ctrl

	# Zone manager.
	zone_mgr.camera_rig = cam_rig

	# NPC wiring.
	npc.controller = ai_ctrl
	npc.visual_root = get_node(WORLD_PATH + "/PatrolNPC/Mesh")
	patrol.ai_controller = ai_ctrl
	patrol.character = npc
	# Patrol points in open central area, avoiding ramp and cover boxes.
	patrol.set_patrol_points([
		Vector3(3, 0, -2),
		Vector3(3, 0, 7),
		Vector3(-2, 0, 7),
		Vector3(-2, 0, -2),
	] as Array[Vector3])

	# Cursor needs the camera — wait one frame for CameraRig to initialize.
	await get_tree().process_frame
	cursor_3d.camera = cam_system.get_camera()
	cursor_3d.aim_line_origin = player
	player_ctrl.cursor = cursor_3d

	# Create inventory system nodes.
	_setup_inventory_system()

	# Debug overlay — wired through GameHUD.
	game_hud.debug_character = player
	game_hud.debug_camera_rig = cam_rig
	game_hud.debug_cursor = cursor_3d
	game_hud.debug_zone_manager = zone_mgr
	game_hud.debug_inventory = player_inventory
	game_hud.debug_equipment_manager = player_equipment
	game_hud.debug_weapon_manager = player_weapons
	game_hud.debug_item_slots = player_item_slots

	# Interaction signal.
	player.ready_to_interact.connect(_on_interact)

	# Bake navigation mesh.
	get_node(WORLD_PATH + "/NavRegion").bake_navigation_mesh()


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
