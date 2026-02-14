## Places hand IK targets on nearby environment surfaces.
## Raycasts sideways from the character, positions L_hand_object / R_hand_object
## markers at hit points, and controls L_arm_object / R_arm_object TwoBoneIK3D
## influence. Marker rotation is set from surface normals — a CopyTransformModifier
## on the skeleton copies marker rotation to hand bones.
## Same ray-based approach as HitReactorComponent.
class_name HandObjectPlacement
extends Node

@export_group("Detection")
## How far to detect nearby surfaces for hand placement.
@export var detection_range: float = 0.8
## Physics layers to detect.
@export_flags_3d_physics var collision_mask: int = 1
## Total number of rays fanned around the character.
@export_range(2, 16) var ray_count: int = 8
## Fan spread in degrees. Rays are split left/right automatically.
@export var fan_angle: float = 180.0
## How often to update raycasts (seconds). Blending runs every frame.
@export var update_interval: float = 0.03
## Height from character origin for ray origins (shoulder level).
@export var ray_height: float = 1.1
## Lateral offset from center for each ray origin.
@export var ray_lateral_offset: float = 0.2

@export_group("Response")
## How fast IK blends in when a surface is detected (exponential damping).
@export var reach_speed: float = 10.0
## How fast IK blends out when the surface clears (exponential damping).
@export var release_speed: float = 5.0
## Offset from surface so the hand doesn't clip through.
@export var surface_offset: float = 0.05

@export_group("Angle Validation")
## Minimum dot product between reach direction and character forward.
## Below this the hand lerps out. -1 = allow behind, 0 = sides only, 1 = dead ahead only.
@export_range(-1.0, 1.0) var min_forward_dot: float = -0.3
## Minimum dot product between surface normal and approach direction.
## Below this the hand lerps out. Rejects surfaces the palm can't face.
@export_range(-1.0, 1.0) var min_normal_dot: float = 0.0

@export_group("Hand Rotation")
## Wrist rotation limits relative to rest pose (degrees).
## X = flexion/extension (bending forward/back).
@export var wrist_limit_x: Vector2 = Vector2(-45.0, 45.0)
## Y = radial/ulnar deviation (bending side to side).
@export var wrist_limit_y: Vector2 = Vector2(-30.0, 30.0)
## Z = pronation/supination (twist/roll).
@export var wrist_limit_z: Vector2 = Vector2(-45.0, 45.0)

@export_group("Debug")
@export var debug_draw: bool = false
@export var debug_color_ray_miss: Color = Color.YELLOW
@export var debug_color_ray_hit: Color = Color.ORANGE
@export var debug_color_hit_point: Color = Color.GREEN
@export var debug_color_marker: Color = Color.CYAN
@export var debug_color_up_vector: Color = Color.MAGENTA

var _visuals: CharacterVisuals
var _skeleton: Skeleton3D

# Object placement markers.
var _left_target: Marker3D    # L_hand_object
var _right_target: Marker3D   # R_hand_object

# Object arm IK solvers (influence controlled).
var _left_arm_ik: Node        # L_arm_object
var _right_arm_ik: Node       # R_arm_object

# Hand rays for surface normal alignment.
var _left_ray: RayCast3D      # L_ray
var _right_ray: RayCast3D     # R_ray

# CopyTransformModifier that copies marker rotation to hand bones.
var _hand_xforms: CopyTransformModifier3D
var _hand_xforms_left_idx: int = -1   # Setting index for left hand
var _hand_xforms_right_idx: int = -1  # Setting index for right hand

# Marker rest bases in character-local space — rotates with the character.
var _left_rest_basis_local: Basis
var _right_rest_basis_local: Basis

# Per-hand state.
var _left_blend: float = 0.0
var _right_blend: float = 0.0
var _left_hit_pos: Vector3
var _right_hit_pos: Vector3
var _left_hit_normal: Vector3 = Vector3.RIGHT
var _right_hit_normal: Vector3 = Vector3.LEFT
var _left_active: bool = false
var _right_active: bool = false

var _update_timer: float = 0.0

var _debug_container: Node3D
var _debug_meshes: Array[MeshInstance3D] = []


func _ready() -> void:
	_visuals = get_parent() as CharacterVisuals
	if _visuals == null:
		push_error("HandObjectPlacement: Parent must be CharacterVisuals.")
		return
	_visuals.ready.connect(_setup, CONNECT_ONE_SHOT | CONNECT_DEFERRED)


