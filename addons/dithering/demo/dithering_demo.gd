extends Node3D
## Demo scene for the Dithering plugin.
##
## Animates primitives so you can observe how dither patterns behave
## with different algorithms and surface-stable projection.

@onready var sphere: MeshInstance3D = $Primitives/Sphere
@onready var cube: MeshInstance3D = $Primitives/Cube
@onready var prism: MeshInstance3D = $Primitives/Prism

var _timer: float = 0.0


func _process(delta: float) -> void:
	_timer += delta

	if sphere:
		sphere.position.y = 2.5 + sin(_timer) * 1.0
	if cube:
		cube.position.y = 2.5 + sin(_timer + PI * 0.5) * 1.0
		cube.rotation.y = _timer
	if prism:
		prism.position.y = 2.5 + sin(_timer + PI) * 1.0
		prism.rotation.z = _timer
