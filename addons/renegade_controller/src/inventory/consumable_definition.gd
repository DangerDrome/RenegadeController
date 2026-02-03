@tool
## Consumable item definition — heals, buffs, etc.
class_name ConsumableDefinition extends ItemDefinition

@export_group("Effects")
@export var heal_amount: int = 0
@export var stamina_restore: int = 0
@export var effect_duration: float = 0.0
@export var effect_id: StringName


func _init() -> void:
	item_type = ItemType.CONSUMABLE
	max_stack_size = 10
