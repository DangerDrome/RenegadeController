## NPCManager: The master controller for all NPCs in the game.
## Manages the abstract/realized lifecycle, spawning/despawning NPCs
## based on player proximity, and running abstract simulation for off-screen NPCs.
## Autoloaded by the plugin.
extends Node

const WantedSystemScript = preload("res://addons/renegade_npc/core/wanted_system.gd")

## Emitted when an NPC is realized (spawned into the world).
signal npc_realized(abstract: AbstractNPC, realized: RealizedNPC)
## Emitted when an NPC is abstractized (removed from the world).
signal npc_abstractized(abstract: AbstractNPC)
## Emitted when an NPC dies.
signal npc_died(abstract: AbstractNPC)

## --- Configuration ---
## Distance from player at which NPCs are realized (spawned).
@export var realize_distance: float = 60.0
## Distance at which realized NPCs are abstractized (despawned).
## Should be > realize_distance to prevent pop-in/out oscillation.
@export var abstractize_distance: float = 80.0
## Maximum simultaneous realized NPCs (performance budget).
@export var max_realized: int = 30
## How many abstract NPCs to update per frame (budget spreading).
@export var abstract_updates_per_frame: int = 10

## --- State ---
## All NPCs in the game world.
var _all_npcs: Dictionary = {}  # npc_id -> AbstractNPC
## Currently realized NPCs.
var _realized_npcs: Dictionary = {}  # npc_id -> RealizedNPC
## Block data for abstract simulation. Key = block_id.
var _block_data: Dictionary = {}
## Player reference (cached).
var _player: Node3D = null
## Index for round-robin abstract updates.
var _abstract_update_index: int = 0
## The base scene used to instantiate realized NPCs.
var _realized_npc_scene: PackedScene = preload("res://addons/renegade_npc/presets/realized_npc.tscn")

## --- Wanted System ---
## Tracks player heat level with law enforcement.
var wanted_system: RefCounted = null  ## WantedSystem instance


func _ready() -> void:
	# Initialize wanted system
	wanted_system = WantedSystemScript.new()

	# Connect to GameClock
	var clock = get_node_or_null("/root/GameClock")
	if clock:
		clock.hour_changed.connect(_on_hour_changed)
		clock.cycle_tick.connect(_on_cycle_tick)


func _process(delta: float) -> void:
	_cache_player()

	if _player:
		_update_realization()
		# Update wanted system with observation status
		if wanted_system:
			var is_observed := _is_player_observed_by_cops()
			wanted_system.update(delta, is_observed)

	_update_abstract_npcs(delta)


## --- REGISTRATION ---

## Register a new NPC into the system. Returns the AbstractNPC.
func register_npc(data: NPCData, block_id: String = "", position: Vector3 = Vector3.ZERO) -> AbstractNPC:
	var abstract := AbstractNPC.new(data)
	abstract.current_block = block_id
	abstract.world_position = position
	abstract._home_block = block_id
	_all_npcs[abstract.npc_id] = abstract
	return abstract


## Register multiple NPCs from an array of NPCData resources.
func register_npcs(data_array: Array[NPCData], block_id: String = "") -> Array[AbstractNPC]:
	var results: Array[AbstractNPC] = []
	for data: NPCData in data_array:
		results.append(register_npc(data, block_id))
	return results


## Remove an NPC from the system entirely.
func unregister_npc(npc_id: String) -> void:
	if _realized_npcs.has(npc_id):
		_abstractize_npc(npc_id)
	_all_npcs.erase(npc_id)


## --- PARTNER SYSTEM ---

