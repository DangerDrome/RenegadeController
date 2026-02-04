extends Control
## Interaction prompt component - show/hide via method calls.

@onready var icon := $HBoxContainer/TextureRect
@onready var label := $HBoxContainer/Label
@onready var anim := $AnimationPlayer


func _ready() -> void:
	visible = false


func show_prompt(text: String, input_icon: Texture2D = null) -> void:
	label.text = text
	icon.texture = input_icon
	icon.visible = input_icon != null
	visible = true
	anim.play("fade_in")


func hide_prompt() -> void:
	anim.play("fade_out")
	await anim.animation_finished
	visible = false
