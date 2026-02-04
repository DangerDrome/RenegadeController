@tool
extends CanvasLayer
## GameHUD - Configurable HUD with pixel font support.
## Exposes font settings, debug overlay, and makes child controls pass-through for mouse input.
## Toggle debug/instructions visibility with F3.

enum PixelFont {
	TINY5,        ## Tiny5 - Compact 5x5 pixel font
	SILKSCREEN,   ## Silkscreen - Classic pixel font
	VT323,        ## VT323 - VT320 terminal style
	PRESS_START,  ## Press Start 2P - Arcade style
}

const FONT_PATHS := {
	PixelFont.TINY5: "res://addons/modular_hud/fonts/Tiny5-Regular.ttf",
	PixelFont.SILKSCREEN: "res://addons/modular_hud/fonts/Silkscreen-Regular.ttf",
	PixelFont.VT323: "res://addons/modular_hud/fonts/VT323-Regular.ttf",
	PixelFont.PRESS_START: "res://addons/modular_hud/fonts/PressStart2P-Regular.ttf",
}

## Recommended sizes for each font at 1920x1080 (3x the 640x360 base)
const FONT_RECOMMENDED_SIZES := {
	PixelFont.TINY5: 30,       # Designed for 5px, 6x scale = 30
	PixelFont.SILKSCREEN: 24,  # Designed for 8px, 3x scale
	PixelFont.VT323: 48,       # Designed for 16px, 3x scale
	PixelFont.PRESS_START: 24, # Designed for 8px multiples, 3x scale
}

@export_group("Font Settings")
@export var pixel_font: PixelFont = PixelFont.TINY5:
	set(value):
		pixel_font = value
		_apply_font_settings()

@export var font_size: int = 30:
	set(value):
		font_size = value
		_apply_font_settings()

@export var use_recommended_size: bool = true:
	set(value):
		use_recommended_size = value
		_apply_font_settings()

@export_group("Font Style")
@export var font_color: Color = Color.WHITE:
	set(value):
		font_color = value
		_apply_font_settings()

@export var font_outline_size: int = 0:
	set(value):
		font_outline_size = value
		_apply_font_settings()

@export var font_outline_color: Color = Color.BLACK:
	set(value):
		font_outline_color = value
		_apply_font_settings()

@export var font_shadow_offset: Vector2 = Vector2.ZERO:
	set(value):
		font_shadow_offset = value
		_apply_font_settings()

@export var font_shadow_color: Color = Color(0, 0, 0, 0.5):
	set(value):
		font_shadow_color = value
		_apply_font_settings()

var _current_font: Font
var _is_ready := false
var _is_applying := false

# Debug overlay references (set by demo_scene.gd or similar)
var debug_character: Node  # RenegadeCharacter
var debug_camera_rig: Node  # CameraRig
var debug_cursor: Node  # Cursor3D
var debug_zone_manager: Node  # CameraZoneManager
var debug_inventory: Node  # Inventory
var debug_equipment_manager: Node  # EquipmentManager
var debug_weapon_manager: Node  # WeaponManager
var debug_item_slots: Node  # ItemSlots

var _debug_visible := true
var _debug_label: RichTextLabel
var _instructions_label: RichTextLabel


func _ready() -> void:
	_is_ready = true
	_load_font()
	_apply_font_settings()

	if not Engine.is_editor_hint():
		# Make all Control children ignore mouse input so clicks pass through to 3D world.
		_set_mouse_filter_recursive(self, Control.MOUSE_FILTER_IGNORE)

		# Get references to debug and instructions labels.
		_debug_label = get_node_or_null("Root/Layout/Center/Toasts/DebugLabel")
		_instructions_label = get_node_or_null("Root/Layout/Center/Main/Instructions")


func _input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	if event.is_action_pressed("toggle_debug"):
		_debug_visible = not _debug_visible
		if _debug_label:
			_debug_label.visible = _debug_visible
		if _instructions_label:
			_instructions_label.visible = _debug_visible


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if not _debug_visible or not _debug_label:
		return
	_update_debug_text()