## Register a cop pair (lead + subordinate). Returns [lead, subordinate] AbstractNPCs.
## Both share the same position and block, linked by partner_id.
## partner_chance: probability (0.0-1.0) that this cop actually gets a partner.
func register_cop_pair(lead_data: NPCData, subordinate_data: NPCData, block_id: String = "",
		position: Vector3 = Vector3.ZERO, partner_chance: float = 0.8) -> Array[AbstractNPC]:
	var lead := register_npc(lead_data, block_id, position)
	lead.is_partner_lead = true

	# Roll to see if this cop gets a partner
	if randf() > partner_chance:
		# Solo cop - no partner
		return [lead]

	# Spawn subordinate close beside lead (use lead's snapped position)
	var offset := Vector3(randf_range(0.8, 1.2), 0.0, randf_range(-0.3, 0.3))
	var sub := register_npc(subordinate_data, block_id, lead.world_position + offset)
	sub.is_partner_lead = false

	# Link them
	lead.partner_id = sub.npc_id
	sub.partner_id = lead.npc_id

	return [lead, sub]


## Register a cop pair using the same NPCData for both (randomized names/IDs).
func register_cop_pair_same_data(data: NPCData, block_id: String = "",
		position: Vector3 = Vector3.ZERO, partner_chance: float = 0.8) -> Array[AbstractNPC]:
	return register_cop_pair(data, data, block_id, position, partner_chance)


## Get the partner of an NPC (null if no partner or partner doesn't exist).
func get_partner(npc_id: String) -> AbstractNPC:
	var npc: AbstractNPC = _all_npcs.get(npc_id)
	if not npc or npc.partner_id.is_empty():
		return null
	return _all_npcs.get(npc.partner_id)


## Get the realized partner of an NPC (null if partner not realized).
func get_realized_partner(npc_id: String) -> RealizedNPC:
	var partner: AbstractNPC = get_partner(npc_id)
	if not partner:
		return null
	return _realized_npcs.get(partner.npc_id)


## --- BLOCK DATA ---

## Register a city block for abstract simulation.
## block_data should include: block_id, crime_level, commerce_level,
## police_presence, gang_territory (Dictionary), connections (Array of block_data dicts).
func register_block(block_id: String, data: Dictionary) -> void:
	data["block_id"] = block_id
	_block_data[block_id] = data


## Update a block's properties (e.g., crime level changed).
func update_block(block_id: String, updates: Dictionary) -> void:
	if _block_data.has(block_id):
		_block_data[block_id].merge(updates, true)


## --- REALIZATION ---

func _update_realization() -> void:
	if not _player:
		return
	
	var player_pos: Vector3 = _player.global_position
	
	# Check if any abstract NPCs should be realized
	for npc_id: String in _all_npcs:
		var abstract: AbstractNPC = _all_npcs[npc_id]
		
		if not abstract.is_alive:
			continue
		
		var distance: float = player_pos.distance_to(abstract.world_position)
		
		if abstract.is_realized:
			# Should we abstractize?
			if distance > abstractize_distance:
				_abstractize_npc(npc_id)
		else:
			# Should we realize?
			if distance < realize_distance and _realized_npcs.size() < max_realized:
				_realize_npc(npc_id)


func _realize_npc(npc_id: String) -> void:
	var abstract: AbstractNPC = _all_npcs.get(npc_id)
	if not abstract or abstract.is_realized:
		return

	# Realize the NPC
	var realized := _create_realized_npc(abstract)
	if not realized:
		return

	_realized_npcs[npc_id] = realized
	npc_realized.emit(abstract, realized)

	# Also realize partner if they have one and they're not already realized
	if not abstract.partner_id.is_empty():
		var partner: AbstractNPC = _all_npcs.get(abstract.partner_id)
		if partner and partner.is_alive and not partner.is_realized:
			# Budget check - only if we have room
			if _realized_npcs.size() < max_realized:
				var partner_realized := _create_realized_npc(partner)
				if partner_realized:
					_realized_npcs[partner.npc_id] = partner_realized
					npc_realized.emit(partner, partner_realized)


