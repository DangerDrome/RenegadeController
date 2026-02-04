extends Control
## Time and weather display - connects to HUDEvents signals from SkyWeather.

@export var show_time: bool = true
@export var show_period: bool = true
@export var show_weather: bool = true

@onready var time_label: Label = $Panel/VBox/TimeLabel
@onready var period_label: Label = $Panel/VBox/PeriodLabel
@onready var weather_label: Label = $Panel/VBox/WeatherLabel

var _current_time: float = 12.0
var _current_period: String = "Day"
var _current_weather: String = "Clear"


func _ready() -> void:
	# Hide by default until we confirm SkyWeather exists
	visible = false

	# Connect to HUDEvents if available
	var hud_events := get_node_or_null("/root/HUDEvents")
	if hud_events:
		if hud_events.has_signal("time_changed"):
			hud_events.time_changed.connect(_on_time_changed)
			visible = true
		if hud_events.has_signal("weather_changed"):
			hud_events.weather_changed.connect(_on_weather_changed)

	# Also try to find SkyWeather directly and connect
	await get_tree().process_frame
	_find_and_connect_sky_weather()


func _find_and_connect_sky_weather() -> void:
	# Search for SkyWeather node in the scene
	var sky := _find_node_by_class(get_tree().root, "SkyWeather")
	if not sky:
		return

	# Found SkyWeather - show the widget
	visible = true

	# Safely connect to signals if they exist
	if sky.has_signal("time_changed") and not sky.time_changed.is_connected(_on_sky_time_changed):
		sky.time_changed.connect(_on_sky_time_changed)
	if sky.has_signal("period_changed") and not sky.period_changed.is_connected(_on_sky_period_changed):
		sky.period_changed.connect(_on_sky_period_changed)
	if sky.has_signal("weather_changed") and not sky.weather_changed.is_connected(_on_sky_weather_changed):
		sky.weather_changed.connect(_on_sky_weather_changed)

	# Get initial values if methods exist
	if sky.has_method("get_period"):
		_current_time = sky.time
		_current_period = sky.get_period().capitalize()
	if sky.has_method("get_weather_name"):
		_current_weather = sky.get_weather_name()

	_update_display()


func _find_node_by_class(node: Node, class_name_str: String) -> Node:
	# Check by script class name (works even if SkyWeather plugin is disabled)
	var script := node.get_script() as Script
	if script and script.get_global_name() == class_name_str:
		return node
	# Recurse into children
	for child in node.get_children():
		var result := _find_node_by_class(child, class_name_str)
		if result:
			return result
	return null


func _on_time_changed(hour: float, period: String) -> void:
	_current_time = hour
	_current_period = period.capitalize()
	_update_display()


func _on_weather_changed(weather_name: String) -> void:
	_current_weather = weather_name
	_update_display()


func _on_sky_time_changed(hour: float) -> void:
	_current_time = hour
	_update_display()


func _on_sky_period_changed(period: String) -> void:
	_current_period = period.capitalize()
	_update_display()


func _on_sky_weather_changed(preset: Resource) -> void:
	_current_weather = preset.name if preset else "Clear"
	_update_display()


func _update_display() -> void:
	if not is_inside_tree():
		return

	if time_label:
		var hour := int(_current_time)
		var minute := int((_current_time - hour) * 60)
		time_label.text = "%02d:%02d" % [hour, minute]
		time_label.visible = show_time

	if period_label:
		period_label.text = _current_period
		period_label.visible = show_period

	if weather_label:
		weather_label.text = _current_weather
		weather_label.visible = show_weather
