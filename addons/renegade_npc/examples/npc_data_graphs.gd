## NPCDataGraphs: Real-time NPC data visualization overlay (always visible).
## Shows 7 graph panels: drive distribution, module sparklines, aggregate threat,
## reputation timeline, social memory, health distribution, and system metrics.
## Samples data every 0.25s (matching UTILITY_EVAL_INTERVAL).
## Layout defined in npc_data_graphs.tscn — this script handles data only.
extends CanvasLayer


# --- Ring buffer for rolling time-series data ---
class RingBuffer:
	var _data: PackedFloat32Array
	var _head: int = 0
	var _count: int = 0
	var _capacity: int

	func _init(capacity: int = 120) -> void:
		_capacity = capacity
		_data.resize(capacity)
		_data.fill(0.0)

	func push(value: float) -> void:
		_data[_head] = value
		_head = (_head + 1) % _capacity
		if _count < _capacity:
			_count += 1

	func get_ordered() -> PackedFloat32Array:
		if _count == 0:
			return PackedFloat32Array()
		var result := PackedFloat32Array()
		result.resize(_count)
		var start: int = (_head - _count + _capacity) % _capacity
		for i: int in range(_count):
			result[i] = _data[(start + i) % _capacity]
		return result

	func latest() -> float:
		if _count == 0:
			return 0.0
		return _data[(_head - 1 + _capacity) % _capacity]

	func clear() -> void:
		_head = 0
		_count = 0
		_data.fill(0.0)

	func max_value() -> float:
		if _count == 0:
			return 0.0
		var mx: float = _data[0]
		var start: int = (_head - _count + _capacity) % _capacity
		for i: int in range(_count):
			mx = maxf(mx, _data[(start + i) % _capacity])
		return mx


# --- Constants ---
const SAMPLE_INTERVAL: float = 0.25
const LONG_CAPACITY: int = 240   # 60s at 0.25s intervals
const SHORT_CAPACITY: int = 120  # 30s at 0.25s intervals
const HYSTERESIS_DIST: float = 2.0

# Drive colors (matches demo_hud.gd / test_visualizer.gd)
const DRIVE_COLORS := {
	"idle": Color(0.53, 0.53, 0.53),
	"patrol": Color(0.8, 0.8, 0.0),
	"flee": Color(0.87, 0.2, 0.2),
	"threat": Color(1.0, 0.27, 0.27),
	"socialize": Color(0.27, 0.87, 0.27),
	"work": Color(0.27, 0.87, 0.87),
	"deal": Color(0.87, 0.53, 0.0),
	"guard": Color(0.67, 0.27, 0.87),
}

# Module colors map to drive colors
const MODULE_COLORS := {
	"idle": Color(0.53, 0.53, 0.53),
	"threat": Color(1.0, 0.27, 0.27),
	"flee": Color(0.87, 0.2, 0.2),
	"opportunity": Color(0.87, 0.53, 0.0),
	"social": Color(0.27, 0.87, 0.27),
}

# Memory curve colors
const MEMORY_COLORS := {
	"disposition": Color(0.0, 0.83, 1.0),
	"trust": Color(0.27, 0.87, 0.27),
	"temp_fear": Color(0.87, 0.2, 0.2),
	"temp_like": Color(0.87, 0.87, 0.0),
}

# --- Scene references ---
@onready var _root_panel: PanelContainer = $Root
@onready var _graph_panels: Array[Node] = [
	$Root/Margin/VBox/Grid/DriveDistribution,
	$Root/Margin/VBox/Grid/ModuleSparklines,
	$Root/Margin/VBox/Grid/AggregateThreat,
	$Root/Margin/VBox/Grid/ReputationTimeline,
	$Root/Margin/VBox/Grid/SocialMemory,
	$Root/Margin/VBox/Grid/HealthDistribution,
	$Root/Margin/VBox/Grid/SystemMetrics,
]
@onready var _legend_panel: Node = $Root/Margin/VBox/Grid/Legend

# --- State ---
var _sample_timer: float = 0.0
var _visible: bool = true  # Always visible

# Nearest NPC tracking
var _nearest_npc: RealizedNPC = null
var _nearest_npc_name: String = ""

# Buffers — system metrics (60s)
var _buf_realized: RingBuffer = RingBuffer.new(LONG_CAPACITY)
var _buf_alive: RingBuffer = RingBuffer.new(LONG_CAPACITY)

# Buffers — aggregate threat (60s)
var _buf_avg_threat: RingBuffer = RingBuffer.new(LONG_CAPACITY)

# Buffers — reputation timeline (60s), keyed by faction
var _buf_reputation: Dictionary = {}  # faction_name -> RingBuffer

# Buffers — drive distribution (updated each sample, not time-series)
var _drive_counts: Dictionary = {}  # drive_name -> int

# Buffers — module sparklines (30s), keyed by module name
var _buf_modules: Dictionary = {}  # module_name -> RingBuffer

# Buffers — social memory (60s)
var _buf_disposition: RingBuffer = RingBuffer.new(LONG_CAPACITY)
var _buf_trust: RingBuffer = RingBuffer.new(LONG_CAPACITY)
var _buf_temp_fear: RingBuffer = RingBuffer.new(LONG_CAPACITY)
var _buf_temp_like: RingBuffer = RingBuffer.new(LONG_CAPACITY)