## Internal: Creates and initializes a RealizedNPC from an AbstractNPC.
func _create_realized_npc(abstract: AbstractNPC) -> RealizedNPC:
	if abstract.is_realized:
		return null

	# Instantiate from the NPC scene (editable in editor)
	var realized: RealizedNPC = null
	if _realized_npc_scene:
		realized = _realized_npc_scene.instantiate() as RealizedNPC
	else:
		realized = RealizedNPC.new()
		var col := CollisionShape3D.new()
		var capsule := CapsuleShape3D.new()
		capsule.radius = 0.3
		capsule.height = 1.8
		col.shape = capsule
		col.position.y = 0.9
		realized.add_child(col)

	# Add custom model if specified in NPCData
	if abstract.data.model_scene:
		var model_parent: Node3D = realized.get_node_or_null("Model")
		if not model_parent:
			model_parent = Node3D.new()
			model_parent.name = "Model"
			realized.add_child(model_parent)
		var model: Node3D = abstract.data.model_scene.instantiate()
		model_parent.add_child(model)

	realized.died.connect(_on_npc_died.bind(abstract.npc_id))

	# Add to scene tree before initialize (global_position requires being in tree)
	var npc_container := _get_npc_container()
	npc_container.add_child(realized)
	realized.initialize(abstract)

	return realized


func _abstractize_npc(npc_id: String) -> void:
	var realized: RealizedNPC = _realized_npcs.get(npc_id)
	if not realized:
		return
	
	realized.serialize_to_abstract()
	realized.queue_free()
	_realized_npcs.erase(npc_id)
	
	var abstract: AbstractNPC = _all_npcs.get(npc_id)
	if abstract:
		npc_abstractized.emit(abstract)


## --- ABSTRACT SIMULATION ---

func _update_abstract_npcs(delta: float) -> void:
	var npc_ids: Array = _all_npcs.keys()
	if npc_ids.is_empty():
		return
	
	var count: int = mini(abstract_updates_per_frame, npc_ids.size())
	
	for i: int in range(count):
		var index: int = (_abstract_update_index + i) % npc_ids.size()
		var npc_id: String = npc_ids[index]
		var abstract: AbstractNPC = _all_npcs[npc_id]
		
		if not abstract.is_realized and abstract.is_alive:
			var block: Dictionary = _block_data.get(abstract.current_block, {})
			abstract.abstract_update(delta * float(npc_ids.size()) / float(count), block)
	
	_abstract_update_index = (_abstract_update_index + count) % maxi(npc_ids.size(), 1)


## --- TIME EVENTS ---

func _on_hour_changed(hour: int) -> void:
	# Decay social memories for all NPCs
	for npc_id: String in _all_npcs:
		(_all_npcs[npc_id] as AbstractNPC).decay_memories(0.05)


func _on_cycle_tick() -> void:
	# Periodic maintenance
	pass


## --- EVENTS ---

## Broadcast a threat event to all realized NPCs.
## Example: NPCManager.broadcast_threat({"position": gunfire_pos, "type": "gunfire"})
func broadcast_threat(event_data: Dictionary) -> void:
	get_tree().call_group("npcs", "on_threat_event", event_data)


func _on_npc_died(npc_id: String) -> void:
	var abstract: AbstractNPC = _all_npcs.get(npc_id)
	if abstract:
		npc_died.emit(abstract)
	# Keep in _all_npcs for persistence (is_alive = false)
	_realized_npcs.erase(npc_id)


## --- QUERIES ---

## Get all NPCs in a specific block.
func get_npcs_in_block(block_id: String) -> Array[AbstractNPC]:
	var result: Array[AbstractNPC] = []
	for npc_id: String in _all_npcs:
		var abstract: AbstractNPC = _all_npcs[npc_id]
		if abstract.current_block == block_id and abstract.is_alive:
			result.append(abstract)
	return result


## Get all NPCs of a specific faction.
func get_npcs_by_faction(faction: String) -> Array[AbstractNPC]:
	var result: Array[AbstractNPC] = []
	for npc_id: String in _all_npcs:
		var abstract: AbstractNPC = _all_npcs[npc_id]
		if abstract.data.faction == faction and abstract.is_alive:
			result.append(abstract)
	return result


## Get a specific AbstractNPC by ID.
func get_npc(npc_id: String) -> AbstractNPC:
	return _all_npcs.get(npc_id)


