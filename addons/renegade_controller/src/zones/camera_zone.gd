## Level volume that triggers a camera preset change when the player enters.
## Place these in your level as Area3D nodes with collision shapes.
## Add to the "camera_zones" group for auto-detection by CameraZoneManager.
@tool
class_name CameraZone extends Area3D

## The camera preset to transition to when a player enters this zone.
@export var camera_preset: CameraPreset:
	set(value):
		camera_preset = value
		_update_debug_label()

## Priority for overlapping zones. Higher priority wins.
@export var zone_priority: int = 0

## When true, leaving this zone reverts to the previous preset or default.
@export var revert_on_exit: bool = true

@export_group("Zone Size")
## Size of the zone collision box. Edit this to change zone bounds.
@export var zone_size: Vector3 = Vector3(10, 5, 10):
	set(value):
		zone_size = value
		_update_collision_shape()

@export_group("Camera Marker")
## Optional marker to define fixed camera position. If set, overrides preset offset.
## If not assigned, will auto-discover child node named "CameraMarker".
@export var camera_marker: Marker3D:
	set(value):
		camera_marker = value
		_update_camera_preview()

## Custom look-at target (any Node3D). If set, camera will look at this instead of the default marker.
## Use this to make the camera look at a specific object in the scene.
@export var look_at_target: Node3D:
	set(value):
		look_at_target = value
		_update_camera_preview()

## Default look-at marker (auto-discovered as child of CameraMarker).
## Only used if look_at_target is not set.
var look_at_marker: Marker3D:
	set(value):
		look_at_marker = value
		_update_camera_preview()

## Emitted when a player enters this zone. CameraZoneManager listens for this.
signal zone_entered(zone: CameraZone)
## Emitted when a player exits this zone.
signal zone_exited(zone: CameraZone)

var _debug_label: Label3D


var _frustum_mesh: MeshInstance3D  # Lines only.
var _body_mesh: MeshInstance3D  # Camera body and lens (layer 2, hidden from preview).
var _target_mesh: MeshInstance3D  # Target crosshair (layer 1, visible in preview).
var _collision_shape: CollisionShape3D
var _is_editor_selected: bool = false


## Returns the effective look-at node: look_at_target if set, otherwise look_at_marker.
func get_look_at_node() -> Node3D:
	if look_at_target and is_instance_valid(look_at_target):
		return look_at_target
	if look_at_marker and is_instance_valid(look_at_marker):
		return look_at_marker
	return null


## Called by the editor plugin when selection changes.
func set_editor_selected(selected: bool) -> void:
	if _is_editor_selected != selected:
		_is_editor_selected = selected
		_update_camera_preview()


func _ready() -> void:
	# Auto-add to group for discovery.
	if not is_in_group("camera_zones"):
		add_to_group("camera_zones")

	# Zone doesn't block anything physically.
	collision_layer = 0

	# Auto-discover markers if not set.
	_auto_discover_markers()

	# Find or create collision shape.
	_setup_collision_shape()

	# Connect signals.
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	# Debug visualization in editor.
	if Engine.is_editor_hint():
		_create_debug_label()
		_create_camera_preview()


func _auto_discover_markers() -> void:
	# Auto-discover camera marker if not assigned.
	if not camera_marker:
		var cam_node := get_node_or_null("CameraMarker")
		if cam_node is Marker3D:
			camera_marker = cam_node

	# Auto-discover look-at marker if not assigned.
	# First check as sibling, then as child of camera_marker.
	if not look_at_marker:
		var look_node := get_node_or_null("LookAtMarker")
		if look_node is Marker3D:
			look_at_marker = look_node
		elif camera_marker:
			var child_look := camera_marker.get_node_or_null("LookAtMarker")
			if child_look is Marker3D:
				look_at_marker = child_look


func _setup_collision_shape() -> void:
	# Find existing collision shape.
	for child in get_children():
		if child is CollisionShape3D:
			_collision_shape = child
			break

	# Create one if not found.
	if not _collision_shape:
		_collision_shape = CollisionShape3D.new()
		_collision_shape.name = "CollisionShape3D"
		add_child(_collision_shape)

	# Ensure it has a BoxShape3D.
	if not _collision_shape.shape is BoxShape3D:
		_collision_shape.shape = BoxShape3D.new()

	# Apply zone_size.
	_update_collision_shape()


