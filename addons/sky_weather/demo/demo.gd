extends Control
## Demo UI for testing SkyWeather

@onready var sky: SkyWeather = $"../SkyWeather"
@onready var time_slider: HSlider = $Panel/VBox/TimeSlider
@onready var time_label: Label = $Panel/VBox/TimeLabel
@onready var period_label: Label = $Panel/VBox/PeriodLabel
@onready var weather_label: Label = $Panel/VBox/WeatherLabel

# Load presets once
var _clear: WeatherPreset = preload("res://addons/sky_weather/presets/clear.tres")
var _overcast: WeatherPreset = preload("res://addons/sky_weather/presets/overcast.tres")
var _foggy: WeatherPreset = preload("res://addons/sky_weather/presets/foggy.tres")
var _rainy: WeatherPreset = preload("res://addons/sky_weather/presets/rainy.tres")


func _ready() -> void:
	time_slider.value = sky.time
	sky.time_changed.connect(_on_time_changed)
	sky.period_changed.connect(_on_period_changed)
	sky.weather_changed.connect(_on_weather_changed)
	_update_labels()


func _on_time_changed(_hour: float) -> void:
	_update_labels()


func _on_period_changed(period: String) -> void:
	period_label.text = period.capitalize()


func _on_weather_changed(preset: WeatherPreset) -> void:
	weather_label.text = "Weather: " + (preset.name if preset else "Clear")


func _update_labels() -> void:
	time_label.text = sky.get_time_string()
	period_label.text = sky.get_period().capitalize()
	weather_label.text = "Weather: " + sky.get_weather_name()


func _on_time_slider_value_changed(value: float) -> void:
	sky.time = value


func _on_clear_pressed() -> void:
	print("Setting weather: Clear")
	sky.weather = _clear


func _on_overcast_pressed() -> void:
	print("Setting weather: Overcast")
	sky.weather = _overcast


func _on_foggy_pressed() -> void:
	print("Setting weather: Foggy")
	sky.weather = _foggy


func _on_rainy_pressed() -> void:
	print("Setting weather: Rainy")
	sky.weather = _rainy
