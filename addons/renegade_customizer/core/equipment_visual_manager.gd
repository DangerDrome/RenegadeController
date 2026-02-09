## Manages visual representation of equipped items on a character's skeleton.
## Listens to an external EquipmentManager (from renegade_controller) via signals
## and applies mesh swaps or bone attachments accordingly.
##
## Supports two strategies:
## - MESH_SWAP: swaps the .mesh property on body group MeshInstance3D nodes
## - BONE_ATTACH: instances equipment scenes on BoneAttachment3D mount points
class_name EquipmentVisualManager
extends Node

## Emitted after a visual change has been applied to the skeleton.
signal visual_updated(slot_name: StringName)

@export_group("References")
## The Skeleton3D node to apply visuals to. All slot configs reference paths from here.
@export var skeleton: Skeleton3D

@export_group("Slot Configuration")
## Array of slot visual configs mapping equipment slots to skeleton nodes.
@export var slot_configs: Array[EquipmentSlotVisualConfig] = []

## Tracks currently attached scenes for BONE_ATTACH slots so we can clean up.
var _attached_instances: Dictionary = {}  # StringName → Node3D


func _ready() -> void:
	if not skeleton:
		push_warning("EquipmentVisualManager: No skeleton assigned.")


## Connect to an external EquipmentManager's signals.
## Call this from your game scene setup — keeps the two plugins decoupled.
func connect_to_equipment_manager(manager: Node) -> void:
	if manager.has_signal("item_equipped"):
		manager.item_equipped.connect(_on_item_equipped)
	else:
		push_warning("EquipmentVisualManager: Manager missing 'item_equipped' signal.")

	if manager.has_signal("item_unequipped"):
		manager.item_unequipped.connect(_on_item_unequipped)
	else:
		push_warning("EquipmentVisualManager: Manager missing 'item_unequipped' signal.")


## Apply equipment visuals for a slot. Pass null item to clear.
func apply_equipment(slot_name: StringName, item: Resource) -> void:
	if not skeleton:
		return

	var config := _find_config(slot_name)
	if not config:
		return

	match config.strategy:
		EquipmentSlotVisualConfig.Strategy.MESH_SWAP:
			_apply_mesh_swap(config, item)
		EquipmentSlotVisualConfig.Strategy.BONE_ATTACH:
			_apply_bone_attach(config, slot_name, item)

	visual_updated.emit(slot_name)


## Clear all equipment visuals back to defaults.
func clear_all() -> void:
	for config in slot_configs:
		apply_equipment(config.slot_name, null)


## Refresh all visuals from a dictionary of currently equipped items.
## Useful when opening the customizer to sync turntable preview with game state.
func sync_from_equipment(equipped: Dictionary) -> void:
	for config in slot_configs:
		var item: Resource = equipped.get(config.slot_name, null)
		apply_equipment(config.slot_name, item)


# -- Private ----------------------------------------------------------------

func _apply_mesh_swap(config: EquipmentSlotVisualConfig, item: Resource) -> void:
	var mesh_node := skeleton.get_node_or_null(config.node_path) as MeshInstance3D
	if not mesh_node:
		push_warning("EquipmentVisualManager: MeshInstance3D not found at '%s'." % config.node_path)
		return

	if item and item.get("equipment_mesh"):
		mesh_node.mesh = item.equipment_mesh
	else:
		mesh_node.mesh = config.default_mesh


func _apply_bone_attach(
	config: EquipmentSlotVisualConfig,
	slot_name: StringName,
	item: Resource
) -> void:
	var mount := skeleton.get_node_or_null(config.node_path) as Node3D
	if not mount:
		push_warning("EquipmentVisualManager: Mount point not found at '%s'." % config.node_path)
		return

	# Clean up previous attachment.
	if _attached_instances.has(slot_name):
		var old: Node3D = _attached_instances[slot_name]
		if is_instance_valid(old):
			old.queue_free()
		_attached_instances.erase(slot_name)

	# Attach new equipment scene if provided.
	if item and item.get("equipment_scene") and item.equipment_scene:
		var instance: Node3D = item.equipment_scene.instantiate()
		mount.add_child(instance)
		if item.get("mount_offset"):
			instance.transform = item.mount_offset
		_attached_instances[slot_name] = instance


func _find_config(slot_name: StringName) -> EquipmentSlotVisualConfig:
	for config in slot_configs:
		if config.slot_name == slot_name:
			return config
	return null


func _on_item_equipped(slot_name: StringName, item: Resource) -> void:
	apply_equipment(slot_name, item)


func _on_item_unequipped(slot_name: StringName, _item: Resource) -> void:
	apply_equipment(slot_name, null)
