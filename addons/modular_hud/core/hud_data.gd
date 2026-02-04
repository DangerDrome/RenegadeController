class_name HUDData extends Resource
## Reactive data binding for HUD components.
## Game systems write to value, HUD reacts via changed signal.

@export var value := 0.0:
	set(v):
		if value != v:
			value = v
			emit_changed()

@export var max_value := 100.0
