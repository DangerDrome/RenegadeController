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
	
	# Debug overlay.
	debug.character = player
	debug.camera_rig = cam_rig
	debug.cursor = cursor_3d
	debug.zone_manager = zone_mgr
	
	# Interaction signal.
	player.ready_to_interact.connect(_on_interact)
	
	# Bake navigation mesh.
	$NavRegion.bake_navigation_mesh()


func _on_interact(target: Node3D) -> void:
	if target.has_method("on_interact"):
		target.on_interact()
