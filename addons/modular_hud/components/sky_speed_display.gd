extends Control
## Time speed slider - controls time_scale on SkyWeather.
## Hides if no SkyWeather found.
## Range: -100 (reverse x100) to 0 (paused) to +100 (forward x100)

@onready var slider: HSlider = $VBox/Slider
@onready var label: Label = $VBox/Label

var _sky_weather: Node
var _updating := false


func _ready() -> void:
	visible = false
	await get_tree().process_frame
	_find_sky_weather()


func _find_sky_weather() -> void:
	_sky_weather = _find_node_by_class(get_tree().root, "SkyWeather")
	if not _sky_weather:
		return

	visible = true

	# Set slider to match current time_scale
	if "time_scale" in _sky_weather:
		_updating = true
		slider.value = _sky_weather.time_scale
		_updating = false

	_update_label()


func _find_node_by_class(node: Node, class_name_str: String) -> Node:
	var script := node.get_script() as Script
	if script and script.get_global_name() == class_name_str:
		return node
	for child in node.get_children():
		var result := _find_node_by_class(child, class_name_str)
		if result:
			return result
	return null


func _on_slider_value_changed(value: float) -> void:
	if _updating or not _sky_weather:
		return

	var scale := int(value)
	# Skip 0 - snap to 1 or -1
	if scale == 0:
		scale = 1 if slider.value >= 0 else -1
		_updating = true
		slider.value = scale
		_updating = false

	_sky_weather.time_scale = scale
	_update_label()


func _update_label() -> void:
	if not is_inside_tree() or not label:
		return

	var scale := int(slider.value)
	if scale == 0:
		scale = 1

	if scale >= 1:
		label.text = "x%d" % scale
	else:
		label.text = "%d" % scale
