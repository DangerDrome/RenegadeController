## Reusable graph panel for NPC data visualization.
## Draws one of 7 graph types using custom _draw() on the GraphArea control.
## Finds parent NPCDataGraphs node for data access.
extends PanelContainer

enum GraphType {
	DRIVE_DISTRIBUTION,
	MODULE_SPARKLINES,
	AGGREGATE_THREAT,
	REPUTATION_TIMELINE,
	SOCIAL_MEMORY,
	HEALTH_DISTRIBUTION,
	SYSTEM_METRICS,
}

@export var graph_type: GraphType = GraphType.DRIVE_DISTRIBUTION
@export var title_text: String = "Graph"

@onready var _title_label: Label = $Margin/VBox/Title
@onready var _graph_area: Control = $Margin/VBox/GraphArea

var _data_source: Node = null  # NPCDataGraphs parent


func _ready() -> void:
	_title_label.text = title_text
	_graph_area.draw.connect(_on_graph_area_draw)


func set_data_source(source: Node) -> void:
	_data_source = source


func redraw() -> void:
	if _graph_area:
		_graph_area.queue_redraw()


# --- Drawing ---

func _on_graph_area_draw() -> void:
	if not _data_source:
		return

	var sz: Vector2 = _graph_area.size

	match graph_type:
		GraphType.DRIVE_DISTRIBUTION:
			_draw_drive_distribution(sz)
		GraphType.MODULE_SPARKLINES:
			_draw_module_sparklines(sz)
		GraphType.AGGREGATE_THREAT:
			_draw_aggregate_threat(sz)
		GraphType.REPUTATION_TIMELINE:
			_draw_reputation_timeline(sz)
		GraphType.SOCIAL_MEMORY:
			_draw_social_memory(sz)
		GraphType.HEALTH_DISTRIBUTION:
			_draw_health_distribution(sz)
		GraphType.SYSTEM_METRICS:
			_draw_system_metrics(sz)


func _get_font() -> Font:
	return _title_label.get_theme_font("font") if _title_label else ThemeDB.fallback_font


func _draw_drive_distribution(sz: Vector2) -> void:
	var font: Font = _get_font()
	var ml: float = 80.0
	var mr: float = 45.0
	var mb: float = 8.0
	var mt: float = 4.0
	var plot_w: float = sz.x - ml - mr
	var plot_h: float = sz.y - mt - mb

	var drive_counts: Dictionary = _data_source._drive_counts
	if drive_counts.is_empty():
		_graph_area.draw_string(font, Vector2(ml, sz.y * 0.5),
			"No realized NPCs", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.3, 0.3, 0.3))
		return

	var sorted_drives: Array = []
	for d: String in drive_counts:
		sorted_drives.append([d, drive_counts[d]])
	sorted_drives.sort_custom(func(a: Array, b: Array) -> bool: return a[1] > b[1])

	var max_count: int = sorted_drives[0][1] if not sorted_drives.is_empty() else 1
	if max_count == 0:
		max_count = 1

	var bar_h: float = minf(20.0, plot_h / float(sorted_drives.size()) - 2.0)

	var drive_colors: Dictionary = _data_source.DRIVE_COLORS
	for i: int in range(sorted_drives.size()):
		var drive_name: String = sorted_drives[i][0]
		var count: int = sorted_drives[i][1]
		var y: float = mt + float(i) * (bar_h + 3.0)

		_graph_area.draw_string(font, Vector2(5, y + bar_h * 0.75),
			drive_name, HORIZONTAL_ALIGNMENT_LEFT, int(ml - 8), 11,
			drive_colors.get(drive_name, Color(0.4, 0.4, 0.4)))

		var bar_w: float = (float(count) / float(max_count)) * plot_w
		var color: Color = drive_colors.get(drive_name, Color(0.4, 0.4, 0.4))
		_graph_area.draw_rect(Rect2(ml, y, bar_w, bar_h), color)

		_graph_area.draw_string(font, Vector2(ml + bar_w + 5, y + bar_h * 0.75),
			str(count), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.7, 0.7, 0.7))