func _update_collision_shape() -> void:
	if _collision_shape and _collision_shape.shape is BoxShape3D:
		var box: BoxShape3D = _collision_shape.shape
		# Make shape unique to avoid affecting other instances.
		if not box.resource_local_to_scene:
			box = box.duplicate()
			_collision_shape.shape = box
		box.size = zone_size
		# Center the collision shape vertically.
		_collision_shape.position.y = zone_size.y / 2.0


func _on_body_entered(body: Node3D) -> void:
	if Engine.is_editor_hint():
		return
	if body.is_in_group("player"):
		zone_entered.emit(self)


func _on_body_exited(body: Node3D) -> void:
	if Engine.is_editor_hint():
		return
	if body.is_in_group("player"):
		zone_exited.emit(self)


func _create_debug_label() -> void:
	_debug_label = Label3D.new()
	_debug_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_debug_label.font_size = 32
	_debug_label.modulate = Color(1, 1, 0, 0.8)
	add_child(_debug_label)
	_update_debug_label()


func _update_debug_label() -> void:
	if _debug_label:
		var preset_name := camera_preset.preset_name if camera_preset else "None"
		_debug_label.text = "CamZone: %s (P:%d)" % [preset_name, zone_priority]


func _create_camera_preview() -> void:
	# Create mesh for camera body/lens (layer 2, hidden from preview camera).
	_body_mesh = MeshInstance3D.new()
	_body_mesh.name = "CameraBody"
	_body_mesh.mesh = ImmediateMesh.new()
	_body_mesh.layers = 2  # Layer 2 only.
	add_child(_body_mesh)

	# Create mesh for lines/frustum (layer 2, hidden from preview).
	_frustum_mesh = MeshInstance3D.new()
	_frustum_mesh.name = "CameraFrustum"
	_frustum_mesh.mesh = ImmediateMesh.new()
	_frustum_mesh.layers = 2  # Layer 2 only.
	add_child(_frustum_mesh)

	# Create mesh for target crosshair (layer 1, visible in preview).
	_target_mesh = MeshInstance3D.new()
	_target_mesh.name = "TargetCrosshair"
	_target_mesh.mesh = ImmediateMesh.new()
	_target_mesh.layers = 1  # Layer 1 only.
	add_child(_target_mesh)

	_update_camera_preview()


