## Radial weapon wheel for quick weapon switching during gameplay.
## Open with a key (e.g. TAB), select by moving mouse, close to confirm.
class_name WeaponWheel extends Control

signal weapon_selected(slot: StringName)

@export_group("References")
@export var equipment_manager: EquipmentManager

@export_group("Appearance")
@export var wheel_radius: float = 120.0
@export var inner_radius: float = 40.0
@export var segment_color: Color = Color(0.2, 0.2, 0.2, 0.85)
@export var hover_color: Color = Color(0.5, 0.45, 0.2, 0.9)
@export var icon_size: float = 40.0

@export_group("Input")
@export var deadzone: float = 30.0

var _segments: Array[StringName] = [&"primary", &"secondary", &"throwable"]
var _selected_index: int = -1
var _is_open: bool = false


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP


## Open the weapon wheel. Pauses movement input (not the tree).
func open() -> void:
	if _is_open:
		return
	_is_open = true
	visible = true
	_selected_index = -1
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	queue_redraw()


## Close the weapon wheel and emit the selection.
func close() -> void:
	if not _is_open:
		return
	_is_open = false
	visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	if _selected_index >= 0 and _selected_index < _segments.size():
		weapon_selected.emit(_segments[_selected_index])


func _input(event: InputEvent) -> void:
	if not _is_open:
		return

	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		var center := size / 2.0
		var offset: Vector2 = motion.position - center
		if offset.length() > deadzone:
			var angle := fmod(offset.angle() + TAU + PI / 2.0, TAU)
			var segment_size := TAU / _segments.size()
			_selected_index = int(angle / segment_size) % _segments.size()
		else:
			_selected_index = -1
		queue_redraw()


func _draw() -> void:
	var center := size / 2.0
	var segment_count := _segments.size()
	var segment_angle := TAU / segment_count

	for i in segment_count:
		var start_a := i * segment_angle - PI / 2.0
		var end_a := start_a + segment_angle
		var color := hover_color if i == _selected_index else segment_color

		# Draw filled segment.
		_draw_ring_segment(center, inner_radius, wheel_radius, start_a, end_a, color)

		# Draw segment border.
		var edge_start := center + Vector2(inner_radius, 0).rotated(start_a)
		var edge_end := center + Vector2(wheel_radius, 0).rotated(start_a)
		draw_line(edge_start, edge_end, Color(0.4, 0.4, 0.4, 0.6), 1.0)

		# Draw item icon at segment midpoint.
		var mid_a := start_a + segment_angle / 2.0
		var icon_pos := center + Vector2((inner_radius + wheel_radius) * 0.5, 0).rotated(mid_a)

		if equipment_manager:
			var item := equipment_manager.get_equipped(_segments[i])
			if item and item.icon:
				var rect := Rect2(icon_pos - Vector2(icon_size, icon_size) / 2.0, Vector2(icon_size, icon_size))
				draw_texture_rect(item.icon, rect, false)
			else:
				# Draw slot label if empty.
				var label := String(_segments[i]).capitalize()
				draw_string(ThemeDB.fallback_font, icon_pos + Vector2(-20, 5), label, HORIZONTAL_ALIGNMENT_CENTER, -1, 11, Color(0.6, 0.6, 0.6))


func _draw_ring_segment(center: Vector2, inner_r: float, outer_r: float,
		start_a: float, end_a: float, color: Color) -> void:
	var points := PackedVector2Array()
	var steps := 20

	# Outer arc.
	for j in steps + 1:
		var a := lerpf(start_a, end_a, float(j) / steps)
		points.append(center + Vector2(outer_r, 0).rotated(a))

	# Inner arc (reversed).
	for j in range(steps, -1, -1):
		var a := lerpf(start_a, end_a, float(j) / steps)
		points.append(center + Vector2(inner_r, 0).rotated(a))

	draw_colored_polygon(points, color)
