@tool
class_name CameraZoneInspectorPlugin extends EditorInspectorPlugin

var _preview_control: Control
var _preset_settings_control: Control


func _can_handle(object: Object) -> bool:
	# Handle CameraZone or Marker3D that's a child of CameraZone.
	if object is CameraZone:
		return true
	if object is Marker3D:
		var parent := (object as Node).get_parent()
		if parent is CameraZone:
			return true
		# Also handle Camera_target (child of Camera, grandchild of CameraZone).
		if parent is Marker3D:
			var grandparent := parent.get_parent()
			if grandparent is CameraZone:
				return true
	return false


func _parse_begin(object: Object) -> void:
	# Find the CameraZone and determine if this is the Camera marker.
	var zone: CameraZone = null
	var is_camera_marker := false
	if object is CameraZone:
		zone = object
	elif object is Marker3D:
		var parent := (object as Node).get_parent()
		if parent is CameraZone:
			zone = parent
			is_camera_marker = true  # Direct child of CameraZone = Camera marker.
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

	# Add preset settings when Camera marker is selected.
	if is_camera_marker:
		_preset_settings_control = CameraPresetSettingsControl.new()
		_preset_settings_control.setup(zone)
		add_custom_control(_preset_settings_control)


## Custom control that displays a camera preview using SubViewport.
class CameraPreviewControl extends VBoxContainer:
	var _zone: CameraZone
	var _subviewport: SubViewport
	var _preview_camera: Camera3D
	var _texture_rect: TextureRect
	var _resize_handle: Control
	var _is_dragging := false
	var _preview_height := 220.0

	func setup(zone: CameraZone) -> void:
		_zone = zone

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

		# Create preview camera (exclude layer 2 to hide camera body/lens).
		_preview_camera = Camera3D.new()
		_preview_camera.cull_mask = 1  # Only layer 1.
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
		if not is_instance_valid(_zone) or not is_instance_valid(_preview_camera):
			return
		if not _preview_camera.is_inside_tree():
			return

		var marker := _zone.camera_marker
		if not marker or not is_instance_valid(marker):
			return
		if not marker.is_inside_tree():
			return

		# Position the camera at the marker.
		_preview_camera.global_transform = marker.global_transform

		# Look at the target if available.
		var look_node := _zone.get_look_at_node()
		if look_node and is_instance_valid(look_node) and look_node.is_inside_tree():
			var look_pos := look_node.global_position
			var cam_pos := _preview_camera.global_position
			var dir := (look_pos - cam_pos).normalized()
			# Avoid colinear issue.
			var up := Vector3.FORWARD if absf(dir.y) > 0.9 else Vector3.UP
			_preview_camera.look_at(look_pos, up)

		# Apply FOV from preset if available.
		if _zone.camera_preset:
			_preview_camera.fov = _zone.camera_preset.fov

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


