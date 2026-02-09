## IdleModule: Baseline fallback module. Returns a low constant score
## so NPCs always have something to do when no other drive is active.
## When dominant: NPC wanders slowly, plays ambient animations.
class_name IdleModule
extends UtilityModule

## Base idle score - should be low enough that any real drive overrides it
var base_score: float = NPCConfig.Idle.BASE_SCORE


func get_module_name() -> String:
	return "IdleModule"


func get_drive_name() -> String:
	return "idle"


func evaluate() -> float:
	# Slightly higher for low-energy personalities (they're content doing nothing)
	var energy_modifier: float = 1.0 - personality.hustle * NPCConfig.Idle.ENERGY_MODIFIER
	return clampf(base_score * energy_modifier, NPCConfig.Idle.CLAMP_MIN, NPCConfig.Idle.CLAMP_MAX)
