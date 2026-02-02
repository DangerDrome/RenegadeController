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
var inventory: Inventory
var equipment_manager: EquipmentManager
var weapon_manager: WeaponManager
var item_slots: ItemSlots


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
		lines.append("")
	
	# Inventory state.
	if inventory:
		var total_items := 0
		var occupied_slots := 0
		for slot in inventory.slots:
			if not slot.is_empty():
				occupied_slots += 1
				total_items += slot.quantity
		lines.append("[b]Inventory[/b]")
		lines.append("  Slots: %d / %d" % [occupied_slots, inventory.max_slots])
		lines.append("  Total Items: %d" % total_items)
		# Show first few items.
		var shown := 0
		for slot in inventory.slots:
			if not slot.is_empty() and shown < 5:
				var type_color := _get_item_type_color(slot.item.item_type)
				if slot.quantity > 1:
					lines.append("  [color=%s]%s[/color] x%d" % [type_color, slot.item.display_name, slot.quantity])
				else:
					lines.append("  [color=%s]%s[/color]" % [type_color, slot.item.display_name])
				shown += 1
		if occupied_slots > 5:
			lines.append("  [color=gray]... +%d more[/color]" % (occupied_slots - 5))
		lines.append("")

	# Item slots (belt) state.
	if item_slots:
		var belt_occupied := item_slots.get_occupied_slot_count()
		var belt_total := item_slots.slot_count
		lines.append("[b]Belt Slots[/b]")
		if belt_occupied >= belt_total:
			lines.append("  Slots: [color=red]%d / %d (FULL)[/color]" % [belt_occupied, belt_total])
		else:
			lines.append("  Slots: %d / %d" % [belt_occupied, belt_total])
		lines.append("")
	
	# Equipment state.
	if equipment_manager:
		lines.append("[b]Equipment[/b]")
		for slot_name in equipment_manager.equipped:
			var item := equipment_manager.equipped[slot_name] as ItemDefinition
			var active_marker := ""
			if slot_name == equipment_manager.get_active_weapon_slot():
				active_marker = " [color=yellow]*[/color]"
			if item:
				lines.append("  %s: [color=orange]%s[/color]%s" % [String(slot_name).capitalize(), item.display_name, active_marker])
			else:
				lines.append("  %s: [color=gray]empty[/color]%s" % [String(slot_name).capitalize(), active_marker])
		lines.append("")
	
	# Weapon state.
	if weapon_manager:
		lines.append("[b]Weapon[/b]")
		if weapon_manager.current_weapon:
			lines.append("  Active: [color=orange]%s[/color]" % weapon_manager.current_weapon.display_name)
			lines.append("  Ammo: %d / %d" % [weapon_manager.ammo_in_magazine, weapon_manager.current_weapon.magazine_size])
			lines.append("  State: %s" % _get_weapon_state_string(weapon_manager.state))
		else:
			lines.append("  Active: [color=gray]none[/color]")
		lines.append("")
	
	# FPS.
	lines.append("")
	lines.append("[color=gray]FPS: %d[/color]" % Engine.get_frames_per_second())
	
	_label.text = "\n".join(lines)


func _fmt_vec3(v: Vector3) -> String:
	return "(%.1f, %.1f, %.1f)" % [v.x, v.y, v.z]


func _get_item_type_color(type: ItemDefinition.ItemType) -> String:
	match type:
		ItemDefinition.ItemType.WEAPON:
			return "orange"
		ItemDefinition.ItemType.GEAR:
			return "cyan"
		ItemDefinition.ItemType.CONSUMABLE:
			return "green"
		ItemDefinition.ItemType.KEY_ITEM:
			return "yellow"
	return "white"


func _get_weapon_state_string(state: WeaponManager.State) -> String:
	match state:
		WeaponManager.State.IDLE:
			return "[color=green]Idle[/color]"
		WeaponManager.State.SWITCHING:
			return "[color=yellow]Switching[/color]"
		WeaponManager.State.FIRING:
			return "[color=red]Firing[/color]"
		WeaponManager.State.RELOADING:
			return "[color=yellow]Reloading[/color]"
	return "Unknown"
