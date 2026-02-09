## Tests for SocialMemory: decay, disposition, serialization.
extends RefCounted


static func run(t: Variant) -> void:
	_test_initial_state(t)
	_test_positive_interaction(t)
	_test_negative_interaction(t)
	_test_disposition_range(t)
	_test_decay(t)
	_test_decay_clears_temp(t)
	_test_persistent_fear_slow_decay(t)
	_test_serialization_roundtrip(t)
	_test_know_accumulates(t)
	_test_trust_requires_know(t)


static func _test_initial_state(t: Variant) -> void:
	var mem := SocialMemory.new()
	t.assert_approx(mem.get_disposition(), 0.0, 0.001, "New memory has zero disposition")
	t.assert_approx(mem.get_trust(), 0.0, 0.001, "New memory has zero trust")


static func _test_positive_interaction(t: Variant) -> void:
	var mem := SocialMemory.new()
	mem.add_positive(0.5, 0.0)
	t.assert_gt(mem.get_disposition(), 0.0, "Positive interaction increases disposition")
	t.assert_gt(mem.temp_like, 0.0, "Positive interaction sets temp_like")
	t.assert_gt(mem.like, 0.0, "Positive interaction builds persistent like")


static func _test_negative_interaction(t: Variant) -> void:
	var mem := SocialMemory.new()
	mem.add_negative(0.5, 0.0)
	t.assert_lt(mem.get_disposition(), 0.0, "Negative interaction decreases disposition")
	t.assert_gt(mem.temp_fear, 0.0, "Negative interaction sets temp_fear")
	t.assert_gt(mem.fear, 0.0, "Negative interaction builds persistent fear")


static func _test_disposition_range(t: Variant) -> void:
	var mem := SocialMemory.new()
	# Max out positive
	for i: int in range(20):
		mem.add_positive(1.0, 0.0)
	t.assert_in_range(mem.get_disposition(), -1.0, 1.0, "Disposition clamped to [-1, 1] at max positive")

	# Max out negative
	mem = SocialMemory.new()
	for i: int in range(20):
		mem.add_negative(1.0, 0.0)
	t.assert_in_range(mem.get_disposition(), -1.0, 1.0, "Disposition clamped to [-1, 1] at max negative")


static func _test_decay(t: Variant) -> void:
	var mem := SocialMemory.new()
	mem.add_negative(0.8, 0.0)
	var before := mem.temp_fear
	mem.decay(0.1)
	t.assert_lt(mem.temp_fear, before, "Decay reduces temp_fear")


static func _test_decay_clears_temp(t: Variant) -> void:
	var mem := SocialMemory.new()
	mem.add_negative(0.3, 0.0)
	# Decay enough to fully clear temp_fear
	for i: int in range(10):
		mem.decay(0.1)
	t.assert_approx(mem.temp_fear, 0.0, 0.001, "Repeated decay fully clears temp_fear")


static func _test_persistent_fear_slow_decay(t: Variant) -> void:
	var mem := SocialMemory.new()
	mem.add_negative(1.0, 0.0)
	var fear_before := mem.fear
	# Decay with no like (fear should slowly decay)
	for i: int in range(50):
		mem.decay(0.1)
	t.assert_lt(mem.fear, fear_before, "Persistent fear decays slowly when like is zero")
	t.assert_gt(mem.fear, 0.0, "Persistent fear doesn't fully disappear after moderate decay")


static func _test_serialization_roundtrip(t: Variant) -> void:
	var mem := SocialMemory.new()
	mem.add_positive(0.4, 1.0)
	mem.add_negative(0.2, 2.0)

	var dict := mem.to_dict()
	var restored := SocialMemory.from_dict(dict)

	t.assert_approx(restored.like, mem.like, 0.02, "Serialized like roundtrips")
	t.assert_approx(restored.fear, mem.fear, 0.02, "Serialized fear roundtrips")
	t.assert_approx(restored.temp_like, mem.temp_like, 0.02, "Serialized temp_like roundtrips")
	t.assert_approx(restored.temp_fear, mem.temp_fear, 0.02, "Serialized temp_fear roundtrips")


static func _test_know_accumulates(t: Variant) -> void:
	var mem := SocialMemory.new()
	mem.add_positive(0.1, 0.0)
	mem.add_negative(0.1, 0.0)
	mem.add_positive(0.1, 0.0)
	t.assert_approx(mem.know, 0.15, 0.001, "Know accumulates with each interaction (+0.05 each)")
	t.assert_eq(mem.interaction_count, 3, "Interaction count tracks correctly")


static func _test_trust_requires_know(t: Variant) -> void:
	var mem := SocialMemory.new()
	mem.like = 1.0
	mem.know = 0.0
	t.assert_approx(mem.get_trust(), 0.0, 0.001, "Trust is zero when know is zero, even with max like")

	mem.know = 0.5
	t.assert_gt(mem.get_trust(), 0.0, "Trust increases when know increases")
