## Tuning parameters for hit reactions and ragdoll behavior.
class_name HitReactionConfig
extends Resource

@export_group("Hitstop")
## Enable frame-freeze on impact for combat feel.
@export var enable_hitstop: bool = true
## Duration of hitstop in seconds (1-3 frames at 60fps = 0.016 - 0.05).
@export_range(0.0, 0.1) var hitstop_duration: float = 0.033

@export_group("Tier 1 - Procedural Flinch")
## Maximum rotation offset applied to spine on hit (degrees).
@export_range(0.0, 30.0) var flinch_max_angle: float = 15.0
## How fast the flinch decays back to neutral.
@export_range(1.0, 20.0) var flinch_decay_speed: float = 8.0

@export_group("Tier 2 - Partial Ragdoll")
## Starting influence when partial ragdoll activates.
@export_range(0.0, 1.0) var partial_ragdoll_influence: float = 0.6
## Duration of influence blend back to zero.
@export_range(0.1, 1.0) var partial_ragdoll_duration: float = 0.4
## Force multiplier for impulse applied to struck bone.
@export var impulse_multiplier: float = 5.0

@export_group("Tier 3 - Full Ragdoll")
## Duration before ragdoll can begin recovery.
@export var ragdoll_settle_time: float = 1.0
## Influence blend duration from ragdoll back to recovery animation.
@export_range(0.1, 1.0) var recovery_blend_duration: float = 0.5

@export_group("Bone Groups")
## Bones affected by upper body hits.
@export var upper_body_bones: PackedStringArray = PackedStringArray([
	"spine_02", "spine_03", "neck_01", "head",
	"clavicle_l", "upperarm_l", "clavicle_r", "upperarm_r",
])
## Bones affected by lower body hits.
@export var lower_body_bones: PackedStringArray = PackedStringArray([
	"pelvis", "thigh_l", "calf_l", "thigh_r", "calf_r",
])
