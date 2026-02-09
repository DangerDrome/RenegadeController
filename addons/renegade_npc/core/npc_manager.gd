## NPCManager: The master controller for all NPCs in the game.
## Manages the abstract/realized lifecycle, spawning/despawning NPCs
## based on player proximity, and running abstract simulation for off-screen NPCs.
## Autoloaded by the plugin.
extends Node

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


func _ready() -> void:
	# Connect to GameClock
	var clock = get_node_or_null("/root/GameClock")
	if clock:
		clock.hour_changed.connect(_on_hour_changed)
		clock.cycle_tick.connect(_on_cycle_tick)


func _process(delta: float) -> void:
	_cache_player()
	
	if _player:
		_update_realization()
	
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

	realized.died.connect(_on_npc_died.bind(npc_id))

	# Add to scene tree before initialize (global_position requires being in tree)
	var npc_container := _get_npc_container()
	npc_container.add_child(realized)
	realized.initialize(abstract)
	
	_realized_npcs[npc_id] = realized
	npc_realized.emit(abstract, realized)


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


## --- SAVE/LOAD ---

func save_all() -> Dictionary:
	var npc_states: Dictionary = {}
	for npc_id: String in _all_npcs:
		npc_states[npc_id] = (_all_npcs[npc_id] as AbstractNPC).to_dict()
	
	return {
		"npcs": npc_states,
		"reputation": ReputationManager.save_state() if ReputationManager else {},
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
