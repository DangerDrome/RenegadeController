## ReputationManager: Manages faction-to-faction dispositions and
## player reputation per-district and city-wide.
## Autoloaded by the plugin.
##
## Reputation model (Rain World inspired):
##   - District Reputation: per-district, per-faction standing with the player
##   - City-wide Reputation: global standing with a faction
##   - Effective: lerp(district, citywide, abs(citywide) / 100.0)
##   - Individual NPC memory layered on top via SocialMemory
extends Node

## Emitted when player reputation with a faction crosses a threshold.
signal reputation_threshold_crossed(faction: String, new_level: String)

## --- Faction Dispositions ---
## Static faction-to-faction relationships. Key = "factionA:factionB", Value = -1.0 to 1.0.
## Negative = hostile, 0 = neutral, Positive = friendly.
var faction_dispositions: Dictionary = {}

## --- Player Reputation ---
## City-wide: Key = faction, Value = float (-100 to 100)
var city_reputation: Dictionary = {}
## District-level: Key = "district:faction", Value = float (-100 to 100)
var district_reputation: Dictionary = {}

## Reputation thresholds
var HOSTILE_THRESHOLD: float = NPCConfig.Reputation.HOSTILE_THRESHOLD
var NEUTRAL_LOW: float = NPCConfig.Reputation.NEUTRAL_LOW
var NEUTRAL_HIGH: float = NPCConfig.Reputation.NEUTRAL_HIGH
var FRIENDLY_THRESHOLD: float = NPCConfig.Reputation.FRIENDLY_THRESHOLD
var ALLIED_THRESHOLD: float = NPCConfig.Reputation.ALLIED_THRESHOLD


func _ready() -> void:
	# Connect to GameClock for periodic reputation decay
	var clock = get_node_or_null("/root/GameClock")
	if clock:
		clock.cycle_tick.connect(_on_cycle_tick)


## --- SETUP ---

## Register a faction-to-faction disposition.
## Example: set_faction_disposition("la_mirada", "lapd", -0.8)
func set_faction_disposition(faction_a: String, faction_b: String, disposition: float) -> void:
	var key := _faction_key(faction_a, faction_b)
	faction_dispositions[key] = clampf(disposition, -1.0, 1.0)


## Get how faction_a feels about faction_b. Returns -1.0 to 1.0.
func get_faction_disposition(faction_a: String, faction_b: String) -> float:
	if faction_a == faction_b:
		return 1.0  # Same faction = allied
	var key := _faction_key(faction_a, faction_b)
	return faction_dispositions.get(key, 0.0)


## --- PLAYER REPUTATION ---

## Modify player reputation with a faction in a specific district.
func modify_reputation(faction: String, amount: float, district: String = "") -> void:
	# City-wide always gets a portion
	var city_current: float = city_reputation.get(faction, 0.0)
	city_reputation[faction] = clampf(city_current + amount * 0.5, -100.0, 100.0)
	
	# District-specific gets the full amount
	if not district.is_empty():
		var key := "%s:%s" % [district, faction]
		var dist_current: float = district_reputation.get(key, 0.0)
		district_reputation[key] = clampf(dist_current + amount, -100.0, 100.0)
	
	# Check thresholds
	var effective := get_effective_reputation(faction, district)
	var level := _get_reputation_level(effective)
	reputation_threshold_crossed.emit(faction, level)


## Get effective player reputation with a faction in a district.
## Uses Rain World's lerp formula: lerp(district, city, abs(city) / 100)
func get_effective_reputation(faction: String, district: String = "") -> float:
	var city_rep: float = city_reputation.get(faction, 0.0)
	
	if district.is_empty():
		return city_rep
	
	var key := "%s:%s" % [district, faction]
	var dist_rep: float = district_reputation.get(key, 0.0)
	
	# The more extreme the city-wide rep, the more it dominates
	var blend: float = absf(city_rep) / 100.0
	return lerpf(dist_rep, city_rep, blend)


## Get the reputation level string for a given value.
func _get_reputation_level(value: float) -> String:
	if value >= ALLIED_THRESHOLD:
		return "allied"
	elif value >= FRIENDLY_THRESHOLD:
		return "friendly"
	elif value > HOSTILE_THRESHOLD:
		return "neutral"
	else:
		return "hostile"


## Get reputation level for player with a faction.
func get_player_standing(faction: String, district: String = "") -> String:
	return _get_reputation_level(get_effective_reputation(faction, district))


## Get all city-wide faction reputations. Returns a dictionary of faction -> reputation value.
## This is a shallow copy - safe to iterate without modifying the internal state.
func get_city_reputation() -> Dictionary:
	return city_reputation.duplicate()


## Get all district-level reputations. Returns a dictionary of "district:faction" -> reputation value.
## This is a shallow copy - safe to iterate without modifying the internal state.
func get_district_reputation() -> Dictionary:
	return district_reputation.duplicate()


## Get all faction dispositions. Returns a dictionary of "factionA:factionB" -> disposition value.
## This is a shallow copy - safe to iterate without modifying the internal state.
func get_faction_dispositions() -> Dictionary:
	return faction_dispositions.duplicate()


## --- CYCLE DECAY ---

func _on_cycle_tick() -> void:
	# Slight natural drift toward neutral (forgiveness mechanic)
	for faction: String in city_reputation:
		var rep: float = city_reputation[faction]
		if rep < 0.0:
			city_reputation[faction] = minf(rep + 1.0, 0.0)
	
	for key: String in district_reputation:
		var rep: float = district_reputation[key]
		if rep < 0.0:
			district_reputation[key] = minf(rep + 2.0, 0.0)


## --- UTILITY ---

func _faction_key(a: String, b: String) -> String:
	# Always alphabetical so A:B == B:A
	if a < b:
		return "%s:%s" % [a, b]
	return "%s:%s" % [b, a]


## --- SAVE/LOAD ---

func save_state() -> Dictionary:
	return {
		"faction_dispositions": faction_dispositions.duplicate(),
		"city_reputation": city_reputation.duplicate(),
		"district_reputation": district_reputation.duplicate(),
	}


func load_state(state: Dictionary) -> void:
	faction_dispositions = state.get("faction_dispositions", {})
	city_reputation = state.get("city_reputation", {})
	district_reputation = state.get("district_reputation", {})
