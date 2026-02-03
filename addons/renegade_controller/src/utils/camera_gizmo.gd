## Static utility class for drawing camera gizmos in the editor.
## Provides shared drawing primitives used by CameraZone.
@tool
class_name CameraGizmo extends RefCounted


#region Constants
const BODY_WIDTH := 0.25
const BODY_HEIGHT := 0.3
const BODY_DEPTH := 0.4
const LENS_BASE_RADIUS := 0.12
const LENS_LENGTH := 0.15
const LENS_OFFSET := 0.25
const LENS_SEGMENTS := 4
const FRUSTUM_NEAR := 0.3
const FRUSTUM_FAR := 1.55
const FRUSTUM_ASPECT := 16.0 / 9.0
const ARROW_HEIGHT := 0.1
const ARROW_WIDTH := 0.15
const DASH_LENGTH := 0.1
const GAP_LENGTH := 0.08
#endregion


#region Drawing Primitives
## Add a line between two world-space points.
static func add_line(im: ImmediateMesh, owner_node: Node3D, start: Vector3, end: Vector3) -> void:
	im.surface_add_vertex(owner_node.to_local(start))
	im.surface_add_vertex(owner_node.to_local(end))


## Add a triangle from three world-space points.
static func add_tri(im: ImmediateMesh, owner_node: Node3D, a: Vector3, b: Vector3, c: Vector3) -> void:
	im.surface_add_vertex(owner_node.to_local(a))
	im.surface_add_vertex(owner_node.to_local(b))
	im.surface_add_vertex(owner_node.to_local(c))


## Add a dashed line between two world-space points.
static func add_dashed_line(im: ImmediateMesh, owner_node: Node3D, start: Vector3, end: Vector3, dash_length: float = DASH_LENGTH, gap_length: float = GAP_LENGTH) -> void:
	var dir := end - start
	var total_length := dir.length()
	dir = dir.normalized()
	var pos := 0.0
	while pos < total_length:
		var dash_start := start + dir * pos
		var dash_end_pos := minf(pos + dash_length, total_length)
		var dash_end := start + dir * dash_end_pos
		add_line(im, owner_node, dash_start, dash_end)
		pos += dash_length + gap_length


## Add a wireframe cube centered at a world-space position.
static func add_wireframe_cube(im: ImmediateMesh, owner_node: Node3D, center: Vector3, size: float, basis: Basis) -> void:
	var half := size * 0.5
	var r := basis.x * half
	var u := basis.y * half
	var f := -basis.z * half

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

	# Back face
	add_line(im, owner_node, corners[0], corners[1])
	add_line(im, owner_node, corners[1], corners[2])
	add_line(im, owner_node, corners[2], corners[3])
	add_line(im, owner_node, corners[3], corners[0])
	# Front face
	add_line(im, owner_node, corners[4], corners[5])
	add_line(im, owner_node, corners[5], corners[6])
	add_line(im, owner_node, corners[6], corners[7])
	add_line(im, owner_node, corners[7], corners[4])
	# Connecting edges
	add_line(im, owner_node, corners[0], corners[4])
	add_line(im, owner_node, corners[1], corners[5])
	add_line(im, owner_node, corners[2], corners[6])
	add_line(im, owner_node, corners[3], corners[7])


## Add a filled cube centered at a world-space position.
static func add_filled_cube(im: ImmediateMesh, owner_node: Node3D, center: Vector3, size: float, basis: Basis) -> void:
	var half := size * 0.5
	var r := basis.x * half
	var u := basis.y * half
	var f := -basis.z * half

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

	# 6 faces, 2 triangles each
	# Back face
	add_tri(im, owner_node, c[0], c[1], c[2])
	add_tri(im, owner_node, c[0], c[2], c[3])
	# Front face
	add_tri(im, owner_node, c[4], c[6], c[5])
	add_tri(im, owner_node, c[4], c[7], c[6])
	# Top face
	add_tri(im, owner_node, c[3], c[2], c[6])
	add_tri(im, owner_node, c[3], c[6], c[7])
	# Bottom face
	add_tri(im, owner_node, c[0], c[5], c[1])
	add_tri(im, owner_node, c[0], c[4], c[5])
	# Left face
	add_tri(im, owner_node, c[0], c[3], c[7])
	add_tri(im, owner_node, c[0], c[7], c[4])
	# Right face
	add_tri(im, owner_node, c[1], c[6], c[2])
	add_tri(im, owner_node, c[1], c[5], c[6])
