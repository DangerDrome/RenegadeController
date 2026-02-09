## TestVisualizer: In-game test runner overlay toggled with F5.
## Shows a terminal log of test results on the left, scenario graphs on the right.
## Add as a child CanvasLayer in the demo scene.
extends CanvasLayer

const _TestSocialMemory = preload("res://addons/renegade_npc/tests/test_social_memory.gd")
const _TestPersonality = preload("res://addons/renegade_npc/tests/test_personality.gd")
const _TestModuleScoring = preload("res://addons/renegade_npc/tests/test_module_scoring.gd")
const _TestFleeRecovery = preload("res://addons/renegade_npc/tests/test_flee_recovery.gd")
const _TestReputation = preload("res://addons/renegade_npc/tests/test_reputation.gd")
const _TestAbstractNPC = preload("res://addons/renegade_npc/tests/test_abstract_npc.gd")
const _Scenarios = preload("res://addons/renegade_npc/tests/test_scenarios.gd")
const _ScenarioDataScript = preload("res://addons/renegade_npc/tests/scenario_data.gd")

# Drive colors matching demo_hud.gd
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

# UI nodes
var _root_panel: PanelContainer
var _terminal: RichTextLabel
var _run_all_btn: Button
var _run_unit_btn: Button
var _run_scenario_btn: Button
var _progress_bar: ProgressBar
var _status_label: Label
var _graph_tabs: TabContainer
var _drive_timeline: Control
var _score_curves: Control
var _personality_map: Control

# Test state
var _pass_count: int = 0
var _fail_count: int = 0
var _skip_count: int = 0
var _current_suite: String = ""
var _errors: Array[String] = []
var _total_suites: int = 0
var _completed_suites: int = 0
var _scenario_data: RefCounted = null

# Suite tracking
var _suite_pass: int = 0
var _suite_fail: int = 0
var _suite_start_ms: int = 0

var _visible: bool = false


func _ready() -> void:
	_build_ui()
	_root_panel.visible = false
	_run_all_btn.pressed.connect(_on_run_all)
	_run_unit_btn.pressed.connect(_on_run_unit)
	_run_scenario_btn.pressed.connect(_on_run_scenarios)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_F5:
		_visible = not _visible
		_root_panel.visible = _visible
		get_viewport().set_input_as_handled()


func _build_ui() -> void:
	# Full-screen dark panel
	_root_panel = PanelContainer.new()
	_root_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.04, 0.10, 0.95)
	_root_panel.add_theme_stylebox_override("panel", style)
	add_child(_root_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 15)
	margin.add_theme_constant_override("margin_right", 15)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	_root_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	margin.add_child(vbox)

	# --- Header row ---
	var header := HBoxContainer.new()
	vbox.add_child(header)

	var title := Label.new()
	title.text = "TEST RUNNER"
	title.add_theme_color_override("font_color", Color(0.0, 0.83, 1.0))
	title.add_theme_font_size_override("font_size", 18)
	header.add_child(title)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)

	_run_all_btn = Button.new()
	_run_all_btn.text = "Run All"
	_run_all_btn.custom_minimum_size.x = 80
	header.add_child(_run_all_btn)

	_run_unit_btn = Button.new()
	_run_unit_btn.text = "Unit"
	_run_unit_btn.custom_minimum_size.x = 60
	header.add_child(_run_unit_btn)

	_run_scenario_btn = Button.new()
	_run_scenario_btn.text = "Scenarios"
	_run_scenario_btn.custom_minimum_size.x = 80
	header.add_child(_run_scenario_btn)

	var close_hint := Label.new()
	close_hint.text = "  [F5 close]"
	close_hint.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
	close_hint.add_theme_font_size_override("font_size", 12)
	header.add_child(close_hint)

	# --- Progress ---
	_progress_bar = ProgressBar.new()
	_progress_bar.custom_minimum_size.y = 6
	_progress_bar.value = 0
	_progress_bar.show_percentage = false
	vbox.add_child(_progress_bar)

	_status_label = Label.new()
	_status_label.text = "Press Run All to execute 90 unit + 27 scenario tests."
	_status_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	_status_label.add_theme_font_size_override("font_size", 13)
	vbox.add_child(_status_label)

	# --- Split: terminal | graphs ---
	var hsplit := HSplitContainer.new()
	hsplit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(hsplit)

	# Left: terminal log
	var left_box := VBoxContainer.new()
	left_box.custom_minimum_size.x = 480
	hsplit.add_child(left_box)

	var term_label := Label.new()
	term_label.text = "Terminal"
	term_label.add_theme_color_override("font_color", Color(0.0, 0.83, 1.0))
	term_label.add_theme_font_size_override("font_size", 13)
	left_box.add_child(term_label)

	_terminal = RichTextLabel.new()
	_terminal.bbcode_enabled = true
	_terminal.scroll_following = true
	_terminal.selection_enabled = true
	_terminal.context_menu_enabled = true
	_terminal.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_terminal.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_terminal.add_theme_font_size_override("normal_font_size", 12)
	_terminal.add_theme_font_size_override("bold_font_size", 12)
	_terminal.add_theme_font_size_override("mono_font_size", 12)
	# Dark terminal background
	var term_style := StyleBoxFlat.new()
	term_style.bg_color = Color(0.02, 0.02, 0.06)
	term_style.content_margin_left = 8
	term_style.content_margin_right = 8
	term_style.content_margin_top = 6
	term_style.content_margin_bottom = 6
	_terminal.add_theme_stylebox_override("normal", term_style)
	left_box.add_child(_terminal)

	# Right: graphs
	var right_box := VBoxContainer.new()
	right_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hsplit.add_child(right_box)

	_graph_tabs = TabContainer.new()
	_graph_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_graph_tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_box.add_child(_graph_tabs)

	_drive_timeline = _GraphPanel.new()
	_drive_timeline.name = "Drive Timeline"
	_graph_tabs.add_child(_drive_timeline)

	_score_curves = _GraphPanel.new()
	_score_curves.name = "Score Curves"
	_graph_tabs.add_child(_score_curves)

	_personality_map = _GraphPanel.new()
	_personality_map.name = "Personality Map"
	_graph_tabs.add_child(_personality_map)


