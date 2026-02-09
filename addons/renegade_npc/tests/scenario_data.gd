## ScenarioData: Collects per-tick snapshots during scenario runs for visualization.
## Used by both the headless runner (JSON export) and in-editor visualizer (live graphs).
extends RefCounted


class Snapshot extends RefCounted:
	var time: float
	var active_drive: String
	var module_scores: Dictionary  # drive_name -> float
	var health_pct: float

	func to_dict() -> Dictionary:
		return {
			"t": time,
			"drive": active_drive,
			"scores": module_scores.duplicate(),
			"health": health_pct,
		}

	static func from_dict(d: Dictionary) -> Snapshot:
		var s := Snapshot.new()
		s.time = d.get("t", 0.0)
		s.active_drive = d.get("drive", "idle")
		s.module_scores = d.get("scores", {})
		s.health_pct = d.get("health", 1.0)
		return s


class NPCTimeline extends RefCounted:
	var npc_name: String
	var archetype: String
	var personality: Dictionary  # trait_name -> float
	var snapshots: Array = []  # Array of Snapshot
	var drive_time: Dictionary  # drive_name -> float seconds
	var total_time: float

	func to_dict() -> Dictionary:
		var snap_dicts: Array = []
		for s: Snapshot in snapshots:
			snap_dicts.append(s.to_dict())
		return {
			"npc_name": npc_name,
			"archetype": archetype,
			"personality": personality.duplicate(),
			"snapshots": snap_dicts,
			"drive_time": drive_time.duplicate(),
			"total_time": total_time,
		}

	static func from_dict(d: Dictionary) -> NPCTimeline:
		var tl := NPCTimeline.new()
		tl.npc_name = d.get("npc_name", "")
		tl.archetype = d.get("archetype", "")
		tl.personality = d.get("personality", {})
		tl.drive_time = d.get("drive_time", {})
		tl.total_time = d.get("total_time", 0.0)
		for sd: Dictionary in d.get("snapshots", []):
			tl.snapshots.append(Snapshot.from_dict(sd))
		return tl


class ScenarioResult extends RefCounted:
	var scenario_name: String
	var timelines: Array = []  # Array of NPCTimeline
	var assertions: Array = []  # Array of {passed: bool, description: String}

	func to_dict() -> Dictionary:
		var tl_dicts: Array = []
		for tl: NPCTimeline in timelines:
			tl_dicts.append(tl.to_dict())
		return {
			"scenario_name": scenario_name,
			"timelines": tl_dicts,
			"assertions": assertions.duplicate(true),
		}

	static func from_dict(d: Dictionary) -> ScenarioResult:
		var sr := ScenarioResult.new()
		sr.scenario_name = d.get("scenario_name", "")
		sr.assertions = d.get("assertions", [])
		for td: Dictionary in d.get("timelines", []):
			sr.timelines.append(NPCTimeline.from_dict(td))
		return sr


var results: Array = []  # Array of ScenarioResult


func add_result(result: ScenarioResult) -> void:
	results.append(result)


func to_json() -> String:
	var data: Array = []
	for r: ScenarioResult in results:
		data.append(r.to_dict())
	return JSON.stringify(data, "\t")


static func from_json(json_string: String) -> RefCounted:
	var ScenarioDataScript: GDScript = load("res://addons/renegade_npc/tests/scenario_data.gd")
	var sd: RefCounted = ScenarioDataScript.new()
	var parsed: Variant = JSON.parse_string(json_string)
	if parsed is Array:
		for rd: Dictionary in parsed:
			sd.results.append(ScenarioResult.from_dict(rd))
	return sd
