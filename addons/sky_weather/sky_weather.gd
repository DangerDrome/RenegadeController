@tool
class_name SkyWeather
extends Node3D
## Simple day/night cycle and weather system.
## Creates its own WorldEnvironment and DirectionalLight3D as children.

## Time of day in hours (0-24). Wraps automatically.
@export_range(0, 24, 0.01) var time: float = 12.0:
	set(v):
		var old_time := time
		# Check for day wrap before normalizing
		if v >= 24.0 and old_time < 24.0:
			day_count += 1
			day_changed.emit(day_count)
		elif v < 0.0 and old_time >= 0.0:
			day_count -= 1
			day_changed.emit(day_count)
		# Normalize to 0-24 range
		time = fmod(v, 24.0)
		if time < 0:
			time += 24.0
		_update_sky()
		time_changed.emit(time)
		var new_period := get_period()
		if new_period != _last_period:
			_last_period = new_period
			period_changed.emit(new_period)
			_emit_hud_time()

## Real minutes per full 24-hour day cycle. Set to 0 to pause time.
@export var day_duration_minutes: float = 24.0

## Time scale multiplier. Positive = forward, negative = backward.
## x1 = realtime (24 min/day), x2 = double speed, -1 = reverse realtime, etc.
## Note: 0 is not allowed, minimum is 1 or -1.
@export_range(-300, 300) var time_scale: int = 1:
	set(v):
		if v == 0:
			v = 1
		time_scale = v

## Current weather preset
@export var weather: WeatherPreset:
	set(v):
		if v != weather:
			# Capture current state for transition
			if weather:
				_weather_from = weather.duplicate()
			else:
				_weather_from = null
			_weather_t = 0.0
		weather = v
		_update_sky()
		weather_changed.emit(v)
		_emit_hud_weather()

## Transition duration when weather changes (seconds)
@export var weather_transition_time: float = 5.0

@export_group("Sun")
## Base sun energy at noon
@export var sun_energy: float = 1.0
## Sun color at noon
@export var sun_color: Color = Color(1.0, 0.95, 0.9)

@export_group("Sun Path")
## Compass rotation of sun path in degrees. 0 = sun rises in +X (east), sets in -X (west).
## Adjust to match your scene orientation.
@export_range(-180, 180) var sun_path_rotation: float = 0.0:
	set(v):
		sun_path_rotation = v
		_update_sky()

## Axial tilt / latitude effect in degrees. Controls sun's maximum height at noon.
## 0 = sun directly overhead at noon (equator at equinox)
## 23.5 = typical temperate latitude (sun reaches ~66.5° at noon)
## 45 = sun only reaches 45° above horizon at noon
## Negative values = southern hemisphere effect
@export_range(-90, 90) var axial_tilt: float = 23.5:
	set(v):
		axial_tilt = v
		_update_sky()

signal time_changed(hour: float)
signal period_changed(period: String)
signal weather_changed(preset: WeatherPreset)
signal day_changed(day: int)

## Current day count (increments at midnight)
var day_count: int = 1

# Sky color presets by time of day
const SKY_COLORS := {
	"night":  {"top": Color(0.005, 0.005, 0.02), "horizon": Color(0.02, 0.02, 0.05), "ground": Color(0.0, 0.0, 0.0), "energy": 0.1, "ambient": 0.02},
	"dawn":   {"top": Color(0.3, 0.4, 0.6), "horizon": Color(1.0, 0.6, 0.4), "ground": Color(0.3, 0.25, 0.2), "energy": 0.8, "ambient": 0.4},
	"day":    {"top": Color(0.3, 0.5, 0.9), "horizon": Color(0.7, 0.8, 0.95), "ground": Color(0.4, 0.35, 0.3), "energy": 1.0, "ambient": 1.0},
	"dusk":   {"top": Color(0.2, 0.25, 0.45), "horizon": Color(1.0, 0.45, 0.3), "ground": Color(0.25, 0.15, 0.1), "energy": 0.6, "ambient": 0.3},
}

var _sun: DirectionalLight3D
var _environment: WorldEnvironment
var _sky_material: ProceduralSkyMaterial
var _env: Environment
var _precipitation_instance: Node3D
var _last_period: String = ""
var _weather_from: WeatherPreset
var _weather_t: float = 1.0


func _ready() -> void:
	_setup_nodes()
	_update_sky()
	_register_npc_hooks()


func _register_npc_hooks() -> void:
	if Engine.is_editor_hint():
		return
	# Register conditions for NPCBrainHooks if available
	var hooks := get_node_or_null("/root/NPCBrainHooks")
	if not hooks:
		return

	hooks.register_condition(&"is_night", func() -> bool:
		return time >= 20.0 or time < 6.0)
	hooks.register_condition(&"is_day", func() -> bool:
		return time >= 7.0 and time < 18.0)
	hooks.register_condition(&"is_dawn", func() -> bool:
		return time >= 5.0 and time < 7.0)
	hooks.register_condition(&"is_dusk", func() -> bool:
		return time >= 18.0 and time < 20.0)
	hooks.register_condition(&"is_raining", func() -> bool:
		return weather and weather.precipitation != null)
	hooks.register_condition(&"is_cloudy", func() -> bool:
		return weather and weather.clouds > 0.5)
	hooks.register_condition(&"is_foggy", func() -> bool:
		return weather and weather.fog_density > 0.01)


