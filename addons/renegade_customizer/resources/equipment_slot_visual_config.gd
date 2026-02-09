## Resource that maps an equipment slot to its visual representation on the skeleton.
## Configured per-character to define where equipment meshes appear.
class_name EquipmentSlotVisualConfig
extends Resource

enum Strategy {
	## Swap the .mesh property on an existing MeshInstance3D child of the skeleton.
	## Used for replacement items: jackets, pants, boots, helmets.
	MESH_SWAP,
	## Instance a PackedScene as a child of a BoneAttachment3D mount point.
	## Used for additive items: sunglasses, holsters, weapons, walkman.
	BONE_ATTACH,
}

@export_group("Slot Identity")
## Must match the slot name used by EquipmentManager (e.g., &"primary", &"head", &"torso").
@export var slot_name: StringName

@export_group("Visual Mapping")
## Which strategy to use when applying visuals for this slot.
@export var strategy: Strategy = Strategy.MESH_SWAP
## Path from Skeleton3D to the target node.
## For MESH_SWAP: path to the MeshInstance3D (e.g., "slot_torso").
## For BONE_ATTACH: path to the mount Node3D (e.g., "acc_head/mount").
@export var node_path: String
## The mesh to display when nothing is equipped (MESH_SWAP only).
@export var default_mesh: Mesh