func _draw_module_sparklines(sz: Vector2) -> void:
	var font: Font = _get_font()
	var ml: float = 40.0
	var mr: float = 10.0
	var mb: float = 20.0
	var mt: float = 4.0
	var plot_w: float = sz.x - ml - mr
	var plot_h: float = sz.y - mt - mb

	# Show nearest NPC name in title area
	if _data_source._nearest_npc_name != "":
		_title_label.text = title_text + "  [" + _data_source._nearest_npc_name + "]"
	else:
		_title_label.text = title_text

	var buf_modules: Dictionary = _data_source._buf_modules
	if buf_modules.is_empty():
		_graph_area.draw_string(font, Vector2(ml, sz.y * 0.5),
			"No NPC nearby", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.3, 0.3, 0.3))
		return

	# Grid lines
	for g: int in range(5):
		var y: float = mt + (plot_h / 4.0) * float(g)
		_graph_area.draw_line(Vector2(ml, y), Vector2(ml + plot_w, y), Color(0.1, 0.1, 0.15))
	_graph_area.draw_string(font, Vector2(2, mt + 4), "1.0", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.3, 0.3, 0.3))
	_graph_area.draw_string(font, Vector2(2, mt + plot_h + 4), "0.0", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.3, 0.3, 0.3))

	var module_colors: Dictionary = _data_source.MODULE_COLORS
	var legend_x: float = ml
	for module_name: String in buf_modules:
		var buf = buf_modules[module_name]
		var data: PackedFloat32Array = buf.get_ordered()
		if data.size() < 2:
			continue

		var color: Color = module_colors.get(module_name, Color(0.4, 0.4, 0.4))
		var points: PackedVector2Array = []
		for i: int in range(data.size()):
			var x: float = ml + (float(i) / float(data.size() - 1)) * plot_w
			var y: float = mt + plot_h - clampf(data[i], 0.0, 1.0) * plot_h
			points.append(Vector2(x, y))
		_graph_area.draw_polyline(points, color, 1.5, true)

		var label_y: float = sz.y - 5
		_graph_area.draw_rect(Rect2(legend_x, label_y - 8, 8, 8), color)
		_graph_area.draw_string(font, Vector2(legend_x + 10, label_y),
			module_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.5, 0.5, 0.5))
		legend_x += font.get_string_size(module_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x + 22


func _draw_aggregate_threat(sz: Vector2) -> void:
	var font: Font = _get_font()
	var ml: float = 40.0
	var mr: float = 10.0
	var mb: float = 10.0
	var mt: float = 4.0
	var plot_w: float = sz.x - ml - mr
	var plot_h: float = sz.y - mt - mb

	var buf: Object = _data_source._buf_avg_threat
	var data: PackedFloat32Array = buf.get_ordered()
	if data.size() < 2:
		_graph_area.draw_string(font, Vector2(ml, sz.y * 0.5),
			"Collecting data...", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.3, 0.3, 0.3))
		return

	# Grid lines
	for g: int in range(5):
		var y: float = mt + (plot_h / 4.0) * float(g)
		_graph_area.draw_line(Vector2(ml, y), Vector2(ml + plot_w, y), Color(0.1, 0.1, 0.15))

	var max_val: float = buf.max_value()
	if max_val < 0.01:
		max_val = 1.0
	_graph_area.draw_string(font, Vector2(2, mt + 4), "%.2f" % max_val, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.3, 0.3, 0.3))
	_graph_area.draw_string(font, Vector2(2, mt + plot_h + 4), "0.0", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.3, 0.3, 0.3))

	var line_color := Color(1.0, 0.27, 0.27)
	var fill_color := Color(1.0, 0.15, 0.15, 0.2)
	var points: PackedVector2Array = []
	var fill_points: PackedVector2Array = []

	for i: int in range(data.size()):
		var x: float = ml + (float(i) / float(data.size() - 1)) * plot_w
		var y: float = mt + plot_h - clampf(data[i] / max_val, 0.0, 1.0) * plot_h
		points.append(Vector2(x, y))
		fill_points.append(Vector2(x, y))

	fill_points.append(Vector2(ml + plot_w, mt + plot_h))
	fill_points.append(Vector2(ml, mt + plot_h))
	if fill_points.size() >= 3:
		_graph_area.draw_colored_polygon(fill_points, fill_color)
	if points.size() >= 2:
		_graph_area.draw_polyline(points, line_color, 1.5, true)

	# Current value in title
	_title_label.text = title_text + "  %.3f" % buf.latest()


