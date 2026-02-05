extends Control
class_name HUDDataBar
## Base class for data-bound progress bars (health, stamina, etc.).
## Subclasses can override the warning threshold.

@export var data: HUDData
## Threshold (0-1) below which the bar plays a warning animation.
@export_range(0.0, 1.0) var warning_threshold: float = 0.25

@onready var bar := $TextureProgressBar
@onready var anim := $AnimationPlayer


func _ready() -> void:
	if data:
		data.changed.connect(_update)
		_update()


func _update() -> void:
	if not is_inside_tree():
		return

	var ratio := data.value / data.max_value if data.max_value > 0 else 0.0
	var target := ratio * 100.0
	var tween := create_tween()
	tween.tween_property(bar, "value", target, 0.15)

	# Warning animation when below threshold
	if ratio < warning_threshold and warning_threshold > 0.0:
		if not anim.is_playing() or anim.current_animation != "pulse":
			anim.play("pulse")
	else:
		if anim.is_playing() and anim.current_animation == "pulse":
			anim.stop()
