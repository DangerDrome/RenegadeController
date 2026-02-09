## NPCStateRecorder: Records and replays NPC state over time.
## Works like a cassette tape - records while time moves forward, replays when rewinding.
## Timestamps are based on SkyWeather time (total hours) for synchronization.
class_name NPCStateRecorder
extends RefCounted

## A single recorded snapshot of NPC state.
class StateSnapshot:
	var timestamp: float = 0.0  ## Total hours from SkyWeather
	var position: Vector3 = Vector3.ZERO
	var rotation_y: float = 0.0
	var velocity: Vector3 = Vector3.ZERO
	var drive: String = "idle"
	var is_moving: bool = false

	func _init(p_timestamp: float = 0.0) -> void:
		timestamp = p_timestamp

	func to_dict() -> Dictionary:
		return {
			"t": timestamp,
			"p": [position.x, position.y, position.z],
			"ry": rotation_y,
			"v": [velocity.x, velocity.y, velocity.z],
			"d": drive,
			"m": is_moving,
		}

	static func from_dict(data: Dictionary) -> StateSnapshot:
		var snap := StateSnapshot.new(data.get("t", 0.0))
		var p: Array = data.get("p", [0, 0, 0])
		snap.position = Vector3(p[0], p[1], p[2])
		snap.rotation_y = data.get("ry", 0.0)
		var v: Array = data.get("v", [0, 0, 0])
		snap.velocity = Vector3(v[0], v[1], v[2])
		snap.drive = data.get("d", "idle")
		snap.is_moving = data.get("m", false)
		return snap


## --- Configuration ---
## Seconds between state recordings (in real time when time_scale = 1)
const RECORD_INTERVAL: float = 0.1
## Maximum number of snapshots to keep (ring buffer). At 0.1s interval, 600 = 1 minute of history
const MAX_SNAPSHOTS: int = 6000  ## 10 minutes at 0.1s = 600, so 6000 = ~10 minutes

## --- State ---
var _snapshots: Array[StateSnapshot] = []
var _record_timer: float = 0.0
var _last_record_time: float = -1.0  ## Last SkyWeather time we recorded at
var _is_rewinding: bool = false
var _playback_index: int = -1  ## Current position during playback
var _sky_weather: Node = null  ## Cached reference to SkyWeather

## The NPC we're recording
var _npc: RealizedNPC = null


func _init(npc: RealizedNPC) -> void:
	_npc = npc
	_find_sky_weather()


func _find_sky_weather() -> void:
	if not _npc or not _npc.is_inside_tree():
		return
	# Use HUDEvents helper or find manually
	var root := _npc.get_tree().root
	_sky_weather = _find_node_by_class(root, "SkyWeather")


func _find_node_by_class(node: Node, class_name_str: String) -> Node:
	if node.get_class() == class_name_str or (node.get_script() and node.get_script().get_global_name() == class_name_str):
		return node
	for child: Node in node.get_children():
		var found := _find_node_by_class(child, class_name_str)
		if found:
			return found
	return null


## Get current SkyWeather time as total hours (day * 24 + time).
func _get_current_time() -> float:
	if not _sky_weather:
		_find_sky_weather()
	if _sky_weather:
		var day: int = _sky_weather.get("day_count") if "day_count" in _sky_weather else 0
		var time: float = _sky_weather.get("time") if "time" in _sky_weather else 0.0
		return float(day) * 24.0 + time
	return 0.0


## Check if time is currently being rewound.
func _is_time_rewinding() -> bool:
	if not _sky_weather:
		_find_sky_weather()
	if _sky_weather and "time_scale" in _sky_weather:
		return _sky_weather.time_scale < 0
	return false


## Called every physics frame by RealizedNPC.
func update(delta: float) -> void:
	var rewinding := _is_time_rewinding()

	if rewinding:
		if not _is_rewinding:
			# Just started rewinding - find starting playback position
			_start_rewind()
		_do_playback()
	else:
		if _is_rewinding:
			# Just stopped rewinding - resume recording
			_stop_rewind()
		_do_record(delta)


## Start playback mode - find the snapshot closest to current time.
func _start_rewind() -> void:
	_is_rewinding = true
	var current_time := _get_current_time()

	# Find the snapshot just after current time (we'll interpolate backward)
	_playback_index = _find_snapshot_index(current_time)

	# Trim future snapshots - they're now invalid since we're rewinding
	if _playback_index >= 0 and _playback_index < _snapshots.size() - 1:
		_snapshots.resize(_playback_index + 1)


func _stop_rewind() -> void:
	_is_rewinding = false
	_playback_index = -1
	# Clear any snapshots after current time (they're from a future that won't happen)
	var current_time := _get_current_time()
	while not _snapshots.is_empty() and _snapshots.back().timestamp > current_time:
		_snapshots.pop_back()
	_last_record_time = current_time