func _draw_reputation_timeline(sz: Vector2) -> void:
	var font: Font = _get_font()
	var ml: float = 40.0
	var mr: float = 10.0
	var mb: float = 20.0
	var mt: float = 4.0
	var plot_w: float = sz.x - ml - mr
	var plot_h: float = sz.y - mt - mb

	var buf_reputation: Dictionary = _data_source._buf_reputation
	if buf_reputation.is_empty():
		_graph_area.draw_string(font, Vector2(ml, sz.y * 0.5),
			"No reputation data", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.3, 0.3, 0.3))
		return

	# Grid
	for g: int in range(5):
		var y: float = mt + (plot_h / 4.0) * float(g)
		_graph_area.draw_line(Vector2(ml, y), Vector2(ml + plot_w, y), Color(0.1, 0.1, 0.15))

	# Zero line
	var zero_y: float = mt + plot_h * 0.5
	_graph_area.draw_line(Vector2(ml, zero_y), Vector2(ml + plot_w, zero_y), Color(0.25, 0.25, 0.25))

	# Threshold lines at +/-30
	var thresh_hi: float = mt + plot_h * (1.0 - 130.0 / 200.0)
	var thresh_lo: float = mt + plot_h * (1.0 - 70.0 / 200.0)
	_graph_area.draw_line(Vector2(ml, thresh_hi), Vector2(ml + plot_w, thresh_hi), Color(0.2, 0.3, 0.2, 0.5))
	_graph_area.draw_line(Vector2(ml, thresh_lo), Vector2(ml + plot_w, thresh_lo), Color(0.3, 0.2, 0.2, 0.5))

	# Y-axis labels
	_graph_area.draw_string(font, Vector2(2, mt + 4), "+100", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.3, 0.3, 0.3))
	_graph_area.draw_string(font, Vector2(2, zero_y + 4), "0", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.35, 0.35, 0.35))
	_graph_area.draw_string(font, Vector2(2, mt + plot_h + 4), "-100", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.3, 0.3, 0.3))

	var faction_colors: Array[Color] = [
		Color(1.0, 0.27, 0.27),
		Color(0.27, 0.87, 0.27),
		Color(0.27, 0.53, 0.87),
		Color(0.87, 0.87, 0.0),
		Color(0.87, 0.27, 0.87),
	]
	var idx: int = 0
	var legend_x: float = ml
	for faction: String in buf_reputation:
		var buf = buf_reputation[faction]
		var data: PackedFloat32Array = buf.get_ordered()
		if data.size() < 2:
			idx += 1
			continue

		var color: Color = faction_colors[idx % faction_colors.size()]
		var points: PackedVector2Array = []
		for i: int in range(data.size()):
			var x: float = ml + (float(i) / float(data.size() - 1)) * plot_w
			var norm: float = (data[i] + 100.0) / 200.0
			var y: float = mt + plot_h - norm * plot_h
			points.append(Vector2(x, y))
		_graph_area.draw_polyline(points, color, 1.5, true)

		var label_y: float = sz.y - 5
		_graph_area.draw_rect(Rect2(legend_x, label_y - 8, 8, 8), color)
		_graph_area.draw_string(font, Vector2(legend_x + 10, label_y),
			faction, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.5, 0.5, 0.5))
		legend_x += font.get_string_size(faction, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x + 22
		idx += 1


func _draw_social_memory(sz: Vector2) -> void:
	var font: Font = _get_font()
	var ml: float = 40.0
	var mr: float = 10.0
	var mb: float = 20.0
	var mt: float = 4.0
	var plot_w: float = sz.x - ml - mr
	var plot_h: float = sz.y - mt - mb

	# Show nearest NPC name in title
	if _data_source._nearest_npc_name != "":
		_title_label.text = title_text + "  [" + _data_source._nearest_npc_name + "]"
	else:
		_title_label.text = title_text

	var buffers: Dictionary = {
		"disposition": _data_source._buf_disposition,
		"trust": _data_source._buf_trust,
		"temp_fear": _data_source._buf_temp_fear,
		"temp_like": _data_source._buf_temp_like,
	}

	var has_data: bool = false
	for key: String in buffers:
		if buffers[key].get_ordered().size() >= 2:
			has_data = true
			break

	if not has_data:
		_graph_area.draw_string(font, Vector2(ml, sz.y * 0.5),
			"No NPC nearby", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.3, 0.3, 0.3))
		return

	# Grid: Y range -1 to +1
	for g: int in range(5):
		var y: float = mt + (plot_h / 4.0) * float(g)
		_graph_area.draw_line(Vector2(ml, y), Vector2(ml + plot_w, y), Color(0.1, 0.1, 0.15))

	var zero_y: float = mt + plot_h * 0.5
	_graph_area.draw_line(Vector2(ml, zero_y), Vector2(ml + plot_w, zero_y), Color(0.25, 0.25, 0.25))

	_graph_area.draw_string(font, Vector2(2, mt + 4), "+1.0", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.3, 0.3, 0.3))
	_graph_area.draw_string(font, Vector2(2, zero_y + 4), "0", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.35, 0.35, 0.35))
	_graph_area.draw_string(font, Vector2(2, mt + plot_h + 4), "-1.0", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.3, 0.3, 0.3))

	var memory_colors: Dictionary = _data_source.MEMORY_COLORS
	var legend_x: float = ml
	for key: String in buffers:
		var buf = buffers[key]
		var data: PackedFloat32Array = buf.get_ordered()
		if data.size() < 2:
			continue

		var color: Color = memory_colors.get(key, Color(0.4, 0.4, 0.4))
		var points: PackedVector2Array = []
		for i: int in range(data.size()):
			var x: float = ml + (float(i) / float(data.size() - 1)) * plot_w
			var norm: float = (data[i] + 1.0) / 2.0
			var y: float = mt + plot_h - norm * plot_h
			points.append(Vector2(x, y))
		_graph_area.draw_polyline(points, color, 1.5, true)

		var label_y: float = sz.y - 5
		_graph_area.draw_rect(Rect2(legend_x, label_y - 8, 8, 8), color)
		_graph_area.draw_string(font, Vector2(legend_x + 10, label_y),
			key, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.5, 0.5, 0.5))
		legend_x += font.get_string_size(key, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x + 22


func _draw_health_distribution(sz: Vector2) -> void:
	var font: Font = _get_font()
	var ml: float = 30.0
	var mr: float = 10.0
	var mb: float = 20.0
	var mt: float = 4.0
	var plot_w: float = sz.x - ml - mr
	var plot_h: float = sz.y - mt - mb

	var health_buckets: PackedFloat32Array = _data_source._health_buckets
	var max_bucket: float = 0.0
	for i: int in range(10):
		max_bucket = maxf(max_bucket, health_buckets[i])
	if max_bucket < 1.0:
		max_bucket = 1.0

	var bar_w: float = plot_w / 10.0 - 3.0

	for i: int in range(10):
		var x: float = ml + float(i) * (bar_w + 3.0)
		var bar_h: float = (health_buckets[i] / max_bucket) * plot_h
		var y: float = mt + plot_h - bar_h

		var t: float = float(i) / 9.0
		var color := Color(1.0 - t, t, 0.1)
		_graph_area.draw_rect(Rect2(x, y, bar_w, bar_h), color)

		_graph_area.draw_string(font, Vector2(x, sz.y - 5),
			"%d%%" % (i * 10), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.4, 0.4, 0.4))

		if health_buckets[i] > 0:
			_graph_area.draw_string(font, Vector2(x, y - 3),
				str(int(health_buckets[i])), HORIZONTAL_ALIGNMENT_LEFT, -1, 10,
				Color(0.7, 0.7, 0.7))


