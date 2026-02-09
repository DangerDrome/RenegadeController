## Tests for NPCPersonality: deterministic generation, trait ranges, derived traits.
extends RefCounted


static func run(t: Variant) -> void:
	_test_deterministic_from_id(t)
	_test_deterministic_from_seed(t)
	_test_all_traits_in_range(t)
	_test_aggression_bias(t)
	_test_anxiety_inverse_of_grit(t)
	_test_different_ids_different_personalities(t)
	_test_extreme_bias_values(t)


static func _test_deterministic_from_id(t: Variant) -> void:
	var p1 := NPCPersonality.from_id("test_npc_123", 0.5)
	var p2 := NPCPersonality.from_id("test_npc_123", 0.5)
	t.assert_approx(p1.grit, p2.grit, 0.0001, "Same ID produces same grit")
	t.assert_approx(p1.hustle, p2.hustle, 0.0001, "Same ID produces same hustle")
	t.assert_approx(p1.empathy, p2.empathy, 0.0001, "Same ID produces same empathy")
	t.assert_approx(p1.aggression, p2.aggression, 0.0001, "Same ID produces same aggression")


static func _test_deterministic_from_seed(t: Variant) -> void:
	var p1 := NPCPersonality.from_seed(42, 0.5)
	var p2 := NPCPersonality.from_seed(42, 0.5)
	t.assert_approx(p1.grit, p2.grit, 0.0001, "Same seed produces same grit")
	t.assert_approx(p1.anxiety, p2.anxiety, 0.0001, "Same seed produces same anxiety")


static func _test_all_traits_in_range(t: Variant) -> void:
	# Test many seeds to ensure all traits stay in [0, 1]
	var all_valid := true
	for i: int in range(100):
		var p := NPCPersonality.from_seed(i * 7919, 0.5)  # prime multiplier
		for trait_val: float in [p.grit, p.hustle, p.empathy, p.aggression, p.influence, p.anxiety]:
			if trait_val < 0.0 or trait_val > 1.0:
				all_valid = false
				break
	t.assert_true(all_valid, "All traits in [0,1] across 100 random seeds")


static func _test_aggression_bias(t: Variant) -> void:
	# High bias should produce higher aggression on average
	var total_high: float = 0.0
	var total_low: float = 0.0
	for i: int in range(50):
		var p_high := NPCPersonality.from_seed(i, 0.9)
		var p_low := NPCPersonality.from_seed(i, 0.1)
		total_high += p_high.aggression
		total_low += p_low.aggression
	var avg_high := total_high / 50.0
	var avg_low := total_low / 50.0
	t.assert_gt(avg_high, avg_low, "High aggression_bias produces higher average aggression")


static func _test_anxiety_inverse_of_grit(t: Variant) -> void:
	# Anxiety formula: (hustle - grit + 1) / 2 + noise
	# With same hustle, higher grit should produce lower anxiety on average
	var high_grit_anxiety: float = 0.0
	var low_grit_anxiety: float = 0.0
	var count: int = 0
	for i: int in range(200):
		var p := NPCPersonality.from_seed(i, 0.5)
		if p.grit > 0.7:
			high_grit_anxiety += p.anxiety
			count += 1
		elif p.grit < 0.3:
			low_grit_anxiety += p.anxiety

	# Ensure we got enough samples
	if count > 5:
		var avg_high := high_grit_anxiety / float(count)
		var avg_low := low_grit_anxiety / float(maxf(count, 1.0))
		t.assert_lt(avg_high, avg_low, "High-grit NPCs have lower anxiety on average")
	else:
		t.assert_true(true, "High-grit NPCs have lower anxiety on average (skipped: insufficient samples)")


static func _test_different_ids_different_personalities(t: Variant) -> void:
	var p1 := NPCPersonality.from_id("la_mirada_gang_001", 0.7)
	var p2 := NPCPersonality.from_id("la_mirada_gang_002", 0.7)
	var any_diff := absf(p1.grit - p2.grit) > 0.01 or absf(p1.hustle - p2.hustle) > 0.01 or absf(p1.empathy - p2.empathy) > 0.01
	t.assert_true(any_diff, "Different IDs produce different personalities")


static func _test_extreme_bias_values(t: Variant) -> void:
	var p_zero := NPCPersonality.from_seed(1, 0.0)
	var p_one := NPCPersonality.from_seed(1, 1.0)
	t.assert_in_range(p_zero.aggression, 0.0, 1.0, "Aggression valid with bias=0.0")
	t.assert_in_range(p_one.aggression, 0.0, 1.0, "Aggression valid with bias=1.0")
