## NPC Test Runner: Headless test runner for the RenegadeNPC plugin.
## Run with: godot --headless --script addons/renegade_npc/tests/run_tests.gd
##
## Tests pure data classes and module scoring logic without needing a scene tree.
## For scenario tests that need physics (navigation, movement), use the demo scene.
extends SceneTree

const _TestSocialMemory = preload("res://addons/renegade_npc/tests/test_social_memory.gd")
const _TestPersonality = preload("res://addons/renegade_npc/tests/test_personality.gd")
const _TestModuleScoring = preload("res://addons/renegade_npc/tests/test_module_scoring.gd")
const _TestFleeRecovery = preload("res://addons/renegade_npc/tests/test_flee_recovery.gd")
const _TestReputation = preload("res://addons/renegade_npc/tests/test_reputation.gd")
const _TestAbstractNPC = preload("res://addons/renegade_npc/tests/test_abstract_npc.gd")
const _TestActivityLifecycle = preload("res://addons/renegade_npc/tests/test_activity_lifecycle.gd")

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
var _skip_count: int = 0
var _current_suite: String = ""
var _errors: Array[String] = []
var _suite_pass: int = 0
var _suite_fail: int = 0
var _suite_start_ms: int = 0


func _init() -> void:
	print("\n%s%s======================================%s" % [_BOLD, _CYAN, _RESET])
	print("%s%s    RenegadeNPC Test Runner           %s" % [_BOLD, _CYAN, _RESET])
	print("%s%s======================================%s\n" % [_BOLD, _CYAN, _RESET])

	# Defer to first frame so SceneTree is fully initialized
	# (groups, _ready(), node tree all work after first process_frame)
	process_frame.connect(_run_and_report, CONNECT_ONE_SHOT)


func _run_and_report() -> void:
	_run_all_suites()

	# Summary
	print("\n%s======================================%s" % [_BOLD, _RESET])
	var total := _pass_count + _fail_count + _skip_count

	# Pass/fail bar
	var bar_width: int = 36
	var pass_width: int = int(float(_pass_count) / float(total) * bar_width) if total > 0 else 0
	var fail_width: int = int(float(_fail_count) / float(total) * bar_width) if total > 0 else 0
	var skip_width: int = bar_width - pass_width - fail_width
	var bar := "%s%s%s%s%s%s" % [
		_GREEN, "█".repeat(pass_width),
		_RED, "█".repeat(fail_width),
		_DIM, "░".repeat(skip_width),
	]
	print("  %s%s" % [bar, _RESET])

	if _fail_count == 0:
		print("  %s%s✓ %d passed%s / %d total" % [_BOLD, _GREEN, _pass_count, _RESET, total])
	else:
		print("  %s%s%d passed%s, %s%s%d failed%s, %d skipped / %d total" % [
			_BOLD, _GREEN, _pass_count, _RESET,
			_BOLD, _RED, _fail_count, _RESET,
			_skip_count, total,
		])
	if _errors.size() > 0:
		print("")
		print("  %s%sFAILURES:%s" % [_BOLD, _RED, _RESET])
		for err: String in _errors:
			print("    %s✗ %s%s" % [_RED, err, _RESET])
	print("%s======================================%s\n" % [_BOLD, _RESET])

	quit(1 if _fail_count > 0 else 0)


func _run_all_suites() -> void:
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

	_suite("ActivityLifecycle")
	_TestActivityLifecycle.run(self)
	_end_suite()


## --- Test assertion helpers (called by test suites) ---

func _suite(name: String) -> void:
	_current_suite = name
	_suite_pass = 0
	_suite_fail = 0
	_suite_start_ms = Time.get_ticks_msec()
	print("\n%s%s── %s ──%s" % [_BOLD, _CYAN, name, _RESET])


func _end_suite() -> void:
	var elapsed_ms: int = Time.get_ticks_msec() - _suite_start_ms
	var count := _suite_pass + _suite_fail
	var color := _GREEN if _suite_fail == 0 else _RED
	print("  %s%s%d/%d passed%s %s(%dms)%s" % [
		_DIM, color, _suite_pass, count, _RESET, _DIM, elapsed_ms, _RESET,
	])


func assert_true(condition: bool, description: String) -> void:
	if condition:
		_pass_count += 1
		_suite_pass += 1
		print("  %s✓%s %s" % [_GREEN, _RESET, description])
	else:
		_fail_count += 1
		_suite_fail += 1
		var msg := "%s::%s" % [_current_suite, description]
		_errors.append(msg)
		print("  %s✗ %s%s" % [_RED, description, _RESET])


func assert_false(condition: bool, description: String) -> void:
	assert_true(not condition, description)


func assert_eq(actual: Variant, expected: Variant, description: String) -> void:
	if actual == expected:
		_pass_count += 1
		_suite_pass += 1
		print("  %s✓%s %s" % [_GREEN, _RESET, description])
	else:
		_fail_count += 1
		_suite_fail += 1
		var msg := "%s::%s (got %s, expected %s)" % [_current_suite, description, str(actual), str(expected)]
		_errors.append(msg)
		print("  %s✗ %s (got %s, expected %s)%s" % [_RED, description, str(actual), str(expected), _RESET])


func assert_approx(actual: float, expected: float, tolerance: float, description: String) -> void:
	if absf(actual - expected) <= tolerance:
		_pass_count += 1
		_suite_pass += 1
		print("  %s✓%s %s" % [_GREEN, _RESET, description])
	else:
		_fail_count += 1
		_suite_fail += 1
		var msg := "%s::%s (got %.4f, expected %.4f ± %.4f)" % [_current_suite, description, actual, expected, tolerance]
		_errors.append(msg)
		print("  %s✗ %s (got %.4f, expected %.4f ± %.4f)%s" % [_RED, description, actual, expected, tolerance, _RESET])


func assert_in_range(value: float, low: float, high: float, description: String) -> void:
	if value >= low and value <= high:
		_pass_count += 1
		_suite_pass += 1
		print("  %s✓%s %s" % [_GREEN, _RESET, description])
	else:
		_fail_count += 1
		_suite_fail += 1
		var msg := "%s::%s (%.4f not in [%.4f, %.4f])" % [_current_suite, description, value, low, high]
		_errors.append(msg)
		print("  %s✗ %s (%.4f not in [%.4f, %.4f])%s" % [_RED, description, value, low, high, _RESET])


func assert_gt(actual: float, threshold: float, description: String) -> void:
	assert_true(actual > threshold, "%s (%.4f > %.4f)" % [description, actual, threshold])


func assert_lt(actual: float, threshold: float, description: String) -> void:
	assert_true(actual < threshold, "%s (%.4f < %.4f)" % [description, actual, threshold])
