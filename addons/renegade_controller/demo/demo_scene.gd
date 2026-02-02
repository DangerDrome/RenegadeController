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

# Test item definitions.
var pistol_def: WeaponDefinition
var shotgun_def: WeaponDefinition
var medkit_def: ConsumableDefinition
var kevlar_def: GearDefinition
var keycard_def: ItemDefinition


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

	# Create test item definitions.
	_create_test_items()

	# Spawn pickups around the level.
	_spawn_test_pickups()

	# Debug overlay.
	debug.character = player
	debug.camera_rig = cam_rig
	debug.cursor = cursor_3d
	debug.zone_manager = zone_mgr
	debug.inventory = player_inventory
	debug.equipment_manager = player_equipment
	debug.weapon_manager = player_weapons

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

	# Wire equipment manager references.
	player_equipment.inventory = player_inventory
	player_equipment.weapon_manager = player_weapons


func _create_test_items() -> void:
	# Pistol weapon.
	pistol_def = WeaponDefinition.new()
	pistol_def.id = &"pistol"
	pistol_def.display_name = "M1911 Pistol"
	pistol_def.description = "Standard issue sidearm. Reliable and accurate."
	pistol_def.damage = 15.0
	pistol_def.fire_rate = 0.2
	pistol_def.magazine_size = 8
	pistol_def.reload_time = 1.2
	pistol_def.effective_range = 30.0
	pistol_def.fire_mode = WeaponDefinition.FireMode.SEMI_AUTO
	pistol_def.animation_set = &"pistol"
	pistol_def.slot_restrictions = [&"primary", &"secondary"]

	# Shotgun weapon.
	shotgun_def = WeaponDefinition.new()
	shotgun_def.id = &"shotgun"
	shotgun_def.display_name = "Pump Shotgun"
	shotgun_def.description = "Devastating at close range. Slow to reload."
	shotgun_def.damage = 45.0
	shotgun_def.fire_rate = 0.8
	shotgun_def.magazine_size = 6
	shotgun_def.reload_time = 2.5
	shotgun_def.effective_range = 15.0
	shotgun_def.fire_mode = WeaponDefinition.FireMode.SEMI_AUTO
	shotgun_def.animation_set = &"shotgun"
	shotgun_def.slot_restrictions = [&"primary"]

	# Medkit consumable.
	medkit_def = ConsumableDefinition.new()
	medkit_def.id = &"medkit"
	medkit_def.display_name = "First Aid Kit"
	medkit_def.description = "Restores 50 health. Every cop needs one."
	medkit_def.max_stack_size = 5
	medkit_def.heal_amount = 50

	# Kevlar vest gear.
	kevlar_def = GearDefinition.new()
	kevlar_def.id = &"kevlar"
	kevlar_def.display_name = "Kevlar Vest"
	kevlar_def.description = "Standard police body armor. Reduces damage taken."
	kevlar_def.armor_value = 25.0
	kevlar_def.damage_reduction = 0.2
	kevlar_def.slot_restrictions = [&"armor"]

	# Security keycard (key item).
	keycard_def = ItemDefinition.new()
	keycard_def.id = &"keycard_security"
	keycard_def.display_name = "Security Keycard"
	keycard_def.description = "Opens restricted areas. Property of Nexus Corp."
	keycard_def.item_type = ItemDefinition.ItemType.KEY_ITEM
	keycard_def.max_stack_size = 1
	keycard_def.is_unique = true


func _spawn_test_pickups() -> void:
	# Spawn pickups at various positions around the level.
	_spawn_pickup(pistol_def, Vector3(-3, 0.5, 0), Color(0.9, 0.5, 0.2))
	_spawn_pickup(shotgun_def, Vector3(3, 0.5, -3), Color(0.8, 0.3, 0.1))
	_spawn_pickup(medkit_def, Vector3(-5, 0.5, 3), Color(0.2, 0.8, 0.3), 2)
	_spawn_pickup(kevlar_def, Vector3(5, 0.5, 5), Color(0.3, 0.7, 0.9))
	_spawn_pickup(keycard_def, Vector3(0, 0.5, -5), Color(0.9, 0.9, 0.2))


func _spawn_pickup(item: ItemDefinition, pos: Vector3, color: Color, qty: int = 1) -> WorldPickup:
	var pickup := WorldPickup.new()
	pickup.item = item
	pickup.quantity = qty
	pickup.name = "Pickup_" + item.display_name.replace(" ", "_")

	# Create collision shape so cursor can detect it.
	var collision := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.4
	collision.shape = shape
	pickup.add_child(collision)

	# Create a visible mesh.
	var mesh_instance := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = Vector3(0.3, 0.3, 0.3)
	mesh_instance.mesh = box_mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mesh_instance.set_surface_override_material(0, mat)
	pickup.add_child(mesh_instance)

	# Add label above pickup.
	var label := Label3D.new()
	label.text = item.display_name
	label.position = Vector3(0, 0.5, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 18
	label.outline_size = 6
	label.modulate = Color(1, 1, 1, 0.9)
	pickup.add_child(label)

	# Position and add to scene.
	pickup.position = pos
	add_child(pickup)

	return pickup


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
