class_name OutlineMaterial
extends RefCounted
## Helper for creating outline-compatible materials.
## 
## Two approaches:
## 1. Use our custom shaders (simple, works standalone)
## 2. Add data pass to existing materials (keeps your nice materials)

const MAIN_LAYER := 1
const OUTLINE_LAYER := 5
const LAYER_MASK := 1 | 16  # Layers 1 + 5


## Create a simple unshaded material for outline rendering
static func simple(albedo: Color = Color.WHITE, texture: Texture2D = null) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://addons/pixel_outline/outline_mesh_unshaded.gdshader")
	mat.set_shader_parameter("albedo_color", albedo)
	if texture:
		mat.set_shader_parameter("albedo_texture", texture)
		mat.set_shader_parameter("use_texture", true)
	# Add data pass for outline detection
	add_data_pass(mat)
	return mat


## Create a toon-shaded material for outline rendering
static func toon(albedo: Color = Color.WHITE, texture: Texture2D = null) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://addons/pixel_outline/outline_mesh_shaded.gdshader")
	mat.set_shader_parameter("albedo_color", albedo)
	if texture:
		mat.set_shader_parameter("albedo_texture", texture)
		mat.set_shader_parameter("use_texture", true)
	# Add data pass for outline detection
	add_data_pass(mat)
	return mat


## Add outline data pass to an existing material (keeps your material's look)
static func add_data_pass(material: Material) -> Material:
	if material.next_pass:
		push_warning("OutlineMaterial: Material already has a next_pass, skipping")
		return material
	
	var data_mat := ShaderMaterial.new()
	data_mat.shader = load("res://addons/pixel_outline/outline_data_pass.gdshader")
	material.next_pass = data_mat
	return material


## Create a StandardMaterial3D with outline data pass already attached
static func standard(albedo: Color = Color.WHITE, texture: Texture2D = null) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = albedo
	if texture:
		mat.albedo_texture = texture
	
	# Add toon shading for pixel art look
	mat.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	mat.specular_mode = BaseMaterial3D.SPECULAR_TOON
	
	# Add data pass
	add_data_pass(mat)
	return mat


## Configure a MeshInstance3D for outline rendering
static func setup_mesh(mesh: MeshInstance3D, albedo: Color = Color.WHITE) -> void:
	# Set layers
	mesh.layers = LAYER_MASK
	
	# Apply material with data pass
	var mat := standard(albedo)
	mesh.material_override = mat


## Configure a MeshInstance3D keeping its existing material
static func setup_mesh_keep_material(mesh: MeshInstance3D) -> void:
	# Set layers
	mesh.layers = LAYER_MASK
	
	# Add data pass to existing materials
	if mesh.material_override:
		add_data_pass(mesh.material_override)
	else:
		var surface_count := mesh.mesh.get_surface_count() if mesh.mesh else 0
		for i in range(surface_count):
			var mat := mesh.get_surface_override_material(i)
			if mat:
				add_data_pass(mat)
			else:
				mat = mesh.mesh.surface_get_material(i)
				if mat:
					# Need to duplicate to add next_pass
					var dup := mat.duplicate()
					add_data_pass(dup)
					mesh.set_surface_override_material(i, dup)
