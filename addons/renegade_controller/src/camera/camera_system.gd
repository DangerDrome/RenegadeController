## Root node for the camera system.
## Exposes camera markers and modifiers at the top level for easy editing when instanced.
## The camera markers work like zone cameras - position them in the editor and the
## camera will go to that position and look at the player.
class_name CameraSystem extends Node3D

@export_group("Default Cameras")
## Marker defining the default third-person camera position.
## Move this in the editor to adjust where the camera sits relative to the player.
## The camera will be at this position and look at the player.
@export var third_person_camera: Marker3D
## Marker defining the first-person camera position (head offset from player origin).
@export var first_person_camera: Marker3D

@export_group("Camera Modifiers")
## Shake modifier for camera trauma/impact effects.
@export var shake_modifier: ShakeModifier:
	set(value):
		shake_modifier = value
		_update_stack_modifiers()
## Zoom modifier for FOV pulse effects.
@export var zoom_modifier: ZoomModifier:
	set(value):
		zoom_modifier = value
		_update_stack_modifiers()
## Framing modifier for position offset effects.
@export var framing_modifier: FramingModifier:
	set(value):
		framing_modifier = value
		_update_stack_modifiers()

var _modifier_stack: CameraModifierStack
var _camera_rig: CameraRig


func _ready() -> void:
	# Always resolve via get_node to handle NodePath exports correctly.
	# The @export may store a NodePath string that needs resolution.
	var tp_cam := get_node_or_null("ThirdPersonCamera")
	var fp_cam := get_node_or_null("FirstPersonCamera")
	if tp_cam:
		third_person_camera = tp_cam
	if fp_cam:
		first_person_camera = fp_cam

	# Find the camera rig and modifier stack.
	_camera_rig = get_node_or_null("CameraRig") as CameraRig
	if _camera_rig:
		if _camera_rig.modifier_stack:
			_modifier_stack = _camera_rig.modifier_stack
			_update_stack_modifiers()
		# Pass camera markers to rig.
		_camera_rig.default_camera_marker = third_person_camera
		_camera_rig.first_person_marker = first_person_camera
		# Apply the default marker after the scene is fully ready (target may not be set yet).
		if third_person_camera:
			call_deferred("_apply_default_camera")


func _apply_default_camera() -> void:
	if not _camera_rig:
		return
	# Re-read the marker position at runtime to catch any scene overrides.
	var marker := get_node_or_null("ThirdPersonCamera")
	if marker:
		_camera_rig.default_camera_marker = marker
		_camera_rig.apply_default_marker()


func _update_stack_modifiers() -> void:
	if not _modifier_stack:
		return
	_modifier_stack.shake_modifier = shake_modifier
	_modifier_stack.zoom_modifier = zoom_modifier
	_modifier_stack.framing_modifier = framing_modifier
