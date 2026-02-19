## Full game state snapshot for save/load.
## Contains all data needed to restore a game session.
@tool
class_name SaveData extends Resource


#region Metadata
@export_group("Metadata")
## Save slot index.
@export var slot: int = 0

## Player-visible save name.
@export var save_name: String = ""

## When this save was created (Unix timestamp).
@export var timestamp: float = 0.0

## Total play time in seconds.
@export var play_time: float = 0.0

## Save format version for migration.
@export var version: int = 1
#endregion


#region Level State
@export_group("Level")
## Scene file path of the current level.
@export var level_path: String = ""

## Player world position.
@export var player_position: Vector3 = Vector3.ZERO

## Player world rotation.
@export var player_rotation: Vector3 = Vector3.ZERO

## Named spawn marker (for level loading).
@export var spawn_marker: String = ""
#endregion


#region Player State
@export_group("Player")
## Player health.
@export var health: float = 100.0
#endregion


#region Inventory State
@export_group("Inventory")
## Serialized inventory contents. Each entry is a dict with item_path and quantity.
@export var inventory_items: Array[Dictionary] = []

## Equipped weapon slot indices or item paths.
@export var equipped_weapons: Array[String] = []

## Equipped gear slot data.
@export var equipped_gear: Dictionary = {}
#endregion


#region World State
@export_group("World")
## Mission/quest flags (name → value).
@export var mission_flags: Dictionary = {}

## NPC states (id → state dict).
@export var npc_states: Dictionary = {}

## World object states (id → state dict). Doors, pickups, destructibles, etc.
@export var world_object_states: Dictionary = {}
#endregion


#region Checkpoint
@export_group("Checkpoint")
## Name of the last activated checkpoint marker.
@export var checkpoint_marker: String = ""

## Whether this save was created by auto-save.
@export var is_auto_save: bool = false
#endregion
