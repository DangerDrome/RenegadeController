## Configuration for a single splash screen.
## Used by SplashSequence to display boot logos, publisher screens, etc.
@tool
class_name SplashEntry extends Resource


#region Display Settings
@export_group("Display")
## The image to show for this splash screen.
@export var texture: Texture2D

## Background color behind the texture.
@export var background_color: Color = Color.BLACK

## How long the splash is fully visible (seconds).
@export_range(0.1, 10.0, 0.1) var display_duration: float = 2.0
#endregion


#region Fade Settings
@export_group("Fade")
## Duration of the fade-in (seconds).
@export_range(0.0, 3.0, 0.05) var fade_in_duration: float = 0.5

## Duration of the fade-out (seconds).
@export_range(0.0, 3.0, 0.05) var fade_out_duration: float = 0.5
#endregion