func _update_camera_preview() -> void:
	if not Engine.is_editor_hint():
		return

	if not _frustum_mesh or not _frustum_mesh.mesh is ImmediateMesh:
		return
	if not _body_mesh or not _body_mesh.mesh is ImmediateMesh:
		return
	if not _target_mesh or not _target_mesh.mesh is ImmediateMesh:
		return

	var im_lines: ImmediateMesh = _frustum_mesh.mesh
	var im_body: ImmediateMesh = _body_mesh.mesh
	var im_target: ImmediateMesh = _target_mesh.mesh
	im_lines.clear_surfaces()
	im_body.clear_surfaces()
	im_target.clear_surfaces()

	if not camera_marker or not is_instance_valid(camera_marker):
		return

	# Get effective look-at node (target takes priority over marker).
	var look_node := get_look_at_node()

	# Calculate camera orientation.
	var cam_pos := camera_marker.global_position
	var cam_basis: Basis

	if look_node:
		var dir := (look_node.global_position - cam_pos).normalized()
		var up := Vector3.FORWARD if absf(dir.y) > 0.9 else Vector3.UP
		# Build basis looking at target.
		var z_axis := -dir
		var x_axis := up.cross(z_axis).normalized()
		var y_axis := z_axis.cross(x_axis)
		cam_basis = Basis(x_axis, y_axis, z_axis)
	else:
		cam_basis = camera_marker.global_basis

	var forward := -cam_basis.z
	var right := cam_basis.x
	var up_vec := cam_basis.y

	# === Camera Body dimensions ===
	var body_w := 0.25  # Width
	var body_h := 0.3   # Height
	var body_d := 0.4   # Depth

	# Box centered on cam_pos.
	var body_front := cam_pos + forward * (body_d * 0.5)
	var body_back := cam_pos - forward * (body_d * 0.5)

	# Front face corners.
	var bf_tl := body_front + up_vec * body_h * 0.5 - right * body_w * 0.5
	var bf_tr := body_front + up_vec * body_h * 0.5 + right * body_w * 0.5
	var bf_bl := body_front - up_vec * body_h * 0.5 - right * body_w * 0.5
	var bf_br := body_front - up_vec * body_h * 0.5 + right * body_w * 0.5

	# Back face corners.
	var bb_tl := body_back + up_vec * body_h * 0.5 - right * body_w * 0.5
	var bb_tr := body_back + up_vec * body_h * 0.5 + right * body_w * 0.5
	var bb_bl := body_back - up_vec * body_h * 0.5 - right * body_w * 0.5
	var bb_br := body_back - up_vec * body_h * 0.5 + right * body_w * 0.5

	# === Lens Cone dimensions ===
	var lens_base_radius := 0.12
	var lens_length := 0.15
	var cone_offset := 0.25
	var cone_base := body_front + forward * cone_offset
	var cone_tip := cone_base - forward * lens_length
	var lens_segments := 4

	# Generate cone base circle points (rotated 45 degrees).
	var cone_points: Array[Vector3] = []
	for i in lens_segments:
		var angle := TAU * i / lens_segments + PI * 0.25
		var offset := right * cos(angle) * lens_base_radius + up_vec * sin(angle) * lens_base_radius
		cone_points.append(cone_base + offset)

	# === BODY MESH: Camera body and lens (layer 2, hidden from preview) ===
	im_body.surface_begin(Mesh.PRIMITIVE_TRIANGLES)

	# Camera body faces (6 faces, 2 triangles each).
	_add_tri(im_body, bf_tl, bf_tr, bf_br)
	_add_tri(im_body, bf_tl, bf_br, bf_bl)
	_add_tri(im_body, bb_tr, bb_tl, bb_bl)
	_add_tri(im_body, bb_tr, bb_bl, bb_br)
	_add_tri(im_body, bb_tl, bb_tr, bf_tr)
	_add_tri(im_body, bb_tl, bf_tr, bf_tl)
	_add_tri(im_body, bf_bl, bf_br, bb_br)
	_add_tri(im_body, bf_bl, bb_br, bb_bl)
	_add_tri(im_body, bb_tl, bf_tl, bf_bl)
	_add_tri(im_body, bb_tl, bf_bl, bb_bl)
	_add_tri(im_body, bf_tr, bb_tr, bb_br)
	_add_tri(im_body, bf_tr, bb_br, bf_br)

	# Lens cone triangles.
	for i in lens_segments:
		var next := (i + 1) % lens_segments
		_add_tri(im_body, cone_tip, cone_points[i], cone_points[next])

	im_body.surface_end()

	# Body wireframe.
	im_body.surface_begin(Mesh.PRIMITIVE_LINES)
	_add_line(im_body, bf_tl, bf_tr)
	_add_line(im_body, bf_tr, bf_br)
	_add_line(im_body, bf_br, bf_bl)
	_add_line(im_body, bf_bl, bf_tl)
	_add_line(im_body, bb_tl, bb_tr)
	_add_line(im_body, bb_tr, bb_br)
	_add_line(im_body, bb_br, bb_bl)
	_add_line(im_body, bb_bl, bb_tl)
	_add_line(im_body, bf_tl, bb_tl)
	_add_line(im_body, bf_tr, bb_tr)
	_add_line(im_body, bf_bl, bb_bl)
	_add_line(im_body, bf_br, bb_br)
	for i in lens_segments:
		_add_line(im_body, cone_points[i], cone_points[(i + 1) % lens_segments])
	for i in lens_segments:
		_add_line(im_body, cone_points[i], cone_tip)
	im_body.surface_end()

	# Colors based on selection state.
	var face_color: Color
	var line_color: Color
	if _is_editor_selected:
		face_color = Color(0.2, 0.8, 1.0, 0.1)
		line_color = Color(0.2, 0.8, 1.0, 0.9)
	else:
		face_color = Color(0.0, 0.0, 0.0, 0.1)
		line_color = Color(0.0, 0.0, 0.0, 0.9)

	# Body materials.
	var body_face_mat := StandardMaterial3D.new()
	body_face_mat.albedo_color = face_color
	body_face_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	body_face_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	body_face_mat.cull_mode = BaseMaterial3D.CULL_BACK
	body_face_mat.no_depth_test = true
	im_body.surface_set_material(0, body_face_mat)

	var body_line_mat := StandardMaterial3D.new()
	body_line_mat.albedo_color = line_color
	body_line_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	body_line_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	body_line_mat.no_depth_test = true
	im_body.surface_set_material(1, body_line_mat)

	# === FRUSTUM MESH: Lines only (layer 1, visible in preview) ===
	# === Frustum calculations ===
	var near_dist := 0.3
	var far_dist := 1.55
	var aspect := 16.0 / 9.0
	var fov_half := deg_to_rad(35.0)

	var near_h := near_dist * tan(fov_half)
	var near_w := near_h * aspect
	var far_h := far_dist * tan(fov_half)
	var far_w := far_h * aspect

	var near_center := cone_base + forward * near_dist
	var far_center := cone_base + forward * far_dist

	# Near plane corners.
	var n_tl := near_center + up_vec * near_h - right * near_w
	var n_tr := near_center + up_vec * near_h + right * near_w
	var n_bl := near_center - up_vec * near_h - right * near_w
	var n_br := near_center - up_vec * near_h + right * near_w

	# Far plane corners.
	var f_tl := far_center + up_vec * far_h - right * far_w
	var f_tr := far_center + up_vec * far_h + right * far_w
	var f_bl := far_center - up_vec * far_h - right * far_w
	var f_br := far_center - up_vec * far_h + right * far_w

	# Up triangle.
	var arrow_base := (f_tl + f_tr) * 0.5 + up_vec * 0.05
	var arrow_height := 0.1
	var arrow_width := 0.15
	var arrow_tip := arrow_base + up_vec * arrow_height
	var arrow_left := arrow_base - right * arrow_width
	var arrow_right_pt := arrow_base + right * arrow_width

	# Filled triangles for arrow and look-at cube.
	im_lines.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	_add_tri(im_lines, arrow_left, arrow_tip, arrow_right_pt)
	if look_node:
		var look_pos := look_node.global_position
		_add_filled_cube(im_lines, look_pos, 0.15, cam_basis)
	im_lines.surface_end()

	# Wireframe lines.
	im_lines.surface_begin(Mesh.PRIMITIVE_LINES)

	# Near rectangle.
	_add_line(im_lines, n_tl, n_tr)
	_add_line(im_lines, n_tr, n_br)
	_add_line(im_lines, n_br, n_bl)
	_add_line(im_lines, n_bl, n_tl)

	# Far rectangle.
	_add_line(im_lines, f_tl, f_tr)
	_add_line(im_lines, f_tr, f_br)
	_add_line(im_lines, f_br, f_bl)
	_add_line(im_lines, f_bl, f_tl)

	# Connecting lines from near to far (dashed).
	_add_dashed_line(im_lines, n_tl, f_tl)
	_add_dashed_line(im_lines, n_tr, f_tr)
	_add_dashed_line(im_lines, n_bl, f_bl)
	_add_dashed_line(im_lines, n_br, f_br)

	# Up triangle wireframe.
	_add_line(im_lines, arrow_left, arrow_tip)
	_add_line(im_lines, arrow_tip, arrow_right_pt)
	_add_line(im_lines, arrow_right_pt, arrow_left)

	# Look-at target line and cube wireframe.
	if look_node:
		var look_pos := look_node.global_position
		_add_line(im_lines, cam_pos, look_pos)
		_add_wireframe_cube(im_lines, look_pos, 0.15, cam_basis)

	im_lines.surface_end()

	# Frustum materials (use same colors as body).
	var line_face_mat := StandardMaterial3D.new()
	line_face_mat.albedo_color = Color(face_color.r, face_color.g, face_color.b, 0.3)
	line_face_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	line_face_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	line_face_mat.cull_mode = BaseMaterial3D.CULL_BACK
	line_face_mat.no_depth_test = true
	im_lines.surface_set_material(0, line_face_mat)

	var line_mat := StandardMaterial3D.new()
	line_mat.albedo_color = line_color
	line_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	line_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	line_mat.no_depth_test = true
	im_lines.surface_set_material(1, line_mat)

	# === TARGET CROSSHAIR (layer 1, visible in preview) ===
	if look_node:
		var look_pos := look_node.global_position
		var cross_size := 0.1

		im_target.surface_begin(Mesh.PRIMITIVE_LINES)
		# Horizontal line.
		_add_line(im_target, look_pos - right * cross_size, look_pos + right * cross_size)
		# Vertical line.
		_add_line(im_target, look_pos - up_vec * cross_size, look_pos + up_vec * cross_size)
		im_target.surface_end()

		# White material for crosshair.
		var cross_mat := StandardMaterial3D.new()
		cross_mat.albedo_color = Color(1.0, 1.0, 1.0, 1.0)
		cross_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		cross_mat.no_depth_test = true
		im_target.surface_set_material(0, cross_mat)


