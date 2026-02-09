## PursuitModule: Evaluates urgency to chase a fleeing/hostile target.
## Only for combatants. Requires line-of-sight or recent visual.
## When dominant: NPC moves toward target.
class_name PursuitModule
extends UtilityModule


func get_module_name() -> String:
	return "PursuitModule"


func get_drive_name() -> String:
	return "pursue"


func evaluate() -> float:
	if not npc or not abstract:
		return 0.0

	# Only combatants pursue
	if not abstract.data.is_combatant:
		return 0.0

	# Need detection system
	var detection: RefCounted = npc.detection if "detection" in npc else null
	if not detection:
		return 0.0

	# Need LOS or recent visual
	if not detection.has_line_of_sight and not detection.had_recent_visual(3.0):
		return 0.0

	# Get target
	var target: Node3D = detection.target as Node3D if detection.target else null
	if not target or not is_instance_valid(target):
		return 0.0

	# Check if target is hostile
	if not _is_hostile(target):
		return 0.0

	var pursue_score: float = 0.0

	# Base score when we have a valid hostile target
	pursue_score = 0.4

	# Distance factor - closer targets are more urgent
	var distance: float = npc.global_position.distance_to(target.global_position)
	var distance_factor: float = 1.0 - clampf(distance / 30.0, 0.0, 1.0)
	pursue_score += distance_factor * 0.3

	# LOS bonus - confirmed visual is more urgent than last known
	if detection.has_line_of_sight:
		pursue_score += 0.2

	# Personality: aggressive NPCs pursue harder, gritty NPCs don't give up
	pursue_score *= (0.7 + personality.aggression * 0.3 + personality.grit * 0.2)

	# Health check - don't pursue if badly hurt (flee takes over)
	var health_ratio: float = float(abstract.current_health) / float(abstract.data.max_health)
	if health_ratio < 0.3:
		pursue_score *= 0.3  # Heavily reduce pursuit when critical

	return clampf(pursue_score, 0.0, 1.0)


func _is_hostile(target: Node3D) -> bool:
	# Check faction disposition
	if target.has_method("get_faction"):
		var other_faction: String = target.get_faction()
		var rep_mgr: Node = Engine.get_main_loop().root.get_node_or_null("ReputationManager") if Engine.get_main_loop() else null
		if rep_mgr and rep_mgr.has_method("get_faction_disposition"):
			var disposition: float = rep_mgr.get_faction_disposition(
				abstract.data.faction, other_faction
			)
			return disposition < NPCConfig.Threat.HOSTILE_DISP_THRESHOLD

	# Player is hostile if wanted level > 0 (for cops) or memory is negative
	if target.is_in_group("player"):
		# Cops check wanted level
		if abstract.data.faction == NPCConfig.Factions.LAPD:
			var npc_mgr: Node = Engine.get_main_loop().root.get_node_or_null("NPCManager") if Engine.get_main_loop() else null
			if npc_mgr and npc_mgr.has_method("get_wanted_level"):
				if npc_mgr.get_wanted_level() >= 2:  # Wanted level 2+ = pursue
					return true

		# Also check personal memory
		var player_memory := abstract.get_memory("player")
		return player_memory.get_disposition() < NPCConfig.Threat.PLAYER_HOSTILE_THRESHOLD

	return false
