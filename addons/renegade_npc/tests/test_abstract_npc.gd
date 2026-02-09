## Tests for AbstractNPC: initialization, serialization, memory, abstract simulation.
extends RefCounted


static func _make_data(archetype: String = "Civilian", faction: String = "civilian") -> NPCData:
	var data := NPCData.new()
	data.npc_name = "TestNPC"
	data.archetype = archetype
	data.faction = faction
	data.npc_id = ""  # Force unique ID generation
	data.aggression_bias = 0.3
	return data


static func run(t: Variant) -> void:
	_test_init_generates_id(t)
	_test_init_sets_health(t)
	_test_personality_created(t)
	_test_unique_ids(t)
	_test_social_memory_creation(t)
	_test_memory_decay(t)
	_test_serialization_roundtrip(t)
	_test_abstract_drive_evaluation(t)
	_test_block_scoring(t)


static func _test_init_generates_id(t: Variant) -> void:
	var data := _make_data()
	var npc := AbstractNPC.new(data)
	t.assert_true(not npc.npc_id.is_empty(), "AbstractNPC generates a non-empty ID")


static func _test_init_sets_health(t: Variant) -> void:
	var data := _make_data()
	data.max_health = 75
	var npc := AbstractNPC.new(data)
	t.assert_eq(npc.current_health, 75, "Health initialized to max_health")


static func _test_personality_created(t: Variant) -> void:
	var data := _make_data()
	var npc := AbstractNPC.new(data)
	t.assert_true(npc.personality != null, "Personality is created on init")
	t.assert_in_range(npc.personality.grit, 0.0, 1.0, "Personality grit in valid range")


static func _test_unique_ids(t: Variant) -> void:
	var ids: Dictionary = {}
	var all_unique := true
	for i: int in range(100):
		var data := _make_data()
		data.npc_id = ""  # Reset so each generates new
		var npc := AbstractNPC.new(data)
		if ids.has(npc.npc_id):
			all_unique = false
			break
		ids[npc.npc_id] = true
	t.assert_true(all_unique, "100 NPCs generate 100 unique IDs")


static func _test_social_memory_creation(t: Variant) -> void:
	var data := _make_data()
	var npc := AbstractNPC.new(data)
	var mem := npc.get_memory("player")
	t.assert_true(mem != null, "get_memory creates and returns SocialMemory")
	# Second call should return same instance
	var mem2 := npc.get_memory("player")
	t.assert_true(mem == mem2, "get_memory returns same instance for same target")


static func _test_memory_decay(t: Variant) -> void:
	var data := _make_data()
	var npc := AbstractNPC.new(data)
	var mem := npc.get_memory("player")
	mem.add_negative(0.8, 0.0)
	var before := mem.temp_fear
	npc.decay_memories(0.1)
	t.assert_lt(mem.temp_fear, before, "decay_memories reduces temp_fear")


static func _test_serialization_roundtrip(t: Variant) -> void:
	var data := _make_data()
	var npc := AbstractNPC.new(data)
	npc.current_health = 42
	npc.current_block = "test_block"
	npc.world_position = Vector3(10.0, 0.0, -5.0)
	npc.current_drive = "patrol"
	npc.get_memory("player").add_negative(0.5, 1.0)

	var dict := npc.to_dict()

	var npc2 := AbstractNPC.new(data)
	npc2.load_from_dict(dict)

	t.assert_eq(npc2.current_health, 42, "Serialized health roundtrips")
	t.assert_eq(npc2.current_block, "test_block", "Serialized block roundtrips")
	t.assert_eq(npc2.current_drive, "patrol", "Serialized drive roundtrips")
	t.assert_approx(npc2.world_position.x, 10.0, 0.01, "Serialized position.x roundtrips")
	t.assert_approx(npc2.world_position.z, -5.0, 0.01, "Serialized position.z roundtrips")

	var mem := npc2.social_memories.get("player") as SocialMemory
	t.assert_true(mem != null, "Serialized social memory roundtrips")
	if mem:
		t.assert_gt(mem.fear, 0.0, "Serialized memory fear preserved")


static func _test_abstract_drive_evaluation(t: Variant) -> void:
	var data := _make_data("Gang", NPCConfig.Factions.LA_MIRADA)
	data.aggression_bias = 0.8
	var npc := AbstractNPC.new(data)
	npc.current_block = "test_block"

	var block_data := {
		"crime_level": 0.8,
		"police_presence": 0.2,
		"gang_territory": {NPCConfig.Factions.LA_MIRADA: 0.9},
	}

	# Run abstract drive evaluation
	npc._evaluate_abstract_drive(block_data)
	t.assert_true(npc.current_drive != "", "Abstract drive evaluation sets a drive")
	t.assert_true(npc.current_drive in ["patrol", "socialize", "flee", "idle"],
		"Gang abstract drive is a valid drive (got '%s')" % npc.current_drive)


static func _test_block_scoring(t: Variant) -> void:
	var data := _make_data("Vendor", "civilian")
	var npc := AbstractNPC.new(data)

	var high_commerce := {"commerce_level": 0.9, "crime_level": 0.1, "block_id": "market"}
	var high_crime := {"commerce_level": 0.1, "crime_level": 0.9, "block_id": "slums"}

	var score_market: float = npc._score_block(high_commerce)
	var score_slums: float = npc._score_block(high_crime)

	t.assert_gt(score_market, score_slums, "Vendor prefers high-commerce block over high-crime block")
