## Tests for flee state recovery: verifies that NPCs can transition
## out of threat/flee states as conditions change.
## Simulates the module scoring competition over time.
extends RefCounted


static func run(t: Variant) -> void:
	_test_threat_drops_below_idle_after_gunfire_decay(t)
	_test_flee_drops_when_health_recovers(t)
	_test_drive_competition_scenario(t)
	_test_temp_fear_decay_restores_disposition(t)
	_test_combined_threat_flee_recovery(t)


## Helper: create a full module set and evaluate the winning drive.
static func _evaluate_all(modules: Array[UtilityModule]) -> Dictionary:
	var best_module: UtilityModule = null
	var best_score: float = -1.0
	var scores: Dictionary = {}

	for module: UtilityModule in modules:
		var score: float = module.get_weighted_score()
		scores[module.get_drive_name()] = score
		if score > best_score:
			best_score = score
			best_module = module

	return {
		"drive": best_module.get_drive_name() if best_module else "none",
		"score": best_score,
		"scores": scores,
	}


static func _make_abstract(archetype: String = "Civilian", aggression: float = 0.3,
		combatant: bool = false) -> AbstractNPC:
	var data := NPCData.new()
	data.npc_name = "TestNPC"
	data.archetype = archetype
	data.faction = "civilian"
	data.is_combatant = combatant
	data.aggression_bias = aggression
	data.npc_id = "test_flee_%d" % randi()
	return AbstractNPC.new(data)


static func _make_modules(abstract: AbstractNPC) -> Array[UtilityModule]:
	var stub := Node.new()  # Node stub so get_node_or_null() calls succeed
	var modules: Array[UtilityModule] = []
	for ModuleClass: Variant in [IdleModule, ThreatModule, FleeModule]:
		var m: UtilityModule = ModuleClass.new()
		m.npc = stub
		m.abstract = abstract
		m.personality = abstract.personality
		modules.append(m)
	return modules


static func _test_threat_drops_below_idle_after_gunfire_decay(t: Variant) -> void:
	var abstract := _make_abstract()
	var modules := _make_modules(abstract)

	# Find threat module and trigger gunfire
	var threat_mod: ThreatModule = null
	for m: UtilityModule in modules:
		if m is ThreatModule:
			threat_mod = m as ThreatModule

	# Simulate gunfire right now
	threat_mod._last_gunfire_time = Time.get_ticks_msec() / 1000.0
	var result_now := _evaluate_all(modules)
	t.assert_eq(result_now["drive"], "threat", "Threat wins immediately after gunfire")

	# Simulate gunfire 6 seconds ago (past the 5s decay)
	threat_mod._last_gunfire_time = (Time.get_ticks_msec() / 1000.0) - 6.0
	var result_later := _evaluate_all(modules)
	t.assert_eq(result_later["drive"], "idle", "Idle wins after gunfire decays")


static func _test_flee_drops_when_health_recovers(t: Variant) -> void:
	var abstract := _make_abstract("Civilian", 0.1, false)
	var modules := _make_modules(abstract)

	# Critical health
	abstract.current_health = 10
	var result_low := _evaluate_all(modules)

	# Restore health
	abstract.current_health = abstract.data.max_health
	var result_full := _evaluate_all(modules)

	t.assert_gt(result_low["scores"].get("flee", 0.0), result_full["scores"].get("flee", 0.0),
		"Flee score drops when health is restored")
	t.assert_approx(result_full["scores"].get("flee", 0.0), 0.0, 0.001,
		"Flee score is zero at full health")


static func _test_drive_competition_scenario(t: Variant) -> void:
	# Scenario: gunfire happens, threat wins. Time passes, idle should recover.
	var abstract := _make_abstract()
	var modules := _make_modules(abstract)

	var threat_mod: ThreatModule = null
	for m: UtilityModule in modules:
		if m is ThreatModule:
			threat_mod = m as ThreatModule

	# Step 1: Gunfire just happened
	threat_mod._last_gunfire_time = Time.get_ticks_msec() / 1000.0
	var step1 := _evaluate_all(modules)

	# Step 2: 2.5 seconds later (partial decay)
	threat_mod._last_gunfire_time = (Time.get_ticks_msec() / 1000.0) - 2.5
	var step2 := _evaluate_all(modules)

	# Step 3: 5+ seconds later (full decay)
	threat_mod._last_gunfire_time = (Time.get_ticks_msec() / 1000.0) - 5.5
	var step3 := _evaluate_all(modules)

	t.assert_eq(step1["drive"], "threat", "Step 1: Threat wins at t=0")
	t.assert_gt(step2["scores"].get("threat", 0.0), step3["scores"].get("threat", 0.0),
		"Step 2→3: Threat score decreases over time")
	t.assert_eq(step3["drive"], "idle", "Step 3: Idle wins after full decay")


static func _test_temp_fear_decay_restores_disposition(t: Variant) -> void:
	var mem := SocialMemory.new()
	mem.add_negative(0.8, 0.0)
	var initial_disp := mem.get_disposition()
	t.assert_lt(initial_disp, -0.3, "Disposition is strongly negative after fear event")

	# Simulate real-time decay (what _evaluate_utilities does: 0.04 * 0.25 per tick)
	var decay_per_tick: float = 0.25 * 0.04  # UTILITY_EVAL_INTERVAL * 0.04
	for i: int in range(100):  # 100 ticks * 0.25s = 25 seconds
		mem.temp_fear = maxf(mem.temp_fear - decay_per_tick, 0.0)

	t.assert_approx(mem.temp_fear, 0.0, 0.01, "temp_fear decays to ~0 after 25s of real-time decay")
	t.assert_gt(mem.get_disposition(), initial_disp, "Disposition improves as temp_fear decays")


static func _test_combined_threat_flee_recovery(t: Variant) -> void:
	# Full scenario: NPC takes damage + hears gunfire, both should eventually recover
	var abstract := _make_abstract("Civilian", 0.1, false)
	var modules := _make_modules(abstract)

	var threat_mod: ThreatModule = null
	for m: UtilityModule in modules:
		if m is ThreatModule:
			threat_mod = m as ThreatModule

	# Damage NPC and trigger gunfire
	abstract.current_health = 40  # 40% health
	threat_mod._last_gunfire_time = Time.get_ticks_msec() / 1000.0

	var result_panic: Dictionary = _evaluate_all(modules)
	var panic_drive: String = result_panic["drive"]
	t.assert_true(panic_drive == "threat" or panic_drive == "flee",
		"Threat or flee wins during panic (drive=%s)" % panic_drive)

	# Heal and let gunfire decay
	abstract.current_health = abstract.data.max_health
	threat_mod._last_gunfire_time = (Time.get_ticks_msec() / 1000.0) - 10.0

	var result_calm := _evaluate_all(modules)
	t.assert_eq(result_calm["drive"], "idle",
		"Idle wins after health restored and gunfire decayed")