## Record the current NPC state.
func _do_record(delta: float) -> void:
	if not _npc or not is_instance_valid(_npc):
		return

	_record_timer += delta
	if _record_timer < RECORD_INTERVAL:
		return
	_record_timer = 0.0

	var current_time := _get_current_time()

	# Don't record if time hasn't moved forward
	if current_time <= _last_record_time:
		return

	var snapshot := StateSnapshot.new(current_time)
	snapshot.position = _npc.global_position
	snapshot.rotation_y = _npc.rotation.y
	snapshot.velocity = _npc.velocity
	snapshot.drive = _npc._active_drive
	snapshot.is_moving = _npc._is_moving

	_snapshots.append(snapshot)
	_last_record_time = current_time

	# Trim old snapshots if we exceed max
	if _snapshots.size() > MAX_SNAPSHOTS:
		_snapshots.pop_front()


## Play back recorded state at current time.
func _do_playback() -> void:
	if not _npc or not is_instance_valid(_npc):
		return

	if _snapshots.is_empty():
		return

	var current_time := _get_current_time()

	# Find snapshots to interpolate between
	var idx := _find_snapshot_index(current_time)
	if idx < 0:
		# Before first snapshot - hold firmly at origin
		_hold_at_snapshot(_snapshots[0])
		return

	if idx >= _snapshots.size() - 1:
		# After last snapshot - stay at last position
		_hold_at_snapshot(_snapshots.back())
		return

	# Interpolate between idx and idx+1
	var snap_a: StateSnapshot = _snapshots[idx]
	var snap_b: StateSnapshot = _snapshots[idx + 1]

	var t_range := snap_b.timestamp - snap_a.timestamp
	if t_range <= 0.0:
		_hold_at_snapshot(snap_a)
		return

	var t := (current_time - snap_a.timestamp) / t_range
	t = clampf(t, 0.0, 1.0)

	# Interpolate position and rotation
	_npc.global_position = snap_a.position.lerp(snap_b.position, t)
	_npc.rotation.y = lerp_angle(snap_a.rotation_y, snap_b.rotation_y, t)
	_npc.velocity = Vector3.ZERO  # No velocity during playback

	# Stop AI movement during rewind
	_npc._is_moving = false

	# Reset navigation to prevent AI from fighting playback
	if _npc.nav_agent:
		_npc.nav_agent.target_position = _npc.global_position


## Hold the NPC firmly at a snapshot position (no interpolation, no velocity).
## Used when at the beginning or end of the recording.
func _hold_at_snapshot(snap: StateSnapshot) -> void:
	_npc.global_position = snap.position
	_npc.rotation.y = snap.rotation_y
	_npc.velocity = Vector3.ZERO
	_npc._is_moving = false
	if _npc.nav_agent:
		_npc.nav_agent.target_position = snap.position


## Apply a snapshot directly to the NPC.
func _apply_snapshot(snap: StateSnapshot) -> void:
	_npc.global_position = snap.position
	_npc.rotation.y = snap.rotation_y
	_npc.velocity = snap.velocity
	_npc._is_moving = false
	if _npc.nav_agent:
		_npc.nav_agent.target_position = _npc.global_position


## Find the index of the snapshot just before or at the given time.
## Returns -1 if time is before all snapshots.
func _find_snapshot_index(time: float) -> int:
	if _snapshots.is_empty():
		return -1

	# Binary search for efficiency
	var lo: int = 0
	var hi: int = _snapshots.size() - 1

	if time < _snapshots[lo].timestamp:
		return -1
	if time >= _snapshots[hi].timestamp:
		return hi

	while lo < hi:
		var mid: int = (lo + hi + 1) / 2
		if _snapshots[mid].timestamp <= time:
			lo = mid
		else:
			hi = mid - 1

	return lo


## Check if currently in rewind mode.
func is_rewinding() -> bool:
	return _is_rewinding


## Get the number of recorded snapshots.
func get_snapshot_count() -> int:
	return _snapshots.size()


## Get the time range covered by recordings.
func get_time_range() -> Vector2:
	if _snapshots.is_empty():
		return Vector2.ZERO
	return Vector2(_snapshots[0].timestamp, _snapshots.back().timestamp)


## Clear all recorded state.
func clear() -> void:
	_snapshots.clear()
	_record_timer = 0.0
	_last_record_time = -1.0
	_playback_index = -1
	_is_rewinding = false


## Serialize for save games.
func to_dict() -> Dictionary:
	var snap_data: Array = []
	for snap: StateSnapshot in _snapshots:
		snap_data.append(snap.to_dict())
	return {
		"snapshots": snap_data,
		"last_record_time": _last_record_time,
	}


## Deserialize from save data.
func load_from_dict(data: Dictionary) -> void:
	_snapshots.clear()
	var snap_data: Array = data.get("snapshots", [])
	for snap_dict: Dictionary in snap_data:
		_snapshots.append(StateSnapshot.from_dict(snap_dict))
	_last_record_time = data.get("last_record_time", -1.0)
