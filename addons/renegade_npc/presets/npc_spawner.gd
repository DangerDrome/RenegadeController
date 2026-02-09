## NPCSpawner: Drag-and-drop NPC spawn point for editor-based level building.
## Place in your scene, configure archetype/count in inspector, NPCs auto-register on _ready().
## Works with NPCManager autoload — no code wiring required.
@tool
class_name NPCSpawner
extends Marker3D

## --- Configuration ---
@export_enum("Civilian", "Gang", "Cop", "Vendor", "Story") var archetype: String = "Civilian"
@export_range(1, 20) var spawn_count: int = 1
@export var spawn_radius: float = 5.0  ## Random offset from this position
@export var block_id: String = "downtown_east"  ## City block for abstract simulation

@export_group("Cop Settings")
@export_range(0.0, 1.0) var partner_chance: float = 0.8  ## Chance cops spawn with partner

@export_group("Custom Data")
@export var custom_npc_data: NPCData = null  ## Override archetype with specific NPCData

@export_group("Debug")
@export var preview_color: Color = Color.WHITE
@export var show_spawn_radius: bool = true

var _spawned_npcs: Array[AbstractNPC] = []


func _ready() -> void:
	if Engine.is_editor_hint():
		return

	# Wait for navmesh to be baked (LevelSetup bakes it)
	# Give it several frames for the navigation system to initialize
	for i in 5:
		await get_tree().process_frame

	# Additional wait for navmesh - check if navigation map has regions
	var attempts := 0
	while attempts < 30:  # Max ~0.5 seconds wait
		var map := get_world_3d().navigation_map
		if NavigationServer3D.map_get_iteration_id(map) > 0:
			break  # Navmesh is ready
		await get_tree().create_timer(0.016).timeout
		attempts += 1

	_spawn_npcs()


func _spawn_npcs() -> void:
	if not NPCManager:
		push_error("[NPCSpawner] NPCManager autoload not found!")
		return

	for i in spawn_count:
		var pos := _get_spawn_position()
		var abstract: AbstractNPC

		if custom_npc_data:
			# Use custom data directly
			abstract = NPCManager.register_npc(custom_npc_data.duplicate(), block_id, pos)
		elif archetype == "Cop" and partner_chance > 0.0:
			# Cops use partner system
			var data := _make_archetype_data()
			var cops := NPCManager.register_cop_pair_same_data(data, block_id, pos, partner_chance)
			_spawned_npcs.append_array(cops)
			continue  # Skip normal append, pair already added
		else:
			# Normal archetype spawn
			var data := _make_archetype_data()
			abstract = NPCManager.register_npc(data, block_id, pos)

		if abstract:
			_spawned_npcs.append(abstract)


func _make_archetype_data() -> NPCData:
	var data := NPCData.new()
	var preset: Dictionary = NPCConfig.Archetypes.PRESETS.get(archetype, {})

	data.archetype = archetype
	data.npc_name = preset.get("display_name", archetype)
	data.faction = preset.get("faction", NPCConfig.Factions.NONE)
	data.is_combatant = preset.get("is_combatant", false)
	data.aggression_bias = preset.get("aggression_bias", 0.5)
	data.activity_preferences = preset.get("activity_preferences", {"idle": 1.0})
	data.generate_id()

	return data


func _get_spawn_position() -> Vector3:
	if spawn_radius <= 0.0:
		return global_position

	var angle := randf() * TAU
	var dist := randf() * spawn_radius
	var offset := Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)
	return global_position + offset


## --- Editor Preview ---

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if spawn_count < 1:
		warnings.append("Spawn count must be at least 1")
	return warnings
