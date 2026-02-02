@tool
extends EditorPlugin


func _enter_tree() -> void:
	var icon: Texture2D = null
	if FileAccess.file_exists("res://addons/sky_weather/icon.svg"):
		icon = load("res://addons/sky_weather/icon.svg")
	add_custom_type("SkyWeather", "Node3D", preload("sky_weather.gd"), icon)


func _exit_tree() -> void:
	remove_custom_type("SkyWeather")