#endregion


#region Camera Body Drawing
## Draw camera body (box + lens cone) as triangles. Call within surface_begin/end PRIMITIVE_TRIANGLES.
static func draw_camera_body_triangles(im: ImmediateMesh, owner_node: Node3D, cam_pos: Vector3, cam_basis: Basis) -> void:
	var forward := -cam_basis.z
	var right := cam_basis.x
	var up_vec := cam_basis.y

	var body_front := cam_pos + forward * (BODY_DEPTH * 0.5)
	var body_back := cam_pos - forward * (BODY_DEPTH * 0.5)

	# Front face corners
	var bf_tl := body_front + up_vec * BODY_HEIGHT * 0.5 - right * BODY_WIDTH * 0.5
	var bf_tr := body_front + up_vec * BODY_HEIGHT * 0.5 + right * BODY_WIDTH * 0.5
	var bf_bl := body_front - up_vec * BODY_HEIGHT * 0.5 - right * BODY_WIDTH * 0.5
	var bf_br := body_front - up_vec * BODY_HEIGHT * 0.5 + right * BODY_WIDTH * 0.5

	# Back face corners
	var bb_tl := body_back + up_vec * BODY_HEIGHT * 0.5 - right * BODY_WIDTH * 0.5
	var bb_tr := body_back + up_vec * BODY_HEIGHT * 0.5 + right * BODY_WIDTH * 0.5
	var bb_bl := body_back - up_vec * BODY_HEIGHT * 0.5 - right * BODY_WIDTH * 0.5
	var bb_br := body_back - up_vec * BODY_HEIGHT * 0.5 + right * BODY_WIDTH * 0.5

	# Lens cone
	var cone_base := body_front + forward * LENS_OFFSET
	var cone_tip := cone_base - forward * LENS_LENGTH
	var cone_points: Array[Vector3] = []
	for i in LENS_SEGMENTS:
		var angle := TAU * i / LENS_SEGMENTS + PI * 0.25
		var offset := right * cos(angle) * LENS_BASE_RADIUS + up_vec * sin(angle) * LENS_BASE_RADIUS
		cone_points.append(cone_base + offset)

	# Camera body faces
	add_tri(im, owner_node, bf_tl, bf_tr, bf_br)
	add_tri(im, owner_node, bf_tl, bf_br, bf_bl)
	add_tri(im, owner_node, bb_tr, bb_tl, bb_bl)
	add_tri(im, owner_node, bb_tr, bb_bl, bb_br)
	add_tri(im, owner_node, bb_tl, bb_tr, bf_tr)
	add_tri(im, owner_node, bb_tl, bf_tr, bf_tl)
	add_tri(im, owner_node, bf_bl, bf_br, bb_br)
	add_tri(im, owner_node, bf_bl, bb_br, bb_bl)
	add_tri(im, owner_node, bb_tl, bf_tl, bf_bl)
	add_tri(im, owner_node, bb_tl, bf_bl, bb_bl)
	add_tri(im, owner_node, bf_tr, bb_tr, bb_br)
	add_tri(im, owner_node, bf_tr, bb_br, bf_br)

	# Lens cone triangles
	for i in LENS_SEGMENTS:
		var next := (i + 1) % LENS_SEGMENTS
		add_tri(im, owner_node, cone_tip, cone_points[i], cone_points[next])