func _load_font() -> void:
	var font_path: String = FONT_PATHS.get(pixel_font, FONT_PATHS[PixelFont.TINY5])
	if ResourceLoader.exists(font_path):
		var loaded = load(font_path)
		if loaded is Font:
			_current_font = loaded
		else:
			push_warning("GameHUD: Failed to load font at %s" % font_path)
			_current_font = null
	else:
		push_warning("GameHUD: Font not found at %s" % font_path)
		_current_font = null


func _apply_font_settings() -> void:
	if not _is_ready or _is_applying:
		return

	_is_applying = true
	_load_font()

	if use_recommended_size:
		# Set directly to avoid triggering setter recursion
		font_size = FONT_RECOMMENDED_SIZES.get(pixel_font, 10)

	if _current_font:
		_apply_font_recursive(self)
	_is_applying = false


func _apply_font_recursive(node: Node) -> void:
	if node is Control:
		var control := node as Control

		# Apply font to controls that support it
		if _current_font:
			if control is Label:
				var label := control as Label
				# Clear LabelSettings to allow theme overrides to work
				if label.label_settings:
					label.label_settings = null
				label.add_theme_font_override("font", _current_font)
				label.add_theme_font_size_override("font_size", font_size)
				label.add_theme_color_override("font_color", font_color)
				label.add_theme_constant_override("outline_size", font_outline_size)
				label.add_theme_color_override("font_outline_color", font_outline_color)
				label.add_theme_constant_override("shadow_offset_x", int(font_shadow_offset.x))
				label.add_theme_constant_override("shadow_offset_y", int(font_shadow_offset.y))
				label.add_theme_color_override("font_shadow_color", font_shadow_color)
			elif control is RichTextLabel:
				var rtl := control as RichTextLabel
				rtl.add_theme_font_override("normal_font", _current_font)
				rtl.add_theme_font_size_override("normal_font_size", font_size)
				rtl.add_theme_color_override("default_color", font_color)
			elif control is Button:
				var btn := control as Button
				btn.add_theme_font_override("font", _current_font)
				btn.add_theme_font_size_override("font_size", font_size)
				btn.add_theme_color_override("font_color", font_color)
			elif control is LineEdit:
				var le := control as LineEdit
				le.add_theme_font_override("font", _current_font)
				le.add_theme_font_size_override("font_size", font_size)
				le.add_theme_color_override("font_color", font_color)

	for child in node.get_children():
		_apply_font_recursive(child)


func _set_mouse_filter_recursive(node: Node, filter: Control.MouseFilter) -> void:
	if node is Control:
		node.mouse_filter = filter
	for child in node.get_children():
		_set_mouse_filter_recursive(child, filter)


## Switch to a different pixel font
func set_pixel_font(font: PixelFont) -> void:
	pixel_font = font


## Get the current font resource
func get_current_font() -> Font:
	return _current_font


## Apply current font settings to a specific control
func apply_font_to_control(control: Control) -> void:
	_apply_font_recursive(control)


# ============================================================================
# DEBUG OVERLAY
# ============================================================================

