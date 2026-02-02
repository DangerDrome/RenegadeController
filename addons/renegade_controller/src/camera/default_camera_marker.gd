## Marker for default camera positions (third-person, first-person).
## Works like zone camera markers with editor visualization.
## Position this marker where you want the camera to be.
## The camera will look at the target (player) from this position.
@tool
class_name DefaultCameraMarker extends Marker3D

## Optional look-at target. If not set, camera looks at player.
@export var look_at_target: Node3D:
	set(value):
		look_at_target = value
		_update_preview()

## Label shown in editor.
@export var marker_label: String = "Camera":
	set(value):
		marker_label = value
		_update_label()

var _debug_label: Label3D
var _body_mesh: MeshInstance3D
var _frustum_mesh: MeshInstance3D
var _is_editor_selected: bool = false


func _ready() -> void:
	if Engine.is_editor_hint():
		_create_debug_label()
		_create_preview_meshes()


func set_editor_selected(selected: bool) -> void:
	if _is_editor_selected != selected:
		_is_editor_selected = selected
		_update_preview()


func _create_debug_label() -> void:
	_debug_label = Label3D.new()
	_debug_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_debug_label.font_size = 24
	_debug_label.modulate = Color(0.2, 0.8, 1.0, 0.9)
	_debug_label.position = Vector3(0, 0.5, 0)
	add_child(_debug_label)
	_update_label()


func _update_label() -> void:
	if _debug_label:
		_debug_label.text = marker_label


func _create_preview_meshes() -> void:
	_body_mesh = MeshInstance3D.new()
	_body_mesh.name = "CameraBody"
	_body_mesh.mesh = ImmediateMesh.new()
	_body_mesh.layers = 2
	add_child(_body_mesh)

	_frustum_mesh = MeshInstance3D.new()
	_frustum_mesh.name = "CameraFrustum"
	_frustum_mesh.mesh = ImmediateMesh.new()
	_frustum_mesh.layers = 2
	add_child(_frustum_mesh)

	_update_preview()


func _update_preview() -> void:
	if not Engine.is_editor_hint():
		return
	if not _body_mesh or not _body_mesh.mesh is ImmediateMesh:
		return
	if not _frustum_mesh or not _frustum_mesh.mesh is ImmediateMesh:
		return

	var im_body: ImmediateMesh = _body_mesh.mesh
	var im_lines: ImmediateMesh = _frustum_mesh.mesh
	im_body.clear_surfaces()
	im_lines.clear_surfaces()

	# Camera orientation - use marker's basis or look at target.
	var cam_pos := global_position
	var cam_basis: Basis

	if look_at_target and is_instance_valid(look_at_target):
		var dir := (look_at_target.global_position - cam_pos).normalized()
		var up := Vector3.FORWARD if absf(dir.y) > 0.9 else Vector3.UP
		var z_axis := -dir
		var x_axis := up.cross(z_axis).normalized()
		var y_axis := z_axis.cross(x_axis)
		cam_basis = Basis(x_axis, y_axis, z_axis)
	else:
		cam_basis = global_basis

	var forward := -cam_basis.z
	var right := cam_basis.x
	var up_vec := cam_basis.y

	# Camera body dimensions.
	var body_w := 0.25
	var body_h := 0.3
	var body_d := 0.4

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

	# Lens cone.
	var lens_base_radius := 0.12
	var lens_length := 0.15
	var cone_offset := 0.25
	var cone_base := body_front + forward * cone_offset
	var cone_tip := cone_base - forward * lens_length
	var lens_segments := 4

	var cone_points: Array[Vector3] = []
	for i in lens_segments:
		var angle := TAU * i / lens_segments + PI * 0.25
		var offset := right * cos(angle) * lens_base_radius + up_vec * sin(angle) * lens_base_radius
		cone_points.append(cone_base + offset)

	# Body mesh - triangles.
	im_body.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
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

	# Colors based on selection.
	var face_color: Color
	var line_color: Color
	if _is_editor_selected:
		face_color = Color(0.2, 0.8, 1.0, 0.15)
		line_color = Color(0.2, 0.8, 1.0, 0.9)
	else:
		face_color = Color(0.2, 0.6, 0.8, 0.1)
		line_color = Color(0.2, 0.6, 0.8, 0.7)

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

	# Frustum.
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

	var n_tl := near_center + up_vec * near_h - right * near_w
	var n_tr := near_center + up_vec * near_h + right * near_w
	var n_bl := near_center - up_vec * near_h - right * near_w
	var n_br := near_center - up_vec * near_h + right * near_w

	var f_tl := far_center + up_vec * far_h - right * far_w
	var f_tr := far_center + up_vec * far_h + right * far_w
	var f_bl := far_center - up_vec * far_h - right * far_w
	var f_br := far_center - up_vec * far_h + right * far_w

	# Up arrow.
	var arrow_base := (f_tl + f_tr) * 0.5 + up_vec * 0.05
	var arrow_height := 0.1
	var arrow_width := 0.15
	var arrow_tip := arrow_base + up_vec * arrow_height
	var arrow_left := arrow_base - right * arrow_width
	var arrow_right_pt := arrow_base + right * arrow_width

	im_lines.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	_add_tri(im_lines, arrow_left, arrow_tip, arrow_right_pt)
	if look_at_target and is_instance_valid(look_at_target):
		_add_filled_cube(im_lines, look_at_target.global_position, 0.15, cam_basis)
	im_lines.surface_end()

	im_lines.surface_begin(Mesh.PRIMITIVE_LINES)
	_add_line(im_lines, n_tl, n_tr)
	_add_line(im_lines, n_tr, n_br)
	_add_line(im_lines, n_br, n_bl)
	_add_line(im_lines, n_bl, n_tl)
	_add_line(im_lines, f_tl, f_tr)
	_add_line(im_lines, f_tr, f_br)
	_add_line(im_lines, f_br, f_bl)
	_add_line(im_lines, f_bl, f_tl)
	_add_dashed_line(im_lines, n_tl, f_tl)
	_add_dashed_line(im_lines, n_tr, f_tr)
	_add_dashed_line(im_lines, n_bl, f_bl)
	_add_dashed_line(im_lines, n_br, f_br)
	_add_line(im_lines, arrow_left, arrow_tip)
	_add_line(im_lines, arrow_tip, arrow_right_pt)
	_add_line(im_lines, arrow_right_pt, arrow_left)
	if look_at_target and is_instance_valid(look_at_target):
		_add_line(im_lines, cam_pos, look_at_target.global_position)
		_add_wireframe_cube(im_lines, look_at_target.global_position, 0.15, cam_basis)
	im_lines.surface_end()

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


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		_update_preview()


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