## Draw camera body wireframe. Call within surface_begin/end PRIMITIVE_LINES.
static func draw_camera_body_wireframe(im: ImmediateMesh, owner_node: Node3D, cam_pos: Vector3, cam_basis: Basis) -> void:
	var forward := -cam_basis.z
	var right := cam_basis.x
	var up_vec := cam_basis.y

	var body_front := cam_pos + forward * (BODY_DEPTH * 0.5)
	var body_back := cam_pos - forward * (BODY_DEPTH * 0.5)

	# Front face corners
	var bf_tl := body_front + up_vec * BODY_HEIGHT * 0.5 - right * BODY_WIDTH * 0.5
	var bf_tr := body_front + up_vec * BODY_HEIGHT * 0.5 + right * BODY_WIDTH * 0.5
	var bf_bl := body_front - up_vec * BODY_HEIGHT * 0.5 - right * BODY_WIDTH * 0.5
	var bf_br := body_front - up_vec * BODY_HEIGHT * 0.5 + right * BODY_WIDTH * 0.5

	# Back face corners
	var bb_tl := body_back + up_vec * BODY_HEIGHT * 0.5 - right * BODY_WIDTH * 0.5
	var bb_tr := body_back + up_vec * BODY_HEIGHT * 0.5 + right * BODY_WIDTH * 0.5
	var bb_bl := body_back - up_vec * BODY_HEIGHT * 0.5 - right * BODY_WIDTH * 0.5
	var bb_br := body_back - up_vec * BODY_HEIGHT * 0.5 + right * BODY_WIDTH * 0.5

	# Lens cone
	var cone_base := body_front + forward * LENS_OFFSET
	var cone_tip := cone_base - forward * LENS_LENGTH
	var cone_points: Array[Vector3] = []
	for i in LENS_SEGMENTS:
		var angle := TAU * i / LENS_SEGMENTS + PI * 0.25
		var offset := right * cos(angle) * LENS_BASE_RADIUS + up_vec * sin(angle) * LENS_BASE_RADIUS
		cone_points.append(cone_base + offset)

	# Body wireframe
	add_line(im, owner_node, bf_tl, bf_tr)
	add_line(im, owner_node, bf_tr, bf_br)
	add_line(im, owner_node, bf_br, bf_bl)
	add_line(im, owner_node, bf_bl, bf_tl)
	add_line(im, owner_node, bb_tl, bb_tr)
	add_line(im, owner_node, bb_tr, bb_br)
	add_line(im, owner_node, bb_br, bb_bl)
	add_line(im, owner_node, bb_bl, bb_tl)
	add_line(im, owner_node, bf_tl, bb_tl)
	add_line(im, owner_node, bf_tr, bb_tr)
	add_line(im, owner_node, bf_bl, bb_bl)
	add_line(im, owner_node, bf_br, bb_br)

	# Lens wireframe
	for i in LENS_SEGMENTS:
		add_line(im, owner_node, cone_points[i], cone_points[(i + 1) % LENS_SEGMENTS])
	for i in LENS_SEGMENTS:
		add_line(im, owner_node, cone_points[i], cone_tip)


## Returns the cone base position (where frustum starts).
static func get_cone_base(cam_pos: Vector3, cam_basis: Basis) -> Vector3:
	var forward := -cam_basis.z
	var body_front := cam_pos + forward * (BODY_DEPTH * 0.5)
	return body_front + forward * LENS_OFFSET
#endregion


#region Frustum Drawing
## Draw camera frustum as triangles (up arrow + optional look-at cube).
## Call within surface_begin/end PRIMITIVE_TRIANGLES.
static func draw_frustum_triangles(im: ImmediateMesh, owner_node: Node3D, cone_base: Vector3, cam_basis: Basis, fov_degrees: float, look_pos: Vector3 = Vector3.INF) -> void:
	var forward := -cam_basis.z
	var right := cam_basis.x
	var up_vec := cam_basis.y
	var fov_half := deg_to_rad(fov_degrees * 0.5)

	var far_h := FRUSTUM_FAR * tan(fov_half)
	var far_w := far_h * FRUSTUM_ASPECT
	var far_center := cone_base + forward * FRUSTUM_FAR

	var f_tl := far_center + up_vec * far_h - right * far_w
	var f_tr := far_center + up_vec * far_h + right * far_w

	# Up arrow
	var arrow_base := (f_tl + f_tr) * 0.5 + up_vec * 0.05
	var arrow_tip := arrow_base + up_vec * ARROW_HEIGHT
	var arrow_left := arrow_base - right * ARROW_WIDTH
	var arrow_right_pt := arrow_base + right * ARROW_WIDTH

	add_tri(im, owner_node, arrow_left, arrow_tip, arrow_right_pt)

	# Look-at cube (if valid position)
	if look_pos != Vector3.INF:
		add_filled_cube(im, owner_node, look_pos, 0.15, cam_basis)


