## NPCData: The data resource that defines an NPC's identity, capabilities, and baseline stats.
## Saved as .tres files and shared across NPCs of the same archetype.
## Mutable per-instance data (health, current drive) lives on AbstractNPC, not here.
class_name NPCData
extends Resource

## --- Identity ---
@export var npc_name: String = "Unnamed"
@export var npc_id: String = "" ## Unique ID - auto-generated if empty
@export_enum("Civilian", "Gang", "Cop", "Vendor", "Story") var archetype: String = "Civilian"
@export var faction: String = "none" ## e.g., NPCConfig.Factions.LA_MIRADA, NPCConfig.Factions.LAPD

## --- Stats ---
@export_range(1, 200) var max_health: int = 100
@export_range(0.5, 10.0, 0.1) var move_speed: float = 3.0
@export_range(0.5, 20.0, 0.1) var run_speed: float = 6.0
@export_range(1.0, 30.0, 0.5) var detection_range: float = 15.0
@export_range(1.0, 5.0, 0.5) var interaction_range: float = 2.5

## --- Combat ---
@export var is_combatant: bool = false
@export_range(0.0, 1.0, 0.05) var aggression_bias: float = 0.5 ## Modifies aggression personality
@export_range(0.0, 1.0, 0.05) var cover_seek_frequency: float = 0.5
@export_range(5.0, 30.0, 1.0) var engagement_distance: float = 12.0

## --- Dialogue ---
@export var dialogue_file: String = "" ## Path to Dialogue Manager .dialogue file
@export var bark_pool: PackedStringArray = [] ## One-liner ambient barks

## --- Visual ---
@export var model_scene: PackedScene = null ## The 3D model scene to instance
@export var animation_library: String = "" ## Animation library name

## --- Utility Module Weights ---
## Override default module weights for this archetype.
## Keys = module class names, Values = weight multipliers.
@export var module_weight_overrides: Dictionary = {}

## --- Activity Preferences ---
## Which activity types this NPC gravitates toward. Higher = more preferred.
@export var activity_preferences: Dictionary = {
	"idle": 1.0,
	"patrol": 0.5,
	"socialize": 0.5,
	"work": 0.3,
	"deal": 0.0,
	"guard": 0.0,
}


func generate_id() -> String:
	if npc_id.is_empty():
		npc_id = "%s_%s_%d" % [faction, archetype.to_lower(), randi()]
	return npc_id