func _update_debug_text() -> void:
	var lines: PackedStringArray = []

	lines.append("[b][color=yellow]RENEGADE CONTROLLER DEBUG[/color][/b]")
	lines.append("[color=gray]F3 to toggle[/color]")
	lines.append("")

	# Character state.
	if debug_character and is_instance_valid(debug_character):
		var speed: float = debug_character.get_horizontal_speed() if debug_character.has_method("get_horizontal_speed") else 0.0
		var speed_ratio: float = debug_character.get_speed_ratio() if debug_character.has_method("get_speed_ratio") else 0.0
		lines.append("[b]Character[/b]")
		lines.append("  Speed: %.1f (%.0f%%)" % [speed, speed_ratio * 100])
		lines.append("  Sprinting: %s" % str(debug_character.get("is_sprinting")))
		lines.append("  Aiming: %s" % str(debug_character.get("is_aiming")))
		lines.append("  On Floor: %s" % str(debug_character.is_on_floor() if debug_character.has_method("is_on_floor") else false))
		lines.append("  Position: %s" % _fmt_vec3(debug_character.global_position))
		lines.append("  Move Dir: %s" % _fmt_vec3(debug_character.get("move_direction") if debug_character.get("move_direction") else Vector3.ZERO))
		lines.append("")

	# Camera state.
	if debug_camera_rig and is_instance_valid(debug_camera_rig):
		var preset_name := "None"
		var input_mode := "N/A"
		var is_fp := false
		var current_preset = debug_camera_rig.get("current_preset")
		if current_preset:
			preset_name = current_preset.get("preset_name") if current_preset.get("preset_name") else "Unknown"
			input_mode = str(current_preset.get("input_mode")) if current_preset.get("input_mode") != null else "N/A"
			is_fp = current_preset.get("is_first_person") if current_preset.get("is_first_person") != null else false
		lines.append("[b]Camera[/b]")
		lines.append("  Preset: [color=cyan]%s[/color]" % preset_name)
		lines.append("  Input Mode: %s" % input_mode)
		lines.append("  First Person: %s" % str(is_fp))
		lines.append("  Transitioning: %s" % str(debug_camera_rig.get("is_transitioning")))
		lines.append("")

	# Cursor state.
	if debug_cursor and is_instance_valid(debug_cursor):
		lines.append("[b]Cursor[/b]")
		lines.append("  Has Hit: %s" % str(debug_cursor.get("has_hit")))
		if debug_cursor.get("has_hit"):
			lines.append("  World Pos: %s" % _fmt_vec3(debug_cursor.get("world_position") if debug_cursor.get("world_position") else Vector3.ZERO))
		lines.append("  Hovering: %s" % str(debug_cursor.get("hovering_interactable")))
		var hovered = debug_cursor.get("hovered_object")
		if hovered and is_instance_valid(hovered):
			lines.append("  Hovered: %s" % hovered.name)
		lines.append("")

	# Zone state.
	if debug_zone_manager and is_instance_valid(debug_zone_manager):
		var zone_name := "Default"
		var current_zone = debug_zone_manager.get("_current_zone")
		if current_zone and current_zone.get("camera_preset"):
			zone_name = current_zone.camera_preset.get("preset_name") if current_zone.camera_preset.get("preset_name") else "Unknown"
		var active_zones = debug_zone_manager.get("_active_zones")
		lines.append("[b]Camera Zone[/b]")
		lines.append("  Active: [color=cyan]%s[/color]" % zone_name)
		lines.append("  Zones Overlapping: %d" % (active_zones.size() if active_zones else 0))
		lines.append("")

	# Inventory state.
	if debug_inventory and is_instance_valid(debug_inventory):
		var total_items := 0
		var occupied_slots := 0
		var slots = debug_inventory.get("slots")
		if slots:
			for slot in slots:
				if slot and not slot.is_empty():
					occupied_slots += 1
					total_items += slot.quantity
		var max_slots = debug_inventory.get("max_slots") if debug_inventory.get("max_slots") else 0
		lines.append("[b]Inventory[/b]")
		lines.append("  Slots: %d / %d" % [occupied_slots, max_slots])
		lines.append("  Total Items: %d" % total_items)
		lines.append("")

	# Equipment state.
	if debug_equipment_manager and is_instance_valid(debug_equipment_manager):
		var equipped = debug_equipment_manager.get("equipped")
		if equipped:
			lines.append("[b]Equipment[/b]")
			var active_slot = debug_equipment_manager.get_active_weapon_slot() if debug_equipment_manager.has_method("get_active_weapon_slot") else ""
			for slot_name in equipped:
				var item = equipped[slot_name]
				var active_marker := ""
				if slot_name == active_slot:
					active_marker = " [color=yellow]*[/color]"
				if item:
					lines.append("  %s: [color=orange]%s[/color]%s" % [String(slot_name).capitalize(), item.display_name, active_marker])
				else:
					lines.append("  %s: [color=gray]empty[/color]%s" % [String(slot_name).capitalize(), active_marker])
			lines.append("")

	# FPS.
	lines.append("[color=gray]FPS: %d[/color]" % Engine.get_frames_per_second())

	_debug_label.text = "\n".join(lines)


func _fmt_vec3(v: Vector3) -> String:
	if v == null:
		return "(0.0, 0.0, 0.0)"
	return "(%.1f, %.1f, %.1f)" % [v.x, v.y, v.z]
