@tool
## Gear/armor item definition — equippable to body slots.
class_name GearDefinition extends ItemDefinition

@export_group("Defense")
@export var armor_value: float = 0.0
@export var damage_reduction: float = 0.0

@export_group("Bonuses")
@export var speed_modifier: float = 0.0
@export var stealth_modifier: float = 0.0


func _init() -> void:
	item_type = ItemType.GEAR
	max_stack_size = 1
