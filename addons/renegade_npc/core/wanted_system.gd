## WantedSystem: Tracks player heat level with law enforcement.
## Heat accumulates from crimes, decays when not observed by cops.
## Persists across scenes (saved/loaded by NPCManager).
##
## Levels 0-5:
##   0 = Clear - Normal patrol
##   1 = Suspicious - Cops approach/question
##   2 = Wanted - Cops pursue on sight
##   3 = Armed Response - Multiple cops, aggressive
##   4 = SWAT - Tactical teams
##   5 = Lethal Force - Shoot on sight
class_name WantedSystem
extends RefCounted

## Emitted when wanted level changes.
signal wanted_level_changed(old_level: int, new_level: int)

## Emitted when heat changes significantly.
signal heat_changed(new_heat: float)

## Current wanted level (0-5).
var current_level: int = 0

## Raw heat value — level = floor(heat / HEAT_PER_LEVEL), capped at 5.
var heat: float = 0.0

## Time since last crime was committed.
var time_since_crime: float = INF

## Whether any cop currently has LOS on the player.
var is_being_observed: bool = false

## Reference to player node (set by NPCManager).
var player: Node3D = null


## Update decay logic. Call every frame from NPCManager._process().
func update(delta: float, p_is_observed: bool) -> void:
	is_being_observed = p_is_observed
	time_since_crime += delta

	# Decay heat when not observed and enough time has passed since crime
	if not is_being_observed and time_since_crime >= NPCConfig.Wanted.DECAY_DELAY:
		heat = maxf(heat - NPCConfig.Wanted.DECAY_RATE * delta, 0.0)
		_update_level()


## Report a crime committed by the player.
func report_crime(crime_type: String) -> void:
	var crime_heat: float = NPCConfig.Wanted.CRIMES.get(crime_type, 10.0)
	heat += crime_heat
	time_since_crime = 0.0
	heat_changed.emit(heat)
	_update_level()


## Add raw heat directly (for custom events).
func add_heat(amount: float) -> void:
	heat += amount
	time_since_crime = 0.0
	heat_changed.emit(heat)
	_update_level()


## Remove heat (for bribes, time passing, etc).
func remove_heat(amount: float) -> void:
	heat = maxf(heat - amount, 0.0)
	heat_changed.emit(heat)
	_update_level()


## Force set a specific level (for debug/story events).
func set_level(level: int) -> void:
	var old := current_level
	current_level = clampi(level, 0, 5)
	heat = current_level * NPCConfig.Wanted.HEAT_PER_LEVEL
	if current_level != old:
		wanted_level_changed.emit(old, current_level)


## Clear all wanted status.
func clear() -> void:
	var old := current_level
	heat = 0.0
	current_level = 0
	time_since_crime = INF
	if old != 0:
		wanted_level_changed.emit(old, 0)
	heat_changed.emit(0.0)


func _update_level() -> void:
	var new_level: int = clampi(int(heat / NPCConfig.Wanted.HEAT_PER_LEVEL), 0, 5)
	if new_level != current_level:
		var old := current_level
		current_level = new_level
		wanted_level_changed.emit(old, new_level)


## Get a human-readable status string.
func get_status_string() -> String:
	match current_level:
		0: return "Clear"
		1: return "Suspicious"
		2: return "Wanted"
		3: return "Armed Response"
		4: return "SWAT"
		5: return "Lethal Force"
		_: return "Unknown"


## Get how aggressively cops should behave (0.0 - 1.0).
func get_aggression_modifier() -> float:
	return clampf(current_level / 5.0, 0.0, 1.0)


## Returns true if cops should pursue the player on sight.
func should_pursue() -> bool:
	return current_level >= 2


## Returns true if cops should use lethal force.
func should_use_lethal_force() -> bool:
	return current_level >= 5


## Save state for persistence.
func save() -> Dictionary:
	return {
		"heat": heat,
		"current_level": current_level,
		"time_since_crime": time_since_crime,
	}


## Load state from saved data.
func load_state(data: Dictionary) -> void:
	heat = data.get("heat", 0.0)
	current_level = data.get("current_level", 0)
	time_since_crime = data.get("time_since_crime", INF)