## --- Terminal output ---

func _term(text: String) -> void:
	_terminal.append_text(text + "\n")


func _term_pass(text: String) -> void:
	_terminal.append_text("[color=green]  ✓[/color] %s\n" % text)


func _term_fail(text: String) -> void:
	_terminal.append_text("[color=red]  ✗ %s[/color]\n" % text)


func _term_suite(text: String) -> void:
	_terminal.append_text("\n[color=cyan][b]── %s ──[/b][/color]\n" % text)


func _term_info(text: String) -> void:
	_terminal.append_text("[color=gray]    %s[/color]\n" % text)


func _term_suite_summary(passed: int, total: int, ms: int) -> void:
	var color := "green" if passed == total else "red"
	_terminal.append_text("[color=%s]  %d/%d passed[/color] [color=gray](%dms)[/color]\n" % [
		color, passed, total, ms,
	])


## --- Reset / Run ---

func _reset_state() -> void:
	_pass_count = 0
	_fail_count = 0
	_skip_count = 0
	_current_suite = ""
	_errors.clear()
	_completed_suites = 0
	_suite_pass = 0
	_suite_fail = 0
	_scenario_data = _ScenarioDataScript.new()
	_progress_bar.value = 0
	_terminal.clear()


func _on_run_all() -> void:
	_reset_state()
	_total_suites = 16
	_status_label.text = "Running all tests..."
	_term("[b][color=cyan]══════ RenegadeNPC Test Runner ══════[/color][/b]")
	await get_tree().process_frame

	_run_unit_tests()
	await get_tree().process_frame
	_run_scenario_tests()
	_finish()


func _on_run_unit() -> void:
	_reset_state()
	_total_suites = 6
	_status_label.text = "Running unit tests..."
	_term("[b][color=cyan]══════ Unit Tests ══════[/color][/b]")
	await get_tree().process_frame

	_run_unit_tests()
	_finish()


func _on_run_scenarios() -> void:
	_reset_state()
	_total_suites = 10
	_status_label.text = "Running scenario tests..."
	_term("[b][color=cyan]══════ Scenario Tests ══════[/color][/b]")
	await get_tree().process_frame

	_run_scenario_tests()
	_finish()


