## Demo level wiring script - mirrors demo_scene.gd approach
extends Node3D

@onready var player: CharacterBody3D = $Player
@onready var player_ctrl: PlayerController = $Player/PlayerController
@onready var cam_system: CameraSystem = $CameraSystem
@onready var cam_rig: CameraRig = $CameraSystem/CameraRig
@onready var cursor_3d: Cursor3D = $CameraSystem/Cursor3D


func _ready() -> void:
	InputSetup.ensure_actions()

	# Player wiring
	player.controller = player_ctrl
	player.camera_rig = cam_rig
	player.visual_root = $Player/Mesh

	# Camera wiring
	cam_system.target = player
	cam_system.player_controller = player_ctrl

	# Cursor needs the camera — wait one frame for CameraRig to initialize
	await get_tree().process_frame
	cursor_3d.camera = cam_system.get_camera()
	cursor_3d.aim_line_origin = player
	player_ctrl.cursor = cursor_3d

	# Bake navigation mesh
	$NavigationRegion3D.bake_navigation_mesh()

	print("[DemoLevel] Ready!")
