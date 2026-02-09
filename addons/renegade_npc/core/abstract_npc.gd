## AbstractNPC: The lightweight data-only representation of an NPC.
## Exists for all NPCs at all times. Contains position, current drive,
## faction standing, social memory, and personality. No nodes, no physics.
## When the player is nearby, a RealizedNPC scene is spawned from this data.
class_name AbstractNPC
extends RefCounted

## Signals
signal realized(npc: AbstractNPC)
signal abstractized(npc: AbstractNPC)
signal drive_changed(npc: AbstractNPC, old_drive: String, new_drive: String)

## --- Identity ---
var npc_id: String
var data: NPCData
var personality: NPCPersonality

## --- State ---
var is_alive: bool = true
var current_health: int = 100
var current_block: String = ""  ## Which city block / area this NPC is in
var world_position: Vector3 = Vector3.ZERO  ## Last known world position
var current_drive: String = "idle"  ## The winning utility module's drive name
var is_realized: bool = false  ## Whether a RealizedNPC scene exists for this

## --- Social ---
## Dictionary of target_id (String) -> SocialMemory
var social_memories: Dictionary = {}

## --- Partner System ---
## Partner ID (empty if solo). Cops typically have partners.
var partner_id: String = ""
## True if this NPC is the lead of a partner pair. Lead makes decisions, subordinate follows.
var is_partner_lead: bool = true

## --- Abstract simulation ---
var _time_in_block: float = 0.0
var _abstract_update_accumulator: float = 0.0
var _home_block: String = ""  ## Where this NPC returns to during off-hours


func _init(p_data: NPCData = null) -> void:
	if p_data:
		data = p_data
		npc_id = data.generate_id()
		current_health = data.max_health
		personality = NPCPersonality.from_id(npc_id, data.aggression_bias)


## Called by NPCManager for off-screen NPCs. Simplified simulation.
func abstract_update(delta: float, block_data: Dictionary) -> void:
	if not is_alive or is_realized:
		return
	
	_abstract_update_accumulator += delta
	_time_in_block += delta
	
	# Only update every 2 seconds to save performance
	if _abstract_update_accumulator < 2.0:
		return
	_abstract_update_accumulator = 0.0
	
	# Simplified drive evaluation
	_evaluate_abstract_drive(block_data)
	
	# Maybe migrate to a different block
	_maybe_migrate(block_data)


func _evaluate_abstract_drive(block_data: Dictionary) -> void:
	var old_drive := current_drive
	
	# Simplified scoring based on archetype + personality
	var threat_level: float = block_data.get("crime_level", 0.0) * (1.0 - personality.grit)
	var opportunity: float = 0.0
	var social: float = personality.hustle * 0.3
	
	match data.archetype:
		"Gang":
			opportunity = block_data.get("crime_level", 0.0) * personality.aggression
			if threat_level > 0.6 and personality.grit < 0.4:
				current_drive = "flee"
			elif opportunity > social:
				current_drive = "patrol"
			else:
				current_drive = "socialize"
		"Cop":
			var duty: float = block_data.get("crime_level", 0.0) * 0.8
			if duty > 0.5:
				current_drive = "patrol"
			else:
				current_drive = "idle"
		"Vendor":
			current_drive = "work"
		"Civilian":
			if threat_level > 0.7:
				current_drive = "flee"
			else:
				current_drive = "idle"
		"Story":
			pass  # Story NPCs don't change drive abstractly
	
	if current_drive != old_drive:
		drive_changed.emit(self, old_drive, current_drive)


func _maybe_migrate(block_data: Dictionary) -> void:
	# Don't migrate too frequently
	if _time_in_block < 30.0:
		return
	
	# Get connected blocks and their attractiveness for this NPC
	var connections: Array = block_data.get("connections", [])
	if connections.is_empty():
		return
	
	# Simple attractiveness check - NPCManager provides block scores
	var best_block: String = current_block
	var best_score: float = _score_block(block_data)
	
	for conn: Dictionary in connections:
		var score := _score_block(conn)
		# Add noise so movement isn't deterministic
		score += randf_range(-0.1, 0.1)
		if score > best_score:
			best_score = score
			best_block = conn.get("block_id", "")
	
	if best_block != current_block and not best_block.is_empty():
		current_block = best_block
		_time_in_block = 0.0


func _score_block(block_data: Dictionary) -> float:
	var score: float = 0.0
	match data.archetype:
		"Gang":
			var territory: Dictionary = block_data.get("gang_territory", {})
			score += territory.get(data.faction, 0.0) * NPCConfig.BlockScoring.GANG_TERRITORY_MULT
			score -= block_data.get("police_presence", 0.0) * personality.anxiety
			score += block_data.get("crime_level", 0.0) * personality.aggression * NPCConfig.BlockScoring.GANG_CRIME_MULT
		"Cop":
			score += block_data.get("crime_level", 0.0) * NPCConfig.BlockScoring.COP_CRIME_MULT
			score += block_data.get("police_presence", 0.0) * NPCConfig.BlockScoring.COP_POLICE_BONUS
		"Vendor":
			score += block_data.get("commerce_level", 0.0) * NPCConfig.BlockScoring.VENDOR_COMMERCE_MULT
			score -= block_data.get("crime_level", 0.0) * NPCConfig.BlockScoring.VENDOR_CRIME_PENALTY
		"Civilian":
			# Attracted to commerce, repelled by crime and gangs
			score += block_data.get("commerce_level", 0.0)
			score -= block_data.get("crime_level", 0.0)
	
	# Home block bonus during off-hours
	if block_data.get("block_id", "") == _home_block:
		score += NPCConfig.BlockScoring.HOME_BLOCK_BONUS
	
	return score


## Get or create social memory for a target entity.
func get_memory(target_id: String) -> SocialMemory:
	if not social_memories.has(target_id):
		social_memories[target_id] = SocialMemory.new()
	return social_memories[target_id]


## Decay all social memories. Call once per game hour.
func decay_memories(rate: float = 0.1) -> void:
	for target_id: String in social_memories:
		(social_memories[target_id] as SocialMemory).decay(rate)


## Serialize for save/load.
func to_dict() -> Dictionary:
	var mem_dict := {}
	for target_id: String in social_memories:
		mem_dict[target_id] = (social_memories[target_id] as SocialMemory).to_dict()
	
	return {
		"npc_id": npc_id,
		"is_alive": is_alive,
		"current_health": current_health,
		"current_block": current_block,
		"world_position": var_to_str(world_position),
		"current_drive": current_drive,
		"home_block": _home_block,
		"social_memories": mem_dict,
		"partner_id": partner_id,
		"is_partner_lead": is_partner_lead,
	}


func load_from_dict(dict: Dictionary) -> void:
	is_alive = dict.get("is_alive", true)
	current_health = dict.get("current_health", data.max_health)
	current_block = dict.get("current_block", "")
	world_position = str_to_var(dict.get("world_position", var_to_str(Vector3.ZERO)))
	current_drive = dict.get("current_drive", "idle")
	_home_block = dict.get("home_block", "")
	partner_id = dict.get("partner_id", "")
	is_partner_lead = dict.get("is_partner_lead", true)

	var mem_dict: Dictionary = dict.get("social_memories", {})
	for target_id: String in mem_dict:
		social_memories[target_id] = SocialMemory.from_dict(mem_dict[target_id])