func _add_line(im: ImmediateMesh, start: Vector3, end: Vector3) -> void:
	im.surface_add_vertex(to_local(start))
	im.surface_add_vertex(to_local(end))


func _add_tri(im: ImmediateMesh, a: Vector3, b: Vector3, c: Vector3) -> void:
	im.surface_add_vertex(to_local(a))
	im.surface_add_vertex(to_local(b))
	im.surface_add_vertex(to_local(c))


func _add_dashed_line(im: ImmediateMesh, start: Vector3, end: Vector3, dash_length: float = 0.1, gap_length: float = 0.08) -> void:
	var dir := end - start
	var total_length := dir.length()
	dir = dir.normalized()
	var pos := 0.0
	while pos < total_length:
		var dash_start := start + dir * pos
		var dash_end_pos := minf(pos + dash_length, total_length)
		var dash_end := start + dir * dash_end_pos
		_add_line(im, dash_start, dash_end)
		pos += dash_length + gap_length


func _add_wireframe_cube(im: ImmediateMesh, center: Vector3, size: float, basis: Basis) -> void:
	var half := size * 0.5
	var r := basis.x * half
	var u := basis.y * half
	var f := -basis.z * half

	# 8 corners of the cube.
	var corners: Array[Vector3] = [
		center - r - u - f,  # 0: back-bottom-left
		center + r - u - f,  # 1: back-bottom-right
		center + r + u - f,  # 2: back-top-right
		center - r + u - f,  # 3: back-top-left
		center - r - u + f,  # 4: front-bottom-left
		center + r - u + f,  # 5: front-bottom-right
		center + r + u + f,  # 6: front-top-right
		center - r + u + f,  # 7: front-top-left
	]

	# Back face.
	_add_line(im, corners[0], corners[1])
	_add_line(im, corners[1], corners[2])
	_add_line(im, corners[2], corners[3])
	_add_line(im, corners[3], corners[0])

	# Front face.
	_add_line(im, corners[4], corners[5])
	_add_line(im, corners[5], corners[6])
	_add_line(im, corners[6], corners[7])
	_add_line(im, corners[7], corners[4])

	# Connecting edges.
	_add_line(im, corners[0], corners[4])
	_add_line(im, corners[1], corners[5])
	_add_line(im, corners[2], corners[6])
	_add_line(im, corners[3], corners[7])


