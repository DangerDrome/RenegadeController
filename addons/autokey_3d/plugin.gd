@tool
class_name AutoKey3DPlugin
extends EditorPlugin
## AutoKey 3D - Global auto-keyframing toggle for 3D animations

var _dock: Control
var _tracked_animation_player: AnimationPlayer
var _autokey_enabled: bool = false
var _last_track_values: Dictionary = {}  # track_idx -> last_value
var _poll_timer: float = 0.0
var _button_check_timer: float = 0.0
var _autokey_button: Button
var _current_animation_name: String = ""
var _last_playhead_time: float = 0.0  # Track playhead to detect scrubbing

const POLL_INTERVAL: float = 0.05
const BUTTON_CHECK_INTERVAL: float = 0.5


func _enter_tree() -> void:
	_dock = preload("res://addons/autokey_3d/autokey_dock.tscn").instantiate()
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, _dock)
	_dock.insert_position_pressed.connect(_on_insert_position)
	_dock.insert_rotation_pressed.connect(_on_insert_rotation)
	_dock.insert_scale_pressed.connect(_on_insert_scale)
	_dock.insert_all_pressed.connect(_on_insert_all)
	_dock.animation_player_selected.connect(_on_animation_player_selected)
	get_editor_interface().get_selection().selection_changed.connect(_on_selection_changed)
	set_process(true)


func _exit_tree() -> void:
	_remove_autokey_button()
	if _dock:
		remove_control_from_docks(_dock)
		_dock.queue_free()
		_dock = null


func _process(delta: float) -> void:
	# Poll for property changes when auto-key is enabled
	if _autokey_enabled and _tracked_animation_player:
		_poll_timer += delta
		if _poll_timer >= POLL_INTERVAL:
			_poll_timer = 0.0
			_check_all_track_changes()

	# Periodically ensure button exists
	_button_check_timer += delta
	if _button_check_timer >= BUTTON_CHECK_INTERVAL:
		_button_check_timer = 0.0
		_ensure_autokey_button()
		_check_animation_changed()
		_auto_detect_animation_player()


func _auto_detect_animation_player() -> void:
	var player := _get_edited_animation_player()
	if player and player != _tracked_animation_player:
		_tracked_animation_player = player
		_last_track_values.clear()
		if _dock:
			_dock.set_current_animation_player(player)


func _check_animation_changed() -> void:
	if not _tracked_animation_player:
		return
	var current := _tracked_animation_player.current_animation
	if current.is_empty():
		current = _tracked_animation_player.assigned_animation
	if current != _current_animation_name:
		_current_animation_name = current
		_last_track_values.clear()


func _find_node_by_class(node: Node, class_name_str: String) -> Control:
	if node.get_class() == class_name_str:
		return node as Control
	for child in node.get_children():
		var result := _find_node_by_class(child, class_name_str)
		if result:
			return result
	return null


func _find_animation_track_editor() -> Control:
	return _find_node_by_class(get_editor_interface().get_base_control(), "AnimationTrackEditor")


func _ensure_autokey_button() -> void:
	# Check if button still exists and is valid
	if _autokey_button and is_instance_valid(_autokey_button):
		return

	var track_editor := _find_animation_track_editor()
	if not track_editor:
		return

	var bottom_toolbar: Container = _find_bottom_toolbar(track_editor)
	if not bottom_toolbar:
		return

	# Create the auto-key button
	_autokey_button = Button.new()
	_autokey_button.name = "AutoKeyToggle"
	_autokey_button.toggle_mode = true
	_autokey_button.tooltip_text = "Auto-Key: Automatically insert keyframes when properties change"
	_autokey_button.button_pressed = _autokey_enabled

	# Try to get the auto-key icon
	var base_control := get_editor_interface().get_base_control()
	var key_icon: Texture2D = null
	for icon_name in ["AutoKey", "KeyAuto", "AnimationKey", "Key"]:
		key_icon = base_control.get_theme_icon(icon_name, "EditorIcons")
		if key_icon and key_icon.get_size().x > 0:
			break
	if key_icon:
		_autokey_button.icon = key_icon
	else:
		_autokey_button.text = "AK"

	_autokey_button.toggled.connect(_on_autokey_toggled)
	_update_button_style()

	# Find "Insert at current time" button and position after it
	var insert_index := -1
	var reference_button: Button = null
	for i in bottom_toolbar.get_child_count():
		var child := bottom_toolbar.get_child(i)
		if child is Button:
			var btn := child as Button
			if btn.tooltip_text and "Insert at current time" in btn.tooltip_text:
				insert_index = i + 1
				reference_button = btn
				break

	# Copy styling from the reference button
	if reference_button:
		_autokey_button.flat = reference_button.flat
		_autokey_button.custom_minimum_size = reference_button.custom_minimum_size
		if reference_button.theme:
			_autokey_button.theme = reference_button.theme

	bottom_toolbar.add_child(_autokey_button)
	if insert_index > 0:
		bottom_toolbar.move_child(_autokey_button, insert_index)


