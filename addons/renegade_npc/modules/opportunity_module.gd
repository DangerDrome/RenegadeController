## OpportunityModule: Evaluates opportunities based on archetype.
## Gang: territory patrol, deals, robbery. Cop: arrests, investigation.
## Vendor: sales. Civilian: shopping, commuting.
## When dominant: NPC pursues the highest-value opportunity.
class_name OpportunityModule
extends UtilityModule

var _current_opportunity: String = ""
var _opportunity_score: float = 0.0
var _target_activity_node: Node3D = null


func get_module_name() -> String:
	return "OpportunityModule"


func get_drive_name() -> String:
	match abstract.data.archetype:
		"Gang":
			return "patrol" if _current_opportunity == "territory" else "deal"
		"Cop":
			return "patrol"
		"Vendor":
			return "work"
		_:
			return "idle"


func evaluate() -> float:
	if not npc or not abstract:
		return 0.0
	
	_opportunity_score = 0.0
	_current_opportunity = ""
	
	# Find nearby activity nodes that match our preferences
	var best_activity_score: float = 0.0
	if not npc.is_inside_tree():
		return 0.0
	var activity_nodes: Array[Node] = npc.get_tree().get_nodes_in_group("activity_nodes")
	
	var npc_faction: String = npc.get_faction() if npc.has_method("get_faction") else ""

	for node: Node in activity_nodes:
		if not node is Node3D:
			continue

		var activity_type: String = ""
		if node.has_method("get_activity_type"):
			activity_type = node.get_activity_type()
		else:
			continue

		# Skip activity types on cooldown (just completed one)
		if npc.get("_activity_cooldown") != null and npc._activity_cooldown > 0.0:
			if activity_type == npc._last_completed_activity:
				continue

		# Check if we prefer this activity
		var preference: float = abstract.data.activity_preferences.get(activity_type, 0.0)
		if preference <= 0.0:
			continue

		# Faction restriction
		if node.has_method("can_use") and not node.can_use(npc_faction):
			continue

		# Distance factor
		var dist: float = npc.global_position.distance_to(node.global_position)
		if dist > NPCConfig.Opportunity.DISTANCE_LIMIT:
			continue
		var dist_score: float = 1.0 - clampf(dist / NPCConfig.Opportunity.DISTANCE_LIMIT, 0.0, 1.0)

		# Is the spot occupied?
		var occupied: bool = false
		if node.has_method("is_occupied"):
			occupied = node.is_occupied()
		if occupied:
			continue

		var score: float = preference * dist_score
		if score > best_activity_score:
			best_activity_score = score
			_target_activity_node = node as Node3D
			_current_opportunity = activity_type
	
	# Personality influence
	_opportunity_score = best_activity_score
	_opportunity_score *= (NPCConfig.Opportunity.HUSTLE_MULT + personality.hustle * NPCConfig.Opportunity.HUSTLE_MULT)

	# Archetype-specific boosts
	var boost: Dictionary = NPCConfig.Opportunity.ARCHETYPE_BOOSTS.get(abstract.data.archetype, {})
	if not boost.is_empty():
		_opportunity_score *= (boost["base"] + personality.aggression * boost.get("agg_mult", 0.0))
	
	return clampf(_opportunity_score, 0.0, 1.0)


func get_target_activity_node() -> Node3D:
	return _target_activity_node


func get_current_opportunity() -> String:
	return _current_opportunity
