extends Control
## Day display - shows current day of the week from Chronos.
## Hides if no Chronos found.

const DAYS := ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
const DAYS_SHORT := ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

@export var use_short_names: bool = false

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

	if _sky_weather.has_signal("day_changed"):
		_sky_weather.day_changed.connect(_on_day_changed)

	# Initial update
	if "day_count" in _sky_weather:
		_update_display(_sky_weather.day_count)


func _on_day_changed(day: int) -> void:
	_update_display(day)


func _update_display(day: int) -> void:
	if not is_inside_tree() or not label:
		return

	# Day 1 = Monday, Day 7 = Sunday, then cycles
	# Use posmod to handle negative days correctly
	var day_index := posmod(day - 1, 7)

	if use_short_names:
		label.text = DAYS_SHORT[day_index]
	else:
		label.text = DAYS[day_index]
