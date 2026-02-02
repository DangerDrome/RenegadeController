@tool
class_name CameraZoneInspectorPlugin extends EditorInspectorPlugin

var _preview_control: Control


func _can_handle(object: Object) -> bool:
	# Handle CameraZone or Marker3D that's a child of CameraZone.
	if object is CameraZone:
		return true
	if object is Marker3D:
		var parent := (object as Node).get_parent()
		if parent is CameraZone:
			return true
		# Also handle LookAtMarker (child of CameraMarker, grandchild of CameraZone).
		if parent is Marker3D:
			var grandparent := parent.get_parent()
			if grandparent is CameraZone:
				return true
	return false


func _parse_begin(object: Object) -> void:
	# Find the CameraZone.
	var zone: CameraZone = null
	if object is CameraZone:
		zone = object
	elif object is Marker3D:
		var parent := (object as Node).get_parent()
		if parent is CameraZone:
			zone = parent
		elif parent is Marker3D:
			var grandparent := parent.get_parent()
			if grandparent is CameraZone:
				zone = grandparent

	if not zone:
		return

	# Create the preview control.
	_preview_control = CameraPreviewControl.new()
	_preview_control.setup(zone)
	add_custom_control(_preview_control)


## Custom control that displays a camera preview using SubViewport.
class CameraPreviewControl extends VBoxContainer:
	var _zone: CameraZone
	var _subviewport: SubViewport
	var _preview_camera: Camera3D
	var _texture_rect: TextureRect

	func setup(zone: CameraZone) -> void:
		_zone = zone

		# Create label.
		var label := Label.new()
		label.text = "Camera Preview"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(label)

		# Create SubViewport (not in tree, just for rendering).
		_subviewport = SubViewport.new()
		_subviewport.size = Vector2i(391, 220)
		_subviewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		_subviewport.handle_input_locally = false
		_subviewport.gui_disable_input = true
		_subviewport.transparent_bg = false
		add_child(_subviewport)

		# Create preview camera.
		_preview_camera = Camera3D.new()
		_subviewport.add_child(_preview_camera)

		# Create TextureRect to display the viewport with proper aspect ratio.
		_texture_rect = TextureRect.new()
		_texture_rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_texture_rect.texture = _subviewport.get_texture()
		_texture_rect.resized.connect(_on_texture_rect_resized)
		add_child(_texture_rect)

		# Add some spacing.
		var spacer := Control.new()
		spacer.custom_minimum_size = Vector2(0, 4)
		add_child(spacer)

		# Initial update.
		_update_preview()

	func _process(_delta: float) -> void:
		_update_preview()

	func _update_preview() -> void:
		if not is_instance_valid(_zone) or not is_instance_valid(_preview_camera):
			return

		var marker := _zone.camera_marker
		if not marker or not is_instance_valid(marker):
			return

		# Position the camera at the marker.
		_preview_camera.global_transform = marker.global_transform

		# Look at the target if available.
		var look_node := _zone.get_look_at_node()
		if look_node and is_instance_valid(look_node):
			var look_pos := look_node.global_position
			var cam_pos := _preview_camera.global_position
			var dir := (look_pos - cam_pos).normalized()
			# Avoid colinear issue.
			var up := Vector3.FORWARD if absf(dir.y) > 0.9 else Vector3.UP
			_preview_camera.look_at(look_pos, up)

		# Apply FOV from preset if available.
		if _zone.camera_preset:
			_preview_camera.fov = _zone.camera_preset.fov

	func _on_texture_rect_resized() -> void:
		if not _texture_rect or not _subviewport:
			return
		# Calculate height based on width to maintain 16:9.
		var width := _texture_rect.size.x
		var height := width * 9.0 / 16.0
		_texture_rect.custom_minimum_size.y = height
		# Update viewport resolution to match.
		_subviewport.size = Vector2i(int(width), int(height))

	func _notification(what: int) -> void:
		if what == NOTIFICATION_PREDELETE:
			# Cleanup.
			if _subviewport:
				_subviewport.queue_free()
