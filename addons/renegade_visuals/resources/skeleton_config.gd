## Maps bone names for the character skeleton.
## Swap this resource to support different skeletons without changing code.
class_name SkeletonConfig
extends Resource

@export_group("Root & Pelvis")
@export var root_bone: StringName = &"root"
@export var pelvis_bone: StringName = &"pelvis"

@export_group("Spine")
@export var spine_01: StringName = &"spine_01"
@export var spine_02: StringName = &"spine_02"
@export var spine_03: StringName = &"spine_03"

@export_group("Head")
@export var neck: StringName = &"neck_01"
@export var head: StringName = &"head"

@export_group("Left Leg")
@export var left_thigh: StringName = &"thigh_l"
@export var left_calf: StringName = &"calf_l"
@export var left_foot: StringName = &"foot_l"

@export_group("Right Leg")
@export var right_thigh: StringName = &"thigh_r"
@export var right_calf: StringName = &"calf_r"
@export var right_foot: StringName = &"foot_r"

@export_group("Left Arm")
@export var left_upperarm: StringName = &"upperarm_l"
@export var left_lowerarm: StringName = &"lowerarm_l"
@export var left_hand: StringName = &"hand_l"

@export_group("Right Arm")
@export var right_upperarm: StringName = &"upperarm_r"
@export var right_lowerarm: StringName = &"lowerarm_r"
@export var right_hand: StringName = &"hand_r"

@export_group("Upper Body Bones (for layering filter)")
## All bones that belong to the upper body for Blend2 bone filtering.
## Populated with UEFN mannequin defaults.
@export var upper_body_bones: PackedStringArray = PackedStringArray([
	"spine_02", "spine_03", "neck_01", "head",
	"clavicle_l", "upperarm_l", "lowerarm_l", "hand_l",
	"clavicle_r", "upperarm_r", "lowerarm_r", "hand_r",
])
