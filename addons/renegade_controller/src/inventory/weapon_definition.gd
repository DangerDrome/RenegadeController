@tool
## Weapon item definition with combat stats and animation references.
class_name WeaponDefinition extends ItemDefinition

enum FireMode { SEMI_AUTO, FULL_AUTO, BURST }

@export_group("Combat Stats")
@export var damage: float = 10.0
@export var fire_rate: float = 0.15
@export var magazine_size: int = 12
@export var reload_time: float = 1.5
@export var effective_range: float = 50.0

@export_group("Animation")
@export var animation_set: StringName = &"pistol"
@export var weapon_scene: PackedScene

@export_group("Behavior")
@export var fire_mode: FireMode = FireMode.SEMI_AUTO
@export var projectile_scene: PackedScene


func _init() -> void:
	item_type = ItemType.WEAPON
	max_stack_size = 1
