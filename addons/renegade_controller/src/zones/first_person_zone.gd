## Specialized camera zone that toggles first-person mode.
## When the player enters, camera transitions to first-person.
## When the player exits, camera returns to previous mode.
##
## Unlike other camera zones, FirstPersonZone does NOT use a zone camera.
## First person mode uses the player's head position + mouse look directly.
@tool
class_name FirstPersonZone extends CameraZone

## Hide the player's visual mesh when in first-person.
@export var hide_player_mesh: bool = true

## Path to the mesh node on the player (relative to the CharacterBody3D root).
## Supports common setups like "Mesh", "Model", "Visual".
@export var mesh_node_path: String = "Mesh"

## Duration for mesh fade in/out transitions.
@export var mesh_fade_duration: float = 0.3

var _fade_tween: Tween
var _cached_materials: Array[StandardMaterial3D] = []
var _original_transparency: Array[BaseMaterial3D.Transparency] = []


## Override to skip camera child creation - first person doesn't need zone cameras.
func _auto_discover_children() -> void:
	# Only create collision shape, not camera rig.
	var has_shape := false
	for child in get_children():
		if child is CollisionShape3D:
			has_shape = true
			break

	if not has_shape and Engine.is_editor_hint():
		var scene_root: Node = get_tree().edited_scene_root if get_tree() else null
		var shape := CollisionShape3D.new()
		shape.name = "ZoneShape"
		var box := BoxShape3D.new()
		box.size = Vector3(10, 5, 10)
		shape.shape = box
		shape.position.y = 2.5
		add_child(shape, true)
		shape.owner = scene_root


func _on_body_entered(body: Node3D) -> void:
	if Engine.is_editor_hint():
		return
	if body.is_in_group("player"):
		if hide_player_mesh:
			_set_mesh_visible(body, false)
		zone_entered.emit(self)


func _on_body_exited(body: Node3D) -> void:
	if Engine.is_editor_hint():
		return
	if body.is_in_group("player"):
		if hide_player_mesh:
			_set_mesh_visible(body, true)
		zone_exited.emit(self)


func _set_mesh_visible(body: Node3D, visible: bool) -> void:
	if not body.has_node(mesh_node_path):
		return
	var mesh_node := body.get_node(mesh_node_path)
	if not mesh_node is Node3D:
		return

	# Kill any existing fade tween.
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()

	# Cache materials on first use.
	if _cached_materials.is_empty():
		_cache_materials(mesh_node)

	# Ensure mesh is visible during fade.
	mesh_node.visible = true

	# Tween alpha on all cached materials.
	var target_alpha := 1.0 if visible else 0.0
	_fade_tween = create_tween()
	_fade_tween.set_parallel(true)

	for i in _cached_materials.size():
		var mat := _cached_materials[i]
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_fade_tween.tween_property(mat, "albedo_color:a", target_alpha, mesh_fade_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	if visible:
		# Restore original transparency after fade-in completes.
		_fade_tween.chain().tween_callback(_restore_transparency)
	else:
		# Hide mesh completely when fade out finishes.
		_fade_tween.chain().tween_callback(func(): mesh_node.visible = false)


func _restore_transparency() -> void:
	for i in _cached_materials.size():
		if i < _original_transparency.size():
			_cached_materials[i].transparency = _original_transparency[i]


func _cache_materials(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_inst := node as MeshInstance3D
		# Check material override first, then surface materials.
		if mesh_inst.material_override and mesh_inst.material_override is StandardMaterial3D:
			var mat := mesh_inst.material_override as StandardMaterial3D
			_cached_materials.append(mat)
			_original_transparency.append(mat.transparency)
		else:
			for i in mesh_inst.get_surface_override_material_count():
				var mat := mesh_inst.get_surface_override_material(i)
				if mat and mat is StandardMaterial3D:
					_cached_materials.append(mat)
					_original_transparency.append(mat.transparency)
			# Also check mesh's own materials if no overrides.
			if mesh_inst.mesh:
				for i in mesh_inst.mesh.get_surface_count():
					var mat := mesh_inst.mesh.surface_get_material(i)
					if mat and mat is StandardMaterial3D and mat not in _cached_materials:
						_cached_materials.append(mat)
						_original_transparency.append(mat.transparency)

	for child in node.get_children():
		_cache_materials(child)
