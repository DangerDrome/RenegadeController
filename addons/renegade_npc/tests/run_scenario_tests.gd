## NPC Scenario Test Runner: Simulates the full utility AI system over
## accelerated time with scripted events, tracks metrics, and validates invariants.
##
## Run with: godot --headless --script addons/renegade_npc/tests/run_scenario_tests.gd
##
## This is how NPC AI systems are typically stress-tested:
##   1. Soak tests — run hundreds of NPCs for simulated hours, check invariants
##   2. Scenario tests — script specific event sequences, verify expected outcomes
##   3. Statistical tests — verify drive distributions match design intent
##   4. Edge case tests — simultaneous events, boundary conditions, rapid state changes
extends SceneTree

const _Scenarios = preload("res://addons/renegade_npc/tests/test_scenarios.gd")
const _ScenarioData = preload("res://addons/renegade_npc/tests/scenario_data.gd")

# ANSI color codes
const _GREEN := "\u001b[32m"
const _RED := "\u001b[31m"
const _CYAN := "\u001b[36m"
const _YELLOW := "\u001b[33m"
const _DIM := "\u001b[2m"
const _BOLD := "\u001b[1m"
const _RESET := "\u001b[0m"

var _pass_count: int = 0
var _fail_count: int = 0
var _current_suite: String = ""
var _errors: Array[String] = []
var _report_lines: Array[String] = []
var _suite_start_ms: int = 0
var _suite_pass: int = 0
var _suite_fail: int = 0
var _scenario_data: RefCounted = _ScenarioData.new()


func _init() -> void:
	_log("==============================================", true)
	_log("  RenegadeNPC Scenario Test Report", true)
	_log("  %s" % Time.get_datetime_string_from_system(), true)
	_log("==============================================\n", true)

	_Scenarios.run_all(self, _scenario_data)

	# End the last suite
	if _current_suite != "":
		_end_suite()

	# Final summary
	_log("\n==============================================", true)
	var total := _pass_count + _fail_count

	# Pass/fail bar
	var bar_width: int = 42
	var pass_width: int = int(float(_pass_count) / float(total) * bar_width) if total > 0 else 0
	var fail_width: int = bar_width - pass_width
	var bar := "%s%s%s%s" % [
		_GREEN, "█".repeat(pass_width),
		_RED if _fail_count > 0 else _DIM, ("█".repeat(fail_width) if _fail_count > 0 else "░".repeat(fail_width)),
	]
	print("  %s%s" % [bar, _RESET])

	if _fail_count == 0:
		_log("  %s%s✓ FINAL: %d passed%s / %d total" % [_BOLD, _GREEN, _pass_count, _RESET, total], true)
	else:
		_log("  %sFINAL: %s%d passed%s, %s%d failed%s / %d total" % [
			_BOLD, _GREEN, _pass_count, _RESET, _RED, _fail_count, _RESET, total,
		], true)
	if _errors.size() > 0:
		_log("", false)
		_log("  %s%sFAILURES:%s" % [_BOLD, _RED, _RESET], true)
		for err: String in _errors:
			_log("    %s✗ %s%s" % [_RED, err, _RESET], true)
	_log("==============================================\n", true)

	# Write plain report to file (strip ANSI codes)
	var report_path := "res://addons/renegade_npc/tests/scenario_report.txt"
	var file := FileAccess.open(report_path, FileAccess.WRITE)
	if file:
		for line: String in _report_lines:
			file.store_line(_strip_ansi(line))
		file.close()
		print("%s[Report saved to %s]%s" % [_DIM, report_path, _RESET])

	# Export scenario data to JSON
	var json_path := "res://addons/renegade_npc/tests/scenario_data.json"
	var json_file := FileAccess.open(json_path, FileAccess.WRITE)
	if json_file:
		json_file.store_string(_scenario_data.to_json())
		json_file.close()
		print("%s[Scenario data exported to %s]%s" % [_DIM, json_path, _RESET])

	quit(1 if _fail_count > 0 else 0)


## --- Logging ---

func _log(text: String, to_report: bool = true) -> void:
	print(text)
	if to_report:
		_report_lines.append(text)


static func _strip_ansi(text: String) -> String:
	var result := text
	for code: String in ["\u001b[32m", "\u001b[31m", "\u001b[36m", "\u001b[33m",
			"\u001b[2m", "\u001b[1m", "\u001b[0m"]:
		result = result.replace(code, "")
	return result


## --- ASCII bar chart helper ---

func _print_drive_bar(drive: String, pct: float, width: int = 30) -> void:
	var bar_len: int = int(pct / 100.0 * float(width))
	var color := _drive_ansi_color(drive)
	var bar := "%s%s%s%s" % [color, "█".repeat(bar_len), _DIM, "░".repeat(width - bar_len)]
	_log("    %-10s %s%s %s%.1f%%%s" % [drive, bar, _RESET, _DIM, pct, _RESET], false)


static func _drive_ansi_color(drive: String) -> String:
	match drive:
		"idle": return "\u001b[37m"       # white/gray
		"patrol": return "\u001b[33m"     # yellow
		"flee", "threat": return "\u001b[31m"  # red
		"socialize": return "\u001b[32m"  # green
		"work": return "\u001b[36m"       # cyan
		"deal": return "\u001b[33m"       # orange → yellow
		_: return "\u001b[37m"


## --- Assertions ---

func suite(name: String) -> void:
	# End previous suite if any
	if _current_suite != "":
		_end_suite()
	_current_suite = name
	_suite_pass = 0
	_suite_fail = 0
	_suite_start_ms = Time.get_ticks_msec()
	_log("\n%s%s── %s ──%s" % [_BOLD, _CYAN, name, _RESET])


func _end_suite() -> void:
	var elapsed_ms: int = Time.get_ticks_msec() - _suite_start_ms
	var count := _suite_pass + _suite_fail
	var color := _GREEN if _suite_fail == 0 else _RED
	_log("  %s%s%d/%d passed%s %s(%dms)%s" % [
		_DIM, color, _suite_pass, count, _RESET, _DIM, elapsed_ms, _RESET,
	])


func check(condition: bool, description: String) -> void:
	if condition:
		_pass_count += 1
		_suite_pass += 1
		_log("  %s[PASS]%s %s" % [_GREEN, _RESET, description])
	else:
		_fail_count += 1
		_suite_fail += 1
		_errors.append("%s :: %s" % [_current_suite, description])
		_log("  %s[FAIL] %s%s" % [_RED, description, _RESET])


func check_gt(actual: float, threshold: float, desc: String) -> void:
	check(actual > threshold, "%s (%.3f > %.3f)" % [desc, actual, threshold])


func check_lt(actual: float, threshold: float, desc: String) -> void:
	check(actual < threshold, "%s (%.3f < %.3f)" % [desc, actual, threshold])


func check_range(value: float, lo: float, hi: float, desc: String) -> void:
	check(value >= lo and value <= hi, "%s (%.3f in [%.3f, %.3f])" % [desc, value, lo, hi])


func check_eq(actual: Variant, expected: Variant, desc: String) -> void:
	check(actual == expected, "%s (got %s, expected %s)" % [desc, str(actual), str(expected)])


func report(text: String) -> void:
	_log("  %s%s%s" % [_DIM, text, _RESET])
