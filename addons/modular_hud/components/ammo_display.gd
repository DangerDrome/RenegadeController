extends Control
## Ammo display component - binds to magazine and reserve HUDData resources.

@export var magazine: HUDData
@export var reserve: HUDData

@onready var mag_label := $HBoxContainer/Magazine
@onready var res_label := $HBoxContainer/Reserve
@onready var anim := $AnimationPlayer


func _ready() -> void:
	if magazine:
		magazine.changed.connect(_update)
	if reserve:
		reserve.changed.connect(_update)
	_update()


func _update() -> void:
	if not is_inside_tree():
		return

	var mag := int(magazine.value) if magazine else 0
	var res := int(reserve.value) if reserve else 0
	mag_label.text = str(mag)
	res_label.text = "/ %d" % res

	# Low ammo flash
	if magazine and magazine.value <= 5:
		if not anim.is_playing() or anim.current_animation != "low_ammo":
			anim.play("low_ammo")
	else:
		if anim.is_playing() and anim.current_animation == "low_ammo":
			anim.stop()
