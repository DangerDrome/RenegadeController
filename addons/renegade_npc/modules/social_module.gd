## SocialModule: Evaluates desire to interact with nearby allies,
## form groups, and occupy social activity spots.
## When dominant: NPC moves toward allies or social activity nodes.
class_name SocialModule
extends UtilityModule

var _social_target: Node3D = null
var _social_score: float = 0.0


func get_module_name() -> String:
	return "SocialModule"


func get_drive_name() -> String:
	return "socialize"


func evaluate() -> float:
	if not npc or not abstract:
		return 0.0
	
	_social_score = 0.0
	_social_target = null
	
	# Check for nearby same-faction NPCs
	var detection_area: Area3D = npc.get_node_or_null("DetectionArea")
	if detection_area:
		var ally_count: int = 0
		var nearest_ally: Node3D = null
		var nearest_dist: float = INF
		
		for body: Node3D in detection_area.get_overlapping_bodies():
			if body == npc:
				continue
			if body.has_method("get_faction") and body.get_faction() == abstract.data.faction:
				ally_count += 1
				var dist: float = npc.global_position.distance_to(body.global_position)
				if dist < nearest_dist:
					nearest_dist = dist
					nearest_ally = body
		
		# More allies nearby = stronger social pull (but diminishing returns)
		if ally_count > 0:
			_social_score += minf(float(ally_count) * NPCConfig.Social.PER_ALLY, NPCConfig.Social.MAX_ALLIES)
			_social_target = nearest_ally

	# Empathy and hustle drive socializing
	_social_score *= (NPCConfig.Social.BASE_WEIGHT + personality.empathy * NPCConfig.Social.EMPATHY_WEIGHT + personality.hustle * NPCConfig.Social.HUSTLE_WEIGHT)

	# Lonely NPCs (no allies nearby) get a slight social urge if empathetic
	if _social_target == null and personality.empathy > NPCConfig.Social.EMPATHY_THRESHOLD:
		_social_score += NPCConfig.Social.LONELY_EMPATHY_BOOST

	# Combatant NPCs socialize less
	if abstract.data.is_combatant:
		_social_score *= NPCConfig.Social.COMBATANT_REDUCER
	
	return clampf(_social_score, 0.0, 1.0)


func get_social_target() -> Node3D:
	return _social_target
