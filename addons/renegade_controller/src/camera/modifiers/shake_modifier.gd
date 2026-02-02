## Trauma-based camera shake using Perlin noise.
## Intensity = trauma^trauma_power. Trauma decays over time.
## Call add_trauma() to trigger shake. Higher trauma = more intense shake.
class_name ShakeModifier extends CameraModifier

## Maximum position offset in each axis.
@export var max_offset: Vector3 = Vector3(0.15, 0.1, 0.05)
## Maximum rotation offset in degrees for each axis.
@export var max_rotation: Vector3 = Vector3(1.5, 1.0, 2.0)
## How fast trauma decays per second.
@export var trauma_decay: float = 1.2
## Power curve for intensity (intensity = trauma^power). Higher = more dramatic.
@export var trauma_power: float = 2.0
## Noise sampling frequency. Higher = faster shake.
@export var noise_frequency: float = 25.0

## Current trauma level (0.0 to 1.0).
var trauma: float = 0.0

var _noise: FastNoiseLite
var _noise_sample: float = 0.0


func _init() -> void:
	_noise = FastNoiseLite.new()
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_noise.frequency = 1.0
	_noise.seed = randi()


## Add trauma to trigger or intensify shake. Automatically enables the modifier.
func add_trauma(amount: float) -> void:
	trauma = clampf(trauma + amount, 0.0, 1.0)
	if trauma > 0.0:
		enable()


func get_position_offset(delta: float) -> Vector3:
	_update_trauma(delta)
	if trauma <= 0.001 or not _noise:
		return Vector3.ZERO

	var intensity := pow(trauma, trauma_power)
	_noise_sample += delta * noise_frequency

	# Sample noise at different offsets for each axis.
	var offset := Vector3(
		_noise.get_noise_1d(_noise_sample) * max_offset.x,
		_noise.get_noise_1d(_noise_sample + 100.0) * max_offset.y,
		_noise.get_noise_1d(_noise_sample + 200.0) * max_offset.z
	)

	return offset * intensity


func get_rotation_offset(_delta: float) -> Vector3:
	# Rotation disabled - handled by CameraRig.
	return Vector3.ZERO


func get_fov_offset(_delta: float) -> float:
	return 0.0


func _update_trauma(delta: float) -> void:
	if trauma > 0.0:
		trauma = maxf(0.0, trauma - trauma_decay * delta)
		if trauma <= 0.0:
			disable()
