## Draws a wide ribbon with arrowheads showing this NPC's navigation path,
## snapped to the floor surface via raycasts.
## Added as a child of RealizedNPC via the realized_npc.tscn scene.
## @tool enables editor preview so you can tweak properties visually.
@tool
extends MeshInstance3D

@export_group("Ribbon")
@export var ribbon_half_width: float = 0.12
@export_group("Arrowheads")
@export var arrow_half_width: float = 0.3
@export var arrow_length: float = 0.45
@export var arrow_spacing: float = 2.5
@export_group("Rendering")
@export var floor_offset: float = 0.05
@export var update_interval: float = 0.1
@export_group("Drive Colors")
@export var color_idle: Color = Color(0.5, 0.5, 0.5, 0.6)
@export var color_patrol: Color = Color(1.0, 1.0, 0.0, 0.6)
@export var color_flee: Color = Color(1.0, 0.0, 0.0, 0.6)
@export var color_threat: Color = Color(1.0, 0.0, 0.0, 0.6)
@export var color_socialize: Color = Color(0.0, 1.0, 0.0, 0.6)
@export var color_work: Color = Color(0.0, 0.8, 1.0, 0.6)
@export var color_deal: Color = Color(1.0, 0.5, 0.0, 0.6)
@export var color_guard: Color = Color(0.5, 0.0, 1.0, 0.6)
@export_group("Editor Preview")
@export var preview_length: float = 5.0
@export var preview_color: Color = Color(1.0, 1.0, 0.0, 0.6)

var _npc: RealizedNPC
var _imm: ImmediateMesh
var _mat: StandardMaterial3D
var _update_timer: float = 0.0


func _ready() -> void:
	_imm = ImmediateMesh.new()
	mesh = _imm
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.albedo_color = Color(1.0, 1.0, 0.0, 0.6)
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.no_depth_test = true
	_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	material_override = _mat

	if Engine.is_editor_hint():
		_build_preview()
		return

	_npc = get_parent() as RealizedNPC
	top_level = true
	add_to_group("trajectory_lines")


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		# Rebuild preview periodically to reflect property changes
		_update_timer -= delta
		if _update_timer > 0.0:
			return
		_update_timer = 0.25
		_build_preview()
		return

	_update_timer -= delta
	if _update_timer > 0.0:
		return
	_update_timer = update_interval

	_imm.clear_surfaces()
	if not visible:
		return
	if not _npc or not is_instance_valid(_npc):
		return
	if not _npc._is_moving or not _npc.nav_agent:
		return

	var raw_path: PackedVector3Array = _npc.nav_agent.get_current_navigation_path()
	if raw_path.size() < 2:
		return

	var path: Array[Vector3] = _snap_path_to_floor(raw_path)
	if path.size() < 2:
		return

	var color: Color = _get_drive_color(_npc._active_drive)
	_mat.albedo_color = color

	_build_ribbon(path)
	_build_arrowheads(path)


## --- EDITOR PREVIEW ---

func _build_preview() -> void:
	_imm.clear_surfaces()
	_mat.albedo_color = preview_color

	# Straight line in local space along -Z (forward)
	var step_count: int = maxi(int(preview_length / 0.5), 2)
	var path: Array[Vector3] = []
	for i: int in range(step_count + 1):
		var t: float = float(i) / float(step_count)
		path.append(Vector3(0.0, floor_offset, -t * preview_length))

	_build_ribbon(path)
	_build_arrowheads(path)


## --- RUNTIME PATH ---

func _snap_path_to_floor(raw_path: PackedVector3Array) -> Array[Vector3]:
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var snapped: Array[Vector3] = []
	for point: Vector3 in raw_path:
		var query := PhysicsRayQueryParameters3D.create(
			point + Vector3.UP * 2.0,
			point + Vector3.DOWN * 5.0
		)
		var hit: Dictionary = space.intersect_ray(query)
		if hit:
			snapped.append(hit.position + Vector3.UP * floor_offset)
		else:
			snapped.append(point + Vector3.UP * floor_offset)
	return snapped


## --- MESH BUILDERS ---

func _build_ribbon(path: Array[Vector3]) -> void:
	_imm.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i: int in range(path.size()):
		var fwd: Vector3
		if i < path.size() - 1:
			fwd = (path[i + 1] - path[i]).normalized()
		else:
			fwd = (path[i] - path[i - 1]).normalized()
		var right: Vector3 = fwd.cross(Vector3.UP).normalized() * ribbon_half_width
		_imm.surface_add_vertex(path[i] - right)
		_imm.surface_add_vertex(path[i] + right)
	_imm.surface_end()


func _build_arrowheads(path: Array[Vector3]) -> void:
	# Cumulative distance along the path
	var cum_dist: Array[float] = [0.0]
	for i: int in range(1, path.size()):
		cum_dist.append(cum_dist[i - 1] + path[i - 1].distance_to(path[i]))
	var total: float = cum_dist.back()
	if total < arrow_spacing * 0.5:
		return

	var next_arrow: float = arrow_spacing
	var added_verts: bool = false
	for i: int in range(1, path.size()):
		while next_arrow <= cum_dist[i] and next_arrow < total - 0.3:
			if not added_verts:
				_imm.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
				added_verts = true
			var t: float = (next_arrow - cum_dist[i - 1]) / (cum_dist[i] - cum_dist[i - 1])
			var pos: Vector3 = path[i - 1].lerp(path[i], t)
			var fwd: Vector3 = (path[i] - path[i - 1]).normalized()
			var right: Vector3 = fwd.cross(Vector3.UP).normalized()

			var base_l: Vector3 = pos - right * arrow_half_width - fwd * arrow_length * 0.5
			var base_r: Vector3 = pos + right * arrow_half_width - fwd * arrow_length * 0.5
			var tip: Vector3 = pos + fwd * arrow_length * 0.5

			_imm.surface_add_vertex(base_l)
			_imm.surface_add_vertex(base_r)
			_imm.surface_add_vertex(tip)

			next_arrow += arrow_spacing
	if added_verts:
		_imm.surface_end()


func _get_drive_color(drive: String) -> Color:
	match drive:
		"idle": return color_idle
		"patrol": return color_patrol
		"flee": return color_flee
		"threat": return color_threat
		"socialize": return color_socialize
		"work": return color_work
		"deal": return color_deal
		"guard": return color_guard
		_: return Color(1.0, 1.0, 1.0, 0.6)
