## Persistent game settings resource.
## Covers graphics, audio, controls, and accessibility options.
## Saved to user://settings.tres.
@tool
class_name SettingsData extends Resource


#region Graphics
@export_group("Graphics")
## Window mode: 0=Windowed, 1=Borderless, 2=Fullscreen.
@export_enum("Windowed", "Borderless", "Fullscreen") var window_mode: int = 0

## VSync mode.
@export var vsync: bool = true

## Max FPS limit. 0 = unlimited.
@export_range(0, 240, 1) var max_fps: int = 0
#endregion


#region Audio
@export_group("Audio")
## Master bus volume (0.0 to 1.0).
@export_range(0.0, 1.0, 0.01) var master_volume: float = 1.0

## Music bus volume (0.0 to 1.0).
@export_range(0.0, 1.0, 0.01) var music_volume: float = 0.8

## SFX bus volume (0.0 to 1.0).
@export_range(0.0, 1.0, 0.01) var sfx_volume: float = 1.0

## Voice/dialogue bus volume (0.0 to 1.0).
@export_range(0.0, 1.0, 0.01) var voice_volume: float = 1.0

## Ambient bus volume (0.0 to 1.0).
@export_range(0.0, 1.0, 0.01) var ambient_volume: float = 0.7

## Mute audio when window loses focus.
@export var mute_on_unfocus: bool = true
#endregion


#region Controls
@export_group("Controls")
## Mouse/stick look sensitivity.
@export_range(0.01, 2.0, 0.01) var sensitivity: float = 0.5

## Invert Y-axis for camera look.
@export var invert_y: bool = false

## Custom input remappings. Keys are action names, values are serialized InputEvents.
@export var input_remaps: Dictionary = {}
#endregion


#region Accessibility
@export_group("Accessibility")
## Show subtitles during dialogue and cutscenes.
@export var subtitles: bool = true

## Scale factor for subtitle text.
@export_range(0.5, 3.0, 0.1) var subtitle_scale: float = 1.0

## Screen shake intensity multiplier. 0 = disabled.
@export_range(0.0, 2.0, 0.1) var screen_shake: float = 1.0
#endregion