func _find_bottom_toolbar(track_editor: Control) -> Container:
	# Search for HFlowContainer (the bottom toolbar)
	var parent := track_editor.get_parent()
	if not parent:
		return null

	var flow_containers: Array = []
	_find_all_by_class(parent, "HFlowContainer", flow_containers)

	if flow_containers.size() > 0:
		return flow_containers[0]

	return null


func _find_all_by_class(node: Node, class_name_str: String, results: Array) -> void:
	if node.get_class() == class_name_str:
		results.append(node)
	for child in node.get_children():
		_find_all_by_class(child, class_name_str, results)


func _find_all_hboxes(node: Node, results: Array) -> void:
	if node is HBoxContainer:
		results.append(node)
	for child in node.get_children():
		_find_all_hboxes(child, results)


func _find_toolbar_in(node: Node) -> HBoxContainer:
	# Look for HBoxContainer that contains buttons (the main toolbar)
	for child in node.get_children():
		if child is HBoxContainer:
			# Check if it has buttons - that's likely the toolbar
			var has_buttons := false
			for subchild in child.get_children():
				if subchild is Button:
					has_buttons = true
					break
			if has_buttons:
				return child
	# Search one level deeper
	for child in node.get_children():
		if child is VBoxContainer or child is Control:
			var result := _find_toolbar_in(child)
			if result:
				return result
	return null


func _remove_autokey_button() -> void:
	if _autokey_button and is_instance_valid(_autokey_button):
		_autokey_button.queue_free()
		_autokey_button = null


func _on_autokey_toggled(enabled: bool) -> void:
	_autokey_enabled = enabled
	_update_button_style()

	# Auto-detect animation player if not set
	if enabled and not _tracked_animation_player:
		_tracked_animation_player = _get_edited_animation_player()

	if enabled and _tracked_animation_player:
		# Store current values for all tracks and playhead position
		_last_playhead_time = _get_playhead_time()
		_snapshot_all_track_values()
		if _dock:
			_dock.show_status("Auto-Key ON - all tracks")
	else:
		_last_track_values.clear()
		if _dock:
			_dock.show_status("Auto-Key OFF")


func _update_button_style() -> void:
	# Let the button use the theme's built-in toggle highlight (blue)
	# No custom styling needed - toggle_mode handles it
	pass


func _snapshot_all_track_values() -> void:
	_last_track_values.clear()
	var anim := _get_current_animation()
	if not anim:
		return

	for track_idx in anim.get_track_count():
		var value := _get_track_current_value(track_idx, anim)
		if value != null:
			_last_track_values[track_idx] = value


func _check_all_track_changes() -> void:
	if not _tracked_animation_player:
		return
	var anim := _get_current_animation()
	if not anim:
		return

	# Check if playhead moved (user is scrubbing) - don't auto-key while scrubbing
	var current_time := _get_playhead_time()
	if not is_equal_approx(current_time, _last_playhead_time):
		# Playhead moved - update stored values but don't insert keys
		_last_playhead_time = current_time
		_snapshot_all_track_values()
		return

	for track_idx in anim.get_track_count():
		var current_value := _get_track_current_value(track_idx, anim)
		if current_value == null:
			continue

		var last_value = _last_track_values.get(track_idx)
		if last_value == null:
			_last_track_values[track_idx] = current_value
			continue

		if _values_differ(current_value, last_value):
			_insert_key_for_track(track_idx, current_time, anim)
			_last_track_values[track_idx] = current_value