func _setup() -> void:
	_skeleton = _visuals.skeleton
	if _skeleton == null:
		return

	var uefn := _skeleton.get_parent()

	# Find markers under IKTargets and capture rest bases in character-local space.
	var char_basis_inv := _visuals.global_basis.inverse()
	for child in uefn.get_children():
		if child.name == &"IKTargets":
			for marker in child.get_children():
				match marker.name:
					&"L_hand_object":
						_left_target = marker as Marker3D
						_left_rest_basis_local = char_basis_inv * marker.global_basis
					&"R_hand_object":
						_right_target = marker as Marker3D
						_right_rest_basis_local = char_basis_inv * marker.global_basis
			break

	# Find IK solvers, hand rays, and CopyTransformModifier.
	for child in _skeleton.get_children():
		match child.name:
			&"L_arm_object": _left_arm_ik = child
			&"R_arm_object": _right_arm_ik = child
			&"hands_xform": _hand_xforms = child
			&"L_hand_attach":
				_left_ray = child.get_node_or_null("L_ray") as RayCast3D
			&"R_hand_attach":
				_right_ray = child.get_node_or_null("R_ray") as RayCast3D

	# Map CopyTransformModifier setting indices to left/right hands.
	if _hand_xforms:
		_hand_xforms.influence = 1.0
		for i in _hand_xforms.get_setting_count():
			var bone_name := _hand_xforms.get_apply_bone_name(i)
			if bone_name.containsn("hand_l"):
				_hand_xforms_left_idx = i
				_hand_xforms.set_amount(i, 0.0)
			elif bone_name.containsn("hand_r"):
				_hand_xforms_right_idx = i
				_hand_xforms.set_amount(i, 0.0)


func _physics_process(delta: float) -> void:
	if _skeleton == null:
		return

	# Throttle raycasts, smooth every frame.
	_update_timer += delta
	if _update_timer >= update_interval:
		_update_timer = 0.0
		_update_raycasts()

	# Exponential damping blend.
	_left_blend = _exp_blend(_left_blend, _left_active, delta)
	_right_blend = _exp_blend(_right_blend, _right_active, delta)

	# Reconstruct world-space rest bases from character's current orientation.
	var char_basis := _visuals.global_basis
	var left_rest := char_basis * _left_rest_basis_local
	var right_rest := char_basis * _right_rest_basis_local

	# Position markers at hit surfaces and orient palms into surface.
	# L_hand_object: Y+ = palm down → marker Y = -hit_normal.
	# R_hand_object: Y- = palm down → marker Y = +hit_normal.
	# Euler clamping prevents unnatural wrist angles.
	if _left_target and _left_blend > 0.001:
		_left_target.global_position = _left_hit_pos + _left_hit_normal * surface_offset
		var desired := _palm_basis(-_left_hit_normal, Vector3.UP)
		_left_target.global_basis = _clamp_basis(desired, left_rest)
	if _right_target and _right_blend > 0.001:
		_right_target.global_position = _right_hit_pos + _right_hit_normal * surface_offset
		var desired := _palm_basis(_right_hit_normal, Vector3.DOWN)
		_right_target.global_basis = _clamp_basis(desired, right_rest)

	# Object arm IK influence.
	if _left_arm_ik:
		_left_arm_ik.set("influence", _left_blend)
	if _right_arm_ik:
		_right_arm_ik.set("influence", _right_blend)

	# CopyTransformModifier per-hand amounts — hands return to rest at blend 0.
	if _hand_xforms:
		if _hand_xforms_left_idx >= 0:
			_hand_xforms.set_amount(_hand_xforms_left_idx, _left_blend)
		if _hand_xforms_right_idx >= 0:
			_hand_xforms.set_amount(_hand_xforms_right_idx, _right_blend)

	# Debug: show markers, their Z axis, and the surface normal.
	if debug_draw:
		_draw_marker_debug(_left_target, _left_blend, _left_hit_normal)
		_draw_marker_debug(_right_target, _right_blend, _right_hit_normal)


func _exp_blend(current: float, active: bool, delta: float) -> float:
	var target_val := 1.0 if active else 0.0
	var speed := reach_speed if active else release_speed
	return lerpf(current, target_val, 1.0 - exp(-speed * delta))