## Get a specific RealizedNPC by ID (null if not realized).
func get_realized_npc(npc_id: String) -> RealizedNPC:
	return _realized_npcs.get(npc_id)


## Get all currently realized NPCs. Returns a dictionary of npc_id -> RealizedNPC.
## This is a shallow copy - safe to iterate without modifying the internal state.
func get_realized_npcs() -> Dictionary:
	return _realized_npcs.duplicate()


## Get all NPCs (abstract). Returns a dictionary of npc_id -> AbstractNPC.
## This is a shallow copy - safe to iterate without modifying the internal state.
func get_all_npcs() -> Dictionary:
	return _all_npcs.duplicate()


## Check if there are any realized NPCs.
func has_realized_npcs() -> bool:
	return not _realized_npcs.is_empty()


## Get count stats.
func get_stats() -> Dictionary:
	var alive_count: int = 0
	for npc_id: String in _all_npcs:
		if (_all_npcs[npc_id] as AbstractNPC).is_alive:
			alive_count += 1
	return {
		"total": _all_npcs.size(),
		"alive": alive_count,
		"realized": _realized_npcs.size(),
		"blocks": _block_data.size(),
	}


## Set a custom scene to use for realized NPCs.
func set_realized_scene(scene: PackedScene) -> void:
	_realized_npc_scene = scene


## --- WANTED SYSTEM ---

## Report a crime committed by the player.
func report_crime(crime_type: String) -> void:
	if wanted_system:
		wanted_system.report_crime(crime_type)


## Get the current wanted level (0-5).
func get_wanted_level() -> int:
	return wanted_system.current_level if wanted_system else 0


## Check if cops should pursue the player on sight.
func should_cops_pursue() -> bool:
	return wanted_system.should_pursue() if wanted_system else false


## Clear all wanted status.
func clear_wanted() -> void:
	if wanted_system:
		wanted_system.clear()


## --- INTERNAL ---

func _cache_player() -> void:
	if not _player or not is_instance_valid(_player):
		var players := get_tree().get_nodes_in_group("player")
		_player = players[0] as Node3D if not players.is_empty() else null


func _get_npc_container() -> Node:
	var container := get_tree().current_scene.get_node_or_null("NPCs")
	if not container:
		container = Node3D.new()
		container.name = "NPCs"
		get_tree().current_scene.add_child(container)
	return container


## Check if any LAPD cop has line-of-sight on the player.
func _is_player_observed_by_cops() -> bool:
	for npc_id: String in _realized_npcs:
		var realized: RealizedNPC = _realized_npcs[npc_id]
		if not realized or not is_instance_valid(realized):
			continue
		# Check if this is a cop (LAPD faction)
		if realized.data and realized.data.faction == NPCConfig.Factions.LAPD:
			# Check if they have LOS on player
			if realized.detection and realized.detection.has_line_of_sight:
				return true
	return false


## --- SAVE/LOAD ---

func save_all() -> Dictionary:
	var npc_states: Dictionary = {}
	for npc_id: String in _all_npcs:
		npc_states[npc_id] = (_all_npcs[npc_id] as AbstractNPC).to_dict()

	return {
		"npcs": npc_states,
		"reputation": ReputationManager.save_state() if ReputationManager else {},
		"wanted": wanted_system.save() if wanted_system else {},
	}


func load_all(save_data: Dictionary, npc_data_registry: Dictionary) -> void:
	# npc_data_registry: npc_id -> NPCData resource
	var npc_states: Dictionary = save_data.get("npcs", {})

	for npc_id: String in npc_states:
		var state: Dictionary = npc_states[npc_id]
		var data: NPCData = npc_data_registry.get(npc_id)
		if data:
			var abstract := AbstractNPC.new(data)
			abstract.load_from_dict(state)
			_all_npcs[npc_id] = abstract

	if ReputationManager and save_data.has("reputation"):
		ReputationManager.load_state(save_data["reputation"])

	if wanted_system and save_data.has("wanted"):
		wanted_system.load_state(save_data["wanted"])
