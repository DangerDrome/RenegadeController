## FleeModule: Evaluates urgency to disengage and retreat.
## Triggers on critical health, overwhelming numbers, or extreme fear.
## When dominant: NPC breaks engagement and pathfinds to safety.
class_name FleeModule
extends UtilityModule


func get_module_name() -> String:
	return "FleeModule"


func get_drive_name() -> String:
	return "flee"


func evaluate() -> float:
	if not npc or not abstract:
		return 0.0

	var flee_score: float = 0.0

	# Health-based urgency — only triggers at low health
	var health_ratio: float = float(abstract.current_health) / float(abstract.data.max_health)
	if health_ratio < NPCConfig.Flee.CRITICAL_HP_THRESHOLD:
		flee_score += (1.0 - health_ratio) * NPCConfig.Flee.CRITICAL_HP_URGENCY
	elif health_ratio < NPCConfig.Flee.MODERATE_HP_THRESHOLD:
		flee_score += (NPCConfig.Flee.MODERATE_HP_THRESHOLD - health_ratio) * NPCConfig.Flee.MODERATE_HP_URGENCY

	# Personality: anxious NPCs flee sooner, gritty NPCs hold longer
	flee_score *= (NPCConfig.Flee.PERSONALITY_BASE + personality.anxiety * NPCConfig.Flee.ANXIETY_MULT - personality.grit * NPCConfig.Flee.GRIT_REDUCER)

	# Non-combatants flee more readily
	if not abstract.data.is_combatant:
		flee_score *= NPCConfig.Flee.NONCOMBATANT_MULT

	return clampf(flee_score, 0.0, 1.0)
