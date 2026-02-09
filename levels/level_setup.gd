## LevelSetup: Handles automatic level initialization for drag-and-drop scenes.
## Attach to the root of any level scene to enable auto-wiring and navmesh baking.
## NPCs self-register via NPCSpawner nodes - no code needed.
class_name LevelSetup
extends Node3D

@export_group("Navigation")
## Auto-bake navigation mesh on level start.
@export var auto_bake_navmesh: bool = true
## NavigationRegion3D to bake. Auto-detected if not set.
@export var navigation_region: NavigationRegion3D

@export_group("City Blocks")
## Register default city blocks for abstract NPC simulation.
@export var register_default_blocks: bool = true

@export_group("Factions")
## Set up default faction dispositions.
@export var setup_default_factions: bool = true

@export_group("Debug")
## Print debug messages during setup.
@export var debug_print: bool = true


func _ready() -> void:
	if debug_print:
		print("\n[LevelSetup] Initializing level: ", name)

	# Ensure input actions exist
	InputSetup.ensure_actions()

	# Wait for scene tree to fully initialize
	await get_tree().process_frame

	# Wire player, camera, and cursor
	_wire_player_and_camera()

	# Setup factions
	if setup_default_factions:
		_setup_factions()

	# Register city blocks
	if register_default_blocks:
		_setup_blocks()

	# Bake navmesh
	if auto_bake_navmesh:
		await _bake_navmesh()

	# Ensure activity nodes have markers
	_ensure_activity_markers()

	if debug_print:
		_print_summary()


func _wire_player_and_camera() -> void:
	# Find player (search children first, then group)
	var player: CharacterBody3D = null
	for child in get_children():
		if child is CharacterBody3D and child.is_in_group("player"):
			player = child
			break
	if not player:
		player = get_tree().get_first_node_in_group("player") as CharacterBody3D
	if not player:
		if debug_print:
			print("[LevelSetup] No player found")
		return

	# Find player controller
	var player_ctrl := player.get_node_or_null("PlayerController") as PlayerController
	if not player_ctrl:
		if debug_print:
			print("[LevelSetup] No PlayerController found on player")
		return

	# Find camera system (search children)
	var cam_system: CameraSystem = null
	for child in get_children():
		if child is CameraSystem:
			cam_system = child
			break
	if not cam_system:
		if debug_print:
			print("[LevelSetup] No CameraSystem found")
		return

	var cam_rig: CameraRig = cam_system.get_node_or_null("CameraRig")
	var cursor_3d: Cursor3D = cam_system.get_node_or_null("Cursor3D")

	# Wire player
	player.controller = player_ctrl
	if cam_rig:
		player.camera_rig = cam_rig
	var mesh := player.get_node_or_null("Mesh")
	if mesh:
		player.visual_root = mesh

	# Wire camera system
	cam_system.target = player
	cam_system.player_controller = player_ctrl

	# Wire cursor (same as demo_scene.gd)
	if cursor_3d:
		cursor_3d.camera = cam_system.get_camera()
		cursor_3d.aim_line_origin = player
		player_ctrl.cursor = cursor_3d

	if debug_print:
		print("[LevelSetup] Wired player, camera, and cursor")


func _setup_factions() -> void:
	if not ReputationManager:
		if debug_print:
			print("[LevelSetup] ReputationManager not found, skipping factions")
		return

	for entry: Array in NPCConfig.Factions.DEFAULT_DISPOSITIONS:
		ReputationManager.set_faction_disposition(entry[0], entry[1], entry[2])

	if debug_print:
		print("[LevelSetup] Factions configured")


func _setup_blocks() -> void:
	if not NPCManager:
		if debug_print:
			print("[LevelSetup] NPCManager not found, skipping blocks")
		return

	for block_id: String in NPCConfig.Blocks.ALL:
		NPCManager.register_block(block_id, NPCConfig.Blocks.ALL[block_id])

	if debug_print:
		print("[LevelSetup] City blocks registered: ", NPCConfig.Blocks.ALL.keys())


func _bake_navmesh() -> void:
	# Find navigation region if not set
	if not navigation_region:
		navigation_region = _find_navigation_region()

	if not navigation_region:
		if debug_print:
			print("[LevelSetup] No NavigationRegion3D found, skipping navmesh bake")
		return

	if debug_print:
		print("[LevelSetup] Baking navigation mesh...")

	navigation_region.bake_navigation_mesh()
	await navigation_region.bake_finished

	if debug_print:
		print("[LevelSetup] Navigation mesh baked")


func _find_navigation_region() -> NavigationRegion3D:
	# Search children first
	for child in get_children():
		if child is NavigationRegion3D:
			return child
		# Check grandchildren
		for grandchild in child.get_children():
			if grandchild is NavigationRegion3D:
				return grandchild
	return null


func _ensure_activity_markers() -> void:
	var color_map: Dictionary = {
		"patrol": Color.YELLOW,
		"idle": Color.GRAY,
		"guard": Color.PURPLE,
		"socialize": Color.GREEN,
		"work": Color.CYAN,
		"deal": Color.ORANGE_RED,
	}

	for node: Node in get_tree().get_nodes_in_group("activity_nodes"):
		var act_node := node as ActivityNode
		if not act_node:
			continue

		# Add marker mesh if missing
		if not act_node.get_node_or_null("MarkerMesh"):
			var mesh := MeshInstance3D.new()
			mesh.name = "MarkerMesh"
			var sphere := SphereMesh.new()
			sphere.radius = 0.3
			sphere.height = 0.6
			mesh.mesh = sphere
			var mat := StandardMaterial3D.new()
			mat.albedo_color = color_map.get(act_node.activity_type, Color.WHITE)
			mat.emission_enabled = true
			mat.emission = mat.albedo_color
			mat.emission_energy_multiplier = 0.5
			mesh.material_override = mat
			mesh.position.y = 0.5
			act_node.add_child(mesh)

		# Add label if missing
		if not act_node.get_node_or_null("ActivityLabel"):
			var label := Label3D.new()
			label.name = "ActivityLabel"
			label.text = act_node.activity_type
			label.position.y = 1.2
			label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			label.no_depth_test = true
			label.font_size = 24
			act_node.add_child(label)


func _print_summary() -> void:
	var spawner_count: int = 0
	var activity_count: int = 0

	for child in get_children():
		if child is NPCSpawner:
			spawner_count += 1
	for node in get_tree().get_nodes_in_group("activity_nodes"):
		activity_count += 1

	print("[LevelSetup] Ready!")
	print("  - NPC Spawners: ", spawner_count)
	print("  - Activity Nodes: ", activity_count)
	if NPCManager:
		print("  - NPC Stats: ", NPCManager.get_stats())