func _add_wireframe_cube(im: ImmediateMesh, center: Vector3, size: float, cam_basis: Basis) -> void:
	var half := size * 0.5
	var r := cam_basis.x * half
	var u := cam_basis.y * half
	var f := -cam_basis.z * half

	var corners: Array[Vector3] = [
		center - r - u - f,
		center + r - u - f,
		center + r + u - f,
		center - r + u - f,
		center - r - u + f,
		center + r - u + f,
		center + r + u + f,
		center - r + u + f,
	]

	_add_line(im, corners[0], corners[1])
	_add_line(im, corners[1], corners[2])
	_add_line(im, corners[2], corners[3])
	_add_line(im, corners[3], corners[0])
	_add_line(im, corners[4], corners[5])
	_add_line(im, corners[5], corners[6])
	_add_line(im, corners[6], corners[7])
	_add_line(im, corners[7], corners[4])
	_add_line(im, corners[0], corners[4])
	_add_line(im, corners[1], corners[5])
	_add_line(im, corners[2], corners[6])
	_add_line(im, corners[3], corners[7])


func _add_filled_cube(im: ImmediateMesh, center: Vector3, size: float, cam_basis: Basis) -> void:
	var half := size * 0.5
	var r := cam_basis.x * half
	var u := cam_basis.y * half
	var f := -cam_basis.z * half

	var c: Array[Vector3] = [
		center - r - u - f,
		center + r - u - f,
		center + r + u - f,
		center - r + u - f,
		center - r - u + f,
		center + r - u + f,
		center + r + u + f,
		center - r + u + f,
	]

	_add_tri(im, c[0], c[1], c[2])
	_add_tri(im, c[0], c[2], c[3])
	_add_tri(im, c[4], c[6], c[5])
	_add_tri(im, c[4], c[7], c[6])
	_add_tri(im, c[3], c[2], c[6])
	_add_tri(im, c[3], c[6], c[7])
	_add_tri(im, c[0], c[5], c[1])
	_add_tri(im, c[0], c[4], c[5])
	_add_tri(im, c[0], c[3], c[7])
	_add_tri(im, c[0], c[7], c[4])
	_add_tri(im, c[1], c[6], c[2])
	_add_tri(im, c[1], c[5], c[6])
