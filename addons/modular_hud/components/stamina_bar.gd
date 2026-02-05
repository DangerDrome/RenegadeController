extends HUDDataBar
## Stamina bar component - binds to HUDData resource.
## Default warning threshold at 20% stamina.

func _ready() -> void:
	warning_threshold = 0.2
	super._ready()
