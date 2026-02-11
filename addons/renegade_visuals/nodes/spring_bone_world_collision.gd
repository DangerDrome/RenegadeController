## Positions existing SpringBoneCollisionCapsule3D children at nearby world geometry.
## Also supports hit reactions by spawning temporary "pusher" collisions.
class_name SpringBoneWorldCollision
extends Node

@export_group("World Collision")
## Enable world collision detection (walls, floors).
@export var world_collision_enabled: bool = true
## How often to update collision detection (seconds).
@export var update_interval: float = 0.05
## Maximum raycast distance for detecting walls/floors.
@export var raycast_distance: float = 1.0
## Physics layers to detect (default: layer 1 = world geometry).
@export_flags_3d_physics var collision_mask: int = 1
## Offset from collision surface (prevents clipping).
@export var surface_offset: float = 0.05

@export_group("Hit Reactions")
## Enable hit reaction collision pushers.
@export var hit_reaction_enabled: bool = true
## How long hit reaction pushers last (seconds).
@export var hit_pusher_duration: float = 0.15
## Size of hit reaction pusher sphere.
@export var hit_pusher_radius: float = 0.2
## How far the pusher travels through the bone.
@export var hit_pusher_travel: float = 0.5
## Easing for pusher movement (0.5 = linear, <0.5 = ease out, >0.5 = ease in).
@export_range(0.1, 2.0) var hit_pusher_easing: float = 0.3

@export_group("Debug")
## Show debug visualization of raycasts.
@export var debug_draw: bool = false:
	set(value):
		debug_draw = value
		if not value:
			_clear_debug_meshes()
			if _debug_container and is_instance_valid(_debug_container):
				_debug_container.queue_free()
				_debug_container = null
		elif is_inside_tree() and _debug_container == null:
			_debug_container = Node3D.new()
			_debug_container.name = "DebugDraw"
			_skeleton.get_parent().add_child(_debug_container)

var _skeleton: Skeleton3D
var _simulators: Array[SpringBoneSimulator3D] = []
var _capsule_colliders: Dictionary = {}  # simulator -> SpringBoneCollisionCapsule3D
var _hit_pushers: Array[Dictionary] = []  # {node, timer, simulator}
var _update_timer: float = 0.0
var _reference_bones: Dictionary = {}  # simulator -> bone index for raycasting origin
var _debug_meshes: Array[MeshInstance3D] = []
var _debug_container: Node3D

# Direction vectors for raycasting
const RAYCAST_DIRS: Array[Vector3] = [
	Vector3.FORWARD,
	Vector3.BACK,
	Vector3.LEFT,
	Vector3.RIGHT,
]


func _ready() -> void:
	# Find skeleton (should be parent)
	var parent := get_parent()
	if parent is Skeleton3D:
		_skeleton = parent
	else:
		push_error("SpringBoneWorldCollision must be a child of Skeleton3D")
		return

	# Find all SpringBoneSimulator3D siblings and their capsule colliders
	for sibling in _skeleton.get_children():
		if sibling is SpringBoneSimulator3D:
			_simulators.append(sibling)
			_find_capsule_collider(sibling)
			_cache_reference_bone(sibling)

	if _simulators.is_empty():
		push_warning("SpringBoneWorldCollision: No SpringBoneSimulator3D found")
		return

	print("[SpringBoneWorldCollision] Found %d spring bone simulators" % _simulators.size())

	# Connect to CharacterVisuals hit signal if available
	if hit_reaction_enabled:
		var char_visuals := _find_character_visuals()
		if char_visuals:
			char_visuals.hit_received.connect(_on_hit_received)
			print("[SpringBoneWorldCollision] Connected to hit_received signal")


func _find_capsule_collider(simulator: SpringBoneSimulator3D) -> void:
	# Look for SpringBoneCollisionCapsule3D child
	for child in simulator.get_children():
		if child is SpringBoneCollisionCapsule3D:
			_capsule_colliders[simulator] = child
			# Start hidden/far away
			child.position = Vector3(0, -100, 0)
			print("[SpringBoneWorldCollision] Found capsule collider for %s" % simulator.name)
			return
	print("[SpringBoneWorldCollision] No capsule collider found for %s" % simulator.name)


func _cache_reference_bone(simulator: SpringBoneSimulator3D) -> void:
	# Get the root bone of the first setting as reference point
	if simulator.setting_count > 0:
		var root_bone: int = simulator.get_root_bone(0)
		_reference_bones[simulator] = root_bone
	else:
		_reference_bones[simulator] = -1


func _physics_process(delta: float) -> void:
	# Clear old debug meshes
	if debug_draw:
		_clear_debug_meshes()

	# Update hit pushers
	_update_hit_pushers(delta)

	if not world_collision_enabled:
		return

	# Throttle world collision updates
	_update_timer += delta
	if _update_timer < update_interval:
		return
	_update_timer = 0.0

	# Update capsule positions for each simulator
	for simulator in _simulators:
		_update_capsule_position(simulator)


