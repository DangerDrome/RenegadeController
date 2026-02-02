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
