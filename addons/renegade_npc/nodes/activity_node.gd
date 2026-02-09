## ActivityNode: A world-space marker where NPCs can perform activities.
## Place these throughout your levels. NPCs pathfind to them based on their
## current drive and activity preferences.
##
## Inspired by Cyberpunk 2077's AISpot/Workspot system.
@tool
class_name ActivityNode
extends Marker3D

## The type of activity available here. Must match keys in NPCData.activity_preferences.
@export_enum("idle", "patrol", "socialize", "work", "deal", "guard") var activity_type: String = "idle"

## Optional animation to play when an NPC occupies this spot.
@export var activity_animation: String = ""

## How long an NPC typically stays here (seconds). 0 = indefinite.
@export_range(0.0, 300.0, 1.0) var typical_duration: float = 30.0

## Maximum NPCs that can use this spot simultaneously.
@export_range(1, 10) var capacity: int = 1

## Which factions can use this spot. Empty = all factions.
@export var allowed_factions: PackedStringArray = []

## --- Runtime state ---
var _occupants: Array[Node] = []


func _ready() -> void:
	add_to_group("activity_nodes")


func get_activity_type() -> String:
	return activity_type


func is_occupied() -> bool:
	# Clean up freed references (reverse loop avoids typed array reassignment issue)
	for i: int in range(_occupants.size() - 1, -1, -1):
		if not is_instance_valid(_occupants[i]):
			_occupants.remove_at(i)
	return _occupants.size() >= capacity


func can_use(npc_faction: String) -> bool:
	if allowed_factions.is_empty():
		return true
	return npc_faction in allowed_factions


func occupy(npc: Node) -> void:
	if npc not in _occupants and not is_occupied():
		_occupants.append(npc)


func release(npc: Node = null) -> void:
	if npc:
		_occupants.erase(npc)
	elif not _occupants.is_empty():
		_occupants.pop_back()


func get_occupant_count() -> int:
	for i: int in range(_occupants.size() - 1, -1, -1):
		if not is_instance_valid(_occupants[i]):
			_occupants.remove_at(i)
	return _occupants.size()


## Editor visualization
func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if activity_type.is_empty():
		warnings.append("ActivityNode needs an activity_type assigned.")
	return warnings
