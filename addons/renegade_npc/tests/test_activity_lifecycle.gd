## Tests for ActivityNode lifecycle: occupy/release, capacity, faction filtering,
## and OpportunityModule integration with activity nodes.
extends RefCounted


## Mock NPC node with faction support for OpportunityModule tests.
class MockNPC extends Node3D:
	var _faction: String = ""
	func get_faction() -> String:
		return _faction


static func run(t: Variant) -> void:
	# ActivityNode API
	_test_occupy_release_cycle(t)
	_test_capacity_limit(t)
	_test_multi_capacity(t)
	_test_faction_allow_all(t)
	_test_faction_restriction(t)
	_test_freed_reference_cleanup(t)
	_test_specific_npc_release(t)
	_test_double_occupy_ignored(t)
	# OpportunityModule integration
	_test_opportunity_skips_occupied(t)
	_test_opportunity_skips_wrong_faction(t)
	_test_opportunity_scores_open_node(t)


# --- ActivityNode API ---

static func _test_occupy_release_cycle(t: Variant) -> void:
	var node := ActivityNode.new()
	node.capacity = 1
	var npc := Node.new()

	t.assert_false(node.is_occupied(), "ActivityNode starts unoccupied")
	node.occupy(npc)
	t.assert_true(node.is_occupied(), "ActivityNode occupied after occupy()")
	t.assert_eq(node.get_occupant_count(), 1, "Occupant count is 1 after occupy")

	node.release(npc)
	t.assert_false(node.is_occupied(), "ActivityNode unoccupied after release()")
	t.assert_eq(node.get_occupant_count(), 0, "Occupant count is 0 after release")

	npc.free()


static func _test_capacity_limit(t: Variant) -> void:
	var node := ActivityNode.new()
	node.capacity = 1
	var npc1 := Node.new()
	var npc2 := Node.new()

	node.occupy(npc1)
	node.occupy(npc2)  # Should be rejected — at capacity
	t.assert_eq(node.get_occupant_count(), 1, "Capacity 1: second NPC rejected")

	node.release(npc1)
	node.occupy(npc2)  # Should succeed now
	t.assert_eq(node.get_occupant_count(), 1, "After release, new NPC can occupy")

	node.release(npc2)
	npc1.free()
	npc2.free()


static func _test_multi_capacity(t: Variant) -> void:
	var node := ActivityNode.new()
	node.capacity = 3
	var npcs: Array[Node] = []
	for i: int in range(4):
		npcs.append(Node.new())

	for i: int in range(3):
		node.occupy(npcs[i])
	t.assert_eq(node.get_occupant_count(), 3, "3 NPCs occupy capacity-3 node")
	t.assert_true(node.is_occupied(), "Node at capacity reports occupied")

	node.occupy(npcs[3])  # Should be rejected
	t.assert_eq(node.get_occupant_count(), 3, "4th NPC rejected at capacity 3")

	for npc: Node in npcs:
		node.release(npc)
		npc.free()


static func _test_faction_allow_all(t: Variant) -> void:
	var node := ActivityNode.new()
	node.allowed_factions = PackedStringArray([])
	t.assert_true(node.can_use("lapd"), "Empty allowed_factions allows LAPD")
	t.assert_true(node.can_use("la_mirada"), "Empty allowed_factions allows La Mirada")
	t.assert_true(node.can_use("civilian"), "Empty allowed_factions allows civilian")
	t.assert_true(node.can_use(""), "Empty allowed_factions allows empty faction")


static func _test_faction_restriction(t: Variant) -> void:
	var node := ActivityNode.new()
	node.allowed_factions = PackedStringArray(["lapd"])
	t.assert_true(node.can_use("lapd"), "LAPD allowed at LAPD-only node")
	t.assert_false(node.can_use("la_mirada"), "La Mirada blocked at LAPD-only node")
	t.assert_false(node.can_use("civilian"), "Civilian blocked at LAPD-only node")
	t.assert_false(node.can_use(""), "Empty faction blocked at LAPD-only node")


static func _test_freed_reference_cleanup(t: Variant) -> void:
	var node := ActivityNode.new()
	node.capacity = 2
	var npc1 := Node.new()
	var npc2 := Node.new()

	node.occupy(npc1)
	node.occupy(npc2)
	t.assert_eq(node.get_occupant_count(), 2, "Two NPCs occupying")

	npc1.free()  # Simulate NPC despawn
	# is_occupied / get_occupant_count should clean up freed references
	t.assert_eq(node.get_occupant_count(), 1, "Freed NPC cleaned up from occupants")
	t.assert_false(node.is_occupied(), "Node not at capacity after freed NPC cleanup")

	node.release(npc2)
	npc2.free()


