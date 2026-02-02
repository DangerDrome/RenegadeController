## Debug overlay that displays live controller state.
## Toggle with F3.
extends CanvasLayer

var _panel: PanelContainer
var _label: RichTextLabel
var _visible: bool = true

var character: RenegadeCharacter
var camera_rig: CameraRig
var cursor: Cursor3D
var zone_manager: CameraZoneManager


func _ready() -> void:
	layer = 100
	_build_ui()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_debug"):
		_visible = not _visible
		_panel.visible = _visible


func _process(_delta: float) -> void:
	if not _visible:
		return
	_update_text()


func _build_ui() -> void:
	_panel = PanelContainer.new()
	
	# Style.
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.7)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	_panel.add_theme_stylebox_override("panel", style)
	
	# Position top-left.
	_panel.anchor_left = 0
	_panel.anchor_top = 0
	_panel.offset_left = 10
	_panel.offset_top = 10
	
	_label = RichTextLabel.new()
	_label.bbcode_enabled = true
	_label.fit_content = true
	_label.custom_minimum_size = Vector2(320, 0)
	_label.add_theme_font_size_override("normal_font_size", 14)
	_panel.add_child(_label)
	
	add_child(_panel)


func _update_text() -> void:
	var lines: PackedStringArray = []
	
	lines.append("[b][color=yellow]RENEGADE CONTROLLER DEBUG[/color][/b]")
	lines.append("[color=gray]F3 to toggle[/color]")
	lines.append("")
	
	# Character state.
	if character:
		var speed := character.get_horizontal_speed()
		var speed_ratio := character.get_speed_ratio()
		lines.append("[b]Character[/b]")
		lines.append("  Speed: %.1f (%.0f%%)" % [speed, speed_ratio * 100])
		lines.append("  Sprinting: %s" % str(character.is_sprinting))
		lines.append("  Aiming: %s" % str(character.is_aiming))
		lines.append("  On Floor: %s" % str(character.is_on_floor()))
		lines.append("  Position: %s" % _fmt_vec3(character.global_position))
		lines.append("  Move Dir: %s" % _fmt_vec3(character.move_direction))
		lines.append("  Aim Dir: %s" % _fmt_vec3(character.aim_direction))
		lines.append("")
	
	# Camera state.
	if camera_rig:
		var preset_name := "None"
		var input_mode := "N/A"
		var is_fp := false
		if camera_rig.current_preset:
			preset_name = camera_rig.current_preset.preset_name
			input_mode = camera_rig.current_preset.input_mode
			is_fp = camera_rig.current_preset.is_first_person
		lines.append("[b]Camera[/b]")
		lines.append("  Preset: [color=cyan]%s[/color]" % preset_name)
		lines.append("  Input Mode: %s" % input_mode)
		lines.append("  First Person: %s" % str(is_fp))
		lines.append("  Transitioning: %s" % str(camera_rig.is_transitioning))
		lines.append("")
	
	# Cursor state.
	if cursor:
		lines.append("[b]Cursor[/b]")
		lines.append("  Has Hit: %s" % str(cursor.has_hit))
		if cursor.has_hit:
			lines.append("  World Pos: %s" % _fmt_vec3(cursor.world_position))
		lines.append("  Hovering Interactable: %s" % str(cursor.hovering_interactable))
		if cursor.hovered_object and is_instance_valid(cursor.hovered_object):
			lines.append("  Hovered: %s" % cursor.hovered_object.name)
		lines.append("")
	
	# Zone state.
	if zone_manager:
		var zone_name := "Default"
		if zone_manager._current_zone and zone_manager._current_zone.camera_preset:
			zone_name = zone_manager._current_zone.camera_preset.preset_name
		lines.append("[b]Camera Zone[/b]")
		lines.append("  Active: [color=cyan]%s[/color]" % zone_name)
		lines.append("  Zones Overlapping: %d" % zone_manager._active_zones.size())
	
	# FPS.
	lines.append("")
	lines.append("[color=gray]FPS: %d[/color]" % Engine.get_frames_per_second())
	
	_label.text = "\n".join(lines)


func _fmt_vec3(v: Vector3) -> String:
	return "(%.1f, %.1f, %.1f)" % [v.x, v.y, v.z]
