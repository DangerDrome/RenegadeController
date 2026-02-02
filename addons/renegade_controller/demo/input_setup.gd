class_name InputSetup

static func ensure_actions() -> void:
	_add_key("move_forward", KEY_W)
	_add_key("move_back", KEY_S)
	_add_key("move_left", KEY_A)
	_add_key("move_right", KEY_D)
	_add_key("sprint", KEY_SHIFT)
	_add_key("jump", KEY_SPACE)
	_add_key("toggle_debug", KEY_F3)
	_add_mouse_button("interact", MOUSE_BUTTON_LEFT)
	_add_mouse_button("aim", MOUSE_BUTTON_RIGHT)

static func _add_key(action: String, keycode: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for event in InputMap.action_get_events(action):
		if event is InputEventKey and event.keycode == keycode:
			return
	var ev := InputEventKey.new()
	ev.keycode = keycode
	InputMap.action_add_event(action, ev)

static func _add_mouse_button(action: String, button: MouseButton) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for event in InputMap.action_get_events(action):
		if event is InputEventMouseButton and event.button_index == button:
			return
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	InputMap.action_add_event(action, ev)