func _values_differ(a: Variant, b: Variant) -> bool:
	if a == null or b == null:
		return a != b
	if a is Vector3 and b is Vector3:
		return not a.is_equal_approx(b)
	elif a is Quaternion and b is Quaternion:
		return not a.is_equal_approx(b)
	elif a is float and b is float:
		return not is_equal_approx(a, b)
	elif a is Vector2 and b is Vector2:
		return not a.is_equal_approx(b)
	return a != b


func _get_track_current_value(track_idx: int, anim: Animation) -> Variant:
	if not _tracked_animation_player:
		return null
	var root := _tracked_animation_player.get_node_or_null(_tracked_animation_player.root_node)
	if not root:
		return null

	var track_path := anim.track_get_path(track_idx)
	var track_type := anim.track_get_type(track_idx)
	var path_str := str(track_path)
	var colon_idx := path_str.rfind(":")
	var node_path := path_str.substr(0, colon_idx) if colon_idx != -1 else path_str
	var property := path_str.substr(colon_idx + 1) if colon_idx != -1 else ""

	var target_node := root.get_node_or_null(node_path)
	if not target_node:
		return null

	match track_type:
		Animation.TYPE_POSITION_3D:
			if target_node is Node3D:
				return target_node.position
		Animation.TYPE_ROTATION_3D:
			if target_node is Node3D:
				return target_node.quaternion
		Animation.TYPE_SCALE_3D:
			if target_node is Node3D:
				return target_node.scale
		Animation.TYPE_VALUE, Animation.TYPE_BEZIER:
			if property:
				return target_node.get_indexed(property)
		Animation.TYPE_BLEND_SHAPE:
			if target_node is MeshInstance3D and property:
				return target_node.get_indexed(property)
	return null


func _insert_key_for_track(track_idx: int, time: float, anim: Animation) -> void:
	if track_idx < 0 or track_idx >= anim.get_track_count():
		return
	if not _tracked_animation_player:
		return

	var root := _tracked_animation_player.get_node_or_null(_tracked_animation_player.root_node)
	if not root:
		return

	var track_path := anim.track_get_path(track_idx)
	var track_type := anim.track_get_type(track_idx)
	var path_str := str(track_path)
	var colon_idx := path_str.rfind(":")
	var node_path := path_str.substr(0, colon_idx) if colon_idx != -1 else path_str
	var property := path_str.substr(colon_idx + 1) if colon_idx != -1 else ""

	var target_node := root.get_node_or_null(node_path)
	if not target_node:
		return

	var existing_key := anim.track_find_key(track_idx, time, Animation.FIND_MODE_EXACT)
	if existing_key != -1:
		anim.track_remove_key(track_idx, existing_key)

	match track_type:
		Animation.TYPE_VALUE:
			anim.track_insert_key(track_idx, time, target_node.get_indexed(property))
		Animation.TYPE_POSITION_3D:
			if target_node is Node3D:
				anim.position_track_insert_key(track_idx, time, target_node.position)
		Animation.TYPE_ROTATION_3D:
			if target_node is Node3D:
				anim.rotation_track_insert_key(track_idx, time, target_node.quaternion)
		Animation.TYPE_SCALE_3D:
			if target_node is Node3D:
				anim.scale_track_insert_key(track_idx, time, target_node.scale)
		Animation.TYPE_BLEND_SHAPE:
			if target_node is MeshInstance3D:
				anim.blend_shape_track_insert_key(track_idx, time, target_node.get_indexed(property))
		Animation.TYPE_BEZIER:
			var value = target_node.get_indexed(property)
			if value is float:
				anim.bezier_track_insert_key(track_idx, time, value)
		_:
			if property:
				anim.track_insert_key(track_idx, time, target_node.get_indexed(property))

	anim.emit_changed()
	if _dock:
		_dock.show_key_inserted_feedback(target_node.name, property if property else "transform", time)