static func _test_specific_npc_release(t: Variant) -> void:
	var node := ActivityNode.new()
	node.capacity = 3
	var npc1 := Node.new()
	var npc2 := Node.new()
	var npc3 := Node.new()

	node.occupy(npc1)
	node.occupy(npc2)
	node.occupy(npc3)

	# Release middle NPC specifically
	node.release(npc2)
	t.assert_eq(node.get_occupant_count(), 2, "Specific release removes only that NPC")

	# npc2 can re-occupy now
	node.occupy(npc2)
	t.assert_eq(node.get_occupant_count(), 3, "Released NPC can re-occupy")

	for npc: Node in [npc1, npc2, npc3]:
		node.release(npc)
		npc.free()


static func _test_double_occupy_ignored(t: Variant) -> void:
	var node := ActivityNode.new()
	node.capacity = 2
	var npc := Node.new()

	node.occupy(npc)
	node.occupy(npc)  # Same NPC again — should be no-op
	t.assert_eq(node.get_occupant_count(), 1, "Double occupy by same NPC is ignored")

	node.release(npc)
	npc.free()


# --- OpportunityModule Integration ---

static func _test_opportunity_skips_occupied(t: Variant) -> void:
	var tree: SceneTree = t as SceneTree

	var activity := ActivityNode.new()
	activity.activity_type = "patrol"
	activity.capacity = 1
	activity.add_to_group("activity_nodes")
	tree.root.add_child(activity)

	var npc := MockNPC.new()
	npc._faction = "lapd"
	tree.root.add_child(npc)

	var data := NPCData.new()
	data.npc_name = "TestCop"
	data.archetype = "Cop"
	data.faction = "lapd"
	data.npc_id = "test_occ_%d" % randi()
	data.activity_preferences = {"patrol": 0.9}

	var abstract := AbstractNPC.new(data)
	var module := OpportunityModule.new()
	module.npc = npc
	module.abstract = abstract
	module.personality = abstract.personality

	# Evaluate with open node
	var score_open := module.evaluate()

	# Occupy the node with someone else
	var blocker := Node.new()
	activity.occupy(blocker)

	var score_occupied := module.evaluate()
	t.assert_gt(score_open, 0.0, "Opportunity scores > 0 for open patrol node")
	t.assert_approx(score_occupied, 0.0, 0.001,
		"Opportunity scores 0 when activity node occupied")

	# Cleanup
	activity.release(blocker)
	blocker.free()
	tree.root.remove_child(npc)
	npc.free()
	tree.root.remove_child(activity)
	activity.free()


static func _test_opportunity_skips_wrong_faction(t: Variant) -> void:
	var tree: SceneTree = t as SceneTree

	# LAPD-only patrol node
	var activity := ActivityNode.new()
	activity.activity_type = "patrol"
	activity.capacity = 1
	activity.allowed_factions = PackedStringArray(["lapd"])
	activity.add_to_group("activity_nodes")
	tree.root.add_child(activity)

	# La Mirada NPC — wrong faction
	var npc := MockNPC.new()
	npc._faction = "la_mirada"
	tree.root.add_child(npc)

	var data := NPCData.new()
	data.npc_name = "TestGang"
	data.archetype = "Gang"
	data.faction = "la_mirada"
	data.npc_id = "test_fac_%d" % randi()
	data.activity_preferences = {"patrol": 0.8}

	var abstract := AbstractNPC.new(data)
	var module := OpportunityModule.new()
	module.npc = npc
	module.abstract = abstract
	module.personality = abstract.personality

	var score := module.evaluate()
	t.assert_approx(score, 0.0, 0.001,
		"Opportunity returns 0 for faction-restricted node")

	tree.root.remove_child(npc)
	npc.free()
	tree.root.remove_child(activity)
	activity.free()


static func _test_opportunity_scores_open_node(t: Variant) -> void:
	var tree: SceneTree = t as SceneTree

	# Open patrol node at origin (same pos as NPC)
	var activity := ActivityNode.new()
	activity.activity_type = "patrol"
	activity.capacity = 1
	activity.allowed_factions = PackedStringArray([])
	activity.add_to_group("activity_nodes")
	tree.root.add_child(activity)

	var npc := MockNPC.new()
	npc._faction = "lapd"
	tree.root.add_child(npc)

	var data := NPCData.new()
	data.npc_name = "TestCop2"
	data.archetype = "Cop"
	data.faction = "lapd"
	data.npc_id = "test_open_%d" % randi()
	data.activity_preferences = {"patrol": 0.9}

	var abstract := AbstractNPC.new(data)
	var module := OpportunityModule.new()
	module.npc = npc
	module.abstract = abstract
	module.personality = abstract.personality

	var score := module.evaluate()
	t.assert_gt(score, 0.0,
		"Opportunity scores > 0 for open faction-matching node")

	tree.root.remove_child(npc)
	npc.free()
	tree.root.remove_child(activity)
	activity.free()