func _run_unit_tests() -> void:
	_suite("SocialMemory")
	_TestSocialMemory.run(self)
	_end_suite()

	_suite("NPCPersonality")
	_TestPersonality.run(self)
	_end_suite()

	_suite("ModuleScoring")
	_TestModuleScoring.run(self)
	_end_suite()

	_suite("FleeRecovery")
	_TestFleeRecovery.run(self)
	_end_suite()

	_suite("ReputationManager")
	_TestReputation.run(self)
	_end_suite()

	_suite("AbstractNPC")
	_TestAbstractNPC.run(self)
	_end_suite()


func _run_scenario_tests() -> void:
	_Scenarios.run_all(self, _scenario_data)
	if _current_suite != "":
		_end_suite()


func _finish() -> void:
	_progress_bar.value = 100
	var total := _pass_count + _fail_count + _skip_count

	# Summary bar in terminal
	var bar_len: int = 40
	var pass_chars: int = int(float(_pass_count) / float(total) * bar_len) if total > 0 else 0
	var fail_chars: int = bar_len - pass_chars
	var bar := "[color=green]%s[/color][color=gray]%s[/color]" % [
		"█".repeat(pass_chars),
		("█".repeat(fail_chars) if _fail_count > 0 else "░".repeat(fail_chars)),
	]
	_term("\n%s" % bar)

	if _fail_count == 0:
		_status_label.text = "All %d tests passed!" % total
		_status_label.add_theme_color_override("font_color", Color(0.3, 0.9, 0.3))
		_term("[b][color=green]✓ %d passed[/color][/b] / %d total" % [_pass_count, total])
	else:
		_status_label.text = "%d passed, %d failed / %d total" % [_pass_count, _fail_count, total]
		_status_label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
		_term("[b][color=green]%d passed[/color], [color=red]%d failed[/color][/b] / %d total" % [
			_pass_count, _fail_count, total,
		])
		_term("")
		for err: String in _errors:
			_term("[color=red]  ✗ %s[/color]" % err)

	_update_graphs()


func _update_graphs() -> void:
	var timeline_panel := _drive_timeline as _GraphPanel
	var curves_panel := _score_curves as _GraphPanel
	var scatter_panel := _personality_map as _GraphPanel

	timeline_panel.scenario_data = _scenario_data
	timeline_panel.graph_type = _GraphPanel.GraphType.DRIVE_TIMELINE
	timeline_panel.queue_redraw()

	curves_panel.scenario_data = _scenario_data
	curves_panel.graph_type = _GraphPanel.GraphType.SCORE_CURVES
	curves_panel.queue_redraw()

	scatter_panel.scenario_data = _scenario_data
	scatter_panel.graph_type = _GraphPanel.GraphType.PERSONALITY_SCATTER
	scatter_panel.queue_redraw()


## --- Assertion API (compatible with both run_tests.gd and run_scenario_tests.gd) ---

func _suite(name: String) -> void:
	_current_suite = name
	_suite_pass = 0
	_suite_fail = 0
	_suite_start_ms = Time.get_ticks_msec()
	_term_suite(name)


## Also used by run_scenario_tests.gd as `suite()`
func suite(name: String) -> void:
	if _current_suite != "":
		_end_suite()
	_suite(name)


func _end_suite() -> void:
	_completed_suites += 1
	if _total_suites > 0:
		_progress_bar.value = float(_completed_suites) / float(_total_suites) * 100.0
	var elapsed_ms: int = Time.get_ticks_msec() - _suite_start_ms
	_term_suite_summary(_suite_pass, _suite_pass + _suite_fail, elapsed_ms)


func assert_true(condition: bool, description: String) -> void:
	if condition:
		_pass_count += 1
		_suite_pass += 1
		_term_pass(description)
	else:
		_fail_count += 1
		_suite_fail += 1
		_errors.append("%s::%s" % [_current_suite, description])
		_term_fail(description)


func assert_false(condition: bool, description: String) -> void:
	assert_true(not condition, description)


func assert_eq(actual: Variant, expected: Variant, description: String) -> void:
	if actual == expected:
		_pass_count += 1
		_suite_pass += 1
		_term_pass(description)
	else:
		_fail_count += 1
		_suite_fail += 1
		var msg := "%s::%s (got %s, expected %s)" % [_current_suite, description, str(actual), str(expected)]
		_errors.append(msg)
		_term_fail("%s (got %s, expected %s)" % [description, str(actual), str(expected)])


