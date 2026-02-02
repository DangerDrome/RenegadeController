## Loot table — defines what items an NPC or container can drop.
## Use guaranteed_drops for items that always drop, entries for random rolls.
class_name LootTable extends Resource

@export var entries: Array[LootEntry] = []
@export var guaranteed_drops: Array[ItemDefinition] = []
@export var roll_count: int = 2


## Roll the loot table and return a list of {item, quantity} dictionaries.
func roll() -> Array[Dictionary]:
	var drops: Array[Dictionary] = []

	for item in guaranteed_drops:
		drops.append({"item": item, "quantity": 1})

	if entries.is_empty():
		return drops

	var total_weight := 0.0
	for entry in entries:
		total_weight += entry.weight

	if total_weight <= 0.0:
		return drops

	for _i in roll_count:
		var roll_value := randf() * total_weight
		var cumulative := 0.0
		for entry in entries:
			cumulative += entry.weight
			if roll_value <= cumulative:
				var qty := randi_range(entry.min_quantity, entry.max_quantity)
				drops.append({"item": entry.item, "quantity": qty})
				break

	return drops
