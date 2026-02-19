## Area3D trigger that activates a checkpoint when the player enters.
## Sets a respawn point and optionally triggers an auto-save.
## Player must be in the "player" group and on collision layer 1.
@tool
class_name CheckpointZone extends Area3D


## Emitted when a player activates this checkpoint.
signal checkpoint_activated(marker_name: String)


#region Checkpoint Settings
@export_group("Checkpoint")
## Unique name for this checkpoint. Used to identify the respawn point.
@export var marker_name: String = ""

## The spawn point where the player respawns. Position a Marker3D child.
@export var spawn_point: Marker3D

## If true, this checkpoint can only be activated once per session.
@export var one_shot: bool = false

## If true, activating this checkpoint triggers an auto-save.
@export var auto_save_on_activate: bool = true
#endregion


var _activated: bool = false


func _ready() -> void:
	# Zone doesn't block anything physically, but detects player on layer 1.
	collision_layer = 0
	collision_mask = 1

	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if Engine.is_editor_hint():
		return
	if _activated and one_shot:
		return
	if body.is_in_group("player"):
		_activated = true
		checkpoint_activated.emit(marker_name)
