## Tooltip/info panel that displays item details when hovering over inventory slots.
class_name ItemInfoPanel extends PanelContainer

@onready var _name_label: Label = %NameLabel
@onready var _type_label: Label = %TypeLabel
@onready var _description_label: RichTextLabel = %DescriptionLabel
@onready var _stats_label: Label = %StatsLabel


func _ready() -> void:
	visible = false


## Show details for the given item.
func show_item(item: ItemDefinition) -> void:
	if not item:
		hide_panel()
		return

	_name_label.text = item.display_name
	_type_label.text = _get_type_string(item.item_type)
	_description_label.text = item.description

	# Build stats string based on item type.
	_stats_label.text = _build_stats(item)
	_stats_label.visible = _stats_label.text.length() > 0

	visible = true


## Hide the panel.
func hide_panel() -> void:
	visible = false


func _get_type_string(type: ItemDefinition.ItemType) -> String:
	match type:
		ItemDefinition.ItemType.WEAPON:
			return "WEAPON"
		ItemDefinition.ItemType.GEAR:
			return "GEAR"
		ItemDefinition.ItemType.CONSUMABLE:
			return "CONSUMABLE"
		ItemDefinition.ItemType.KEY_ITEM:
			return "KEY ITEM"
	return "ITEM"


func _build_stats(item: ItemDefinition) -> String:
	if item is WeaponDefinition:
		var w := item as WeaponDefinition
		var lines: PackedStringArray = []
		lines.append("Damage: %d" % int(w.damage))
		lines.append("Fire Rate: %.2f" % w.fire_rate)
		lines.append("Magazine: %d" % w.magazine_size)
		lines.append("Range: %.0fm" % w.effective_range)
		return "\n".join(lines)

	if item is GearDefinition:
		var g := item as GearDefinition
		var lines: PackedStringArray = []
		if g.armor_value > 0:
			lines.append("Armor: %d" % int(g.armor_value))
		if g.damage_reduction > 0:
			lines.append("DR: %.0f%%" % (g.damage_reduction * 100))
		if g.speed_modifier != 0:
			lines.append("Speed: %+.0f%%" % (g.speed_modifier * 100))
		return "\n".join(lines)

	if item is ConsumableDefinition:
		var c := item as ConsumableDefinition
		var lines: PackedStringArray = []
		if c.heal_amount > 0:
			lines.append("Heals: %d HP" % c.heal_amount)
		if c.stamina_restore > 0:
			lines.append("Stamina: +%d" % c.stamina_restore)
		if c.effect_duration > 0:
			lines.append("Duration: %.1fs" % c.effect_duration)
		return "\n".join(lines)

	return ""