## Draw camera frustum wireframe.
## Call within surface_begin/end PRIMITIVE_LINES.
static func draw_frustum_wireframe(im: ImmediateMesh, owner_node: Node3D, cam_pos: Vector3, cone_base: Vector3, cam_basis: Basis, fov_degrees: float, look_pos: Vector3 = Vector3.INF) -> void:
	var forward := -cam_basis.z
	var right := cam_basis.x
	var up_vec := cam_basis.y
	var fov_half := deg_to_rad(fov_degrees * 0.5)

	var near_h := FRUSTUM_NEAR * tan(fov_half)
	var near_w := near_h * FRUSTUM_ASPECT
	var far_h := FRUSTUM_FAR * tan(fov_half)
	var far_w := far_h * FRUSTUM_ASPECT

	var near_center := cone_base + forward * FRUSTUM_NEAR
	var far_center := cone_base + forward * FRUSTUM_FAR

	# Near plane corners
	var n_tl := near_center + up_vec * near_h - right * near_w
	var n_tr := near_center + up_vec * near_h + right * near_w
	var n_bl := near_center - up_vec * near_h - right * near_w
	var n_br := near_center - up_vec * near_h + right * near_w

	# Far plane corners
	var f_tl := far_center + up_vec * far_h - right * far_w
	var f_tr := far_center + up_vec * far_h + right * far_w
	var f_bl := far_center - up_vec * far_h - right * far_w
	var f_br := far_center - up_vec * far_h + right * far_w

	# Near rectangle
	add_line(im, owner_node, n_tl, n_tr)
	add_line(im, owner_node, n_tr, n_br)
	add_line(im, owner_node, n_br, n_bl)
	add_line(im, owner_node, n_bl, n_tl)

	# Far rectangle
	add_line(im, owner_node, f_tl, f_tr)
	add_line(im, owner_node, f_tr, f_br)
	add_line(im, owner_node, f_br, f_bl)
	add_line(im, owner_node, f_bl, f_tl)

	# Connecting dashed lines
	add_dashed_line(im, owner_node, n_tl, f_tl)
	add_dashed_line(im, owner_node, n_tr, f_tr)
	add_dashed_line(im, owner_node, n_bl, f_bl)
	add_dashed_line(im, owner_node, n_br, f_br)

	# Up arrow wireframe
	var arrow_base := (f_tl + f_tr) * 0.5 + up_vec * 0.05
	var arrow_tip := arrow_base + up_vec * ARROW_HEIGHT
	var arrow_left := arrow_base - right * ARROW_WIDTH
	var arrow_right_pt := arrow_base + right * ARROW_WIDTH

	add_line(im, owner_node, arrow_left, arrow_tip)
	add_line(im, owner_node, arrow_tip, arrow_right_pt)
	add_line(im, owner_node, arrow_right_pt, arrow_left)

	# Look-at line and cube (if valid position)
	if look_pos != Vector3.INF:
		add_line(im, owner_node, cam_pos, look_pos)
		add_wireframe_cube(im, owner_node, look_pos, 0.15, cam_basis)
#endregion


#region Material Creation
## Create a face material for gizmo rendering.
static func create_face_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_BACK
	mat.no_depth_test = true
	return mat


## Create a line material for gizmo rendering.
static func create_line_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.no_depth_test = true
	return mat


## Get selection-based colors for gizmos.
## Returns [face_color, line_color].
static func get_selection_colors(is_selected: bool, base_hue: Color = Color(0.2, 0.8, 1.0)) -> Array[Color]:
	if is_selected:
		return [Color(base_hue.r, base_hue.g, base_hue.b, 0.1), Color(base_hue.r, base_hue.g, base_hue.b, 0.9)]
	else:
		return [Color(0.0, 0.0, 0.0, 0.1), Color(0.0, 0.0, 0.0, 0.9)]
#endregion
