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
			# Check if player is already inside this zone.
			_check_zone_overlap(node)


func _check_zone_overlap(zone: CameraZone) -> void:
	# Check if any player bodies are already overlapping this zone.
	var bodies := zone.get_overlapping_bodies()
	for body in bodies:
		if body.is_in_group("player"):
			_on_zone_entered(zone)
			break

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
		# Revert to default camera (uses CameraRig's default_preset and template_camera).
		_current_zone = null
		camera_rig.reset_to_default()
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
			# Create a runtime copy of the preset.
			# follow_target controls look-at behavior, follow_player controls position only.
			var preset := best.camera_preset.duplicate() as CameraPreset
			# Only enable look-at-player if zone has no explicit look_at target.
			var look_at_node := best.get_look_at_node()
			var camera_marker := best.get_camera_marker()
			var has_look_at := look_at_node != null
			preset.follow_target = has_look_at or best.follow_player

			print("[CameraZoneManager] Transitioning to zone: %s" % best.name)
			print("  - camera_marker: %s" % (camera_marker.name if camera_marker else "NULL"))
			print("  - look_at_node: %s" % (look_at_node.name if look_at_node else "NULL"))
			print("  - preset.follow_target: %s" % preset.follow_target)
			print("  - best.follow_player: %s" % best.follow_player)
			print("  - best.target_player: %s" % best.target_player)

			camera_rig.set_position_follow_only(best.follow_player and not has_look_at)
			camera_rig.transition_to(preset, camera_marker, look_at_node)
		active_zone_changed.emit(best)

#endregion
