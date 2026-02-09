## ThreatModule: Evaluates danger level from nearby hostile entities,
## gunfire, explosions, and player wanted level.
## When dominant: NPC flees or seeks cover.
class_name ThreatModule
extends UtilityModule

## How far to scan for threats (uses DetectionArea if available)
var scan_range: float = 20.0

## Internal state
var _current_threat_level: float = 0.0
var _threat_sources: Array[Node3D] = []
var _last_gunfire_time: float = -100.0
## Gunfire uses real-time seconds (Time.get_ticks_msec) for responsive decay.
var GUNFIRE_DECAY_SECONDS: float = NPCConfig.Threat.GUNFIRE_DECAY


func get_module_name() -> String:
	return "ThreatModule"


func get_drive_name() -> String:
	return "threat"


func evaluate() -> float:
	if not npc or not abstract:
		return 0.0

	_current_threat_level = 0.0
	_threat_sources.clear()

	# Check for hostile entities in detection range
	var detection_area: Area3D = npc.get_node_or_null("DetectionArea")
	if detection_area:
		for body: Node3D in detection_area.get_overlapping_bodies():
			if body == npc:
				continue
			if _is_threat(body):
				_threat_sources.append(body)
				var distance: float = npc.global_position.distance_to(body.global_position)
				var proximity_score: float = 1.0 - clampf(distance / scan_range, 0.0, 1.0)
				_current_threat_level += proximity_score * NPCConfig.Threat.PROXIMITY_WEIGHT

	# Health factor - lower health = higher threat perception
	var health_ratio: float = float(abstract.current_health) / float(abstract.data.max_health)
	if health_ratio < NPCConfig.Threat.HEALTH_THRESHOLD:
		_current_threat_level += (1.0 - health_ratio) * NPCConfig.Threat.HEALTH_WEIGHT

	# Recent gunfire nearby — uses real-time seconds for responsive decay
	var now: float = Time.get_ticks_msec() / 1000.0
	var time_since_gunfire: float = now - _last_gunfire_time
	if time_since_gunfire < GUNFIRE_DECAY_SECONDS:
		_current_threat_level += (1.0 - time_since_gunfire / GUNFIRE_DECAY_SECONDS) * NPCConfig.Threat.GUNFIRE_WEIGHT

	# Personality modifies threat perception
	# High anxiety = perceive more threat; high grit = perceive less
	_current_threat_level *= (1.0 + personality.anxiety * NPCConfig.Threat.ANXIETY_MULT - personality.grit * NPCConfig.Threat.GRIT_REDUCER)

	return clampf(_current_threat_level, 0.0, 1.0)


func _is_threat(body: Node3D) -> bool:
	# Check if entity is hostile to this NPC
	if body.has_method("get_faction"):
		var other_faction: String = body.get_faction()
		var rep_mgr: Node = Engine.get_main_loop().root.get_node_or_null("ReputationManager") if Engine.get_main_loop() else null
		if rep_mgr and rep_mgr.has_method("get_faction_disposition"):
			var disposition: float = rep_mgr.get_faction_disposition(
				abstract.data.faction, other_faction
			)
			return disposition < NPCConfig.Threat.HOSTILE_DISP_THRESHOLD

	# Player is a threat if NPC's memory of player is very negative
	if body.is_in_group("player"):
		var player_memory := abstract.get_memory("player")
		return player_memory.get_disposition() < NPCConfig.Threat.PLAYER_HOSTILE_THRESHOLD

	return false


func get_threat_sources() -> Array[Node3D]:
	return _threat_sources


func get_threat_level() -> float:
	return _current_threat_level


## Call this when a gunfire event occurs nearby.
func notify_gunfire(source_position: Vector3) -> void:
	var distance: float = npc.global_position.distance_to(source_position)
	if distance < scan_range:
		_last_gunfire_time = Time.get_ticks_msec() / 1000.0
