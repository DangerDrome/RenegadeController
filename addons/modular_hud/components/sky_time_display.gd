extends Control
## Time display - shows current time from Chronos.
## Hides if no Chronos found.

@onready var label: Label = $Label

var _sky_weather: Node


func _ready() -> void:
	visible = false
	await get_tree().process_frame
	_find_sky_weather()


func _find_sky_weather() -> void:
	_sky_weather = HUDEvents.find_node_by_class(get_tree().root, "Chronos")
	if not _sky_weather:
		return

	visible = true

	if _sky_weather.has_signal("time_changed"):
		_sky_weather.time_changed.connect(_on_time_changed)

	# Initial update
	if "time" in _sky_weather:
		_update_display(_sky_weather.time)


func _on_time_changed(hour: float, _period: String) -> void:
	_update_display(hour)


func _update_display(hour: float) -> void:
	if not is_inside_tree() or not label:
		return

	var h := int(hour)
	var m := int((hour - h) * 60)
	label.text = "%02d:%02d" % [h, m]