# Buffers — health distribution (updated each sample)
var _health_buckets: PackedFloat32Array  # 10 buckets


func _ready() -> void:
	_health_buckets.resize(10)
	_health_buckets.fill(0.0)

	# Wire up data source for all graph panels
	for panel in _graph_panels:
		if panel.has_method("set_data_source"):
			panel.set_data_source(self)

	_root_panel.visible = true
	if _legend_panel and _legend_panel.has_method("redraw"):
		_legend_panel.redraw()


func _process(delta: float) -> void:
	if not _visible:
		return

	_sample_timer += delta
	if _sample_timer >= SAMPLE_INTERVAL:
		_sample_timer = 0.0
		_collect_sample()
		for panel in _graph_panels:
			if panel.has_method("redraw"):
				panel.redraw()


# --- Data Collection ---

func _collect_sample() -> void:
	var manager = get_node_or_null("/root/NPCManager")
	if not manager:
		return

	# System metrics
	var stats: Dictionary = manager.get_stats()
	_buf_realized.push(float(stats.get("realized", 0)))
	_buf_alive.push(float(stats.get("alive", 0)))

	# Iterate realized NPCs for drive counts, health, threat
	var realized: Dictionary = manager._realized_npcs
	_drive_counts.clear()
	_health_buckets.fill(0.0)
	var threat_sum: float = 0.0
	var threat_count: int = 0

	var player: Node3D = get_tree().get_first_node_in_group("player")

	var nearest: RealizedNPC = null
	var nearest_dist: float = INF

	for npc_id: String in realized:
		var rnpc: RealizedNPC = realized[npc_id]
		if not is_instance_valid(rnpc) or not rnpc.abstract:
			continue

		# Drive count
		var drive: String = rnpc.get_active_drive()
		_drive_counts[drive] = _drive_counts.get(drive, 0) + 1

		# Health bucket
		var hp_pct: float = 0.0
		if rnpc.abstract.data and rnpc.abstract.data.max_health > 0:
			hp_pct = float(rnpc.abstract.current_health) / float(rnpc.abstract.data.max_health)
		var bucket: int = clampi(int(hp_pct * 10.0), 0, 9)
		_health_buckets[bucket] += 1.0

		# Threat score
		var scores: Dictionary = rnpc.get_module_scores()
		if scores.has("threat"):
			threat_sum += scores["threat"]
			threat_count += 1

		# Nearest NPC
		if player:
			var dist: float = player.global_position.distance_to(rnpc.global_position)
			if dist < nearest_dist:
				nearest_dist = dist
				nearest = rnpc

	# Aggregate threat
	var avg_threat: float = threat_sum / float(threat_count) if threat_count > 0 else 0.0
	_buf_avg_threat.push(avg_threat)

	# Nearest NPC with hysteresis
	if nearest:
		if _nearest_npc != nearest:
			# Only switch if new NPC is significantly closer
			if _nearest_npc == null or not is_instance_valid(_nearest_npc):
				_switch_nearest(nearest)
			else:
				var current_dist: float = INF
				if player:
					current_dist = player.global_position.distance_to(_nearest_npc.global_position)
				if nearest_dist < current_dist - HYSTERESIS_DIST:
					_switch_nearest(nearest)
	elif _nearest_npc != null:
		_switch_nearest(null)

	# Sample nearest NPC module scores
	if _nearest_npc and is_instance_valid(_nearest_npc):
		var scores: Dictionary = _nearest_npc.get_module_scores()
		for module_name: String in scores:
			if not _buf_modules.has(module_name):
				_buf_modules[module_name] = RingBuffer.new(SHORT_CAPACITY)
			_buf_modules[module_name].push(scores[module_name])

		# Social memory toward player
		if _nearest_npc.abstract and _nearest_npc.abstract.social_memories.has("player"):
			var mem: SocialMemory = _nearest_npc.abstract.social_memories["player"]
			_buf_disposition.push(mem.get_disposition())
			_buf_trust.push(mem.get_trust())
			_buf_temp_fear.push(mem.temp_fear)
			_buf_temp_like.push(mem.temp_like)
		else:
			_buf_disposition.push(0.0)
			_buf_trust.push(0.0)
			_buf_temp_fear.push(0.0)
			_buf_temp_like.push(0.0)

	# Reputation
	var rep_mgr = get_node_or_null("/root/ReputationManager")
	if rep_mgr:
		for faction: String in rep_mgr.city_reputation:
			if not _buf_reputation.has(faction):
				_buf_reputation[faction] = RingBuffer.new(LONG_CAPACITY)
			_buf_reputation[faction].push(rep_mgr.city_reputation[faction])


func _switch_nearest(npc: RealizedNPC) -> void:
	_nearest_npc = npc
	if npc and npc.abstract and npc.abstract.data:
		_nearest_npc_name = npc.abstract.data.npc_name
	else:
		_nearest_npc_name = ""
	# Clear per-NPC buffers
	_buf_modules.clear()
	_buf_disposition.clear()
	_buf_trust.clear()
	_buf_temp_fear.clear()
	_buf_temp_like.clear()
