## Manages camera zone transitions with priority-based resolution.
## Auto-discovers all CameraZone nodes in the "camera_zones" group.
## Handles overlapping zones by activating the highest-priority preset.
class_name CameraZoneManager extends Node

## The CameraRig to control.
@export var camera_rig: CameraRig

## Fallback preset when no zones are active. If null, uses the CameraRig's default_preset.
@export var default_preset: CameraPreset

## Emitted when the active zone changes (or reverts to default).
signal active_zone_changed(zone: CameraZone)

var _active_zones: Array[CameraZone] = []
var _current_zone: CameraZone = null


func _ready() -> void:
	# Wait one frame for all nodes to be ready.
	await get_tree().process_frame
	_discover_zones()


#region Public API

## Manually register a zone (for dynamically spawned zones).
func register_zone(zone: CameraZone) -> void:
	if not zone.zone_entered.is_connected(_on_zone_entered):
		zone.zone_entered.connect(_on_zone_entered)
		zone.zone_exited.connect(_on_zone_exited)


## Manually unregister a zone.
func unregister_zone(zone: CameraZone) -> void:
	if zone.zone_entered.is_connected(_on_zone_entered):
		zone.zone_entered.disconnect(_on_zone_entered)
		zone.zone_exited.disconnect(_on_zone_exited)
	_active_zones.erase(zone)
	_resolve_active_camera()


## Force transition to a specific preset (bypasses zone system).
func force_preset(preset: CameraPreset) -> void:
	if camera_rig:
		camera_rig.transition_to(preset)

#endregion


#region Zone Discovery

func _discover_zones() -> void:
	var zones := get_tree().get_nodes_in_group("camera_zones")
	for node in zones:
		if node is CameraZone:
			register_zone(node)

#endregion


#region Zone Events

func _on_zone_entered(zone: CameraZone) -> void:
	if zone not in _active_zones:
		_active_zones.append(zone)
	_resolve_active_camera()


func _on_zone_exited(zone: CameraZone) -> void:
	_active_zones.erase(zone)
	_resolve_active_camera()

#endregion


#region Resolution

func _resolve_active_camera() -> void:
	if not camera_rig:
		return
	
	if _active_zones.is_empty():
		# Revert to default.
		_current_zone = null
		var fallback := default_preset if default_preset else camera_rig.default_preset
		if fallback:
			camera_rig.transition_to(fallback)
		active_zone_changed.emit(null)
		return
	
	# Find highest priority zone.
	var best: CameraZone = _active_zones[0]
	for zone in _active_zones:
		if zone.zone_priority > best.zone_priority:
			best = zone
	
	# Only transition if the active zone actually changed.
	if best != _current_zone:
		_current_zone = best
		if best.camera_preset:
			camera_rig.transition_to(best.camera_preset)
		active_zone_changed.emit(best)

#endregion
