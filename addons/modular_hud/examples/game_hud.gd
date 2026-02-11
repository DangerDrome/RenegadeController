@tool
extends CanvasLayer
## GameHUD - Modular HUD that auto-detects available systems and shows relevant content.
## Drop this into ANY scene and it will display appropriate stats:
## - NPC scene: NPC system stats, wanted level, drives, module scores, sparklines
## - Player scene: Character stats, camera, inventory
## - Any scene: FPS, time controls (if SkyWeather present)
##
## Toggle debug overlay with F3. F6 reports crimes (if NPCManager present).
## F1 toggles NPC detail view with module sparklines and social memory curves.


# =============================================================================
# RING BUFFER - Rolling time-series data for sparklines
# =============================================================================

class RingBuffer:
	var _data: PackedFloat32Array
	var _head: int = 0
	var _count: int = 0
	var _capacity: int

	func _init(capacity: int = 60) -> void:
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

	func min_value() -> float:
		if _count == 0:
			return 0.0
		var mn: float = _data[0]
		var start: int = (_head - _count + _capacity) % _capacity
		for i: int in range(_count):
			mn = minf(mn, _data[(start + i) % _capacity])
		return mn


enum PixelFont {
	TINY5,        ## Tiny5 - Compact 5x5 pixel font
	SILKSCREEN,   ## Silkscreen - Classic pixel font
	VT323,        ## VT323 - VT320 terminal style
	PRESS_START,  ## Press Start 2P - Arcade style
}

const FONT_PATHS := {
	PixelFont.TINY5: "res://addons/modular_hud/fonts/Tiny5-Regular.ttf",
	PixelFont.SILKSCREEN: "res://addons/modular_hud/fonts/Silkscreen-Regular.ttf",
	PixelFont.VT323: "res://addons/modular_hud/fonts/VT323-Regular.ttf",
	PixelFont.PRESS_START: "res://addons/modular_hud/fonts/PressStart2P-Regular.ttf",
}

const FONT_RECOMMENDED_SIZES := {
	PixelFont.TINY5: 30,
	PixelFont.SILKSCREEN: 24,
	PixelFont.VT323: 48,
	PixelFont.PRESS_START: 24,
}

@export_group("Font Settings")
@export var pixel_font: PixelFont = PixelFont.TINY5:
	set(value):
		pixel_font = value
		_apply_font_settings()

@export var font_size: int = 30:
	set(value):
		font_size = value
		_apply_font_settings()

@export var use_recommended_size: bool = true:
	set(value):
		use_recommended_size = value
		_apply_font_settings()

@export_group("Font Style")
@export var font_color: Color = Color.WHITE:
	set(value):
		font_color = value
		_apply_font_settings()

@export var font_outline_size: int = 0:
	set(value):
		font_outline_size = value
		_apply_font_settings()

@export var font_outline_color: Color = Color.BLACK:
	set(value):
		font_outline_color = value
		_apply_font_settings()

@export var font_shadow_offset: Vector2 = Vector2.ZERO:
	set(value):
		font_shadow_offset = value
		_apply_font_settings()

@export var font_shadow_color: Color = Color(0, 0, 0, 0.5):
	set(value):
		font_shadow_color = value
		_apply_font_settings()

var _current_font: Font
var _is_ready := false
var _is_applying := false

# --- Time-Series Sampling ---
const SAMPLE_INTERVAL: float = 0.25  # Sample every 0.25s (matches NPC utility eval)
const LONG_CAPACITY: int = 120   # 30s at 0.25s intervals
const SHORT_CAPACITY: int = 60   # 15s at 0.25s intervals
const SPARKLINE_WIDTH: int = 20  # Characters for sparkline display
const SPARKLINE_CHARS: String = "▁▂▃▄▅▆▇█"

var _sample_timer: float = 0.0

# --- System Metric Buffers (long history) ---
var _buf_realized: RingBuffer
var _buf_alive: RingBuffer
var _buf_avg_threat: RingBuffer

