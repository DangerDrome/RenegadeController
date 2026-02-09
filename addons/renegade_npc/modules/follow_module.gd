## FollowModule: Makes subordinate NPCs follow their partner lead.
## When dominant: Subordinate navigates to stay near their lead.
## Only activates for subordinate partners (is_partner_lead = false).
class_name FollowModule
extends UtilityModule

## Cached reference to the lead NPC (RealizedNPC).
var _lead: Node3D = null
## Distance to lead last evaluation.
var _distance_to_lead: float = 0.0


func get_module_name() -> String:
	return "FollowModule"


func get_drive_name() -> String:
	return "follow"


func evaluate() -> float:
	if not npc or not abstract:
		return 0.0

	# Only subordinates follow - leads make their own decisions
	if abstract.is_partner_lead:
		return 0.0

	# Need a partner to follow
	if abstract.partner_id.is_empty():
		return 0.0

	# Try to get the realized lead
	_lead = _get_realized_lead()
	if not _lead:
		# Partner not realized - can't follow
		return 0.0

	# Calculate distance to lead
	_distance_to_lead = npc.global_position.distance_to(_lead.global_position)

	# If close enough, no need to follow
	if _distance_to_lead <= NPCConfig.Follow.MIN_FOLLOW_DISTANCE:
		return 0.0

	# Score increases with distance - want to stay close
	var distance_factor := clampf(
		(_distance_to_lead - NPCConfig.Follow.MIN_FOLLOW_DISTANCE) /
		(NPCConfig.Follow.MAX_FOLLOW_DISTANCE - NPCConfig.Follow.MIN_FOLLOW_DISTANCE),
		0.0, 1.0
	)

	var score := NPCConfig.Follow.BASE_FOLLOW_SCORE * distance_factor * NPCConfig.Follow.DISTANCE_WEIGHT

	# Urgency increases dramatically if very far from lead
	if _distance_to_lead > NPCConfig.Follow.MAX_FOLLOW_DISTANCE:
		score = 0.9  # Very high priority to catch up

	return clampf(score, 0.0, 1.0)


## Get the realized lead NPC (null if lead not realized).
func _get_realized_lead() -> Node3D:
	if not abstract or abstract.partner_id.is_empty():
		return null

	# Use NPCManager to get realized partner
	var npc_manager: Node = npc.get_node_or_null("/root/NPCManager")
	if npc_manager and npc_manager.has_method("get_realized_partner"):
		var partner: Node3D = npc_manager.get_realized_partner(abstract.npc_id)
		# We're the subordinate, so our partner is the lead
		if partner:
			var partner_abstract: AbstractNPC = partner.abstract if "abstract" in partner else null
			if partner_abstract and partner_abstract.is_partner_lead:
				return partner
	return null


## Get the target position to follow to (offset from lead).
func get_follow_target() -> Vector3:
	if not _lead:
		return Vector3.ZERO

	# Calculate offset position - behind and to the side of lead
	var lead_forward: Vector3 = -_lead.global_transform.basis.z.normalized()
	var lead_right: Vector3 = _lead.global_transform.basis.x.normalized()

	var offset := NPCConfig.Follow.FOLLOW_OFFSET
	var target_pos := _lead.global_position
	target_pos -= lead_forward * offset.z  # Behind
	target_pos += lead_right * offset.x    # To the side

	return target_pos


## Get distance to lead (for RealizedNPC to use).
func get_distance_to_lead() -> float:
	return _distance_to_lead


## Get the lead NPC reference.
func get_lead() -> Node3D:
	return _lead
