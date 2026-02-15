@tool
extends EditorPlugin


func _enter_tree() -> void:
	# Core visuals node
	add_custom_type(
		"CharacterVisuals",
		"Node3D",
		preload("nodes/character_visuals.gd"),
		preload("icons/character_visuals.svg")
	)
	# Components
	add_custom_type(
		"LocomotionComponent",
		"Node",
		preload("nodes/locomotion_component.gd"),
		preload("icons/locomotion.svg")
	)
	add_custom_type(
		"FootIKComponent",
		"Node",
		preload("nodes/foot_ik_component.gd"),
		preload("icons/foot_ik.svg")
	)
	add_custom_type(
		"HandIKComponent",
		"Node",
		preload("nodes/hand_ik_component.gd"),
		preload("icons/hand_ik.svg")
	)
	add_custom_type(
		"HitReactionComponent",
		"Node",
		preload("nodes/hit_reaction_component.gd"),
		preload("icons/hit_reaction.svg")
	)
	add_custom_type(
		"ProceduralLeanComponent",
		"Node",
		preload("nodes/procedural_lean_component.gd"),
		preload("icons/lean.svg")
	)
	add_custom_type(
		"HitReactorComponent",
		"Node",
		preload("nodes/hit_reactor_component.gd"),
		preload("icons/hit_reaction.svg")
	)
	add_custom_type(
		"WallHandPlacement",
		"Node",
		preload("nodes/wall_hand_placement.gd"),
		preload("icons/hand_ik.svg")
	)
	add_custom_type(
		"StrideWheelComponent",
		"Node",
		preload("nodes/stride_wheel_component.gd"),
		preload("icons/locomotion.svg")
	)
	add_custom_type(
		"ItemSlots",
		"Node3D",
		preload("nodes/item_slots.gd"),
		null
	)


func _exit_tree() -> void:
	remove_custom_type("CharacterVisuals")
	remove_custom_type("LocomotionComponent")
	remove_custom_type("FootIKComponent")
	remove_custom_type("HandIKComponent")
	remove_custom_type("HitReactionComponent")
	remove_custom_type("ProceduralLeanComponent")
	remove_custom_type("HitReactorComponent")
	remove_custom_type("WallHandPlacement")
	remove_custom_type("StrideWheelComponent")
	remove_custom_type("ItemSlots")
