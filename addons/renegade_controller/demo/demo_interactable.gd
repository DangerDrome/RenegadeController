## Simple interactable for demo scene.
## Works with pre-placed MeshInstance3D children from the editor.
## Highlights on cursor hover, bounces on interact.
extends StaticBody3D

@export var hover_color: Color = Color(1.0, 1.0, 0.2)
@export var interact_color: Color = Color(0.2, 1.0, 0.4)

var _mesh: MeshInstance3D
var _material: StandardMaterial3D
var _base_color: Color
var _original_y: float


func _ready() -> void:
	if not is_in_group("interactable"):
		add_to_group("interactable")
	_original_y = position.y
	# Find first MeshInstance3D child.
	for child in get_children():
		if child is MeshInstance3D:
			_mesh = child
			break
	if _mesh and _mesh.material_override is StandardMaterial3D:
		_material = _mesh.material_override
		_base_color = _material.albedo_color


func on_cursor_enter() -> void:
	if _material:
		_material.albedo_color = hover_color
		_material.emission_enabled = true
		_material.emission = hover_color
		_material.emission_energy_multiplier = 0.3


func on_cursor_exit() -> void:
	if _material:
		_material.albedo_color = _base_color
		_material.emission_enabled = false


func on_interact() -> void:
	if _material:
		_material.albedo_color = interact_color
	var tween := create_tween()
	tween.tween_property(self, "position:y", _original_y + 0.5, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position:y", _original_y, 0.3).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	await get_tree().create_timer(0.5).timeout
	if _material:
		_material.albedo_color = _base_color
