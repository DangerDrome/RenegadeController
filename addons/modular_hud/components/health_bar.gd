extends HUDDataBar
## Health bar component - binds to HUDData resource.
## Default warning threshold at 25% health.

func _ready() -> void:
	warning_threshold = 0.25
	super._ready()
