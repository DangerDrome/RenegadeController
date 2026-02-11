class_name WeatherPreset
extends Resource
## Weather configuration preset for Chronos.

## Display name
@export var name: String = "Clear"

## Icon texture for HUD display
@export var icon: Texture2D

## Sky color tint (multiplied with base sky colors)
@export var sky_tint: Color = Color.WHITE

## Cloud coverage 0-1 (affects sky ground color)
@export_range(0, 1) var clouds: float = 0.0

## Fog density (0 = no fog)
@export_range(0, 0.1, 0.001) var fog_density: float = 0.0

## Fog color
@export var fog_color: Color = Color(0.7, 0.7, 0.75)

## Sun energy multiplier
@export_range(0, 2) var sun_intensity: float = 1.0

## Optional precipitation particles scene
@export var precipitation: PackedScene