func assert_approx(actual: float, expected: float, tolerance: float, description: String) -> void:
	if absf(actual - expected) <= tolerance:
		_pass_count += 1
		_suite_pass += 1
		_term_pass(description)
	else:
		_fail_count += 1
		_suite_fail += 1
		_errors.append("%s::%s (%.4f vs %.4f)" % [_current_suite, description, actual, expected])
		_term_fail("%s (%.4f vs %.4f ± %.4f)" % [description, actual, expected, tolerance])


func assert_in_range(value: float, low: float, high: float, description: String) -> void:
	assert_true(value >= low and value <= high, "%s (%.4f in [%.4f, %.4f])" % [description, value, low, high])


func assert_gt(actual: float, threshold: float, description: String) -> void:
	assert_true(actual > threshold, "%s (%.4f > %.4f)" % [description, actual, threshold])


func assert_lt(actual: float, threshold: float, description: String) -> void:
	assert_true(actual < threshold, "%s (%.4f < %.4f)" % [description, actual, threshold])


## Scenario-style assertions
func check(condition: bool, description: String) -> void:
	assert_true(condition, description)


func check_gt(actual: float, threshold: float, desc: String) -> void:
	check(actual > threshold, "%s (%.3f > %.3f)" % [desc, actual, threshold])


func check_lt(actual: float, threshold: float, desc: String) -> void:
	check(actual < threshold, "%s (%.3f < %.3f)" % [desc, actual, threshold])


func check_range(value: float, lo: float, hi: float, desc: String) -> void:
	check(value >= lo and value <= hi, "%s (%.3f in [%.3f, %.3f])" % [desc, value, lo, hi])


func check_eq(actual: Variant, expected: Variant, desc: String) -> void:
	check(actual == expected, "%s (got %s, expected %s)" % [desc, str(actual), str(expected)])


func report(text: String) -> void:
	_term_info(text)


## --- Graph Panel (inner class for _draw-based charts) ---

