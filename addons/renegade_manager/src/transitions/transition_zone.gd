## Area3D trigger for level transitions (doors, elevators, borders).
## When the player enters, triggers a scene transition with optional visual effect.
## Player must be in the "player" group and on collision layer 1.
@tool
class_name TransitionZone extends Area3D


## Emitted when the transition is triggered.
signal transition_triggered(target_scene: String, spawn_marker: String)


#region Destination
@export_group("Destination")
## Path to the target scene file.
@export_file("*.tscn") var target_scene: String = ""

## Named spawn marker in the target scene.
@export var spawn_marker: String = ""
#endregion


#region Transition
@export_group("Transition")
## Visual effect to play during the transition.
@export var transition_effect: TransitionEffect

## If true, transition triggers automatically on enter. If false, requires interact input.
@export var auto_trigger: bool = true

## Cooldown in seconds before this zone can trigger again.
@export_range(0.0, 10.0, 0.1) var cooldown: float = 1.0
#endregion


var _on_cooldown: bool = false
var _player_inside: bool = false


func _ready() -> void:
	# Zone doesn't block anything physically, but detects player on layer 1.
	collision_layer = 0
	collision_mask = 1

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node3D) -> void:
	if Engine.is_editor_hint():
		return
	if body.is_in_group("player"):
		_player_inside = true
		if auto_trigger:
			_trigger_transition()


func _on_body_exited(body: Node3D) -> void:
	if Engine.is_editor_hint():
		return
	if body.is_in_group("player"):
		_player_inside = false


## Trigger the transition if not on cooldown.
func _trigger_transition() -> void:
	if _on_cooldown:
		return
	if target_scene.is_empty():
		return
	_on_cooldown = true
	transition_triggered.emit(target_scene, spawn_marker)


## Called by external input when auto_trigger is false and player is inside.
func interact() -> void:
	if _player_inside and not auto_trigger:
		_trigger_transition()
