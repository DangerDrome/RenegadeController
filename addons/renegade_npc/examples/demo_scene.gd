## DemoScene: Test scene for the RenegadeNPC plugin.
## Environment, navigation, lighting, activity nodes, and player are all
## editor nodes in demo_scene.tscn — edit them directly in the editor.
##
## This script only handles runtime setup:
##   - Baking the navigation mesh
##   - Configuring factions and city blocks
##   - Spawning NPCs via NPCManager
##
## HOW TO USE:
##   1. Open demo_scene.tscn in the editor
##   2. Edit buildings, lights, activity nodes visually
##   3. Run the scene (F6)
##   4. WASD to move, mouse to look, Esc to free cursor
##   5. F1=detail F2=gunshot F3=rep F4=damage
extends Node3D

## --- NPC Population ---
@export var gang_count: int = 6
@export var cop_count: int = 3
@export var civilian_count: int = 8
@export var vendor_count: int = 2

## --- Focus Mode ---
## Set to an archetype name ("Gang", "Cop", "Civilian", "Vendor") to isolate
## that NPC type. Empty string = all archetypes (default behavior).
@export var focus_archetype: String = ""

## --- Debug ---
## When >= 0, spawn positions and NPC IDs are deterministic for reproducible runs.
@export var spawn_seed: int = -1

var _player: CharacterBody3D
var _rng: RandomNumberGenerator = null
var _next_badge: int = 0


func _ready() -> void:
	print("\n[RenegadeNPC Demo] Initializing...")

	_player = $Player

	# Bake navmesh (CSG collision shapes need a frame to register)
	await get_tree().process_frame
	$NavigationRegion3D.bake_navigation_mesh()
	await $NavigationRegion3D.bake_finished
	print("[Demo] Navigation mesh baked")

	# Seeded RNG for reproducible spawns
	if spawn_seed >= 0:
		_rng = RandomNumberGenerator.new()
		_rng.seed = spawn_seed

	_setup_factions()
	_setup_blocks()
	if focus_archetype != "":
		_filter_activity_nodes()
	_ensure_activity_markers()
	_spawn_npcs()

	print("[RenegadeNPC Demo] Ready! Stats: ", NPCManager.get_stats())
	print("[RenegadeNPC Demo] Controls: WASD=move, Mouse=look, Esc=cursor, F1=detail, F2=gunshot, F3=rep, F4=damage")


## --- FACTIONS ---

func _setup_factions() -> void:
	for entry: Array in NPCConfig.Factions.DEFAULT_DISPOSITIONS:
		ReputationManager.set_faction_disposition(entry[0], entry[1], entry[2])
	print("[Demo] Factions configured")


## --- BLOCKS ---

func _setup_blocks() -> void:
	for block_id: String in NPCConfig.Blocks.ALL:
		NPCManager.register_block(block_id, NPCConfig.Blocks.ALL[block_id])
	print("[Demo] City blocks registered")


## --- ACTIVITY NODE FILTERING ---

## Hide activity nodes whose type isn't in the focused archetype's preferences.
func _filter_activity_nodes() -> void:
	var preset: Dictionary = NPCConfig.Archetypes.PRESETS.get(focus_archetype, {})
	var prefs: Dictionary = preset.get("activity_preferences", {})
	for node: Node in get_tree().get_nodes_in_group("activity_nodes"):
		var act_node := node as ActivityNode
		if not act_node:
			continue
		if act_node.activity_type not in prefs:
			act_node.remove_from_group("activity_nodes")
			act_node.hide()
	print("[Demo] Filtered activity nodes for archetype: %s" % focus_archetype)


## Add MarkerMesh + ActivityLabel to any activity node that lacks them
## (e.g. nodes added in inherited scenes).
func _ensure_activity_markers() -> void:
	var _color_map: Dictionary = {
		"patrol": Color(1.0, 1.0, 0.0, 0.4),
		"socialize": Color(0.0, 1.0, 0.0, 0.4),
		"guard": Color(0.5, 0.0, 1.0, 0.4),
		"work": Color(0.0, 0.8, 1.0, 0.4),
		"deal": Color(1.0, 0.5, 0.0, 0.4),
		"idle": Color(0.5, 0.5, 0.5, 0.4),
	}
	for node: Node in get_tree().get_nodes_in_group("activity_nodes"):
		var act_node := node as ActivityNode
		if not act_node or act_node.get_node_or_null("MarkerMesh"):
			continue
		var color: Color = _color_map.get(act_node.activity_type, Color(0.5, 0.5, 0.5, 0.4))
		# Sphere marker
		var mesh_inst := MeshInstance3D.new()
		mesh_inst.name = "MarkerMesh"
		var sphere := SphereMesh.new()
		sphere.radius = 0.5
		sphere.height = 1.0
		mesh_inst.mesh = sphere
		mesh_inst.position.y = 0.5
		var mat := StandardMaterial3D.new()
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = color
		mesh_inst.material_override = mat
		act_node.add_child(mesh_inst)
		# Floating label
		var label := Label3D.new()
		label.name = "ActivityLabel"
		label.text = act_node.activity_type
		label.position.y = 1.5
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		label.modulate = Color(color.r, color.g, color.b, 1.0)
		act_node.add_child(label)


## --- NPC SPAWNING ---

