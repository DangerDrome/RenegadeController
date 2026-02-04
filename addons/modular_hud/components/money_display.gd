extends Control
## Money display - yellow progress bar that connects to inventory system when available.
## Shows by default with starting value, updates when inventory system is found.

@export var max_money: int = 1000
@export var start_money: int = 50

@onready var progress_bar: ProgressBar = $ProgressBar
@onready var value_label: Label = $ProgressBar/Label

var _amount: int = 50


func _ready() -> void:
	_amount = start_money
	visible = true

	await get_tree().process_frame
	_find_and_connect_inventory()

	_update_display()


func _find_and_connect_inventory() -> void:
	# Look for inventory system by common class names
	var inventory := _find_node_by_script_name(get_tree().root, "Inventory")
	if not inventory:
		inventory = _find_node_by_script_name(get_tree().root, "PlayerInventory")
	if not inventory:
		inventory = _find_node_by_script_name(get_tree().root, "InventoryManager")

	if not inventory:
		return

	# Try to connect to money_changed signal
	if inventory.has_signal("money_changed") and not inventory.money_changed.is_connected(_on_money_changed):
		inventory.money_changed.connect(_on_money_changed)

	# Get initial value if property exists
	if "money" in inventory:
		_amount = inventory.money
	elif "currency" in inventory:
		_amount = inventory.currency

	_update_display()


func _find_node_by_script_name(node: Node, class_name_str: String) -> Node:
	var script := node.get_script() as Script
	if script and script.get_global_name() == class_name_str:
		return node
	for child in node.get_children():
		var result := _find_node_by_script_name(child, class_name_str)
		if result:
			return result
	return null


func _on_money_changed(new_amount: int) -> void:
	_amount = new_amount
	_update_display()


func set_money(amount: int) -> void:
	_amount = amount
	_update_display()


func _update_display() -> void:
	if not is_inside_tree() or not progress_bar:
		return

	progress_bar.max_value = max_money
	progress_bar.value = _amount

	if value_label:
		value_label.text = "$%d" % _amount
