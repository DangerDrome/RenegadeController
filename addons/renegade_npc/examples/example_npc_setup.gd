## Example: How to create NPC data resources and populate a scene.
## This script shows how to set up the NPC system in your game.
##
## USAGE:
##   1. Attach this script to a Node in your test scene
##   2. Make sure your player is in the "player" group
##   3. Place some ActivityNode instances in your scene
##   4. Run and watch NPCs spawn around you
extends Node

## Path to NPCData .tres resources (create these in the Inspector)
## Or create them in code as shown below.

func _ready() -> void:
	# Wait one frame for autoloads to initialize
	await get_tree().process_frame
	
	_setup_factions()
	_setup_blocks()
	_spawn_test_npcs()
	
	print("[Example] NPC system initialized. Stats: ", NPCManager.get_stats())


func _setup_factions() -> void:
	for entry: Array in NPCConfig.Factions.DEFAULT_DISPOSITIONS:
		ReputationManager.set_faction_disposition(entry[0], entry[1], entry[2])


func _setup_blocks() -> void:
	for block_id: String in NPCConfig.Blocks.ALL:
		NPCManager.register_block(block_id, NPCConfig.Blocks.ALL[block_id])


func _spawn_test_npcs() -> void:
	var player: Node3D = get_tree().get_first_node_in_group("player")
	var base_pos: Vector3 = player.global_position if player else Vector3.ZERO
	
	# --- Create NPC Data resources from centralized archetype presets ---
	var gang_data := _make_data_from_archetype("Gang")
	var cop_data := _make_data_from_archetype("Cop")
	var civ_data := _make_data_from_archetype("Civilian")
	var vendor_data := _make_data_from_archetype("Vendor")
	vendor_data.dialogue_file = "res://dialogue/vendor_general.dialogue"
	
	# --- Register NPCs at positions around the player ---
	
	# Spawn a group of gang members
	for i: int in range(4):
		var abstract := NPCManager.register_npc(
			gang_data,
			"downtown_east",
			base_pos + Vector3(randf_range(-20, 20), 0, randf_range(-20, 20))
		)
		print("  Registered: %s (personality: %s)" % [abstract.npc_id, abstract.personality])
	
	# Spawn cops
	for i: int in range(2):
		NPCManager.register_npc(
			cop_data,
			"downtown_east",
			base_pos + Vector3(randf_range(-30, 30), 0, randf_range(-30, 30))
		)
	
	# Spawn civilians
	for i: int in range(6):
		NPCManager.register_npc(
			civ_data,
			"downtown_east",
			base_pos + Vector3(randf_range(-25, 25), 0, randf_range(-25, 25))
		)
	
	# Spawn a vendor
	NPCManager.register_npc(
		vendor_data,
		"market_district",
		base_pos + Vector3(10, 0, 5)
	)


func _make_data_from_archetype(archetype: String) -> NPCData:
	var preset: Dictionary = NPCConfig.Archetypes.PRESETS.get(archetype, {})
	var data := NPCData.new()
	data.npc_name = preset.get("display_name", archetype)
	data.archetype = archetype
	data.faction = preset.get("faction", NPCConfig.Factions.CIVILIAN)
	data.is_combatant = preset.get("is_combatant", false)
	data.aggression_bias = preset.get("aggression_bias", 0.3)
	data.activity_preferences = preset.get("activity_preferences", {"idle": 1.0})
	return data