class _GraphPanel extends Control:
	enum GraphType { DRIVE_TIMELINE, SCORE_CURVES, PERSONALITY_SCATTER }

	var scenario_data: Variant = null
	var graph_type: GraphType = GraphType.DRIVE_TIMELINE

	func _draw() -> void:
		var rect := get_rect()
		draw_rect(Rect2(Vector2.ZERO, rect.size), Color(0.04, 0.04, 0.10))

		if scenario_data == null or scenario_data.results.is_empty():
			var font := ThemeDB.fallback_font
			draw_string(font, Vector2(rect.size.x * 0.2, rect.size.y * 0.5),
				"Run tests to generate graphs", HORIZONTAL_ALIGNMENT_LEFT, -1, 14,
				Color(0.3, 0.3, 0.3))
			return

		match graph_type:
			GraphType.DRIVE_TIMELINE:
				_draw_drive_timeline(rect.size)
			GraphType.SCORE_CURVES:
				_draw_score_curves(rect.size)
			GraphType.PERSONALITY_SCATTER:
				_draw_personality_scatter(rect.size)


	func _draw_drive_timeline(sz: Vector2) -> void:
		var font := ThemeDB.fallback_font
		var margin_left: float = 100.0
		var margin_top: float = 10.0
		var margin_bottom: float = 30.0
		var margin_right: float = 20.0
		var plot_w: float = sz.x - margin_left - margin_right
		var plot_h: float = sz.y - margin_top - margin_bottom

		# Collect all timelines across results
		var timelines: Array = []
		for result: Variant in scenario_data.results:
			for tl: Variant in result.timelines:
				if tl.snapshots.size() > 1:
					timelines.append(tl)
				if timelines.size() >= 20:
					break

		if timelines.is_empty():
			return

		var row_h: float = minf(18.0, plot_h / float(timelines.size()))

		# Find time range
		var max_t: float = 0.0
		for tl: Variant in timelines:
			if not tl.snapshots.is_empty():
				var last: Variant = tl.snapshots[tl.snapshots.size() - 1]
				max_t = maxf(max_t, last.time)
		if max_t <= 0.0:
			return

		# Draw strips
		for i: int in range(timelines.size()):
			var tl: Variant = timelines[i]
			var y: float = margin_top + float(i) * row_h

			# NPC label
			draw_string(font, Vector2(5, y + row_h * 0.75),
				tl.npc_name.left(12), HORIZONTAL_ALIGNMENT_LEFT, int(margin_left - 10), 11,
				Color(0.55, 0.55, 0.55))

			# Drive strips
			for s: int in range(tl.snapshots.size() - 1):
				var snap: Variant = tl.snapshots[s]
				var next_snap: Variant = tl.snapshots[s + 1]
				var x1: float = margin_left + (snap.time / max_t) * plot_w
				var x2: float = margin_left + (next_snap.time / max_t) * plot_w
				var color: Color = _get_drive_color(snap.active_drive)
				draw_rect(Rect2(x1, y + 2, maxf(x2 - x1, 1.0), row_h - 4), color)

		# Time axis
		var axis_y: float = margin_top + float(timelines.size()) * row_h + 5
		draw_line(Vector2(margin_left, axis_y), Vector2(margin_left + plot_w, axis_y),
			Color(0.25, 0.25, 0.25))

		for tick: int in range(9):
			var t: float = max_t / 8.0 * float(tick)
			var x: float = margin_left + (t / max_t) * plot_w
			draw_string(font, Vector2(x - 15, axis_y + 15),
				"%.0fs" % t, HORIZONTAL_ALIGNMENT_LEFT, -1, 10,
				Color(0.4, 0.4, 0.4))

		# Legend
		var legend_x: float = margin_left
		var legend_y: float = sz.y - 5
		var drive_colors := {
			"idle": Color(0.53, 0.53, 0.53), "patrol": Color(0.8, 0.8, 0.0),
			"flee": Color(0.87, 0.2, 0.2), "threat": Color(1.0, 0.27, 0.27),
			"socialize": Color(0.27, 0.87, 0.27), "work": Color(0.27, 0.87, 0.87),
		}
		for drive_name: String in drive_colors:
			draw_rect(Rect2(legend_x, legend_y - 10, 10, 10), drive_colors[drive_name])
			draw_string(font, Vector2(legend_x + 13, legend_y),
				drive_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.5, 0.5, 0.5))
			legend_x += font.get_string_size(drive_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x + 25


	func _draw_score_curves(sz: Vector2) -> void:
		var font := ThemeDB.fallback_font
		var ml: float = 55.0
		var mt: float = 15.0
		var mb: float = 30.0
		var mr: float = 15.0
		var plot_w: float = sz.x - ml - mr
		var plot_h: float = sz.y - mt - mb

		# Use first timeline with snapshots
		var timeline: Variant = null
		for result: Variant in scenario_data.results:
			for tl: Variant in result.timelines:
				if tl.snapshots.size() > 2:
					timeline = tl
					break
			if timeline:
				break

		if timeline == null:
			draw_string(font, Vector2(sz.x * 0.3, sz.y * 0.5),
				"No snapshot data", HORIZONTAL_ALIGNMENT_LEFT, -1, 14,
				Color(0.3, 0.3, 0.3))
			return

		var snaps: Array = timeline.snapshots
		var last_snap: Variant = snaps[snaps.size() - 1]
		var max_t: float = last_snap.time
		if max_t <= 0.0:
			return

		# Collect drives and max score
		var drives: Dictionary = {}
		var max_score: float = 0.0
		for snap: Variant in snaps:
			for drive_name: String in snap.module_scores:
				drives[drive_name] = true
				max_score = maxf(max_score, snap.module_scores[drive_name])
		if max_score <= 0.0:
			max_score = 1.0

		# Grid
		for g: int in range(5):
			var y: float = mt + (plot_h / 4.0) * float(g)
			draw_line(Vector2(ml, y), Vector2(ml + plot_w, y), Color(0.12, 0.12, 0.12))
			draw_string(font, Vector2(5, y + 4),
				"%.2f" % (max_score * (1.0 - float(g) / 4.0)),
				HORIZONTAL_ALIGNMENT_LEFT, int(ml - 10), 10, Color(0.35, 0.35, 0.35))

		# Curves
		for drive_name: String in drives:
			var color: Color = _get_drive_color(drive_name)
			var points: PackedVector2Array = []
			for snap: Variant in snaps:
				var score: float = snap.module_scores.get(drive_name, 0.0)
				var x: float = ml + (snap.time / max_t) * plot_w
				var y: float = mt + plot_h - (score / max_score) * plot_h
				points.append(Vector2(x, y))
			if points.size() >= 2:
				draw_polyline(points, color, 1.5, true)

		# Time axis
		for tick: int in range(7):
			var t: float = max_t / 6.0 * float(tick)
			var x: float = ml + (t / max_t) * plot_w
			draw_string(font, Vector2(x - 12, sz.y - 5),
				"%.1fs" % t, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.4, 0.4, 0.4))


	func _draw_personality_scatter(sz: Vector2) -> void:
		var font := ThemeDB.fallback_font
		var ml: float = 60.0
		var mt: float = 20.0
		var mb: float = 35.0
		var mr: float = 20.0
		var plot_w: float = sz.x - ml - mr
		var plot_h: float = sz.y - mt - mb

		# Collect timelines
		var timelines: Array = []
		for result: Variant in scenario_data.results:
			for tl: Variant in result.timelines:
				timelines.append(tl)

		if timelines.size() < 3:
			draw_string(font, Vector2(sz.x * 0.2, sz.y * 0.5),
				"Need 3+ NPCs for scatter plot", HORIZONTAL_ALIGNMENT_LEFT, -1, 14,
				Color(0.3, 0.3, 0.3))
			return

		# Axes
		draw_line(Vector2(ml, mt), Vector2(ml, mt + plot_h), Color(0.2, 0.2, 0.2))
		draw_line(Vector2(ml, mt + plot_h), Vector2(ml + plot_w, mt + plot_h), Color(0.2, 0.2, 0.2))

		draw_string(font, Vector2(ml + plot_w * 0.35, sz.y - 3),
			"Aggression", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.4, 0.4, 0.4))
		draw_set_transform(Vector2(12, mt + plot_h * 0.65), -PI / 2.0)
		draw_string(font, Vector2.ZERO,
			"% Time in Threat/Flee", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.4, 0.4, 0.4))
		draw_set_transform(Vector2.ZERO, 0.0)

		# Axis ticks
		for i: int in range(5):
			var val: float = float(i) * 0.25
			var x: float = ml + val * plot_w
			draw_string(font, Vector2(x - 8, mt + plot_h + 15),
				"%.2f" % val, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.35, 0.35, 0.35))
			var pct: float = float(i) * 25.0
			var y: float = mt + plot_h - (pct / 100.0) * plot_h
			draw_string(font, Vector2(5, y + 4),
				"%d%%" % int(pct), HORIZONTAL_ALIGNMENT_LEFT, int(ml - 10), 10,
				Color(0.35, 0.35, 0.35))

		# Archetype colors
		var arch_colors := {
			"Civilian": Color(0.27, 0.87, 0.27),
			"Gang": Color(0.87, 0.27, 0.27),
			"Cop": Color(0.27, 0.27, 0.87),
			"Vendor": Color(0.87, 0.87, 0.27),
		}

		# Plot dots
		for tl: Variant in timelines:
			var agg: float = tl.personality.get("aggression", 0.0)
			var threat_pct: float = 0.0
			if tl.total_time > 0.0:
				var threat_t: float = tl.drive_time.get("threat", 0.0) + tl.drive_time.get("flee", 0.0)
				threat_pct = threat_t / tl.total_time
			var x: float = ml + agg * plot_w
			var y: float = mt + plot_h - threat_pct * plot_h
			var color: Color = arch_colors.get(tl.archetype, Color(0.4, 0.4, 0.4))
			color.a = 0.7
			draw_circle(Vector2(x, y), 4.0, color)

		# Legend
		var lx: float = ml
		for arch: String in arch_colors:
			draw_rect(Rect2(lx, 3, 10, 10), arch_colors[arch])
			draw_string(font, Vector2(lx + 13, 12),
				arch, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.5, 0.5, 0.5))
			lx += font.get_string_size(arch, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x + 25


	static func _get_drive_color(drive_name: String) -> Color:
		match drive_name:
			"idle": return Color(0.53, 0.53, 0.53)
			"patrol": return Color(0.8, 0.8, 0.0)
			"flee": return Color(0.87, 0.2, 0.2)
			"threat": return Color(1.0, 0.27, 0.27)
			"socialize": return Color(0.27, 0.87, 0.27)
			"work": return Color(0.27, 0.87, 0.87)
			"deal": return Color(0.87, 0.53, 0.0)
			"guard": return Color(0.67, 0.27, 0.87)
			_: return Color(0.4, 0.4, 0.4)
