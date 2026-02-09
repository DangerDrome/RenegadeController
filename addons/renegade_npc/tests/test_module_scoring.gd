## Tests for utility module scoring logic.
## Uses mock NPC/abstract data to test module evaluate() in isolation.
extends RefCounted


static func run(t: Variant) -> void:
	_test_idle_baseline(t)
	_test_idle_range(t)
	_test_threat_zero_without_threats(t)
	_test_threat_gunfire_decays(t)
	_test_threat_health_factor(t)
	_test_flee_zero_at_full_health(t)
	_test_flee_high_at_critical_health(t)
	_test_flee_noncombatant_bonus(t)
	_test_weighted_score(t)
	_test_module_drive_names_unique(t)


## Create a minimal mock NPC setup for testing modules.
## Returns [AbstractNPC, mock_npc_node] — the "npc node" is just a RefCounted stub.
static func _make_mock(archetype: String = "Civilian", faction: String = "civilian",
		combatant: bool = false, aggression: float = 0.3) -> Array:
	var data := NPCData.new()
	data.npc_name = "TestNPC"
	data.archetype = archetype
	data.faction = faction
	data.is_combatant = combatant
	data.aggression_bias = aggression
	data.npc_id = "test_%d" % randi()

	var abstract := AbstractNPC.new(data)

	# Modules check `if not npc` as a null guard and call
	# npc.get_node_or_null(). We provide a bare Node stub so those
	# calls succeed (returning null children, which is safe).
	var stub := Node.new()
	return [abstract, stub]


static func _setup_module(module: UtilityModule, abstract: AbstractNPC, npc: Variant) -> void:
	module.npc = npc
	module.abstract = abstract
	module.personality = abstract.personality


# --- IdleModule ---

static func _test_idle_baseline(t: Variant) -> void:
	var mock := _make_mock()
	var abstract: AbstractNPC = mock[0]
	var module := IdleModule.new()
	_setup_module(module, abstract, mock[1])
	var score := module.evaluate()
	t.assert_in_range(score, 0.05, 0.3, "Idle score is in [0.05, 0.3]")


static func _test_idle_range(t: Variant) -> void:
	# Test across many personalities to ensure idle stays bounded
	var all_valid := true
	for i: int in range(50):
		var data := NPCData.new()
		data.npc_id = "idle_range_%d" % i
		data.aggression_bias = randf()
		var abstract := AbstractNPC.new(data)
		var module := IdleModule.new()
		_setup_module(module, abstract, null)
		var score := module.evaluate()
		if score < 0.05 or score > 0.3:
			all_valid = false
	t.assert_true(all_valid, "Idle score stays in [0.05, 0.3] across 50 personalities")


# --- ThreatModule ---

static func _test_threat_zero_without_threats(t: Variant) -> void:
	var mock := _make_mock()
	var abstract: AbstractNPC = mock[0]
	var module := ThreatModule.new()
	_setup_module(module, abstract, mock[1])
	# No npc node = no detection area, no gunfire, full health
	var score := module.evaluate()
	t.assert_approx(score, 0.0, 0.001, "Threat is zero with no threats, full health, no gunfire")


static func _test_threat_gunfire_decays(t: Variant) -> void:
	var mock := _make_mock()
	var abstract: AbstractNPC = mock[0]
	var module := ThreatModule.new()
	_setup_module(module, abstract, mock[1])

	# Simulate gunfire at time T
	module._last_gunfire_time = Time.get_ticks_msec() / 1000.0

	# Immediately after: threat should be elevated (health still full, no detection)
	var score_now := module.evaluate()
	t.assert_gt(score_now, 0.1, "Threat elevated immediately after gunfire")

	# Simulate 6 seconds later (past GUNFIRE_DECAY_SECONDS = 5.0)
	module._last_gunfire_time = (Time.get_ticks_msec() / 1000.0) - 6.0
	var score_later := module.evaluate()
	t.assert_approx(score_later, 0.0, 0.001, "Threat zero after gunfire decay period")


static func _test_threat_health_factor(t: Variant) -> void:
	var mock := _make_mock()
	var abstract: AbstractNPC = mock[0]
	var module := ThreatModule.new()
	_setup_module(module, abstract, mock[1])

	# Full health: no health-based threat
	var score_full := module.evaluate()

	# Low health: should add threat
	abstract.current_health = 30  # 30/100 = 0.3 ratio, below 0.5 threshold
	var score_low := module.evaluate()
	t.assert_gt(score_low, score_full, "Low health increases threat perception")


# --- FleeModule ---

static func _test_flee_zero_at_full_health(t: Variant) -> void:
	var mock := _make_mock()
	var abstract: AbstractNPC = mock[0]
	var module := FleeModule.new()
	_setup_module(module, abstract, mock[1])
	var score := module.evaluate()
	t.assert_approx(score, 0.0, 0.001, "Flee is zero at full health")


static func _test_flee_high_at_critical_health(t: Variant) -> void:
	var mock := _make_mock()
	var abstract: AbstractNPC = mock[0]
	var module := FleeModule.new()
	_setup_module(module, abstract, mock[1])
	abstract.current_health = 10  # 10/100 = 0.1 ratio
	var score := module.evaluate()
	t.assert_gt(score, 0.2, "Flee is significant at critical health")


static func _test_flee_noncombatant_bonus(t: Variant) -> void:
	# Non-combatant at low health should flee more urgently
	var mock_civ := _make_mock("Civilian", "civilian", false)
	var abstract_civ: AbstractNPC = mock_civ[0]
	abstract_civ.current_health = 20
	var module_civ := FleeModule.new()
	_setup_module(module_civ, abstract_civ, mock_civ[1])
	var score_civ := module_civ.evaluate()

	var mock_gang := _make_mock("Gang", NPCConfig.Factions.LA_MIRADA, true, 0.8)
	var abstract_gang: AbstractNPC = mock_gang[0]
	abstract_gang.current_health = 20
	var module_gang := FleeModule.new()
	_setup_module(module_gang, abstract_gang, mock_gang[1])
	var score_gang := module_gang.evaluate()

	t.assert_gt(score_civ, score_gang, "Non-combatants flee more readily than combatants at same health")


# --- General ---

static func _test_weighted_score(t: Variant) -> void:
	var mock := _make_mock()
	var abstract: AbstractNPC = mock[0]
	var module := IdleModule.new()
	_setup_module(module, abstract, mock[1])
	module.weight = 2.0
	var base := module.evaluate()
	var weighted := module.get_weighted_score()
	t.assert_approx(weighted, base * 2.0, 0.001, "Weighted score = evaluate() * weight")


static func _test_module_drive_names_unique(t: Variant) -> void:
	# ThreatModule should return "threat", FleeModule should return "flee"
	# They must be different for drive change detection to work
	var threat := ThreatModule.new()
	var flee := FleeModule.new()
	t.assert_true(threat.get_drive_name() != flee.get_drive_name(),
		"ThreatModule and FleeModule have different drive names ('%s' vs '%s')" % [
			threat.get_drive_name(), flee.get_drive_name()
		])
	t.assert_eq(threat.get_drive_name(), "threat", "ThreatModule drive is 'threat'")
	t.assert_eq(flee.get_drive_name(), "flee", "FleeModule drive is 'flee'")