func _draw_system_metrics(sz: Vector2) -> void:
	var font: Font = _get_font()
	var ml: float = 40.0
	var mr: float = 10.0
	var mb: float = 10.0
	var mt: float = 4.0
	var plot_w: float = sz.x - ml - mr
	var plot_h: float = sz.y - mt - mb

	var buf_realized: Object = _data_source._buf_realized
	var buf_alive: Object = _data_source._buf_alive
	var data_realized: PackedFloat32Array = buf_realized.get_ordered()
	var data_alive: PackedFloat32Array = buf_alive.get_ordered()

	if data_realized.size() < 2:
		_graph_area.draw_string(font, Vector2(ml, sz.y * 0.5),
			"Collecting data...", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.3, 0.3, 0.3))
		return

	var max_val: float = maxf(buf_realized.max_value(), buf_alive.max_value())
	if max_val < 1.0:
		max_val = 1.0

	# Grid
	for g: int in range(5):
		var y: float = mt + (plot_h / 4.0) * float(g)
		_graph_area.draw_line(Vector2(ml, y), Vector2(ml + plot_w, y), Color(0.1, 0.1, 0.15))

	_graph_area.draw_string(font, Vector2(2, mt + 4), str(int(max_val)), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.3, 0.3, 0.3))
	_graph_area.draw_string(font, Vector2(2, mt + plot_h + 4), "0", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.3, 0.3, 0.3))

	# Alive line (green)
	var alive_color := Color(0.27, 0.87, 0.27)
	var alive_pts: PackedVector2Array = []
	for i: int in range(data_alive.size()):
		var x: float = ml + (float(i) / float(data_alive.size() - 1)) * plot_w
		var y: float = mt + plot_h - clampf(data_alive[i] / max_val, 0.0, 1.0) * plot_h
		alive_pts.append(Vector2(x, y))
	if alive_pts.size() >= 2:
		_graph_area.draw_polyline(alive_pts, alive_color, 1.5, true)

	# Realized line (cyan)
	var real_color := Color(0.0, 0.83, 1.0)
	var real_pts: PackedVector2Array = []
	for i: int in range(data_realized.size()):
		var x: float = ml + (float(i) / float(data_realized.size() - 1)) * plot_w
		var y: float = mt + plot_h - clampf(data_realized[i] / max_val, 0.0, 1.0) * plot_h
		real_pts.append(Vector2(x, y))
	if real_pts.size() >= 2:
		_graph_area.draw_polyline(real_pts, real_color, 1.5, true)

	# Current values drawn in graph area
	_graph_area.draw_string(font, Vector2(ml + 5, mt + 16),
		"Realized: %d" % int(buf_realized.latest()), HORIZONTAL_ALIGNMENT_LEFT, -1, 11,
		real_color)
	_graph_area.draw_string(font, Vector2(ml + 5, mt + 30),
		"Alive: %d" % int(buf_alive.latest()), HORIZONTAL_ALIGNMENT_LEFT, -1, 11,
		alive_color)