const ARCHETYPE_COLORS: Dictionary = {
	"Gang": Color(1.0, 0.2, 0.2),
	"Cop": Color(0.2, 0.4, 1.0),
	"Civilian": Color(0.6, 0.6, 0.6),
	"Vendor": Color(0.0, 0.9, 0.7),
}


func _spawn_npcs() -> void:
	var base_pos := _player.global_position if _player else Vector3.ZERO

	# Use local counts so exports stay unchanged in the inspector
	var g_count := gang_count if (focus_archetype == "" or focus_archetype == "Gang") else 0
	var c_count := cop_count if (focus_archetype == "" or focus_archetype == "Cop") else 0
	var ci_count := civilian_count if (focus_archetype == "" or focus_archetype == "Civilian") else 0
	var v_count := vendor_count if (focus_archetype == "" or focus_archetype == "Vendor") else 0

	# --- NPC Data templates ---
	var gang_data := _make_data_from_archetype("Gang")
	var cop_data := _make_data_from_archetype("Cop")
	var civ_data := _make_data_from_archetype("Civilian")
	var vendor_data := _make_data_from_archetype("Vendor")

	# Single callback for all archetypes — color derived from archetype
	NPCManager.npc_realized.connect(_on_npc_realized)

	# --- Spawn ---
	_spawn_group(gang_data, g_count, base_pos, 25.0, "downtown_east")
	_spawn_group(cop_data, c_count, base_pos, 30.0, "downtown_east")
	_spawn_group(civ_data, ci_count, base_pos, 20.0, "downtown_east")
	_spawn_group(vendor_data, v_count, base_pos, 15.0, "market_district")

	print("[Demo] Spawned NPCs: %d gang, %d cops, %d civilians, %d vendors" % [
		g_count, c_count, ci_count, v_count
	])


func _make_data_from_archetype(archetype: String) -> NPCData:
	var preset: Dictionary = NPCConfig.Archetypes.PRESETS.get(archetype, {})
	var data := NPCData.new()
	data.npc_name = preset.get("display_name", archetype)
	data.archetype = archetype
	data.faction = preset.get("faction", NPCConfig.Factions.CIVILIAN)
	data.is_combatant = preset.get("is_combatant", false)
	data.aggression_bias = preset.get("aggression_bias", 0.3)
	data.activity_preferences = preset.get("activity_preferences", {"idle": 1.0})
	return data


func _spawn_group(data: NPCData, count: int, center: Vector3, radius: float,
		block: String) -> void:
	for i: int in range(count):
		# Each NPC needs its own NPCData so generate_id() produces unique IDs
		var npc_data := data.duplicate() as NPCData
		if _rng:
			npc_data.npc_id = "%s_%s_%d" % [npc_data.faction, npc_data.archetype, i]
		else:
			npc_data.npc_id = ""  # Force new unique ID generation
		# Assign unique badge numbers to LAPD officers
		if npc_data.archetype == "Cop":
			var badge: int = _generate_badge_number()
			npc_data.npc_name = "Officer #%03d" % badge
		var offset := Vector3(
			_rng.randf_range(-radius, radius) if _rng else randf_range(-radius, radius),
			0.0,
			_rng.randf_range(-radius, radius) if _rng else randf_range(-radius, radius)
		)
		var pos := center + offset
		var abstract := NPCManager.register_npc(npc_data, block, pos)


func _generate_badge_number() -> int:
	_next_badge += 1
	if _rng:
		return 100 + _next_badge
	return 100 + randi_range(0, 899) + _next_badge


func _on_npc_realized(abstract: AbstractNPC, realized: RealizedNPC) -> void:
	var debug_color: Color = ARCHETYPE_COLORS.get(abstract.data.archetype, Color(0.7, 0.7, 0.7))

	# Configure debug mesh color (node exists in the scene)
	var mesh_inst: MeshInstance3D = realized.get_node_or_null("DebugMesh")
	if mesh_inst and mesh_inst.material_override:
		# Duplicate so each NPC gets its own color
		var mat: StandardMaterial3D = mesh_inst.material_override.duplicate()
		mat.albedo_color = debug_color
		mesh_inst.material_override = mat

	# Configure name label
	var label: Label3D = realized.get_node_or_null("NameLabel")
	if label:
		label.text = "%s\n[%s]" % [abstract.data.npc_name, abstract.data.faction]
		label.modulate = debug_color

	# Configure drive label + connect update signal
	var drive_label: Label3D = realized.get_node_or_null("DriveLabel")
	if drive_label:
		realized.drive_changed.connect(func(drive: String) -> void:
			if is_instance_valid(drive_label):
				drive_label.text = "► %s" % drive
				match drive:
					"idle": drive_label.modulate = Color(0.5, 0.5, 0.5)
					"patrol": drive_label.modulate = Color(1.0, 1.0, 0.0)
					"flee", "threat": drive_label.modulate = Color(1.0, 0.0, 0.0)
					"socialize": drive_label.modulate = Color(0.0, 1.0, 0.0)
					"work": drive_label.modulate = Color(0.0, 0.8, 1.0)
					"deal": drive_label.modulate = Color(1.0, 0.5, 0.0)
					"guard": drive_label.modulate = Color(0.5, 0.0, 1.0)
					_: drive_label.modulate = Color.WHITE
		)
		drive_label.text = "► %s" % realized.get_active_drive()