func _process(delta: float) -> void:
	# Advance time based on time_scale
	if day_duration_minutes > 0 and not Engine.is_editor_hint():
		var base_speed := (delta / 60.0) * (24.0 / day_duration_minutes)
		time += base_speed * time_scale

	# Weather transition
	if _weather_t < 1.0:
		_weather_t = minf(_weather_t + delta / weather_transition_time, 1.0)
		_update_sky()


func _setup_nodes() -> void:
	# Find or create sun
	_sun = get_node_or_null("Sun") as DirectionalLight3D
	if not _sun:
		_sun = DirectionalLight3D.new()
		_sun.name = "Sun"
		_sun.shadow_enabled = true
		_sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
		add_child(_sun)
		if Engine.is_editor_hint():
			_sun.owner = get_tree().edited_scene_root

	# Find or create environment
	_environment = get_node_or_null("WorldEnvironment") as WorldEnvironment
	if not _environment:
		_environment = WorldEnvironment.new()
		_environment.name = "WorldEnvironment"

		_env = Environment.new()
		_env.background_mode = Environment.BG_SKY
		_env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
		_env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
		_env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
		_env.tonemap_exposure = 1.0
		_env.fog_enabled = true
		_env.fog_density = 0.0
		_env.fog_aerial_perspective = 0.5

		var sky := Sky.new()
		_sky_material = ProceduralSkyMaterial.new()
		_sky_material.sun_angle_max = 1.0
		sky.sky_material = _sky_material
		_env.sky = sky

		_environment.environment = _env
		add_child(_environment)
		if Engine.is_editor_hint():
			_environment.owner = get_tree().edited_scene_root
	else:
		_env = _environment.environment
		if _env and _env.sky:
			_sky_material = _env.sky.sky_material as ProceduralSkyMaterial


func _update_sky() -> void:
	if not _sun or not _sky_material or not _env:
		return

	# Sun position with proper east-west movement
	# Hour angle: linear progression through the day
	var hour_angle := (time / 24.0) * TAU  # 0 at midnight, PI at noon, TAU at next midnight

	# Elevation: sin wave peaking at noon
	# At midnight (0): below horizon, at 6am (PI/2): horizon, at noon (PI): max, at 6pm (3PI/2): horizon
	var elevation_factor := sin(hour_angle - PI / 2.0)  # Range -1 to 1

	# Max elevation based on axial tilt (90° - tilt = max sun height)
	var max_elevation := deg_to_rad(90.0 - absf(axial_tilt))
	var sun_elevation := elevation_factor * max_elevation  # Negative = below horizon

	# Azimuth: east at sunrise, south at noon, west at sunset
	# Maps time to Y rotation: 6am=-90°, 12pm=0°, 6pm=90°
	var sun_azimuth := (time - 12.0) / 12.0 * PI  # -PI to PI range

	# Apply sun rotation with path adjustment
	_sun.rotation.x = -sun_elevation  # Negative to look down when sun is high
	_sun.rotation.y = sun_azimuth + deg_to_rad(sun_path_rotation)
	_sun.rotation.z = 0.0

	# Sun intensity based on elevation (0 when below horizon)
	var day_factor := clampf(elevation_factor * 2.0 + 0.5, 0.0, 1.0)

	# Get blended sky colors (includes energy and ambient)
	var colors := _get_blended_sky_colors()
	var w := _get_effective_weather()
	var tint := w.sky_tint if w else Color.WHITE
	var weather_intensity := w.sun_intensity if w else 1.0
	var cloud_amt := w.clouds if w else 0.0

	# Apply sky colors with weather tint
	var top_color: Color = colors.top * tint
	var horizon_color: Color = colors.horizon * tint
	var ground_color: Color = colors.ground * tint

	# Cloud effect: blend toward overcast gray
	if cloud_amt > 0.0:
		var cloud_color := Color(0.45, 0.45, 0.5)
		top_color = top_color.lerp(cloud_color, cloud_amt * 0.7)
		horizon_color = horizon_color.lerp(cloud_color, cloud_amt * 0.8)
		ground_color = ground_color.lerp(cloud_color * 0.5, cloud_amt * 0.6)

	_sky_material.sky_top_color = top_color
	_sky_material.sky_horizon_color = horizon_color
	_sky_material.ground_bottom_color = ground_color
	_sky_material.ground_horizon_color = horizon_color * 0.7

	# Sky energy (controls overall brightness) - weather reduces it
	var sky_energy: float = colors.energy * weather_intensity
	_sky_material.sky_energy_multiplier = sky_energy

	# Ambient light - dramatically reduced at night and in bad weather
	var ambient_energy: float = colors.ambient * weather_intensity
	_env.ambient_light_energy = ambient_energy
	_env.ambient_light_color = horizon_color.lerp(Color.WHITE, 0.5)

	# Sun light
	_sun.light_energy = sun_energy * day_factor * weather_intensity
	_sun.light_color = sun_color.lerp(colors.horizon, 0.3)
	_sun.visible = day_factor > 0.01

	# Fog - enabled by weather or at night for atmosphere
	var base_fog := w.fog_density if w else 0.0
	_env.fog_enabled = base_fog > 0.0
	_env.fog_density = base_fog
	_env.fog_light_color = w.fog_color if w else Color(0.7, 0.7, 0.75)

	# Precipitation
	_update_precipitation(w)


