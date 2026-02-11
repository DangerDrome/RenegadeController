## Demo level wiring script - mirrors demo_scene.gd approach
extends Node3D

@onready var player: CharacterBody3D = $Player
@onready var player_ctrl: PlayerController = $Player/PlayerController
@onready var cam_system: CameraSystem = $CameraSystem
@onready var cam_rig: CameraRig = $CameraSystem/CameraRig
@onready var cursor_3d: Cursor3D = $Player/Cursor3D


func _ready() -> void:
	InputSetup.ensure_actions()

	# Player wiring
	player.controller = player_ctrl
	player.camera_rig = cam_rig
	player.visual_root = $Player/CharacterVisuals

	# Camera wiring
	cam_system.target = player
	cam_system.player_controller = player_ctrl

	# Cursor needs the camera — wait one frame for CameraRig to initialize
	await get_tree().process_frame
	cursor_3d.camera = cam_system.get_camera()
	cursor_3d.aim_line_origin = player

	# Bake navigation mesh
	$NavigationRegion3D.bake_navigation_mesh()

	print("[DemoLevel] Ready! Press H to test hit reaction, / for animation retargeting")


# ============ Animation Retarget Test (/) ============
var _test_anim_player: AnimationPlayer
var _test_anim_idx: int = 0
var _test_anim_names: Array[String] = []
var _test_loaded: bool = false

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		# H key - test hit reaction
		if event.keycode == KEY_H:
			_test_hit_reaction()
			return

		# Check for / or ? key
		var is_slash: bool = event.keycode == KEY_SLASH or event.unicode == 47 or event.unicode == 63
		if is_slash:
			if not _test_loaded:
				_test_retarget_animation()
			else:
				_test_next_animation()


func _test_hit_reaction() -> void:
	var char_visuals: CharacterVisuals = $Player/CharacterVisuals
	if char_visuals:
		# Hit from a random direction with force 15
		var random_dir := Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
		print("[DemoLevel] Testing hit reaction from direction: ", random_dir)
		char_visuals.apply_hit(&"spine_03", random_dir, 15.0)
	else:
		print("[DemoLevel] No CharacterVisuals found!")


func _test_retarget_animation() -> void:
	# TODO: AnimationConverter class not yet implemented
	push_warning("Animation retargeting test disabled - AnimationConverter not implemented")
	print("[Retarget Test] Skipped - requires AnimationConverter utility class")


func _test_next_animation() -> void:
	if _test_anim_names.is_empty():
		print("[Retarget Test] No animations loaded.")
		return
	_test_anim_idx = (_test_anim_idx + 1) % _test_anim_names.size()
	_play_test_animation()


func _play_test_animation() -> void:
	var anim_name: String = _test_anim_names[_test_anim_idx]
	print("Playing [", _test_anim_idx + 1, "/", _test_anim_names.size(), "]: ", anim_name)

	# Debug: Check animation exists and has data
	if _test_anim_player.has_animation(anim_name):
		var anim: Animation = _test_anim_player.get_animation(anim_name)
		print("  Animation length: ", anim.length, "s, tracks: ", anim.get_track_count())

		# Get animation root for path resolution
		var anim_root: Node = _test_anim_player.get_node(_test_anim_player.root_node)

		# Show first few track paths and verify they resolve
		for i in range(min(anim.get_track_count(), 5)):
			var path: NodePath = anim.track_get_path(i)
			var key_count: int = anim.track_get_key_count(i)
			var track_type: int = anim.track_get_type(i)
			var type_str: String = ["VALUE", "POSITION", "ROTATION", "SCALE", "BLEND", "METHOD", "BEZIER", "AUDIO", "ANIM"][track_type] if track_type < 9 else "?"

			# Check if path resolves (for bone tracks, extract node path part)
			var node_path_str: String = String(path)
			var colon_idx: int = node_path_str.find(":")
			var check_path: String = node_path_str.substr(0, colon_idx) if colon_idx != -1 else node_path_str
			var target_node: Node = anim_root.get_node_or_null(check_path) if not check_path.is_empty() else anim_root
			var status: String = "✓" if target_node else "✗"

			print("    ", status, " Track ", i, " [", type_str, "]: ", path, " (", key_count, " keys)")
	else:
		print("  ERROR: Animation not found!")
		return

	_test_anim_player.play(anim_name)

	# Verify it started
	await get_tree().process_frame
	print("  is_playing: ", _test_anim_player.is_playing(), ", position: ", _test_anim_player.current_animation_position)


func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for child in node.get_children():
		var found: Skeleton3D = _find_skeleton(child)
		if found:
			return found
	return null
