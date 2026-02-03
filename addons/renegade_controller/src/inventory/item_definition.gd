@tool
## Base item definition. All items in the game extend this resource.
## Create .tres files from this (or subclasses) and edit in the inspector.
class_name ItemDefinition extends Resource

enum ItemType { WEAPON, GEAR, CONSUMABLE, KEY_ITEM }

@export_group("Identity")
@export var id: StringName
@export var display_name: String
@export_multiline var description: String
@export var icon: Texture2D

@export_group("Stacking")
@export var max_stack_size: int = 1
@export var is_unique: bool = false

@export_group("Classification")
@export var item_type: ItemType
@export var slot_restrictions: Array[StringName] = []

@export_group("World Representation")
@export var pickup_scene: PackedScene
@export var world_mesh: Mesh


## Returns a display color based on item type for UI/visual highlighting.
func get_display_color() -> Color:
	match item_type:
		ItemType.WEAPON:
			return Color(0.9, 0.5, 0.2)  # Orange
		ItemType.GEAR:
			return Color(0.3, 0.7, 0.9)  # Cyan
		ItemType.CONSUMABLE:
			return Color(0.2, 0.8, 0.3)  # Green
		ItemType.KEY_ITEM:
			return Color(0.9, 0.9, 0.2)  # Yellow
	return Color(0.5, 0.5, 0.5)  # Gray default


## Returns a gray color for null/invalid items.
static func get_default_color() -> Color:
	return Color(0.5, 0.5, 0.5)
