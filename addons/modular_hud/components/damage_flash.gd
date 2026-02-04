extends ColorRect
## Damage flash component - listens to HUDEvents.damage_taken.

func _ready() -> void:
	modulate.a = 0.0
	HUDEvents.damage_taken.connect(_on_damage)


func _on_damage(amount: float, _direction: Vector2) -> void:
	modulate.a = clamp(amount / 50.0, 0.2, 0.6)
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
