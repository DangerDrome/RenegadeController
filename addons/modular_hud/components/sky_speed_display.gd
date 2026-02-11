extends Control
## Time speed slider - controls ENTIRE GAME speed.
## Sets Engine.time_scale for simulation AND Chronos.time_scale for day/night.
## Range: -10 (rewind) to +10 (fast forward). Rewind stops at session start.

@onready var slider: HSlider = $VBox/Slider
@onready var label: Label = $VBox/Label

var _sky_weather: Node
var _updating := false
var _at_session_start := false


func _ready() -> void:
	# Always visible - controls game speed even without Chronos
	visible = true
	await get_tree().process_frame
	_find_sky_weather()

	# Sync slider with current Engine.time_scale
	_updating = true
	slider.value = Engine.time_scale
	_updating = false
	_update_label()


func _process(_delta: float) -> void:
	# Check if we've hit session start while rewinding
	if Engine.time_scale < 0 and _sky_weather and _sky_weather.has_method("is_session_initialized"):
		if _sky_weather.is_session_initialized():
			var at_start: bool = _sky_weather.is_at_session_start()
			if at_start and not _at_session_start:
				_at_session_start = true
				# Stop rewinding - we've hit the start
				Engine.time_scale = 0
				_updating = true
				slider.value = 0
				_updating = false
				_update_label()
			elif not at_start:
				_at_session_start = false


func _find_sky_weather() -> void:
	_sky_weather = HUDEvents.find_node_by_class(get_tree().root, "Chronos")


func _on_slider_value_changed(value: float) -> void:
	if _updating:
		return

	var scale := value

	# Engine.time_scale only supports positive values (0 = pause, 1+ = speed)
	# Use absolute value for engine, but Chronos can go negative for rewind
	Engine.time_scale = absf(scale)

	# Chronos time_scale controls day/night direction (negative = rewind)
	if _sky_weather and "time_scale" in _sky_weather:
		if absf(scale) >= 1:
			_sky_weather.time_scale = int(scale)
		elif scale > 0:
			_sky_weather.time_scale = 1
		elif scale < 0:
			_sky_weather.time_scale = -1
		else:
			_sky_weather.time_scale = 0

	_update_label()


func _update_label() -> void:
	if not is_inside_tree() or not label:
		return

	var scale := slider.value
	if scale == 0:
		label.text = "PAUSED"
	elif scale < 0:
		# Negative = rewind
		if scale > -1:
			label.text = "◀ %.1f" % absf(scale)
		else:
			label.text = "◀ %d" % int(absf(scale))
	elif scale < 1:
		label.text = "▶ %.1f" % scale
	else:
		label.text = "▶ %d" % int(scale)
