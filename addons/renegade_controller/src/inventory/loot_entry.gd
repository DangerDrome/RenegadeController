## Single entry in a loot table — item + weight + quantity range.
class_name LootEntry extends Resource

@export var item: ItemDefinition
@export_range(0.0, 100.0) var weight: float = 10.0
@export var min_quantity: int = 1
@export var max_quantity: int = 1
