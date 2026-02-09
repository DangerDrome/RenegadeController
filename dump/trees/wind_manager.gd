extends Node
## Manages global wind parameters for tree shaders.
## Registered as WindManager autoload in Project Settings.

@export_group("Wind Size")
## How the wind sin/cos frequencies are scaled for each timer component.
## x: global wind scale, y: trunk sway scale, z: branch scale, w: leaf flutter scale
@export var wind_size: Vector4 = Vector4(5000.0, 1500.0, 500.0, 5.0)

@export_group("Wind Power")
## Wind strength multipliers.
## x: trunk sway, y: branch movement, z: leaf flutter
@export var wind_power: Vector3 = Vector3(5.0, 3.0, 0.125)

@export_group("Presets")
## Apply a wind preset
@export_enum("Custom", "Calm", "Light Breeze", "Moderate", "Strong", "Storm") var preset: int = 2:
	set(v):
		preset = v
		_apply_preset(v)


func _ready() -> void:
	_update_global_uniforms()


func _apply_preset(p: int) -> void:
	match p:
		0:  # Custom - don't change values
			pass
		1:  # Calm
			wind_size = Vector4(8000.0, 2000.0, 800.0, 8.0)
			wind_power = Vector3(1.0, 0.5, 0.03)
		2:  # Light Breeze
			wind_size = Vector4(5000.0, 1500.0, 500.0, 5.0)
			wind_power = Vector3(3.0, 1.5, 0.08)
		3:  # Moderate
			wind_size = Vector4(5000.0, 1500.0, 500.0, 5.0)
			wind_power = Vector3(5.0, 3.0, 0.125)
		4:  # Strong
			wind_size = Vector4(4000.0, 1200.0, 400.0, 4.0)
			wind_power = Vector3(8.0, 5.0, 0.2)
		5:  # Storm
			wind_size = Vector4(3000.0, 1000.0, 300.0, 3.0)
			wind_power = Vector3(15.0, 10.0, 0.4)
	_update_global_uniforms()


func _update_global_uniforms() -> void:
	RenderingServer.global_shader_parameter_set(&"tree_wind_size", wind_size)
	RenderingServer.global_shader_parameter_set(&"tree_wind_power", wind_power)


## Call this when changing wind parameters at runtime
func set_wind(size: Vector4, power: Vector3) -> void:
	wind_size = size
	wind_power = power
	preset = 0  # Custom
	_update_global_uniforms()


## Smoothly transition wind over time
func transition_wind(target_size: Vector4, target_power: Vector3, duration: float) -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "wind_size", target_size, duration)
	tween.tween_property(self, "wind_power", target_power, duration)
	tween.tween_callback(_update_global_uniforms).set_delay(0.05)


func _process(_delta: float) -> void:
	# Update uniforms every frame during transitions
	if is_inside_tree():
		_update_global_uniforms()
