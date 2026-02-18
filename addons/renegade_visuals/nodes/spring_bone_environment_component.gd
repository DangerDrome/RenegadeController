## Displaces a SpringBoneCollisionCapsule3D based on nearby world geometry.
## The capsule uses inside=true so spring bones are constrained within it.
## When the capsule shifts away from walls/objects, bones react naturally —
## the character's upper body leans away from nearby surfaces.
## Previously misnamed "HitReactorComponent" (not related to hit reactions!).
class_name SpringBoneEnvironmentComponent
extends Node

@export_group("Detection")
## How far to detect nearby surfaces.
@export var detection_range: float = 1.2
## Physics layers to detect (default: layers 1+2 = world geometry + characters).
@export_flags_3d_physics var collision_mask: int = 3
## Number of horizontal rays to cast around the character.
@export_range(4, 16) var ray_count: int = 8
## How often to update raycasts (seconds). Capsule smoothing runs every frame.
@export var update_interval: float = 0.03
## Height offset from character origin for raycast origin (chest level).
@export var ray_height: float = 0.9

@export_group("Response")
## Maximum displacement as a fraction of capsule diameter. 0.25 = quarter diameter.
@export_range(0.05, 0.5) var max_displacement_ratio: float = 0.25
## Speed for capsule to react to nearby surfaces (exponential damping).
@export var react_speed: float = 10.0
## Speed for capsule to return to rest when clear (exponential damping).
@export var return_speed: float = 5.0

@export_group("Debug")
## Show debug rays and displacement.
@export var debug_draw: bool = false
## Color for rays that miss.
@export var debug_color_ray_miss: Color = Color.YELLOW
## Color for rays that hit.
@export var debug_color_ray_hit: Color = Color.ORANGE
## Color for hit points on surfaces.
@export var debug_color_hit_point: Color = Color.GREEN
## Color for the displacement target indicator.
@export var debug_color_displacement: Color = Color.RED
## Color for the HitReactor capsule shape.
@export var debug_color_capsule: Color = Color(0.2, 0.6, 1.0, 0.15)

var _visuals: CharacterVisuals
var _skeleton: Skeleton3D
var _capsule: SpringBoneCollisionCapsule3D
var _simulator: SpringBoneSimulator3D

var _rest_transform: Transform3D
var _max_displacement: float = 0.0
var _current_offset: Vector3 = Vector3.ZERO
var _target_offset: Vector3 = Vector3.ZERO

var _update_timer: float = 0.0
var _ray_directions: Array[Vector3] = []

var _debug_container: Node3D
var _debug_meshes: Array[MeshInstance3D] = []
var _debug_capsule_mi: MeshInstance3D


func _ready() -> void:
	_visuals = get_parent() as CharacterVisuals
	if _visuals == null:
		push_error("HitReactorComponent: Parent must be a CharacterVisuals node.")
		return

	_visuals.ready.connect(_setup, CONNECT_ONE_SHOT | CONNECT_DEFERRED)


func _setup() -> void:
	_skeleton = _visuals.skeleton
	if _skeleton == null:
		return

	_find_hit_reactor()

	if _capsule == null:
		push_warning("HitReactorComponent: No SpringBoneCollisionCapsule3D named 'HitReactor' found in spring bone simulators.")
		return

	_rest_transform = _capsule.transform
	_max_displacement = _capsule.radius * 2.0 * max_displacement_ratio

	# Tell the spring bone simulation to use the Skeleton3D as its center.
	# This makes it ignore world movement (walking/running) entirely —
	# only local changes (like our capsule displacement) affect the bones.
	var skel_path: NodePath = _simulator.get_path_to(_skeleton)
	for i in _simulator.setting_count:
		_simulator.set_center_from(i, SpringBoneSimulator3D.CENTER_FROM_NODE)
		_simulator.set_center_node(i, skel_path)

	# Build horizontal ray directions evenly spaced around a circle.
	_ray_directions.clear()
	for i in ray_count:
		var angle := (float(i) / ray_count) * TAU
		_ray_directions.append(Vector3(cos(angle), 0.0, sin(angle)))


func _find_hit_reactor() -> void:
	for child in _skeleton.get_children():
		if child is SpringBoneSimulator3D:
			for grandchild in child.get_children():
				if grandchild is SpringBoneCollisionCapsule3D and grandchild.name == &"HitReactor":
					_capsule = grandchild
					_simulator = child
					return