# --- Reputation Buffers (keyed by faction) ---
var _buf_reputation: Dictionary = {}  # faction_name -> RingBuffer

# --- Per-NPC Buffers (reset when nearest NPC changes) ---
var _buf_modules: Dictionary = {}  # module_name -> RingBuffer
var _buf_disposition: RingBuffer
var _buf_trust: RingBuffer
var _buf_temp_fear: RingBuffer
var _buf_temp_like: RingBuffer
var _tracked_npc_id: String = ""  # ID of NPC being tracked for sparklines

# --- Panel References ---
var _main_panel: RichTextLabel      # Center/Main/Instructions - main content
var _toasts_panel: RichTextLabel    # Center/Toasts/DebugLabel - secondary content
var _profiler_panel: RichTextLabel  # Footer/Profiler - module scores
var _static_panel: RichTextLabel    # Header/empty - static NPC data
var _stats_panel: RichTextLabel     # Footer/Stats - NPC system data
var _face_cam_label: Label          # Footer/Face_cam - status icon area
var _log_panel: RichTextLabel       # Footer/Messages - log messages
var _minimap_label: Label           # Footer/MiniMap - placeholder for minimap component

# --- System References (auto-detected) ---
var _npc_manager: Node = null
var _rep_manager: Node = null
var _player: Node3D = null
var _nearest_npc: Node = null
var _nearest_npc_name: String = ""

# --- Debug references (can be set externally) ---
var debug_character: Node
var debug_camera_rig: Node
var debug_cursor: Node
var debug_zone_manager: Node
var debug_inventory: Node
var debug_equipment_manager: Node

# --- State ---
var _crime_index: int = 0
const CRIME_TYPES: Array[String] = ["trespass", "assault", "murder", "cop_assault", "cop_murder"]

# --- Log Messages ---
var _log_messages: PackedStringArray = []
const MAX_LOG_MESSAGES: int = 6


func _ready() -> void:
	_is_ready = true
	_load_font()
	_apply_font_settings()

	if not Engine.is_editor_hint():
		_set_mouse_filter_recursive(self, Control.MOUSE_FILTER_IGNORE)
		_cache_panel_references()
		_init_buffers()
		add_log("[color=cyan]GameHUD initialized[/color]")


func _init_buffers() -> void:
	# System-wide buffers (long history)
	_buf_realized = RingBuffer.new(LONG_CAPACITY)
	_buf_alive = RingBuffer.new(LONG_CAPACITY)
	_buf_avg_threat = RingBuffer.new(LONG_CAPACITY)

	# Per-NPC social memory buffers (short history, reset on NPC change)
	_buf_disposition = RingBuffer.new(SHORT_CAPACITY)
	_buf_trust = RingBuffer.new(SHORT_CAPACITY)
	_buf_temp_fear = RingBuffer.new(SHORT_CAPACITY)
	_buf_temp_like = RingBuffer.new(SHORT_CAPACITY)


func _cache_panel_references() -> void:
	# Main content panels
	_main_panel = get_node_or_null("Root/Layout/Center/Main/Instructions")
	_toasts_panel = get_node_or_null("Root/Layout/Center/Toasts/DebugLabel")
	_profiler_panel = get_node_or_null("Root/Layout/Footer/Profiler/Panel/ModuleScores")
	_static_panel = get_node_or_null("Root/Layout/Header/empty/StaticData")
	_stats_panel = get_node_or_null("Root/Layout/Footer/Stats/NPCSystemData")

	# Footer panels
	_face_cam_label = get_node_or_null("Root/Layout/Footer/Face_cam/Panel/Label")
	_log_panel = get_node_or_null("Root/Layout/Footer/Messages/Panel/LogLabel")
	_minimap_label = get_node_or_null("Root/Layout/Footer/MiniMap/Panel/Label")


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	# Auto-detect systems each frame (they might load late)
	_detect_systems()

	# Sample time-series data at fixed interval
	_sample_timer += delta
	if _sample_timer >= SAMPLE_INTERVAL:
		_sample_timer = 0.0
		_collect_samples()

	# Update all panels with modular content
	_update_static_panel()
	_update_main_panel()
	_update_toasts_panel()
	_update_stats_panel()
	_update_profiler_panel()
	_update_footer_panels()