func _update_raycasts() -> void:
	if debug_draw:
		_clear_debug()

	if _visuals.controller == null:
		_left_active = false
		_right_active = false
		return

	var space := _skeleton.get_world_3d().direct_space_state
	if space == null:
		return

	var exclude: Array[RID] = [_visuals.controller.get_rid()]
	var char_pos := _visuals.controller.global_position
	# Use visuals basis — the controller doesn't rotate, visual_root does.
	var char_basis := _visuals.global_basis
	var origin := char_pos + Vector3.UP * ray_height

	var half_fan := deg_to_rad(fan_angle * 0.5)
	var left_best := detection_range + 1.0
	var right_best := detection_range + 1.0
	_left_active = false
	_right_active = false

	for i in ray_count:
		# Evenly distribute rays across the fan arc.
		var t := float(i) / (ray_count - 1) - 0.5 if ray_count > 1 else 0.0
		var angle := t * half_fan * 2.0

		# Positive X = right, negative X = left in local space.
		var local_dir := Vector3(sin(angle), 0.0, -cos(angle)).normalized()
		var dir := char_basis * local_dir
		var lateral := signf(local_dir.x) * ray_lateral_offset
		var ray_origin := origin + char_basis.x * lateral
		var end := ray_origin + dir * detection_range

		var query := PhysicsRayQueryParameters3D.create(ray_origin, end)
		query.collision_mask = collision_mask
		query.collide_with_bodies = true
		query.exclude = exclude

		var result := space.intersect_ray(query)

		if debug_draw:
			_draw_debug_line(ray_origin, end, debug_color_ray_miss if result.is_empty() else debug_color_ray_hit)

		if result.is_empty():
			continue

		var dist: float = ray_origin.distance_to(result.position)
		var is_left := local_dir.x <= 0.0

		if is_left and dist < left_best:
			left_best = dist
			_left_hit_pos = result.position
			_left_hit_normal = result.normal
			_left_active = true
		elif not is_left and dist < right_best:
			right_best = dist
			_right_hit_pos = result.position
			_right_hit_normal = result.normal
			_right_active = true

		if debug_draw:
			_draw_debug_sphere(result.position, 0.03, debug_color_hit_point)

	# Invalidate hits with bad angles — blend will naturally lerp out.
	if _left_active and not _is_valid_reach(_left_hit_pos, _left_hit_normal):
		_left_active = false
	if _right_active and not _is_valid_reach(_right_hit_pos, _right_hit_normal):
		_right_active = false


func _is_valid_reach(hit_pos: Vector3, hit_normal: Vector3) -> bool:
	## Dot product checks to reject unnatural hand placements.
	var char_basis := _visuals.global_basis
	var origin := _visuals.controller.global_position + Vector3.UP * ray_height
	var to_target := (hit_pos - origin).normalized()

	# Reject targets behind the character.
	var forward := -char_basis.z
	if forward.dot(to_target) < min_forward_dot:
		return false

	# Reject surfaces facing away — palm can't press against them.
	if hit_normal.dot(-to_target) < min_normal_dot:
		return false

	return true


func _clamp_basis(desired: Basis, rest: Basis) -> Basis:
	## Clamps the rotation of desired relative to rest using per-axis euler limits.
	## Decomposes the delta rotation into euler angles, clamps each axis, rebuilds.
	var delta := rest.inverse() * desired
	var euler := delta.get_euler()
	euler.x = clampf(euler.x, deg_to_rad(wrist_limit_x.x), deg_to_rad(wrist_limit_x.y))
	euler.y = clampf(euler.y, deg_to_rad(wrist_limit_y.x), deg_to_rad(wrist_limit_y.y))
	euler.z = clampf(euler.z, deg_to_rad(wrist_limit_z.x), deg_to_rad(wrist_limit_z.y))
	return rest * Basis.from_euler(euler)


func _palm_basis(y_axis: Vector3, up_ref: Vector3) -> Basis:
	## Builds a basis with the given Y axis. X is aligned as close to
	## up_ref as possible (perpendicular to Y). Z completes the basis.
	var z := up_ref.cross(y_axis)
	if z.length_squared() < 0.001:
		z = Vector3.FORWARD.cross(y_axis)
	z = z.normalized()
	var x := y_axis.cross(z).normalized()
	return Basis(x, y_axis, z)


func _draw_marker_debug(target: Marker3D, blend: float, hit_normal: Vector3) -> void:
	if target == null or blend < 0.001:
		return
	var pos := target.global_position
	_draw_debug_sphere(pos, 0.04, debug_color_marker)
	# Marker's Z axis (should align with surface normal).
	var marker_z := target.global_basis.z.normalized()
	_draw_debug_line(pos, pos + marker_z * 0.15, debug_color_up_vector)
	# Actual surface normal from raycast.
	_draw_debug_line(pos, pos + hit_normal * 0.2, Color.WHITE)


#region Debug Drawing

func _clear_debug() -> void:
	for m in _debug_meshes:
		if is_instance_valid(m):
			m.queue_free()
	_debug_meshes.clear()


func _ensure_debug_container() -> void:
	if _debug_container != null and is_instance_valid(_debug_container):
		return
	_debug_container = Node3D.new()
	_debug_container.name = "HandObjectPlacementDebug"
	_skeleton.get_tree().current_scene.add_child(_debug_container)


func _draw_debug_sphere(pos: Vector3, radius: float, color: Color) -> void:
	_ensure_debug_container()
	var mi := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	sphere.radial_segments = 8
	sphere.rings = 4
	mi.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = mat
	_debug_container.add_child(mi)
	mi.global_position = pos
	_debug_meshes.append(mi)


func _draw_debug_line(start: Vector3, end: Vector3, color: Color) -> void:
	_ensure_debug_container()
	var mi := MeshInstance3D.new()
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	im.surface_add_vertex(start)
	im.surface_add_vertex(end)
	im.surface_end()
	mi.mesh = im
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = mat
	_debug_container.add_child(mi)
	_debug_meshes.append(mi)

#endregion