func _physics_process(delta: float) -> void:
	if _capsule == null:
		return

	# Throttle raycasts but smooth every frame.
	_update_timer += delta
	if _update_timer >= update_interval:
		_update_timer = 0.0
		_update_target_offset()

	# Exponential damping — faster reaction, slower return.
	var speed: float = react_speed if _target_offset.length_squared() > 0.001 else return_speed
	_current_offset = _current_offset.lerp(_target_offset, 1.0 - exp(-speed * delta))

	# Apply: rest global transform + world-space offset.
	var rest_global: Transform3D = _simulator.global_transform * _rest_transform
	_capsule.global_transform = Transform3D(rest_global.basis, rest_global.origin + _current_offset)

	if debug_draw:
		_draw_debug_capsule()


func _update_target_offset() -> void:
	if debug_draw:
		_clear_debug_meshes()

	if _visuals.controller == null:
		_target_offset = Vector3.ZERO
		return

	var space_state := _skeleton.get_world_3d().direct_space_state
	if space_state == null:
		_target_offset = Vector3.ZERO
		return

	# Raycast from the character body's position at chest height.
	var origin: Vector3 = _visuals.controller.global_position + Vector3.UP * ray_height

	# Exclude the character body from raycasts.
	var exclude: Array[RID] = [_visuals.controller.get_rid()]

	var total_push := Vector3.ZERO

	for dir in _ray_directions:
		var ray_end: Vector3 = origin + dir * detection_range

		var query := PhysicsRayQueryParameters3D.create(origin, ray_end)
		query.collision_mask = collision_mask
		query.collide_with_bodies = true
		query.exclude = exclude

		var result := space_state.intersect_ray(query)

		if debug_draw:
			_draw_debug_line(origin, ray_end, debug_color_ray_miss if result.is_empty() else debug_color_ray_hit)

		if result.is_empty():
			continue

		var hit_pos: Vector3 = result["position"]
		var hit_normal: Vector3 = result["normal"]
		var dist: float = origin.distance_to(hit_pos)

		if debug_draw:
			_draw_debug_sphere(hit_pos, 0.04, debug_color_hit_point)

		# Quadratic falloff — subtle at range, strong up close.
		var t: float = 1.0 - (dist / detection_range)
		var strength: float = t * t

		# Push horizontally away from surface.
		var push_dir := Vector3(hit_normal.x, 0.0, hit_normal.z)
		if push_dir.length_squared() < 0.001:
			continue
		total_push += push_dir.normalized() * strength * _max_displacement

	# Clamp total displacement.
	if total_push.length() > _max_displacement:
		total_push = total_push.normalized() * _max_displacement

	_target_offset = total_push

	if debug_draw and total_push.length() > 0.01:
		_draw_debug_sphere(origin + total_push, 0.06, debug_color_displacement)


#region Debug Drawing

func _clear_debug_meshes() -> void:
	for mesh in _debug_meshes:
		if is_instance_valid(mesh):
			mesh.queue_free()
	_debug_meshes.clear()


func _draw_debug_sphere(pos: Vector3, radius: float, color: Color) -> void:
	_ensure_debug_container()
	if _debug_container == null:
		return

	var mi := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	sphere.radial_segments = 8
	sphere.rings = 4
	mi.mesh = sphere

	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = mat

	_debug_container.add_child(mi)
	mi.global_position = pos
	_debug_meshes.append(mi)


func _draw_debug_line(start: Vector3, end: Vector3, color: Color) -> void:
	_ensure_debug_container()
	if _debug_container == null:
		return

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


func _draw_debug_capsule() -> void:
	_ensure_debug_container()
	if _debug_container == null:
		return

	# Create the persistent capsule mesh once; just update its transform after.
	if _debug_capsule_mi == null or not is_instance_valid(_debug_capsule_mi):
		_debug_capsule_mi = MeshInstance3D.new()
		var capsule_mesh := CapsuleMesh.new()
		capsule_mesh.radius = _capsule.radius
		capsule_mesh.height = _capsule.height
		capsule_mesh.radial_segments = 12
		capsule_mesh.rings = 4
		_debug_capsule_mi.mesh = capsule_mesh

		var mat := StandardMaterial3D.new()
		mat.albedo_color = debug_color_capsule
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.no_depth_test = true
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.render_priority = 1
		_debug_capsule_mi.material_override = mat
		_debug_capsule_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

		_debug_container.add_child(_debug_capsule_mi)

	_debug_capsule_mi.global_transform = _capsule.global_transform


func _ensure_debug_container() -> void:
	if _debug_container != null and is_instance_valid(_debug_container):
		return
	_debug_container = Node3D.new()
	_debug_container.name = "HitReactorDebug"
	# Parent at scene root so world-space vertices aren't double-transformed.
	_skeleton.get_tree().current_scene.add_child(_debug_container)

#endregion