func _update_capsule_position(simulator: SpringBoneSimulator3D) -> void:
	var capsule: SpringBoneCollisionCapsule3D = _capsule_colliders.get(simulator)
	if capsule == null:
		return

	var space_state := _skeleton.get_world_3d().direct_space_state
	if space_state == null:
		return

	# Get reference bone position for raycasting
	var ref_bone_idx: int = _reference_bones.get(simulator, -1)
	if ref_bone_idx < 0:
		return

	var bone_global := _skeleton.global_transform * _skeleton.get_bone_global_pose(ref_bone_idx)
	var bone_pos: Vector3 = bone_global.origin

	# Debug: draw bone origin
	if debug_draw:
		_draw_debug_sphere(bone_pos, 0.03, Color.CYAN)

	# Find nearest wall collision
	var nearest_hit: Dictionary = {}
	var nearest_dist: float = INF

	for dir in RAYCAST_DIRS:
		var world_dir: Vector3 = _skeleton.global_transform.basis * dir
		var ray_end: Vector3 = bone_pos + world_dir * raycast_distance

		var query := PhysicsRayQueryParameters3D.create(bone_pos, ray_end)
		query.collision_mask = collision_mask

		var result := space_state.intersect_ray(query)
		var has_hit: bool = not result.is_empty()

		# Debug: draw raycast
		if debug_draw:
			_draw_debug_line(bone_pos, ray_end, Color.ORANGE if has_hit else Color.YELLOW)
			if has_hit:
				_draw_debug_sphere(result["position"], 0.05, Color.GREEN)

		if has_hit:
			var dist: float = bone_pos.distance_to(result["position"])
			if dist < nearest_dist:
				nearest_dist = dist
				nearest_hit = result

	# Position capsule at nearest collision or hide it
	if not nearest_hit.is_empty():
		var hit_pos: Vector3 = nearest_hit["position"]
		var hit_normal: Vector3 = nearest_hit["normal"]

		# Position capsule at surface with offset
		var capsule_pos: Vector3 = hit_pos + hit_normal * (capsule.radius + surface_offset)
		capsule.global_position = capsule_pos

		# Debug: draw capsule position
		if debug_draw:
			_draw_debug_sphere(capsule_pos, capsule.radius, Color(1, 0, 0, 0.3))
	else:
		# No collision - move capsule far away
		capsule.position = Vector3(0, -100, 0)


func _on_hit_received(bone_name: StringName, direction: Vector3, force: float) -> void:
	if not hit_reaction_enabled:
		return

	# Find the bone position
	var bone_idx: int = _skeleton.find_bone(String(bone_name))
	if bone_idx == -1:
		# Try common fallbacks
		bone_idx = _skeleton.find_bone("spine_03")
	if bone_idx == -1:
		return

	var bone_global := _skeleton.global_transform * _skeleton.get_bone_global_pose(bone_idx)
	var bone_pos: Vector3 = bone_global.origin

	# Spawn a pusher sphere that moves through the bone
	# This pushes spring bones in the hit direction
	var pusher_start: Vector3 = bone_pos - direction.normalized() * hit_pusher_radius * 2

	# Add pusher to all relevant simulators
	for simulator in _simulators:
		var sphere := SpringBoneCollisionSphere3D.new()
		sphere.radius = hit_pusher_radius
		simulator.add_child(sphere)
		sphere.global_position = pusher_start

		_hit_pushers.append({
			"node": sphere,
			"timer": hit_pusher_duration,
			"start_pos": pusher_start,
			"end_pos": bone_pos + direction.normalized() * hit_pusher_travel,
			"duration": hit_pusher_duration,
		})

	if debug_draw:
		print("[SpringBoneWorldCollision] Hit pusher at bone: ", bone_name)


func _update_hit_pushers(delta: float) -> void:
	var to_remove: Array[int] = []

	for i in range(_hit_pushers.size()):
		var pusher: Dictionary = _hit_pushers[i]
		pusher.timer -= delta

		if pusher.timer <= 0:
			to_remove.append(i)
			if is_instance_valid(pusher.node):
				pusher.node.queue_free()
		else:
			# Move pusher along path
			var t: float = 1.0 - (pusher.timer / pusher.duration)
			t = ease(t, hit_pusher_easing)
			if is_instance_valid(pusher.node):
				var pos: Vector3 = pusher.start_pos.lerp(pusher.end_pos, t)
				pusher.node.global_position = pos

	# Remove expired pushers (reverse order)
	for i in range(to_remove.size() - 1, -1, -1):
		_hit_pushers.remove_at(to_remove[i])


## Find CharacterVisuals ancestor.
func _find_character_visuals() -> CharacterVisuals:
	var node := get_parent()
	while node:
		if node is CharacterVisuals:
			return node
		node = node.get_parent()
	return null


## Manually trigger a hit reaction (for testing or external use).
func apply_hit(direction: Vector3, force: float, bone_name: String = "spine_03") -> void:
	_on_hit_received(StringName(bone_name), direction, force)


#region Debug Drawing

func _clear_debug_meshes() -> void:
	for mesh in _debug_meshes:
		if is_instance_valid(mesh):
			mesh.queue_free()
	_debug_meshes.clear()


func _draw_debug_sphere(pos: Vector3, radius: float, color: Color) -> void:
	if _debug_container == null or not _debug_container.is_inside_tree():
		return

	var mesh_instance := MeshInstance3D.new()
	var sphere_mesh := SphereMesh.new()
	sphere_mesh.radius = radius
	sphere_mesh.height = radius * 2
	sphere_mesh.radial_segments = 8
	sphere_mesh.rings = 4
	mesh_instance.mesh = sphere_mesh

	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh_instance.material_override = mat

	_debug_container.add_child(mesh_instance)
	mesh_instance.global_position = pos
	_debug_meshes.append(mesh_instance)


func _draw_debug_line(start: Vector3, end: Vector3, color: Color) -> void:
	if _debug_container == null or not _debug_container.is_inside_tree():
		return

	var mesh_instance := MeshInstance3D.new()
	var immediate_mesh := ImmediateMesh.new()

	immediate_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	immediate_mesh.surface_add_vertex(start)
	immediate_mesh.surface_add_vertex(end)
	immediate_mesh.surface_end()

	mesh_instance.mesh = immediate_mesh

	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh_instance.material_override = mat

	_debug_container.add_child(mesh_instance)
	_debug_meshes.append(mesh_instance)

#endregion
