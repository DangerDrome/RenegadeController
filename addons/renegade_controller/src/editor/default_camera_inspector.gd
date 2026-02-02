@tool
class_name DefaultCameraInspectorPlugin extends EditorInspectorPlugin

var _preview_control: Control


func _can_handle(object: Object) -> bool:
	# Handle DefaultCameraMarker nodes.
	if object is DefaultCameraMarker:
		return true
	return false


func _parse_begin(object: Object) -> void:
	if not object is DefaultCameraMarker:
		return

	var marker := object as DefaultCameraMarker

	# Create the preview control.
	_preview_control = DefaultCameraPreviewControl.new()
	_preview_control.setup(marker)
	add_custom_control(_preview_control)


## Custom control that displays a camera preview using SubViewport.
class DefaultCameraPreviewControl extends VBoxContainer:
	var _marker: DefaultCameraMarker
	var _subviewport: SubViewport
	var _preview_camera: Camera3D
	var _texture_rect: TextureRect
	var _resize_handle: Control
	var _is_dragging := false
	var _preview_height := 220.0

	func setup(marker: DefaultCameraMarker) -> void:
		_marker = marker

		# Create label.
		var label := Label.new()
		label.text = "Camera Preview"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(label)

		# Create SubViewport (not in tree, just for rendering).
		_subviewport = SubViewport.new()
		_subviewport.size = Vector2i(391, int(_preview_height))
		_subviewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		_subviewport.handle_input_locally = false
		_subviewport.gui_disable_input = true
		_subviewport.transparent_bg = false
		add_child(_subviewport)

		# Create preview camera (exclude layer 2 to hide camera body/lens gizmos).
		_preview_camera = Camera3D.new()
		_preview_camera.cull_mask = 1  # Only layer 1.
		_preview_camera.near = 0.01
		_preview_camera.far = 1000.0
		_subviewport.add_child(_preview_camera)

		# Create TextureRect to display the viewport with proper aspect ratio.
		_texture_rect = TextureRect.new()
		_texture_rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_texture_rect.texture = _subviewport.get_texture()
		_texture_rect.custom_minimum_size.y = _preview_height
		add_child(_texture_rect)

		# Create resize handle at the bottom.
		_resize_handle = Panel.new()
		_resize_handle.custom_minimum_size = Vector2(0, 8)
		_resize_handle.mouse_default_cursor_shape = Control.CURSOR_VSIZE
		_resize_handle.gui_input.connect(_on_resize_handle_input)
		var handle_style := StyleBoxFlat.new()
		handle_style.bg_color = Color(0.3, 0.3, 0.3)
		_resize_handle.add_theme_stylebox_override("panel", handle_style)
		add_child(_resize_handle)

		# Initial update.
		_update_preview()
		_update_viewport_size()

	func _process(_delta: float) -> void:
		_update_preview()

	func _update_preview() -> void:
		if not is_instance_valid(_marker) or not is_instance_valid(_preview_camera):
			return
		if not _preview_camera.is_inside_tree():
			return
		if not _marker.is_inside_tree():
			return

		# Get preset and player.
		var camera_rig := _find_camera_rig(_marker)
		var preset: CameraPreset = camera_rig.default_preset if camera_rig else null
		var player := _find_player(_marker)

		# Position: always at marker's world position.
		_preview_camera.global_position = _marker.global_position

		# Rotation: if follow_target is true and we have a player, look at them.
		# Otherwise use marker's rotation directly (matches 3D viewport).
		if preset and preset.follow_target and player:
			var look_target := player.global_position + Vector3.UP * 1.0
			var dir := look_target - _preview_camera.global_position
			if dir.length_squared() > 0.001:
				var up := Vector3.FORWARD if absf(dir.normalized().y) > 0.9 else Vector3.UP
				_preview_camera.look_at(look_target, up)
		else:
			_preview_camera.global_basis = _marker.global_basis

		# FOV from preset.
		var fov := preset.fov if preset else 70.0
		_preview_camera.fov = fov

	func _find_camera_rig(node: Node) -> CameraRig:
		# Look for CameraRig as sibling (child of same parent).
		var parent := node.get_parent()
		if not parent:
			return null
		for child in parent.get_children():
			if child is CameraRig:
				return child
		return null

	func _find_player(node: Node) -> Node3D:
		# Find a node in the "player" group in the scene.
		var root := node.get_tree().edited_scene_root if Engine.is_editor_hint() else node.get_tree().root
		if not root:
			return null
		# Search for RenegadeCharacter or node in "player" group.
		return _find_player_recursive(root)

	func _find_player_recursive(node: Node) -> Node3D:
		if node is CharacterBody3D and node.name == "Player":
			return node
		if node.is_in_group("player"):
			return node as Node3D
		for child in node.get_children():
			var found := _find_player_recursive(child)
			if found:
				return found
		return null

	func _on_resize_handle_input(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_LEFT:
				_is_dragging = event.pressed
		elif event is InputEventMouseMotion and _is_dragging:
			_preview_height = clampf(_preview_height + event.relative.y, 100.0, 600.0)
			_texture_rect.custom_minimum_size.y = _preview_height
			_update_viewport_size()

	func _update_viewport_size() -> void:
		if not _texture_rect or not _subviewport:
			return
		# Calculate width based on height to maintain 16:9.
		var width := _preview_height * 16.0 / 9.0
		_subviewport.size = Vector2i(int(width), int(_preview_height))

	func _notification(what: int) -> void:
		if what == NOTIFICATION_PREDELETE:
			# Cleanup.
			if _subviewport:
				_subviewport.queue_free()
