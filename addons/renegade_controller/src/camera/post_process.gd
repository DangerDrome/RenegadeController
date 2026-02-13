## Exposes postprocess shader uniforms to the inspector.
## Attach to the PostProcess MeshInstance3D inside CameraRig.
@tool
class_name PostProcess
extends MeshInstance3D

@export var enabled: bool = true:
	set(v):
		enabled = v
		visible = v

@export_group("Edge Detection")
@export_range(0.0, 1.0, 0.001) var depth_threshold: float = 0.05:
	set(v):
		depth_threshold = v
		_set_param(&"depth_threshold", v)

@export_range(0.0, 1.0, 0.001) var reverse_depth_threshold: float = 0.25:
	set(v):
		reverse_depth_threshold = v
		_set_param(&"reverse_depth_threshold", v)

@export_range(0.0, 1.0, 0.01) var normal_threshold: float = 0.6:
	set(v):
		normal_threshold = v
		_set_param(&"normal_threshold", v)

@export_group("Shading")
@export_range(0.0, 1.0, 0.01) var darken_amount: float = 0.3:
	set(v):
		darken_amount = v
		_set_param(&"darken_amount", v)

@export_range(0.0, 10.0, 0.01) var lighten_amount: float = 1.5:
	set(v):
		lighten_amount = v
		_set_param(&"lighten_amount", v)

@export_group("Lighting")
@export var normal_edge_bias: Vector3 = Vector3(1, 1, 1):
	set(v):
		normal_edge_bias = v
		_set_param(&"normal_edge_bias", v)

@export var light_direction: Vector3 = Vector3(-0.96, -0.18, 0.2):
	set(v):
		light_direction = v
		_set_param(&"light_direction", v)


func _ready() -> void:
	_push_all_params()


func _push_all_params() -> void:
	_set_param(&"depth_threshold", depth_threshold)
	_set_param(&"reverse_depth_threshold", reverse_depth_threshold)
	_set_param(&"normal_threshold", normal_threshold)
	_set_param(&"darken_amount", darken_amount)
	_set_param(&"lighten_amount", lighten_amount)
	_set_param(&"normal_edge_bias", normal_edge_bias)
	_set_param(&"light_direction", light_direction)


func _set_param(param: StringName, value: Variant) -> void:
	var mat := material_override as ShaderMaterial
	if mat == null and mesh:
		mat = mesh.surface_get_material(0) as ShaderMaterial
	if mat:
		mat.set_shader_parameter(param, value)
