## Manages a stack of camera modifiers and applies their combined offsets.
## Sits between SpringArm3D and Camera3D in the hierarchy.
## Modifiers are processed in priority order (lower priority values first).
class_name CameraModifierStack extends Node3D

## Reference to the camera. Set by CameraRig after hierarchy is built.
@export var camera: Camera3D
## Global scale for shake effects (accessibility option).
@export_range(0.0, 1.0) var shake_intensity_scale: float = 1.0

@export_group("Modifiers")
## Shake modifier for camera trauma/impact effects.
@export var shake_modifier: ShakeModifier:
	set(value):
		if shake_modifier and shake_modifier in modifiers:
			remove_modifier_immediate(shake_modifier)
		shake_modifier = value
		if shake_modifier and is_inside_tree():
			add_modifier(shake_modifier)
## Zoom modifier for FOV pulse effects.
@export var zoom_modifier: ZoomModifier:
	set(value):
		if zoom_modifier and zoom_modifier in modifiers:
			remove_modifier_immediate(zoom_modifier)
		zoom_modifier = value
		if zoom_modifier and is_inside_tree():
			add_modifier(zoom_modifier)
## Framing modifier for position offset effects.
@export var framing_modifier: FramingModifier:
	set(value):
		if framing_modifier and framing_modifier in modifiers:
			remove_modifier_immediate(framing_modifier)
		framing_modifier = value
		if framing_modifier and is_inside_tree():
			add_modifier(framing_modifier)

var modifiers: Array[CameraModifier] = []
var _base_fov: float = 70.0
var _fov_offset_active: bool = false


func _ready() -> void:
	# Add exported modifiers that were set before entering tree.
	if shake_modifier:
		add_modifier(shake_modifier)
	if zoom_modifier:
		add_modifier(zoom_modifier)
	if framing_modifier:
		add_modifier(framing_modifier)


func _process(delta: float) -> void:
	if modifiers.is_empty():
		return

	var position_offset := Vector3.ZERO
	var rotation_offset := Vector3.ZERO
	var fov_offset := 0.0

	# Process modifiers in priority order (array is kept sorted).
	var i := 0
	while i < modifiers.size():
		var mod := modifiers[i]
		mod.update_alpha(delta)

		# Remove finished modifiers.
		if mod.is_finished():
			modifiers.remove_at(i)
			continue

		# Accumulate offsets (scaled by both influence and alpha).
		var weight := mod.influence * mod.alpha
		position_offset += mod.get_position_offset(delta) * weight
		rotation_offset += mod.get_rotation_offset(delta) * weight
		fov_offset += mod.get_fov_offset(delta) * weight

		# Exclusive modifier blocks others when active.
		if mod.exclusive and mod.alpha > 0.5:
			i += 1
			break

		i += 1

	# Apply combined offsets to this node's transform.
	# Note: Only applying position offset. Rotation is disabled to avoid
	# conflicts with CameraRig's look_at handling.
	position = position_offset * shake_intensity_scale

	# Apply FOV offset to camera.
	if camera:
		if absf(fov_offset) > 0.01:
			# Starting FOV effect - capture current FOV as base.
			if not _fov_offset_active:
				_base_fov = camera.fov
				_fov_offset_active = true
			camera.fov = _base_fov + fov_offset
		else:
			# FOV effect ended - let CameraRig control FOV again.
			_fov_offset_active = false


## Add a modifier to the stack. Automatically sorted by priority.
func add_modifier(modifier: CameraModifier) -> void:
	if modifier in modifiers:
		return
	modifiers.append(modifier)
	_sort_by_priority()


## Remove a modifier by disabling it (lets it fade out naturally).
func remove_modifier(modifier: CameraModifier) -> void:
	if modifier in modifiers:
		modifier.disable()


## Remove a modifier immediately without fade out.
func remove_modifier_immediate(modifier: CameraModifier) -> void:
	var idx := modifiers.find(modifier)
	if idx >= 0:
		modifiers.remove_at(idx)


## Find the first modifier of a specific type.
func get_modifier(type: Script) -> CameraModifier:
	for mod in modifiers:
		if mod.get_script() == type:
			return mod
	return null


## Convenience helper to get the ShakeModifier.
func get_shake() -> ShakeModifier:
	return get_modifier(ShakeModifier) as ShakeModifier


## Get current total position offset (for debug display).
func get_current_position_offset() -> Vector3:
	return position


## Get current total rotation offset (for debug display).
func get_current_rotation_offset() -> Vector3:
	return rotation_degrees


## Get current FOV offset (for debug display).
func get_current_fov_offset() -> float:
	if camera and _fov_offset_active:
		return camera.fov - _base_fov
	return 0.0


func _sort_by_priority() -> void:
	modifiers.sort_custom(func(a: CameraModifier, b: CameraModifier) -> bool:
		return a.priority < b.priority
	)
