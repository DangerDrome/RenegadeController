## Floating tooltip panel that shows stat comparison between a hovered item
## and the currently equipped item. Displays green/red deltas.
## CassettePunk style: monospace amber text on dark background.
class_name StatComparisonPanel
extends PanelContainer

@export_group("Display")
## Stats to compare, in display order. Must match property names on item Resources.
@export var stat_names: Array[StringName] = [
	&"damage", &"fire_rate", &"magazine_size", &"reload_time",
	&"effective_range", &"damage_reduction",
]
## Human-readable labels for each stat. Must match stat_names order.
@export var stat_labels: Array[String] = [
	"DAMAGE", "FIRE RATE", "MAG SIZE", "RELOAD",
	"RANGE", "ARMOR",
]
## Stats where lower is better (e.g., reload time).
@export var lower_is_better: Array[StringName] = [&"reload_time"]

@onready var _item_name_label: Label = %ItemNameLabel
@onready var _stats_container: VBoxContainer = %StatsContainer

## Delay before showing the panel (prevents flicker during fast scanning).
var _show_timer := 0.0
const SHOW_DELAY := 0.15
var _pending_show := false
var _incoming: Resource
var _current: Resource


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	if _pending_show:
		_show_timer += delta
		if _show_timer >= SHOW_DELAY:
			_pending_show = false
			_display_comparison(_incoming, _current)
			visible = true

	# Follow mouse position with offset.
	if visible:
		var mouse_pos := get_viewport().get_mouse_position()
		global_position = mouse_pos + Vector2(16, 16)
		# Keep on screen.
		var screen_size := get_viewport_rect().size
		if global_position.x + size.x > screen_size.x:
			global_position.x = mouse_pos.x - size.x - 16
		if global_position.y + size.y > screen_size.y:
			global_position.y = mouse_pos.y - size.y - 16


## Show comparison between incoming item and currently equipped item.
func show_comparison(incoming: Resource, current: Resource) -> void:
	_incoming = incoming
	_current = current
	_show_timer = 0.0
	_pending_show = true


## Hide the panel.
func hide_comparison() -> void:
	_pending_show = false
	visible = false
	_incoming = null
	_current = null


func _display_comparison(incoming: Resource, current: Resource) -> void:
	# Clear previous stats.
	for child in _stats_container.get_children():
		child.queue_free()

	# Item name.
	if _item_name_label and incoming:
		_item_name_label.text = incoming.get("display_name") if incoming.has("display_name") else "Unknown Item"
		# Rarity color on name.
		var rarity_colors := {
			0: Color("#D4C5A9"),
			1: Color("#2EC4B6"),
			2: Color("#FF3366"),
			3: Color("#C0C0C0"),
			4: Color("#FFD700"),
		}
		var rarity: int = incoming.get("rarity") if incoming.has("rarity") else 0
		var rarity_color: Color = rarity_colors.get(rarity) if rarity_colors.has(rarity) else Color("#D4C5A9")
		_item_name_label.add_theme_color_override("font_color", rarity_color)

	# Build stat rows.
	for i in range(stat_names.size()):
		var stat_name: StringName = stat_names[i]
		var label_text: String = stat_labels[i] if i < stat_labels.size() else str(stat_name)

		var incoming_val: float = incoming.get(stat_name) if incoming and incoming.has(stat_name) else 0.0
		var current_val: float = current.get(stat_name) if current and current.has(stat_name) else 0.0

		# Skip stats that are 0 on both items.
		if incoming_val == 0.0 and current_val == 0.0:
			continue

		var delta := incoming_val - current_val
		var row := _create_stat_row(label_text, incoming_val, delta, stat_name in lower_is_better)
		_stats_container.add_child(row)


func _create_stat_row(
	label_text: String,
	value: float,
	delta: float,
	invert: bool
) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	# Stat label — amber monospace.
	var name_label := Label.new()
	name_label.text = label_text
	name_label.add_theme_color_override("font_color", Color("#FFB347"))
	name_label.custom_minimum_size.x = 100
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.add_child(name_label)

	# Value.
	var value_label := Label.new()
	var display_val := "%0.1f" % value if fmod(value, 1.0) != 0.0 else str(int(value))
	value_label.text = display_val
	value_label.add_theme_color_override("font_color", Color("#E0D6C0"))
	value_label.custom_minimum_size.x = 50
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value_label)

	# Delta indicator.
	if absf(delta) > 0.001:
		var delta_label := Label.new()
		var is_better: bool = (delta < 0.0) if invert else (delta > 0.0)
		var is_worse: bool = (delta > 0.0) if invert else (delta < 0.0)
		var arrow := "▲" if delta > 0.0 else "▼"
		var delta_display := "%0.1f" % absf(delta) if fmod(absf(delta), 1.0) != 0.0 else str(int(absf(delta)))
		delta_label.text = " %s%s" % [arrow, delta_display]

		if is_better:
			delta_label.add_theme_color_override("font_color", Color("#2EC4B6"))  # Teal — good.
		elif is_worse:
			delta_label.add_theme_color_override("font_color", Color("#FF3366"))  # Hot pink — bad.
		else:
			delta_label.add_theme_color_override("font_color", Color("#888888"))

		row.add_child(delta_label)

	return row
