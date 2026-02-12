@tool
class_name AutoKeyDock
extends Control
## Dock UI for AutoKey 3D plugin - Per-track auto-key toggle

signal insert_position_pressed
signal insert_rotation_pressed
signal insert_scale_pressed
signal insert_all_pressed
signal animation_player_selected(player: AnimationPlayer)

## Whether to automatically create tracks if they don't exist
var auto_create_tracks: bool = true

var _animation_player_dropdown: OptionButton
var _animation_dropdown: OptionButton
var _position_btn: Button
var _rotation_btn: Button
var _scale_btn: Button
var _all_btn: Button
var _auto_create_check: CheckBox
var _status_label: Label
var _feedback_timer: Timer

var _available_players: Array[AnimationPlayer] = []
var _current_player: AnimationPlayer


func _ready() -> void:
	_build_ui()
	_feedback_timer = Timer.new()
	_feedback_timer.one_shot = true
	_feedback_timer.timeout.connect(_clear_feedback)
	add_child(_feedback_timer)


func _build_ui() -> void:
	# Main container
	var main_vbox := VBoxContainer.new()
	main_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(main_vbox)

	# Title
	var title := Label.new()
	title.text = "AutoKey 3D"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 16)
	main_vbox.add_child(title)

	main_vbox.add_child(HSeparator.new())

	# Animation Player selection
	var player_label := Label.new()
	player_label.text = "Animation Player:"
	main_vbox.add_child(player_label)

	_animation_player_dropdown = OptionButton.new()
	_animation_player_dropdown.item_selected.connect(_on_player_selected)
	_animation_player_dropdown.custom_minimum_size.x = 150
	main_vbox.add_child(_animation_player_dropdown)

	# Animation selection
	var anim_label := Label.new()
	anim_label.text = "Animation:"
	main_vbox.add_child(anim_label)

	_animation_dropdown = OptionButton.new()
	_animation_dropdown.item_selected.connect(_on_animation_selected)
	_animation_dropdown.custom_minimum_size.x = 150
	main_vbox.add_child(_animation_dropdown)

	main_vbox.add_child(HSeparator.new())

	# Auto-key info
	var info_label := Label.new()
	info_label.text = "Auto-Key:"
	main_vbox.add_child(info_label)

	var info_text := Label.new()
	info_text.text = "Use the Auto-Key button in\nthe Animation panel toolbar\nto auto-insert keyframes."
	info_text.add_theme_font_size_override("font_size", 11)
	info_text.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	main_vbox.add_child(info_text)

	main_vbox.add_child(HSeparator.new())

	# Insert Key buttons section
	var insert_label := Label.new()
	insert_label.text = "Manual Insert (Selected Nodes):"
	main_vbox.add_child(insert_label)

	# Button grid
	var button_grid := GridContainer.new()
	button_grid.columns = 2
	main_vbox.add_child(button_grid)

	_position_btn = Button.new()
	_position_btn.text = "Position"
	_position_btn.pressed.connect(func(): insert_position_pressed.emit())
	_position_btn.custom_minimum_size = Vector2(70, 30)
	button_grid.add_child(_position_btn)

	_rotation_btn = Button.new()
	_rotation_btn.text = "Rotation"
	_rotation_btn.pressed.connect(func(): insert_rotation_pressed.emit())
	_rotation_btn.custom_minimum_size = Vector2(70, 30)
	button_grid.add_child(_rotation_btn)

	_scale_btn = Button.new()
	_scale_btn.text = "Scale"
	_scale_btn.pressed.connect(func(): insert_scale_pressed.emit())
	_scale_btn.custom_minimum_size = Vector2(70, 30)
	button_grid.add_child(_scale_btn)

	_all_btn = Button.new()
	_all_btn.text = "All"
	_all_btn.pressed.connect(func(): insert_all_pressed.emit())
	_all_btn.custom_minimum_size = Vector2(70, 30)
	button_grid.add_child(_all_btn)

	main_vbox.add_child(HSeparator.new())

	# Auto-create tracks checkbox
	_auto_create_check = CheckBox.new()
	_auto_create_check.text = "Auto-create missing tracks"
	_auto_create_check.button_pressed = true
	_auto_create_check.toggled.connect(func(pressed: bool): auto_create_tracks = pressed)
	main_vbox.add_child(_auto_create_check)

	main_vbox.add_child(HSeparator.new())

	# Status/feedback label
	_status_label = Label.new()
	_status_label.text = "Select an AnimationPlayer to begin"
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.custom_minimum_size.y = 40
	main_vbox.add_child(_status_label)

	# Set minimum size for the dock
	custom_minimum_size = Vector2(180, 320)


func _on_player_selected(index: int) -> void:
	if index < 0 or index >= _available_players.size():
		_current_player = null
		_update_animation_list()
		return

	_current_player = _available_players[index]
	animation_player_selected.emit(_current_player)
	_update_animation_list()
	_status_label.text = "Ready - use [A] buttons on tracks"


func _on_animation_selected(index: int) -> void:
	if not _current_player or index < 0:
		return

	var anim_name := _animation_dropdown.get_item_text(index)
	if _current_player.has_animation(anim_name):
		_current_player.assigned_animation = anim_name


func _update_animation_list() -> void:
	_animation_dropdown.clear()

	if not _current_player:
		return

	var anim_list := _current_player.get_animation_list()
	for anim_name in anim_list:
		_animation_dropdown.add_item(anim_name)

	# Select current animation if any
	var current := _current_player.current_animation
	if current.is_empty():
		current = _current_player.assigned_animation

	for i in _animation_dropdown.item_count:
		if _animation_dropdown.get_item_text(i) == current:
			_animation_dropdown.select(i)
			break


func set_available_animation_players(players: Array[AnimationPlayer]) -> void:
	_available_players = players
	_animation_player_dropdown.clear()

	for player in players:
		var display_name := player.name
		if player.get_parent():
			display_name = player.get_parent().name + "/" + player.name
		_animation_player_dropdown.add_item(display_name)

	# Auto-select if only one, or try to keep current selection
	if players.size() == 1:
		_animation_player_dropdown.select(0)
		_on_player_selected(0)
	elif _current_player and _current_player in players:
		var idx := players.find(_current_player)
		_animation_player_dropdown.select(idx)


func set_current_animation_player(player: AnimationPlayer) -> void:
	_current_player = player
	_update_animation_list()


func show_status(text: String) -> void:
	_status_label.text = text
	_status_label.remove_theme_color_override("font_color")


func show_key_inserted_feedback(node_name: String, property: String, time: float) -> void:
	_status_label.text = "Key: %s.%s @ %.2fs" % [node_name, property, time]
	_status_label.add_theme_color_override("font_color", Color.GREEN)
	_feedback_timer.start(2.0)


func _clear_feedback() -> void:
	_status_label.remove_theme_color_override("font_color")
	_status_label.text = "Ready - use [A] buttons on tracks"