func _add_filled_cube(im: ImmediateMesh, center: Vector3, size: float, basis: Basis) -> void:
	var half := size * 0.5
	var r := basis.x * half
	var u := basis.y * half
	var f := -basis.z * half

	# 8 corners of the cube.
	var c: Array[Vector3] = [
		center - r - u - f,  # 0: back-bottom-left
		center + r - u - f,  # 1: back-bottom-right
		center + r + u - f,  # 2: back-top-right
		center - r + u - f,  # 3: back-top-left
		center - r - u + f,  # 4: front-bottom-left
		center + r - u + f,  # 5: front-bottom-right
		center + r + u + f,  # 6: front-top-right
		center - r + u + f,  # 7: front-top-left
	]

	# 6 faces, 2 triangles each.
	# Back face (0, 1, 2, 3).
	_add_tri(im, c[0], c[1], c[2])
	_add_tri(im, c[0], c[2], c[3])
	# Front face (4, 5, 6, 7).
	_add_tri(im, c[4], c[6], c[5])
	_add_tri(im, c[4], c[7], c[6])
	# Top face (3, 2, 6, 7).
	_add_tri(im, c[3], c[2], c[6])
	_add_tri(im, c[3], c[6], c[7])
	# Bottom face (0, 1, 5, 4).
	_add_tri(im, c[0], c[5], c[1])
	_add_tri(im, c[0], c[4], c[5])
	# Left face (0, 3, 7, 4).
	_add_tri(im, c[0], c[3], c[7])
	_add_tri(im, c[0], c[7], c[4])
	# Right face (1, 2, 6, 5).
	_add_tri(im, c[1], c[6], c[2])
	_add_tri(im, c[1], c[5], c[6])


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		_update_camera_preview()