func _get_edited_animation_player() -> AnimationPlayer:
	var selection := get_editor_interface().get_selection()
	for node in selection.get_selected_nodes():
		if node is AnimationPlayer:
			return node
		if node.has_node("AnimationPlayer"):
			return node.get_node("AnimationPlayer")
		var parent := node.get_parent()
		if parent and parent.has_node("AnimationPlayer"):
			return parent.get_node("AnimationPlayer")

	var root := get_editor_interface().get_edited_scene_root()
	if root:
		var players: Array[AnimationPlayer] = []
		_find_animation_players(root, players)
		for player in players:
			if not player.current_animation.is_empty() or not player.assigned_animation.is_empty():
				return player
		if players.size() == 1:
			return players[0]
	return null


func _scan_for_animation_players() -> void:
	var root := get_editor_interface().get_edited_scene_root()
	if not root:
		return
	var players: Array[AnimationPlayer] = []
	_find_animation_players(root, players)
	if _dock:
		_dock.set_available_animation_players(players)


func _find_animation_players(node: Node, result: Array[AnimationPlayer]) -> void:
	if node is AnimationPlayer:
		result.append(node)
	for child in node.get_children():
		_find_animation_players(child, result)


func _on_selection_changed() -> void:
	_scan_for_animation_players()


func _on_animation_player_selected(player: AnimationPlayer) -> void:
	_tracked_animation_player = player
	if _dock:
		_dock.set_current_animation_player(player)
	_last_track_values.clear()


func _get_current_animation() -> Animation:
	if not _tracked_animation_player:
		return null
	var current_name := _tracked_animation_player.current_animation
	if current_name.is_empty():
		current_name = _tracked_animation_player.assigned_animation
	if current_name.is_empty() or not _tracked_animation_player.has_animation(current_name):
		return null
	return _tracked_animation_player.get_animation(current_name)


func _get_playhead_time() -> float:
	if not _tracked_animation_player:
		return 0.0
	return _tracked_animation_player.current_animation_position


func _on_insert_position() -> void:
	_insert_keys_for_selected("position")

func _on_insert_rotation() -> void:
	_insert_keys_for_selected("rotation")

func _on_insert_scale() -> void:
	_insert_keys_for_selected("scale")

func _on_insert_all() -> void:
	_insert_keys_for_selected("position")
	_insert_keys_for_selected("rotation")
	_insert_keys_for_selected("scale")


func _insert_keys_for_selected(property: String) -> void:
	if not _tracked_animation_player:
		_tracked_animation_player = _get_edited_animation_player()
	if not _tracked_animation_player:
		push_warning("AutoKey3D: No AnimationPlayer")
		return
	var current_anim := _get_current_animation()
	if not current_anim:
		push_warning("AutoKey3D: No animation selected")
		return

	var selection := get_editor_interface().get_selection()
	for node in selection.get_selected_nodes():
		if node is Node3D:
			_insert_key_for_property(node, property, current_anim)


func _insert_key_for_property(node: Node3D, property: String, anim: Animation) -> void:
	var track_path := _get_track_path(node, property)
	var track_idx := anim.find_track(track_path, Animation.TYPE_VALUE)
	if track_idx == -1:
		var type_map := {"position": Animation.TYPE_POSITION_3D, "rotation": Animation.TYPE_ROTATION_3D, "scale": Animation.TYPE_SCALE_3D}
		track_idx = anim.find_track(track_path, type_map.get(property, Animation.TYPE_VALUE))
	if track_idx == -1:
		if _dock and _dock.auto_create_tracks:
			track_idx = _create_track_for_property(node, property, anim)
		else:
			return
	if track_idx == -1:
		return

	var time := _get_playhead_time()
	_insert_key_for_track(track_idx, time, anim)


func _get_track_path(node: Node3D, property: String) -> NodePath:
	if not _tracked_animation_player:
		return NodePath()
	var root := _tracked_animation_player.get_node(_tracked_animation_player.root_node)
	return NodePath(str(root.get_path_to(node)) + ":" + property)


func _create_track_for_property(node: Node3D, property: String, anim: Animation) -> int:
	var track_path := _get_track_path(node, property)
	var type_map := {"position": Animation.TYPE_POSITION_3D, "rotation": Animation.TYPE_ROTATION_3D, "scale": Animation.TYPE_SCALE_3D}
	var track_type: Animation.TrackType = type_map.get(property, Animation.TYPE_VALUE)
	var track_idx := anim.add_track(track_type)
	anim.track_set_path(track_idx, track_path)
	return track_idx