## Custom control that displays editable camera preset settings when Camera marker is selected.
class CameraPresetSettingsControl extends VBoxContainer:
	var _zone: CameraZone
	var _settings_container: VBoxContainer
	var _no_preset_label: Label
	var _make_unique_button: Button
	var _unique_label: Label
	var _current_preset: CameraPreset
	var _is_building := false
	var _current_section_content: VBoxContainer

	func setup(zone: CameraZone) -> void:
		_zone = zone

		# Add header with separator.
		var separator := HSeparator.new()
		add_child(separator)

		var header_row := HBoxContainer.new()
		header_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		add_child(header_row)

		var header := Label.new()
		header.text = "Camera Preset Settings"
		header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		header_row.add_child(header)

		_make_unique_button = Button.new()
		_make_unique_button.text = "Make Unique"
		_make_unique_button.pressed.connect(_on_make_unique_pressed)
		header_row.add_child(_make_unique_button)

		_unique_label = Label.new()
		_unique_label.text = "(Unique)"
		_unique_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))
		_unique_label.visible = false
		header_row.add_child(_unique_label)

		# Create settings container.
		_settings_container = VBoxContainer.new()
		add_child(_settings_container)

		# No preset label (shown when no preset assigned).
		_no_preset_label = Label.new()
		_no_preset_label.text = "No camera preset assigned to zone."
		_no_preset_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_no_preset_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		_settings_container.add_child(_no_preset_label)

		# Initial build.
		_rebuild_settings()

	func _process(_delta: float) -> void:
		if not is_instance_valid(_zone):
			return
		# Only rebuild if preset reference changed.
		if _zone.camera_preset != _current_preset:
			_rebuild_settings()

	func _on_make_unique_pressed() -> void:
		if not is_instance_valid(_zone) or not _zone.camera_preset:
			return
		# Duplicate the preset resource.
		var new_preset: CameraPreset = _zone.camera_preset.duplicate()
		new_preset.preset_name = _zone.camera_preset.preset_name + " (Unique)"
		_zone.camera_preset = new_preset
		_current_preset = new_preset
		_rebuild_settings()
		_notify_property_changed()

	func _rebuild_settings() -> void:
		if _is_building:
			return
		_is_building = true

		if not is_instance_valid(_zone):
			_is_building = false
			return

		var preset := _zone.camera_preset
		_current_preset = preset

		if not preset:
			_no_preset_label.visible = true
			_make_unique_button.visible = false
			_unique_label.visible = false
			for child in _settings_container.get_children():
				if child != _no_preset_label:
					child.queue_free()
			_is_building = false
			return

		_no_preset_label.visible = false

		# Check if preset is unique (no resource path = embedded/unique).
		var is_unique := preset.resource_path.is_empty()
		_make_unique_button.visible = not is_unique
		_unique_label.visible = is_unique

		# Clear old settings (except no_preset_label).
		for child in _settings_container.get_children():
			if child != _no_preset_label:
				child.queue_free()

		# Reset current section.
		_current_section_content = null

		# Build editable settings using collapsible sections.
		_add_string_setting("Preset Name", preset.preset_name, func(v: String) -> void: preset.preset_name = v)

		_add_section_header("Mode")
		_add_bool_setting("First Person", preset.is_first_person, func(v: bool) -> void: preset.is_first_person = v)
		_add_vector3_setting("Head Offset", preset.head_offset, func(v: Vector3) -> void: preset.head_offset = v)

		_add_section_header("Position")
		_add_vector3_setting("Offset", preset.offset, func(v: Vector3) -> void: preset.offset = v)
		_add_float_setting("Spring Length", preset.spring_length, 0.0, 50.0, 0.1, func(v: float) -> void: preset.spring_length = v)
		_add_bool_setting("Use Collision", preset.use_collision, func(v: bool) -> void: preset.use_collision = v)

		_add_section_header("Rotation")
		_add_float_setting("Yaw Offset", preset.yaw_offset, -180.0, 180.0, 0.1, func(v: float) -> void: preset.yaw_offset = v)
		_add_float_setting("Pitch", preset.pitch, -89.0, 89.0, 0.1, func(v: float) -> void: preset.pitch = v)
		_add_bool_setting("Fixed Rotation", preset.fixed_rotation, func(v: bool) -> void: preset.fixed_rotation = v)
		_add_float_setting("Fixed Yaw", preset.fixed_yaw, -180.0, 180.0, 0.1, func(v: float) -> void: preset.fixed_yaw = v)

		_add_section_header("Follow Behavior")
		_add_float_setting("Follow Speed", preset.follow_speed, 1.0, 50.0, 0.1, func(v: float) -> void: preset.follow_speed = v)
		_add_float_setting("Rotation Speed", preset.rotation_speed, 1.0, 50.0, 0.1, func(v: float) -> void: preset.rotation_speed = v)

		_add_section_header("Transition")
		_add_float_setting("Duration", preset.transition_duration, 0.05, 3.0, 0.05, func(v: float) -> void: preset.transition_duration = v)
		_add_enum_setting("Transition Type", preset.transition_type, [
			"Linear", "Sine", "Quint", "Quart", "Quad", "Expo",
			"Elastic", "Cubic", "Circ", "Bounce", "Back", "Spring"
		], func(v: int) -> void: preset.transition_type = v as Tween.TransitionType)
		_add_enum_setting("Ease Type", preset.ease_type, [
			"Ease In", "Ease Out", "Ease In/Out", "Ease Out/In"
		], func(v: int) -> void: preset.ease_type = v as Tween.EaseType)

		_add_section_header("FOV")
		_add_float_setting("Field of View", preset.fov, 30.0, 120.0, 0.5, func(v: float) -> void: preset.fov = v)

		_add_section_header("Input Mapping")
		_add_enum_setting("Input Mode", ["CAMERA_RELATIVE", "FIXED_AXIS", "WORLD"].find(preset.input_mode), [
			"Camera Relative", "Fixed Axis", "World"
		], func(v: int) -> void: preset.input_mode = ["CAMERA_RELATIVE", "FIXED_AXIS", "WORLD"][v])
		_add_vector3_setting("Fixed Forward", preset.fixed_forward, func(v: Vector3) -> void: preset.fixed_forward = v)
		_add_vector3_setting("Fixed Right", preset.fixed_right, func(v: Vector3) -> void: preset.fixed_right = v)

		_add_section_header("Mouse Look")
		_add_float_setting("Mouse Sensitivity", preset.mouse_sensitivity, 0.01, 1.0, 0.01, func(v: float) -> void: preset.mouse_sensitivity = v)
		_add_float_setting("Min Pitch", preset.min_pitch, -89.0, 0.0, 0.1, func(v: float) -> void: preset.min_pitch = v)
		_add_float_setting("Max Pitch", preset.max_pitch, 0.0, 89.0, 0.1, func(v: float) -> void: preset.max_pitch = v)

		_is_building = false

	func _add_section_header(text: String) -> void:
		# Padding above header.
		var top_spacer := Control.new()
		top_spacer.custom_minimum_size.y = 8
		_settings_container.add_child(top_spacer)

		# Section panel with rounded corners (hardcoded dark theme colors).
		var section_panel := PanelContainer.new()
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.17, 0.17, 0.17)
		style.corner_radius_top_left = 4
		style.corner_radius_top_right = 4
		style.corner_radius_bottom_left = 4
		style.corner_radius_bottom_right = 4
		style.content_margin_left = 4
		style.content_margin_right = 4
		style.content_margin_top = 2
		style.content_margin_bottom = 2
		style.border_width_top = 0
		style.border_width_bottom = 0
		style.border_width_left = 0
		style.border_width_right = 0
		section_panel.add_theme_stylebox_override("panel", style)
		_settings_container.add_child(section_panel)

		var section_vbox := VBoxContainer.new()
		section_panel.add_child(section_vbox)

		# Twirl-down button.
		var btn := Button.new()
		btn.flat = true
		btn.text = text
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
		# Get bold font and arrow icons from editor theme.
		var editor_theme := EditorInterface.get_editor_theme()
		var bold_font := editor_theme.get_font("bold", "EditorFonts")
		btn.add_theme_font_override("font", bold_font)
		var arrow_right := editor_theme.get_icon("GuiTreeArrowRight", "EditorIcons")
		var arrow_down := editor_theme.get_icon("GuiTreeArrowDown", "EditorIcons")
		btn.icon = arrow_down
		section_vbox.add_child(btn)

		# Content container (starts expanded) with inspector background color.
		var content_panel := PanelContainer.new()
		var content_style := StyleBoxFlat.new()
		content_style.bg_color = Color(0.17, 0.17, 0.17)
		content_style.content_margin_left = 30
		content_style.content_margin_right = 8
		content_style.content_margin_top = 4
		content_style.content_margin_bottom = 4
		content_panel.add_theme_stylebox_override("panel", content_style)
		content_panel.visible = true
		section_vbox.add_child(content_panel)

		var content := VBoxContainer.new()
		content_panel.add_child(content)
		_current_section_content = content

		# Toggle on click.
		btn.pressed.connect(_make_toggle_callback(btn, content_panel, arrow_right, arrow_down))

		# Padding below section.
		var bottom_spacer := Control.new()
		bottom_spacer.custom_minimum_size.y = 4
		_settings_container.add_child(bottom_spacer)

	func _make_toggle_callback(btn: Button, content_panel: PanelContainer, arrow_right: Texture2D, arrow_down: Texture2D) -> Callable:
		return func() -> void:
			content_panel.visible = not content_panel.visible
			btn.icon = arrow_down if content_panel.visible else arrow_right

	func _get_current_container() -> VBoxContainer:
		return _current_section_content if _current_section_content else _settings_container

	func _add_string_setting(label_text: String, value: String, setter: Callable) -> void:
		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var label := Label.new()
		label.text = label_text + ":"
		label.custom_minimum_size.x = 120
		label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
		row.add_child(label)

		var edit := LineEdit.new()
		edit.text = value
		edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		edit.text_changed.connect(func(new_text: String) -> void:
			setter.call(new_text)
			_notify_property_changed()
		)
		row.add_child(edit)

		_get_current_container().add_child(row)

	func _add_bool_setting(label_text: String, value: bool, setter: Callable) -> void:
		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var label := Label.new()
		label.text = label_text + ":"
		label.custom_minimum_size.x = 120
		label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
		row.add_child(label)

		var checkbox := CheckBox.new()
		checkbox.button_pressed = value
		checkbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		checkbox.toggled.connect(func(pressed: bool) -> void:
			setter.call(pressed)
			_notify_property_changed()
		)
		row.add_child(checkbox)

		_get_current_container().add_child(row)

	func _add_float_setting(label_text: String, value: float, min_val: float, max_val: float, step: float, setter: Callable) -> void:
		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var label := Label.new()
		label.text = label_text + ":"
		label.custom_minimum_size.x = 120
		label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
		row.add_child(label)

		var spinbox := SpinBox.new()
		spinbox.min_value = min_val
		spinbox.max_value = max_val
		spinbox.step = step
		spinbox.value = value
		spinbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		spinbox.value_changed.connect(func(new_val: float) -> void:
			setter.call(new_val)
			_notify_property_changed()
		)
		row.add_child(spinbox)

		_get_current_container().add_child(row)

	func _add_vector3_setting(label_text: String, value: Vector3, setter: Callable) -> void:
		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var label := Label.new()
		label.text = label_text + ":"
		label.custom_minimum_size.x = 120
		label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
		row.add_child(label)

		var current := value
		for i in 3:
			var spinbox := SpinBox.new()
			spinbox.min_value = -1000.0
			spinbox.max_value = 1000.0
			spinbox.step = 0.1
			spinbox.value = value[i]
			spinbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			spinbox.custom_minimum_size.x = 60
			var axis := i
			spinbox.value_changed.connect(func(new_val: float) -> void:
				current[axis] = new_val
				setter.call(current)
				_notify_property_changed()
			)
			row.add_child(spinbox)

		_get_current_container().add_child(row)

	func _add_enum_setting(label_text: String, value: int, options: Array, setter: Callable) -> void:
		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var label := Label.new()
		label.text = label_text + ":"
		label.custom_minimum_size.x = 120
		label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
		row.add_child(label)

		var option_btn := OptionButton.new()
		for opt in options:
			option_btn.add_item(opt)
		option_btn.selected = maxi(0, value)
		option_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		option_btn.item_selected.connect(func(idx: int) -> void:
			setter.call(idx)
			_notify_property_changed()
		)
		row.add_child(option_btn)

		_get_current_container().add_child(row)

	func _notify_property_changed() -> void:
		if is_instance_valid(_zone):
			_zone.notify_property_list_changed()
			# Mark scene as modified.
			if Engine.is_editor_hint():
				var edited_scene := EditorInterface.get_edited_scene_root()
				if edited_scene:
					edited_scene.set_meta("_edit_dirty_", true)