func _detect_systems() -> void:
	# NPC System
	if not _npc_manager:
		_npc_manager = get_node_or_null("/root/NPCManager")

	# Reputation System
	if not _rep_manager:
		_rep_manager = get_node_or_null("/root/ReputationManager")

	# Player
	if not _player or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node3D

	# Find nearest realized NPC for detailed stats
	_update_nearest_npc()


func _update_nearest_npc() -> void:
	if not _npc_manager or not _npc_manager.has_method("get_realized_npcs"):
		_nearest_npc = null
		return

	var nearest: Node = null
	var nearest_dist: float = INF
	var ref_pos: Vector3 = _player.global_position if _player else Vector3.ZERO

	var realized_npcs: Dictionary = _npc_manager.get_realized_npcs()
	for npc_id: String in realized_npcs:
		var npc = realized_npcs[npc_id]
		if not is_instance_valid(npc):
			continue
		var dist: float = ref_pos.distance_to(npc.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = npc

	# Hysteresis - only switch if significantly closer
	if nearest and nearest != _nearest_npc:
		if _nearest_npc == null or not is_instance_valid(_nearest_npc):
			_switch_tracked_npc(nearest)
		elif nearest_dist < ref_pos.distance_to(_nearest_npc.global_position) - 2.0:
			_switch_tracked_npc(nearest)


func _switch_tracked_npc(npc: Node) -> void:
	_nearest_npc = npc
	_nearest_npc_name = _get_npc_name(npc)

	# Get NPC ID and reset buffers if tracking a new NPC
	var new_id: String = ""
	if npc and "abstract" in npc and npc.abstract:
		new_id = npc.abstract.npc_id if "npc_id" in npc.abstract else str(npc.get_instance_id())

	if new_id != _tracked_npc_id:
		_tracked_npc_id = new_id
		# Clear per-NPC buffers
		_buf_modules.clear()
		if _buf_disposition:
			_buf_disposition.clear()
		if _buf_trust:
			_buf_trust.clear()
		if _buf_temp_fear:
			_buf_temp_fear.clear()
		if _buf_temp_like:
			_buf_temp_like.clear()


func _collect_samples() -> void:
	if not _npc_manager:
		return

	# System metrics
	var stats: Dictionary = _npc_manager.get_stats() if _npc_manager.has_method("get_stats") else {}
	if _buf_realized:
		_buf_realized.push(float(stats.get("realized", 0)))
	if _buf_alive:
		_buf_alive.push(float(stats.get("alive", 0)))

	# Aggregate threat across all realized NPCs
	var threat_sum: float = 0.0
	var threat_count: int = 0
	if _npc_manager.has_method("get_realized_npcs"):
		var realized_npcs: Dictionary = _npc_manager.get_realized_npcs()
		for npc_id: String in realized_npcs:
			var npc = realized_npcs[npc_id]
			if is_instance_valid(npc) and npc.has_method("get_module_scores"):
				var scores: Dictionary = npc.get_module_scores()
				if scores.has("threat"):
					threat_sum += scores["threat"]
					threat_count += 1
	var avg_threat: float = threat_sum / float(threat_count) if threat_count > 0 else 0.0
	if _buf_avg_threat:
		_buf_avg_threat.push(avg_threat)

	# Reputation per faction
	if _rep_manager and _rep_manager.has_method("get_city_reputation"):
		var city_rep: Dictionary = _rep_manager.get_city_reputation()
		for faction: String in city_rep:
			if not _buf_reputation.has(faction):
				_buf_reputation[faction] = RingBuffer.new(LONG_CAPACITY)
			_buf_reputation[faction].push(city_rep[faction])

	# Per-NPC samples (module scores + social memory)
	if _nearest_npc and is_instance_valid(_nearest_npc):
		# Module scores
		if _nearest_npc.has_method("get_module_scores"):
			var scores: Dictionary = _nearest_npc.get_module_scores()
			for module_name: String in scores:
				if not _buf_modules.has(module_name):
					_buf_modules[module_name] = RingBuffer.new(SHORT_CAPACITY)
				_buf_modules[module_name].push(scores[module_name])

		# Social memory toward player
		if "abstract" in _nearest_npc and _nearest_npc.abstract:
			var a = _nearest_npc.abstract
			if "social_memories" in a and a.social_memories.has("player"):
				var mem = a.social_memories["player"]
				if _buf_disposition:
					_buf_disposition.push(mem.get_disposition() if mem.has_method("get_disposition") else 0.0)
				if _buf_trust:
					_buf_trust.push(mem.get_trust() if mem.has_method("get_trust") else 0.0)
				if _buf_temp_fear:
					_buf_temp_fear.push(mem.temp_fear if "temp_fear" in mem else 0.0)
				if _buf_temp_like:
					_buf_temp_like.push(mem.temp_like if "temp_like" in mem else 0.0)
			else:
				# No memory toward player yet
				if _buf_disposition:
					_buf_disposition.push(0.0)
				if _buf_trust:
					_buf_trust.push(0.0)
				if _buf_temp_fear:
					_buf_temp_fear.push(0.0)
				if _buf_temp_like:
					_buf_temp_like.push(0.0)


func _get_npc_name(npc: Node) -> String:
	if npc and "abstract" in npc and npc.abstract and "data" in npc.abstract:
		return npc.abstract.data.npc_name if npc.abstract.data else "Unknown"
	return "Unknown"


# =============================================================================
# STATIC PANEL - Header bar with static NPC data
# =============================================================================

func _update_static_panel() -> void:
	if not _static_panel:
		return

	var parts: PackedStringArray = []
	parts.append("[b][color=gray]STATUS[/color][/b]")

	if _npc_manager:
		# Population stats
		var stats: Dictionary = _npc_manager.get_stats() if _npc_manager.has_method("get_stats") else {}
		parts.append("[b]Pop:[/b] %d/%d/%d" % [stats.get("realized", 0), stats.get("alive", 0), stats.get("total", 0)])

		# Wanted level
		if _npc_manager.wanted_system:
			var ws = _npc_manager.wanted_system
			var level: int = _npc_manager.get_wanted_level() if _npc_manager.has_method("get_wanted_level") else 0
			var stars: String = "★".repeat(level) + "☆".repeat(5 - level)
			var status := ""
			if _npc_manager.has_method("should_cops_pursue") and _npc_manager.should_cops_pursue():
				status = "[color=red]PURSUIT[/color]"
			elif ws.is_being_observed:
				status = "[color=yellow]OBSERVED[/color]"
			parts.append("  |  [b]Wanted:[/b] %s %.0f %s" % [stars, ws.heat, status])

		# Nearest NPC info
		if _nearest_npc and is_instance_valid(_nearest_npc):
			parts.append("  |  [b][color=yellow]%s[/color][/b]" % _nearest_npc_name)

			if "abstract" in _nearest_npc and _nearest_npc.abstract:
				var a = _nearest_npc.abstract

				# Archetype/Faction
				if a.data:
					if "archetype" in a.data and a.data.archetype:
						parts.append("[color=cyan]%s[/color]" % a.data.archetype)
					if "faction" in a.data and a.data.faction:
						parts.append("[color=gray](%s)[/color]" % a.data.faction)

				# Personality traits
				if "personality" in a and a.personality:
					var p = a.personality
					parts.append("Grit:[color=lime]%.1f[/color] Anx:[color=orange]%.1f[/color] Agg:[color=red]%.1f[/color]" % [p.grit, p.anxiety, p.aggression])
	else:
		parts.append("[color=gray]Player Mode[/color]")

	_static_panel.text = " ".join(parts)


# =============================================================================
# MAIN PANEL - Primary content area (left side)
# =============================================================================

func _update_main_panel() -> void:
	if not _main_panel:
		return

	var text := ""

	# Show player system content if no NPC manager
	if not _npc_manager:
		text += _build_player_system_text()

	_main_panel.text = text


func _update_stats_panel() -> void:
	if not _stats_panel:
		return

	if not _npc_manager:
		_stats_panel.text = ""
		return

	var lines: PackedStringArray = []
	lines.append("[b][color=cyan]NPC SYSTEM[/color][/b]")
	lines.append("")

	# Health distribution
	lines.append("[b]Health:[/b]")
	var health_buckets: Array[int] = _get_health_distribution()
	for i in range(10):
		var pct: int = (i + 1) * 10
		var bar: String = "█".repeat(mini(health_buckets[i], 8))
		if health_buckets[i] > 0:
			lines.append("  %3d%%: %s %d" % [pct, bar, health_buckets[i]])

	lines.append("")

	# Drive distribution
	var drive_counts: Dictionary = _get_drive_counts()
	if not drive_counts.is_empty():
		lines.append("[b]Drives:[/b]")
		for d: String in drive_counts:
			var bar: String = "█".repeat(mini(drive_counts[d], 10))
			lines.append("  [color=%s]%-7s %s[/color] %d" % [_drive_color(d), d.to_upper(), bar, drive_counts[d]])

	_stats_panel.text = "\n".join(lines)


func _build_player_system_text() -> String:
	var text := "[b][color=cyan]═══ PLAYER SYSTEM ═══[/color][/b]\n\n"

	if debug_character and is_instance_valid(debug_character):
		var speed: float = debug_character.get_horizontal_speed() if debug_character.has_method("get_horizontal_speed") else 0.0
		text += "[b]Character[/b]\n"
		text += "  Speed: %.1f\n" % speed
		text += "  Sprinting: %s\n" % str(debug_character.get("is_sprinting"))
		text += "  Aiming: %s\n" % str(debug_character.get("is_aiming"))
		text += "  Position: %s\n\n" % _fmt_vec3(debug_character.global_position)

	if debug_camera_rig and is_instance_valid(debug_camera_rig):
		var preset_name := "None"
		var current_preset = debug_camera_rig.get("current_preset")
		if current_preset:
			preset_name = current_preset.get("preset_name") if current_preset.get("preset_name") else "Unknown"
		text += "[b]Camera[/b]\n"
		text += "  Preset: [color=cyan]%s[/color]\n" % preset_name
		text += "  Transitioning: %s\n\n" % str(debug_camera_rig.get("is_transitioning"))

	if debug_inventory and is_instance_valid(debug_inventory):
		var slots = debug_inventory.get("slots")
		var occupied := 0
		if slots:
			for slot in slots:
				if slot and not slot.is_empty():
					occupied += 1
		text += "[b]Inventory[/b]\n"
		text += "  Slots: %d / %d\n\n" % [occupied, debug_inventory.get("max_slots") if debug_inventory.get("max_slots") else 0]

	text += "[color=gray]F3: Toggle debug overlay[/color]"
	return text


# =============================================================================
# TOASTS PANEL - Secondary content (right side)
# =============================================================================

func _update_toasts_panel() -> void:
	if not _toasts_panel:
		return

	var lines: PackedStringArray = []
	lines.append("[b][color=yellow]GRAPHS[/color][/b]")
	lines.append("")

	# Show aggregate sparklines
	if _npc_manager:
		var stats: Dictionary = _npc_manager.get_stats() if _npc_manager.has_method("get_stats") else {}

		# System metrics sparklines
		lines.append("[b]System Metrics:[/b]")
		var realized: int = stats.get("realized", 0)
		var alive: int = stats.get("alive", 0)
		lines.append("  Realized: %3d %s" % [realized, _render_sparkline(_buf_realized, 18, 0, -1)])
		lines.append("  Alive:    %3d %s" % [alive, _render_sparkline(_buf_alive, 18, 0, -1)])
		lines.append("")

		# Average threat sparkline
		var avg_threat: float = _buf_avg_threat.latest() if _buf_avg_threat else 0.0
		lines.append("[b]Aggregate Threat:[/b]")
		lines.append("  Avg: %.2f %s" % [avg_threat, _render_sparkline_colored(_buf_avg_threat, "red", 18)])
		lines.append("")

	# Reputation sparklines
	if _rep_manager and _rep_manager.has_method("get_city_reputation"):
		var city_rep: Dictionary = _rep_manager.get_city_reputation()
		if not city_rep.is_empty():
			lines.append("[b]Reputation:[/b]")
			for faction: String in city_rep:
				var rep: float = city_rep[faction]
				var color: String = "red" if rep < -30 else "yellow" if rep < 30 else "lime"
				var sparkline: String = ""
				if _buf_reputation.has(faction):
					sparkline = _render_sparkline(_buf_reputation[faction], 12, -100, 100)
				lines.append("  %-8s [color=%s]%+4.0f[/color] %s" % [faction.substr(0, 8), color, rep, sparkline])
			lines.append("")

	# Nearest NPC summary
	if _nearest_npc and is_instance_valid(_nearest_npc):
		lines.append("[b]Nearest:[/b] %s" % _nearest_npc_name)
		if _nearest_npc.has_method("get_active_drive"):
			var drive: String = _nearest_npc.get_active_drive()
			lines.append("  Drive: [color=%s]%s[/color]" % [_drive_color(drive), drive])
		lines.append("")

	# FPS and controls
	lines.append("[color=gray]FPS: %d[/color]" % Engine.get_frames_per_second())
	lines.append("[color=gray]F2: Gunshot | F6: Crime[/color]")

	_toasts_panel.text = "\n".join(lines)


# =============================================================================
# PROFILER PANEL - Module scores for nearest NPC
# =============================================================================

func _update_profiler_panel() -> void:
	if not _profiler_panel:
		return

	var lines: PackedStringArray = []
	lines.append("[b][color=magenta]PROFILER[/color][/b]")

	if _npc_manager and _nearest_npc and is_instance_valid(_nearest_npc):
		lines.append("[b][color=yellow]%s[/color][/b]" % _nearest_npc_name)

		# Module scores with sparklines
		if _nearest_npc.has_method("get_module_scores"):
			var scores: Dictionary = _nearest_npc.get_module_scores()
			for module_name: String in scores:
				var score: float = scores[module_name]
				var bar_len: int = int(score * 10)
				var bar: String = "█".repeat(bar_len) + "░".repeat(10 - bar_len)
				var sparkline: String = ""
				if _buf_modules.has(module_name):
					sparkline = " " + _render_sparkline(_buf_modules[module_name], 12)
				lines.append("[color=%s]%-6s %s[/color] %.2f%s" % [
					_module_color(module_name), module_name.substr(0, 6), bar, score, sparkline
				])

		# Current drive
		if _nearest_npc.has_method("get_active_drive"):
			var drive: String = _nearest_npc.get_active_drive()
			lines.append("")
			lines.append("[b]Drive:[/b] [color=%s]%s[/color]" % [_drive_color(drive), drive.to_upper()])

		# Social memory toward player
		if "abstract" in _nearest_npc and _nearest_npc.abstract:
			var a = _nearest_npc.abstract
			if "social_memories" in a and a.social_memories.has("player"):
				var mem = a.social_memories["player"]
				var disp: float = mem.get_disposition() if mem.has_method("get_disposition") else 0.0
				var trust: float = mem.get_trust() if mem.has_method("get_trust") else 0.0
				var fear: float = mem.temp_fear if "temp_fear" in mem else 0.0
				var like: float = mem.temp_like if "temp_like" in mem else 0.0

				lines.append("")
				lines.append("[b]→Player:[/b]")
				lines.append("  Disp:%+4.0f %s" % [disp, _render_sparkline_colored(_buf_disposition, "cyan", 10, -100, 100)])
				lines.append("  Trust:%+3.0f %s" % [trust, _render_sparkline_colored(_buf_trust, "lime", 10, -100, 100)])
				lines.append("  Fear:%4.0f %s" % [fear, _render_sparkline_colored(_buf_temp_fear, "red", 10)])
				lines.append("  Like:%4.0f %s" % [like, _render_sparkline_colored(_buf_temp_like, "yellow", 10)])
	else:
		lines.append("")
		lines.append("[color=gray]No NPC nearby[/color]")

	_profiler_panel.text = "\n".join(lines)


# =============================================================================
# FOOTER PANELS
# =============================================================================

func _update_footer_panels() -> void:
	# Face Cam - placeholder for future use (portrait, etc)
	if _face_cam_label:
		_face_cam_label.text = ""

	# Log panel - Running log (updated via add_log)
	if _log_panel:
		var log_text := "[b][color=lime]LOG[/color][/b]\n"
		log_text += "\n".join(_log_messages)
		_log_panel.text = log_text

	# Minimap - placeholder for minimap component
	if _minimap_label:
		_minimap_label.text = ""


# =============================================================================
# INPUT HANDLING
# =============================================================================

func _input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_F2:
				_fire_test_gunshot()
			KEY_F6:
				_report_crime()


func _report_crime() -> void:
	if not _npc_manager or not _npc_manager.has_method("report_crime"):
		return
	var crime_type: String = CRIME_TYPES[_crime_index]
	_crime_index = (_crime_index + 1) % CRIME_TYPES.size()
	_npc_manager.report_crime(crime_type)
	add_log("[color=red]Crime: %s[/color]" % crime_type)


func _fire_test_gunshot() -> void:
	if not _npc_manager or not _npc_manager.has_method("broadcast_threat"):
		return
	var pos: Vector3 = _player.global_position if _player else Vector3.ZERO
	_npc_manager.broadcast_threat({"position": pos, "type": "gunfire"})
	add_log("[color=yellow]Gunshot![/color]")


## Add a message to the log panel. Supports BBCode.
func add_log(message: String) -> void:
	_log_messages.append(message)
	while _log_messages.size() > MAX_LOG_MESSAGES:
		_log_messages.remove_at(0)


# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

func _get_drive_counts() -> Dictionary:
	var counts: Dictionary = {}
	if not _npc_manager or not _npc_manager.has_method("get_realized_npcs"):
		return counts
	var realized_npcs: Dictionary = _npc_manager.get_realized_npcs()
	for npc_id: String in realized_npcs:
		var npc = realized_npcs[npc_id]
		if is_instance_valid(npc) and npc.has_method("get_active_drive"):
			var d: String = npc.get_active_drive()
			counts[d] = counts.get(d, 0) + 1
	return counts


func _get_health_distribution() -> Array[int]:
	var buckets: Array[int] = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
	if not _npc_manager or not _npc_manager.has_method("get_realized_npcs"):
		return buckets
	var realized_npcs: Dictionary = _npc_manager.get_realized_npcs()
	for npc_id: String in realized_npcs:
		var npc = realized_npcs[npc_id]
		if not is_instance_valid(npc) or not "abstract" in npc:
			continue
		var a = npc.abstract
		if not a or not a.data:
			continue
		var hp_pct: float = float(a.current_health) / float(a.data.max_health) if a.data.max_health > 0 else 0.0
		var bucket: int = clampi(int(hp_pct * 10.0), 0, 9)
		buckets[bucket] += 1
	return buckets


func _drive_color(drive: String) -> String:
	match drive:
		"idle": return "gray"
		"patrol": return "yellow"
		"flee", "threat": return "red"
		"pursue": return "magenta"
		"socialize": return "lime"
		"work": return "cyan"
		"deal": return "orange"
		"guard": return "purple"
		_: return "white"


func _module_color(module: String) -> String:
	match module:
		"idle": return "gray"
		"threat": return "red"
		"flee": return "orange"
		"opportunity": return "yellow"
		"social": return "lime"
		"pursuit", "pursue": return "magenta"
		_: return "white"


func _render_sparkline(buffer: RingBuffer, width: int = SPARKLINE_WIDTH, min_val: float = 0.0, max_val: float = 1.0) -> String:
	if not buffer:
		return "─".repeat(width)
	var data := buffer.get_ordered()
	if data.is_empty():
		return "─".repeat(width)

	# Auto-scale if no range provided or range is zero
	var range_val: float = max_val - min_val
	if range_val <= 0.0:
		min_val = buffer.min_value()
		max_val = buffer.max_value()
		range_val = max_val - min_val
		if range_val <= 0.0:
			range_val = 1.0

	var result := ""
	var step: int = maxi(1, data.size() / width)

	for i in range(width):
		var idx: int = i * data.size() / width
		if idx >= data.size():
			result += "─"
			continue
		var value: float = data[idx]
		var normalized: float = clampf((value - min_val) / range_val, 0.0, 1.0)
		var char_idx: int = int(normalized * (SPARKLINE_CHARS.length() - 1))
		result += SPARKLINE_CHARS[char_idx]

	return result


func _render_sparkline_colored(buffer: RingBuffer, color: String, width: int = SPARKLINE_WIDTH, min_val: float = 0.0, max_val: float = 1.0) -> String:
	var sparkline: String = _render_sparkline(buffer, width, min_val, max_val)
	return "[color=%s]%s[/color]" % [color, sparkline]


func _fmt_vec3(v: Vector3) -> String:
	return "(%.1f, %.1f, %.1f)" % [v.x, v.y, v.z]


# =============================================================================
# FONT MANAGEMENT
# =============================================================================

func _load_font() -> void:
	var font_path: String = FONT_PATHS.get(pixel_font, FONT_PATHS[PixelFont.TINY5])
	if ResourceLoader.exists(font_path):
		var loaded = load(font_path)
		if loaded is Font:
			_current_font = loaded
		else:
			_current_font = null
	else:
		_current_font = null


func _apply_font_settings() -> void:
	if not _is_ready or _is_applying:
		return
	_is_applying = true
	_load_font()
	if use_recommended_size:
		font_size = FONT_RECOMMENDED_SIZES.get(pixel_font, 10)
	if _current_font:
		_apply_font_recursive(self)
	_is_applying = false


func _apply_font_recursive(node: Node) -> void:
	if node is Control:
		if _current_font:
			if node is Label:
				var label := node as Label
				if label.label_settings:
					label.label_settings = null
				label.add_theme_font_override("font", _current_font)
				label.add_theme_font_size_override("font_size", font_size)
				label.add_theme_color_override("font_color", font_color)
				label.add_theme_constant_override("outline_size", font_outline_size)
				label.add_theme_color_override("font_outline_color", font_outline_color)
				label.add_theme_constant_override("shadow_offset_x", int(font_shadow_offset.x))
				label.add_theme_constant_override("shadow_offset_y", int(font_shadow_offset.y))
				label.add_theme_color_override("font_shadow_color", font_shadow_color)
			elif node is RichTextLabel:
				var rtl := node as RichTextLabel
				rtl.add_theme_font_override("normal_font", _current_font)
				rtl.add_theme_font_size_override("normal_font_size", font_size)
				rtl.add_theme_color_override("default_color", font_color)
			elif node is Button:
				var btn := node as Button
				btn.add_theme_font_override("font", _current_font)
				btn.add_theme_font_size_override("font_size", font_size)
				btn.add_theme_color_override("font_color", font_color)
	for child in node.get_children():
		_apply_font_recursive(child)


func _set_mouse_filter_recursive(node: Node, filter: Control.MouseFilter) -> void:
	if node is Control:
		# Don't disable mouse on interactive elements
		if node is BaseButton or node is Slider or node is LineEdit or node is TextEdit or node is SpinBox:
			node.mouse_filter = Control.MOUSE_FILTER_STOP
		else:
			node.mouse_filter = filter
	for child in node.get_children():
		_set_mouse_filter_recursive(child, filter)


func set_pixel_font(new_font: PixelFont) -> void:
	pixel_font = new_font


func get_current_font() -> Font:
	return _current_font


func apply_font_to_control(control: Control) -> void:
	_apply_font_recursive(control)
