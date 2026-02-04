extends Control
## Performance profiler display with CPU cores, GPU graph, and draw calls.

const GRAPH_HISTORY := 60  # Number of samples to keep
const BAR_CHARS := "▁▂▃▄▅▆▇█"

@onready var cpu_label: Label = $VBox/CPU/Label
@onready var gpu_label: Label = $VBox/GPU/Label
@onready var gpu_graph: Control = $VBox/GPU/Graph
@onready var stats_label: Label = $VBox/Stats/Label

var _frame_times: Array[float] = []
var _gpu_times: Array[float] = []
var _update_timer: float = 0.0

# CPU core count (cached)
var _cpu_cores: int = 1


func _ready() -> void:
	_cpu_cores = OS.get_processor_count()

	# Initialize graph arrays
	for i in GRAPH_HISTORY:
		_frame_times.append(0.0)
		_gpu_times.append(0.0)


func _process(delta: float) -> void:
	# Update at ~10 fps to reduce overhead
	_update_timer += delta
	if _update_timer < 0.1:
		return
	_update_timer = 0.0

	_update_frame_times(delta)
	_update_cpu_display()
	_update_gpu_display()
	_update_stats_display()
	gpu_graph.queue_redraw()


func _update_frame_times(delta: float) -> void:
	# Shift and add new frame time
	_frame_times.pop_front()
	_frame_times.append(delta * 1000.0)  # Convert to ms

	# GPU time from RenderingServer if available
	var gpu_time := Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	_gpu_times.pop_front()
	_gpu_times.append(gpu_time)


func _update_cpu_display() -> void:
	if not cpu_label:
		return

	var fps := Performance.get_monitor(Performance.TIME_FPS)
	var process_time := Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	var physics_time := Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0

	# Estimate CPU usage based on frame time vs target (assuming 60fps target)
	var target_frame := 16.67  # 60 fps
	var frame_time := 1000.0 / maxf(fps, 1.0)
	var cpu_load := clampf(frame_time / target_frame, 0.0, 2.0)

	# Create ASCII bar for CPU load
	var bar := _make_bar(cpu_load / 2.0, 10)

	var text := "CPU [%d cores]\n" % _cpu_cores
	text += "FPS: %d\n" % int(fps)
	text += "Load: %s %.0f%%\n" % [bar, cpu_load * 50.0]
	text += "Process: %.1fms\n" % process_time
	text += "Physics: %.1fms" % physics_time

	cpu_label.text = text


func _update_gpu_display() -> void:
	if not gpu_label:
		return

	var vram_used := Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0  # MB
	var draw_calls := Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	var objects := Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
	var primitives := Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)

	var text := "GPU\n"
	text += "VRAM: %.0fMB\n" % vram_used
	text += "Draw Calls: %d\n" % int(draw_calls)
	text += "Objects: %d\n" % int(objects)
	text += "Tris: %dk" % int(primitives / 1000.0)

	gpu_label.text = text


func _update_stats_display() -> void:
	if not stats_label:
		return

	var mem_static := Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0
	var mem_dynamic := Performance.get_monitor(Performance.MEMORY_MESSAGE_BUFFER_MAX) / 1048576.0
	var nodes := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	var orphans := Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	var resources := Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)

	# Frame time sparkline
	var sparkline := _make_sparkline(_frame_times, 20)

	var text := "MEMORY\n"
	text += "Static: %.0fMB\n" % mem_static
	text += "Nodes: %d\n" % int(nodes)
	text += "Orphans: %d\n" % int(orphans)
	text += "Resources: %d\n" % int(resources)
	text += "\nFRAME TIME\n"
	text += sparkline

	stats_label.text = text


func _make_bar(value: float, width: int) -> String:
	## Create an ASCII progress bar
	var filled := int(clampf(value, 0.0, 1.0) * width)
	var bar := ""
	for i in width:
		if i < filled:
			bar += "█"
		else:
			bar += "░"
	return bar


func _make_sparkline(values: Array[float], width: int) -> String:
	## Create a sparkline from recent values
	if values.is_empty():
		return ""

	# Sample the values to fit width
	var step := maxi(1, values.size() / width)
	var sampled: Array[float] = []
	for i in range(0, values.size(), step):
		if sampled.size() >= width:
			break
		sampled.append(values[i])

	# Find min/max for scaling
	var min_val := sampled.min()
	var max_val := maxf(sampled.max(), min_val + 0.1)

	var line := ""
	for val in sampled:
		var normalized: float = (val - min_val) / (max_val - min_val)
		var char_idx := int(clampf(normalized * (BAR_CHARS.length() - 1), 0, BAR_CHARS.length() - 1))
		line += BAR_CHARS[char_idx]

	return line


# Custom drawing for GPU graph
func _on_graph_draw() -> void:
	if not gpu_graph:
		return

	var rect := gpu_graph.get_rect()
	var w := rect.size.x
	var h := rect.size.y

	if _frame_times.is_empty() or w <= 0 or h <= 0:
		return

	# Draw background
	gpu_graph.draw_rect(Rect2(0, 0, w, h), Color(0.1, 0.1, 0.1, 0.5))

	# Find max for scaling (cap at 50ms to keep scale reasonable)
	var max_time := maxf(16.67, _frame_times.max())
	max_time = minf(max_time, 50.0)

	# Draw 16.67ms line (60fps target)
	var target_y := h - (16.67 / max_time) * h
	gpu_graph.draw_line(Vector2(0, target_y), Vector2(w, target_y), Color(0.2, 0.6, 0.2, 0.5), 1.0)

	# Draw 33.33ms line (30fps)
	var low_y := h - (33.33 / max_time) * h
	if low_y > 0:
		gpu_graph.draw_line(Vector2(0, low_y), Vector2(w, low_y), Color(0.6, 0.6, 0.2, 0.5), 1.0)

	# Draw frame time line
	var points: PackedVector2Array = []
	var step := w / float(GRAPH_HISTORY - 1)

	for i in _frame_times.size():
		var x := i * step
		var y := h - (_frame_times[i] / max_time) * h
		y = clampf(y, 0, h)
		points.append(Vector2(x, y))

	if points.size() >= 2:
		# Color based on performance (green = good, yellow = ok, red = bad)
		var avg_time := 0.0
		for t in _frame_times:
			avg_time += t
		avg_time /= _frame_times.size()

		var color := Color.GREEN
		if avg_time > 16.67:
			color = Color.YELLOW
		if avg_time > 33.33:
			color = Color.RED

		gpu_graph.draw_polyline(points, color, 2.0, true)
