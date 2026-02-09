## Tests for ReputationManager: faction dispositions, player rep, decay.
## ReputationManager is an autoload (extends Node), so we instantiate it directly.
extends RefCounted


static func _make_rep_manager() -> Node:
	# Create a standalone instance (not autoloaded) for testing
	var script: GDScript = load("res://addons/renegade_npc/core/reputation_manager.gd")
	var mgr: Node = script.new()
	return mgr


static func run(t: Variant) -> void:
	_test_same_faction_allied(t)
	_test_set_and_get_disposition(t)
	_test_disposition_symmetric_key(t)
	_test_modify_reputation(t)
	_test_reputation_clamped(t)
	_test_effective_rep_blend(t)
	_test_standings(t)
	_test_save_load_roundtrip(t)


static func _test_same_faction_allied(t: Variant) -> void:
	var mgr := _make_rep_manager()
	var disp: float = mgr.get_faction_disposition(NPCConfig.Factions.LA_MIRADA, NPCConfig.Factions.LA_MIRADA)
	t.assert_approx(disp, 1.0, 0.001, "Same faction disposition is 1.0")
	mgr.free()


static func _test_set_and_get_disposition(t: Variant) -> void:
	var mgr := _make_rep_manager()
	mgr.set_faction_disposition(NPCConfig.Factions.LA_MIRADA, NPCConfig.Factions.LAPD, -0.8)
	var disp: float = mgr.get_faction_disposition(NPCConfig.Factions.LA_MIRADA, NPCConfig.Factions.LAPD)
	t.assert_approx(disp, -0.8, 0.001, "Set/get disposition works")
	mgr.free()


static func _test_disposition_symmetric_key(t: Variant) -> void:
	var mgr := _make_rep_manager()
	mgr.set_faction_disposition("a_faction", "b_faction", -0.5)
	# Should be accessible from either direction
	var ab: float = mgr.get_faction_disposition("a_faction", "b_faction")
	var ba: float = mgr.get_faction_disposition("b_faction", "a_faction")
	t.assert_approx(ab, ba, 0.001, "Faction disposition is symmetric (a:b == b:a)")
	mgr.free()


static func _test_modify_reputation(t: Variant) -> void:
	var mgr := _make_rep_manager()
	mgr.modify_reputation(NPCConfig.Factions.LA_MIRADA, -20.0, "downtown_east")
	var city: float = mgr.city_reputation.get(NPCConfig.Factions.LA_MIRADA, 0.0)
	var district: float = mgr.district_reputation.get("downtown_east:" + NPCConfig.Factions.LA_MIRADA, 0.0)
	t.assert_approx(city, -10.0, 0.01, "City rep gets 50% of amount")
	t.assert_approx(district, -20.0, 0.01, "District rep gets full amount")
	mgr.free()


static func _test_reputation_clamped(t: Variant) -> void:
	var mgr := _make_rep_manager()
	# Exceed maximum
	for i: int in range(20):
		mgr.modify_reputation("test_faction", 50.0, "test_district")
	var city: float = mgr.city_reputation.get("test_faction", 0.0)
	t.assert_in_range(city, -100.0, 100.0, "City rep clamped to [-100, 100]")
	mgr.free()


static func _test_effective_rep_blend(t: Variant) -> void:
	var mgr := _make_rep_manager()
	# Set distinct city and district values
	mgr.city_reputation["test_faction"] = 80.0
	mgr.district_reputation["test_district:test_faction"] = 20.0
	var effective: float = mgr.get_effective_reputation("test_faction", "test_district")
	# blend = abs(80) / 100 = 0.8, so effective = lerp(20, 80, 0.8) = 68
	t.assert_approx(effective, 68.0, 0.1, "Effective rep blends city and district by city magnitude")
	mgr.free()


static func _test_standings(t: Variant) -> void:
	var mgr := _make_rep_manager()
	mgr.city_reputation["hostile_faction"] = -50.0
	mgr.city_reputation["neutral_faction"] = 0.0
	mgr.city_reputation["friendly_faction"] = 40.0
	mgr.city_reputation["allied_faction"] = 70.0

	t.assert_eq(mgr.get_player_standing("hostile_faction"), "hostile", "Standing: hostile at -50")
	t.assert_eq(mgr.get_player_standing("neutral_faction"), "neutral", "Standing: neutral at 0")
	t.assert_eq(mgr.get_player_standing("friendly_faction"), "friendly", "Standing: friendly at 40")
	t.assert_eq(mgr.get_player_standing("allied_faction"), "allied", "Standing: allied at 70")
	mgr.free()


static func _test_save_load_roundtrip(t: Variant) -> void:
	var mgr := _make_rep_manager()
	mgr.set_faction_disposition("a", "b", -0.6)
	mgr.modify_reputation("test", -30.0, "district1")

	var saved: Dictionary = mgr.save_state()
	mgr.free()

	var mgr2 := _make_rep_manager()
	mgr2.load_state(saved)

	t.assert_approx(mgr2.get_faction_disposition("a", "b"), -0.6, 0.001, "Saved faction disposition roundtrips")
	t.assert_approx(mgr2.city_reputation.get("test", 0.0), -15.0, 0.1, "Saved city rep roundtrips")
	mgr2.free()
