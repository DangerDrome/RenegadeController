extends Control
## Stamina bar component - binds to HUDData resource.

@export var data: HUDData

@onready var bar := $TextureProgressBar
@onready var anim := $AnimationPlayer


func _ready() -> void:
	if data:
		data.changed.connect(_update)
		_update()


func _update() -> void:
	if not is_inside_tree():
		return

	var target := (data.value / data.max_value) * 100.0
	var tween := create_tween()
	tween.tween_property(bar, "value", target, 0.15)

	# Low stamina warning
	if data.value / data.max_value < 0.2:
		if not anim.is_playing() or anim.current_animation != "pulse":
			anim.play("pulse")
	else:
		if anim.is_playing() and anim.current_animation == "pulse":
			anim.stop()
