## Level volume that triggers a camera preset change when the player enters.
## Place these in your level as Area3D nodes with collision shapes.
## Add to the "camera_zones" group for auto-detection by CameraZoneManager.
@tool
class_name CameraZone extends Area3D

## The camera preset to transition to when a player enters this zone.
@export var camera_preset: CameraPreset:
	set(value):
		camera_preset = value
		_update_debug_label()

## Priority for overlapping zones. Higher priority wins.
@export var zone_priority: int = 0

## When true, leaving this zone reverts to the previous preset or default.
@export var revert_on_exit: bool = true

## Emitted when a player enters this zone. CameraZoneManager listens for this.
signal zone_entered(zone: CameraZone)
## Emitted when a player exits this zone.
signal zone_exited(zone: CameraZone)

var _debug_label: Label3D


func _ready() -> void:
	# Auto-add to group for discovery.
	if not is_in_group("camera_zones"):
		add_to_group("camera_zones")
	
	# Zone doesn't block anything physically.
	collision_layer = 0
	
	# Connect signals.
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	# Debug visualization in editor.
	if Engine.is_editor_hint():
		_create_debug_label()


func _on_body_entered(body: Node3D) -> void:
	if Engine.is_editor_hint():
		return
	if body.is_in_group("player"):
		zone_entered.emit(self)


func _on_body_exited(body: Node3D) -> void:
	if Engine.is_editor_hint():
		return
	if body.is_in_group("player"):
		zone_exited.emit(self)


func _create_debug_label() -> void:
	_debug_label = Label3D.new()
	_debug_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_debug_label.font_size = 32
	_debug_label.modulate = Color(1, 1, 0, 0.8)
	add_child(_debug_label)
	_update_debug_label()


func _update_debug_label() -> void:
	if _debug_label:
		var preset_name := camera_preset.preset_name if camera_preset else "None"
		_debug_label.text = "CamZone: %s (P:%d)" % [preset_name, zone_priority]
