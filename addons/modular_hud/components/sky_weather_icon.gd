extends Control
## Weather icon display - shows current weather icon from SkyWeather.
## Shows a default icon if no weather preset or icon set.

@onready var texture_rect: TextureRect = $TextureRect

var _sky_weather: Node

# Default icon to show when no weather icon is set
var _default_icon: Texture2D


func _ready() -> void:
	# Try to load a default icon
	if FileAccess.file_exists("res://addons/sky_weather/icons/wbSunny.png"):
		_default_icon = load("res://addons/sky_weather/icons/wbSunny.png")

	visible = false
	await get_tree().process_frame
	_find_sky_weather()


func _find_sky_weather() -> void:
	_sky_weather = _find_node_by_class(get_tree().root, "SkyWeather")
	if not _sky_weather:
		return

	visible = true

	if _sky_weather.has_signal("weather_changed"):
		_sky_weather.weather_changed.connect(_on_weather_changed)

	# Initial update
	_update_display()


func _find_node_by_class(node: Node, class_name_str: String) -> Node:
	var script := node.get_script() as Script
	if script and script.get_global_name() == class_name_str:
		return node
	for child in node.get_children():
		var result := _find_node_by_class(child, class_name_str)
		if result:
			return result
	return null


func _on_weather_changed(_preset: Resource) -> void:
	_update_display()


func _update_display() -> void:
	if not is_inside_tree() or not texture_rect or not _sky_weather:
		return

	var icon: Texture2D = null

	# Try to get icon from weather preset
	if _sky_weather.has_method("get_weather_icon"):
		icon = _sky_weather.get_weather_icon()
	elif "weather" in _sky_weather and _sky_weather.weather and "icon" in _sky_weather.weather:
		icon = _sky_weather.weather.icon

	# Use default if no icon found
	if not icon:
		icon = _default_icon

	if icon:
		texture_rect.texture = icon
		visible = true
	else:
		visible = false
