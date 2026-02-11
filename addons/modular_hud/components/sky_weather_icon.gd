extends Control
## Weather icon display - shows current weather icon from Chronos.
## Shows a default icon if no weather preset or icon set.

## Optional fallback icon to show when no weather icon is set.
## If not set, will try to find a default from the Chronos plugin.
@export var fallback_icon: Texture2D

@onready var texture_rect: TextureRect = $TextureRect

var _sky_weather: Node

# Internal: resolved default icon
var _default_icon: Texture2D


func _ready() -> void:
	# Use exported fallback icon if set, otherwise try to find one from Chronos
	if fallback_icon:
		_default_icon = fallback_icon
	else:
		# Try known locations for a default sunny weather icon
		var icon_paths: Array[String] = [
			"res://addons/chronos/icons/wbSunny.png",
			"res://addons/sky_weather/icons/wbSunny.png",  # Legacy fallback
		]
		for path in icon_paths:
			if FileAccess.file_exists(path):
				_default_icon = load(path)
				break

	visible = false
	await get_tree().process_frame
	_find_sky_weather()


func _find_sky_weather() -> void:
	_sky_weather = HUDEvents.find_node_by_class(get_tree().root, "Chronos")
	if not _sky_weather:
		return

	visible = true

	if _sky_weather.has_signal("weather_changed"):
		_sky_weather.weather_changed.connect(_on_weather_changed)

	# Initial update
	_update_display()


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
