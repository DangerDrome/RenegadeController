## Visual transition effect configuration.
## Defines how screen transitions look: fade, wipe, squeeze, or iris.
## Create .tres files for different transition styles.
@tool
class_name TransitionEffect extends Resource


enum EffectType {
	FADE,
	WIPE,
	SQUEEZE,
	IRIS,
}

#region Effect Settings
@export_group("Effect")
## The type of transition effect.
@export var effect_type: EffectType = EffectType.FADE

## Duration of the transition in seconds.
@export_range(0.05, 5.0, 0.05) var duration: float = 0.5

## Color used for the transition (e.g., fade to black).
@export var color: Color = Color.BLACK

## Optional curve for easing the transition.
@export var curve: Curve

## How long to hold at full coverage before reversing (seconds).
@export_range(0.0, 10.0, 0.05) var hold_duration: float = 0.0
#endregion
