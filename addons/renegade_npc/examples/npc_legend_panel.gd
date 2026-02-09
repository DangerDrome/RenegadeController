## Legend panel for NPC data graphs showing drive and memory color keys.
extends PanelContainer

@onready var _draw_area: Control = $Margin/VBox/DrawArea


func _ready() -> void:
	_draw_area.draw.connect(_on_draw)


func redraw() -> void:
	if _draw_area:
		_draw_area.queue_redraw()


func _on_draw() -> void:
	var sz: Vector2 = _draw_area.size
	var font: Font = get_theme_font("font", "Label") if has_theme_font("font", "Label") else ThemeDB.fallback_font

	var y: float = 16.0
	var line_h: float = 16.0

	# Drive colors
	_draw_area.draw_string(font, Vector2(4, y), "Drives:", HORIZONTAL_ALIGNMENT_LEFT, -1, 11,
		Color(0.5, 0.5, 0.5))
	y += line_h

	var drive_colors := {
		"idle": Color(0.53, 0.53, 0.53),
		"patrol": Color(0.8, 0.8, 0.0),
		"flee": Color(0.87, 0.2, 0.2),
		"threat": Color(1.0, 0.27, 0.27),
		"socialize": Color(0.27, 0.87, 0.27),
		"work": Color(0.27, 0.87, 0.87),
		"deal": Color(0.87, 0.53, 0.0),
		"guard": Color(0.67, 0.27, 0.87),
	}

	var col_x: float = 10.0
	var items_per_row: int = 0
	for drive_name: String in drive_colors:
		_draw_area.draw_rect(Rect2(col_x, y - 9, 8, 8), drive_colors[drive_name])
		_draw_area.draw_string(font, Vector2(col_x + 11, y),
			drive_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.55, 0.55, 0.55))
		col_x += font.get_string_size(drive_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x + 22
		items_per_row += 1
		if items_per_row >= 4:
			items_per_row = 0
			col_x = 10.0
			y += line_h

	if items_per_row > 0:
		y += line_h

	y += 4.0
	_draw_area.draw_string(font, Vector2(4, y), "Memory:", HORIZONTAL_ALIGNMENT_LEFT, -1, 11,
		Color(0.5, 0.5, 0.5))
	y += line_h

	var mem_colors := {
		"disposition": Color(0.0, 0.83, 1.0),
		"trust": Color(0.27, 0.87, 0.27),
		"temp_fear": Color(0.87, 0.2, 0.2),
		"temp_like": Color(0.87, 0.87, 0.0),
	}
	col_x = 10.0
	for key: String in mem_colors:
		_draw_area.draw_rect(Rect2(col_x, y - 9, 8, 8), mem_colors[key])
		_draw_area.draw_string(font, Vector2(col_x + 11, y),
			key, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.55, 0.55, 0.55))
		col_x += font.get_string_size(key, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x + 22

	y += line_h + 8.0
	_draw_area.draw_string(font, Vector2(4, y), "Sample: 0.25s | Short: 30s | Long: 60s",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.35, 0.35, 0.35))
	y += line_h
	_draw_area.draw_string(font, Vector2(4, y), "Nearest NPC: 2m hysteresis",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.35, 0.35, 0.35))