func _get_blended_sky_colors() -> Dictionary:
	# Time periods: dawn 5-7, day 7-18, dusk 18-20, night 20-5
	var from_key: String
	var to_key: String
	var t: float

	if time >= 5.0 and time < 7.0:
		from_key = "night"; to_key = "dawn"; t = (time - 5.0) / 2.0
	elif time >= 7.0 and time < 18.0:
		from_key = "dawn"; to_key = "day"; t = clampf((time - 7.0) / 2.0, 0.0, 1.0)
	elif time >= 18.0 and time < 20.0:
		from_key = "day"; to_key = "dusk"; t = (time - 18.0) / 2.0
	elif time >= 20.0 and time < 22.0:
		from_key = "dusk"; to_key = "night"; t = (time - 20.0) / 2.0
	else:
		from_key = "night"; to_key = "night"; t = 0.0

	var from_colors: Dictionary = SKY_COLORS[from_key]
	var to_colors: Dictionary = SKY_COLORS[to_key]

	return {
		"top": from_colors.top.lerp(to_colors.top, t),
		"horizon": from_colors.horizon.lerp(to_colors.horizon, t),
		"ground": from_colors.ground.lerp(to_colors.ground, t),
		"energy": lerpf(from_colors.energy, to_colors.energy, t),
		"ambient": lerpf(from_colors.ambient, to_colors.ambient, t),
	}


func _get_effective_weather() -> WeatherPreset:
	# No transition needed
	if _weather_t >= 1.0 or not _weather_from or not weather:
		return weather

	# Interpolate between previous and current weather
	var result := WeatherPreset.new()
	var t := _weather_t

	result.sky_tint = _weather_from.sky_tint.lerp(weather.sky_tint, t)
	result.clouds = lerpf(_weather_from.clouds, weather.clouds, t)
	result.fog_density = lerpf(_weather_from.fog_density, weather.fog_density, t)
	result.fog_color = _weather_from.fog_color.lerp(weather.fog_color, t)
	result.sun_intensity = lerpf(_weather_from.sun_intensity, weather.sun_intensity, t)
	result.precipitation = weather.precipitation if t > 0.5 else _weather_from.precipitation
	return result


func _update_precipitation(w: WeatherPreset) -> void:
	var should_have: PackedScene = w.precipitation if w else null

	if should_have and not _precipitation_instance:
		_precipitation_instance = should_have.instantiate()
		add_child(_precipitation_instance)
	elif not should_have and _precipitation_instance:
		_precipitation_instance.queue_free()
		_precipitation_instance = null


## Returns the current time period: "dawn", "day", "dusk", or "night"
func get_period() -> String:
	if time >= 5.0 and time < 7.0:
		return "dawn"
	elif time >= 7.0 and time < 18.0:
		return "day"
	elif time >= 18.0 and time < 20.0:
		return "dusk"
	else:
		return "night"


## Returns true if currently daytime (dawn through dusk)
func is_daytime() -> bool:
	return time >= 5.0 and time < 20.0


## Set time without triggering transitions
func set_time(hour: float) -> void:
	time = hour


## Apply weather instantly without transition
func set_weather_instant(preset: WeatherPreset) -> void:
	_weather_t = 1.0
	weather = preset


## Get formatted time string (HH:MM)
func get_time_string() -> String:
	var hour := int(time)
	var minute := int((time - hour) * 60)
	return "%02d:%02d" % [hour, minute]


## Get weather name or "Clear" if none
func get_weather_name() -> String:
	return weather.name if weather else "Clear"


## Get the current weather icon texture
func get_weather_icon() -> Texture2D:
	return weather.icon if weather else null


## Get time speed multiplier (how many in-game hours per real minute)
func get_time_speed() -> float:
	if day_duration_minutes <= 0:
		return 0.0
	return 24.0 / day_duration_minutes


# HUD integration - emit to HUDEvents if available
func _emit_hud_time() -> void:
	if not is_inside_tree():
		return
	var hud_events := get_node_or_null("/root/HUDEvents")
	if hud_events and hud_events.has_signal("time_changed"):
		hud_events.emit_signal("time_changed", time, get_period())


func _emit_hud_weather() -> void:
	if not is_inside_tree():
		return
	var hud_events := get_node_or_null("/root/HUDEvents")
	if hud_events and hud_events.has_signal("weather_changed"):
		hud_events.emit_signal("weather_changed", get_weather_name())
