@tool
class_name WorldLabel
extends Node3D
## A 3D position marker that renders crisp 2D text above post-processing effects.
##
## Place this node in your 3D scene where you want text to appear.
## The actual text is rendered as a 2D Label on a CanvasLayer above the dither effect.
## Works with SubViewport setups - handles coordinate scaling automatically.

## The text to display.
@export var text: String = "Label":
	set(value):
		text = value
		_update_label()

## Font size in pixels.
@export_range(8, 128) var font_size: int = 24:
	set(value):
		font_size = value
		_update_label()

## Text color.
@export var color: Color = Color.WHITE:
	set(value):
		color = value
		_update_label()

## Outline color for readability.
@export var outline_color: Color = Color.BLACK:
	set(value):
		outline_color = value
		_update_label()

## Outline thickness in pixels.
@export_range(0, 16) var outline_size: int = 4:
	set(value):
		outline_size = value
		_update_label()

## Vertical offset from the 3D position (in pixels, in output resolution).
@export var pixel_offset: Vector2 = Vector2(0, -20):
	set(value):
		pixel_offset = value

## Maximum distance from camera before label fades out. 0 = no fade.
@export var max_distance: float = 50.0

## Distance at which label starts fading.
@export var fade_start_distance: float = 40.0

## Whether the label is currently visible.
@export var label_visible: bool = true:
	set(value):
		label_visible = value
		if _label_node:
			_label_node.visible = value and _on_screen

var _label_node: Label
var _manager: WorldLabelManager
var _on_screen: bool = true
var _sub_viewport: SubViewport
var _sub_viewport_container: SubViewportContainer


func _ready() -> void:
	if Engine.is_editor_hint():
		return

	# Check if we're inside a SubViewport
	_find_viewport_setup()
	_find_or_create_manager()
	_create_label()


func _exit_tree() -> void:
	if _label_node and is_instance_valid(_label_node):
		_label_node.queue_free()
		_label_node = null


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return

	if not _label_node or not _manager:
		return

	_update_screen_position()


func _find_viewport_setup() -> void:
	# Walk up the tree to find SubViewport and SubViewportContainer
	var node := get_parent()
	while node:
		if node is SubViewport:
			_sub_viewport = node
		elif node is SubViewportContainer:
			_sub_viewport_container = node
			break
		node = node.get_parent()


func _find_or_create_manager() -> void:
	# Look for existing manager in the main scene tree
	_manager = _find_manager(get_tree().root)

	if not _manager:
		# Create one on a CanvasLayer above the 3D scene but below interactive UI
		var canvas_layer := CanvasLayer.new()
		canvas_layer.name = "WorldLabelLayer"
		canvas_layer.layer = 5  # Below GameHUD (layer 10) so UI elements remain interactive
		get_tree().root.call_deferred("add_child", canvas_layer)

		_manager = WorldLabelManager.new()
		_manager.name = "WorldLabelManager"
		canvas_layer.call_deferred("add_child", _manager)


func _find_manager(node: Node) -> WorldLabelManager:
	if node is WorldLabelManager:
		return node
	for child in node.get_children():
		var found := _find_manager(child)
		if found:
			return found
	return null


func _create_label() -> void:
	_label_node = Label.new()
	_label_node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label_node.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label_node.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Wait for manager to be ready
	if not _manager or not is_instance_valid(_manager):
		await get_tree().process_frame
		await get_tree().process_frame
		_find_or_create_manager()

	if _manager and is_instance_valid(_manager):
		_manager.add_child(_label_node)

	_update_label()


func _update_label() -> void:
	if not _label_node:
		return

	_label_node.text = text
	_label_node.add_theme_font_size_override("font_size", font_size)
	_label_node.add_theme_color_override("font_color", color)
	_label_node.add_theme_color_override("font_outline_color", outline_color)
	_label_node.add_theme_constant_override("outline_size", outline_size)


func _update_screen_position() -> void:
	var camera := get_viewport().get_camera_3d()
	if not camera:
		_label_node.visible = false
		return

	# Check if behind camera
	var world_pos := global_position
	var camera_forward := -camera.global_basis.z
	var to_label := world_pos - camera.global_position

	_on_screen = to_label.dot(camera_forward) > 0

	if not _on_screen:
		_label_node.visible = false
		return

	# Calculate distance fade
	var distance := camera.global_position.distance_to(world_pos)
	var alpha := 1.0

	if max_distance > 0 and distance > fade_start_distance:
		alpha = 1.0 - clampf((distance - fade_start_distance) / (max_distance - fade_start_distance), 0.0, 1.0)

	if alpha <= 0:
		_label_node.visible = false
		return

	_label_node.visible = label_visible
	_label_node.modulate.a = alpha

	# Project 3D position to screen (in SubViewport coordinates)
	var screen_pos := camera.unproject_position(world_pos)

	# If inside a SubViewport with a container, scale to output resolution
	if _sub_viewport_container:
		var scale_factor := _sub_viewport_container.stretch_shrink
		screen_pos *= scale_factor

		# Also account for container position if it's not at (0,0)
		screen_pos += _sub_viewport_container.global_position

	# Apply pixel offset and center the label
	_label_node.position = screen_pos + pixel_offset - _label_node.size / 2
