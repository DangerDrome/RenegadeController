## Spawns WorldPickup nodes from a LootTable when drop_loot() is called.
## Attach as a child of an NPC's RenegadeCharacter.
class_name LootDropper extends Node

@export_group("Configuration")
@export var loot_table: LootTable
@export var drop_force: float = 3.0
@export var scatter_radius: float = 1.0

## The scene to instantiate for each drop.
## Must have a WorldPickup as root (or a compatible script).
## If null, a default WorldPickup with a CollisionShape3D is created.
@export var pickup_scene: PackedScene


## Roll the loot table and spawn pickups scattered around the given position.
func drop_loot(death_position: Vector3) -> void:
	if not loot_table:
		return

	var drops := loot_table.roll()
	for drop in drops:
		var item := drop["item"] as ItemDefinition
		var qty := drop["quantity"] as int
		if not item:
			continue
		_spawn_pickup(item, qty, death_position)


func _spawn_pickup(item: ItemDefinition, qty: int, origin: Vector3) -> void:
	var pickup: WorldPickup

	if pickup_scene:
		pickup = pickup_scene.instantiate() as WorldPickup
	else:
		pickup = _create_default_pickup()

	pickup.item = item
	pickup.quantity = qty

	# Scatter the drop position.
	var offset := Vector3(
		randf_range(-scatter_radius, scatter_radius),
		0.5,
		randf_range(-scatter_radius, scatter_radius),
	)
	pickup.global_position = origin + offset

	# Add to the current scene (not as child of the dying NPC).
	var scene_root := get_tree().current_scene
	if scene_root:
		scene_root.add_child.call_deferred(pickup)


func _create_default_pickup() -> WorldPickup:
	var pickup := WorldPickup.new()

	# Add a collision shape so the cursor can detect it.
	var col := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.4
	col.shape = shape
	pickup.add_child(col)

	return pickup
