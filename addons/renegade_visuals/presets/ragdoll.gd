extends PhysicalBoneSimulator3D

var _active: bool = false

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
		_active = not _active
		if _active:
			print("[Ragdoll] Started")
			physical_bones_start_simulation()
		else:
			print("[Ragdoll] Stopped")
			physical_bones_stop_simulation()
