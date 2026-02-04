class_name WorldLabelManager
extends Control
## Manager node for WorldLabel instances. Automatically created if needed.
##
## This node serves as the parent for all 2D labels created by WorldLabel nodes.
## It should be placed on a CanvasLayer above post-processing effects.

func _ready() -> void:
	# Fill the screen so labels can be positioned anywhere
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
