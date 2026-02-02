## Handles weapon instantiation, holstering, drawing, and state.
## Attach as a child of RenegadeCharacter, assign a weapon_holder Node3D.
class_name WeaponManager extends Node3D

signal weapon_ready
signal weapon_fired
signal reload_started
signal reload_finished

enum State { IDLE, SWITCHING, FIRING, RELOADING }

@export_group("References")
@export var weapon_holder: Node3D

@export_group("Timing")
@export var holster_time: float = 0.3
@export var draw_time: float = 0.4

var current_weapon: WeaponDefinition
var current_weapon_instance: Node3D
var state: State = State.IDLE
var ammo_in_magazine: int = 0

var _fire_cooldown: float = 0.0


func _process(delta: float) -> void:
	if _fire_cooldown > 0.0:
		_fire_cooldown -= delta


## Set the active weapon. Holsters current, spawns new.
func set_weapon(weapon: WeaponDefinition) -> void:
	if state != State.IDLE:
		return

	state = State.SWITCHING

	# Holster current weapon.
	if current_weapon_instance:
		await _holster()

	_clear_instance()

	if weapon:
		current_weapon = weapon
		ammo_in_magazine = weapon.magazine_size
		_spawn_instance()
		await _draw()
	else:
		current_weapon = null

	state = State.IDLE
	weapon_ready.emit()


## Fire the current weapon. Returns true if fired.
func fire() -> bool:
	if state != State.IDLE:
		return false
	if current_weapon == null:
		return false
	if _fire_cooldown > 0.0:
		return false
	if ammo_in_magazine <= 0:
		return false

	ammo_in_magazine -= 1
	_fire_cooldown = current_weapon.fire_rate
	weapon_fired.emit()
	return true


## Start a reload. Async — waits for reload_time.
func reload() -> void:
	if state != State.IDLE:
		return
	if current_weapon == null:
		return
	if ammo_in_magazine >= current_weapon.magazine_size:
		return

	state = State.RELOADING
	reload_started.emit()
	await get_tree().create_timer(current_weapon.reload_time).timeout
	ammo_in_magazine = current_weapon.magazine_size
	state = State.IDLE
	reload_finished.emit()


## Remove the current weapon entirely.
func clear_weapon() -> void:
	_clear_instance()
	current_weapon = null
	ammo_in_magazine = 0


func _spawn_instance() -> void:
	if not weapon_holder:
		return
	if current_weapon and current_weapon.weapon_scene:
		current_weapon_instance = current_weapon.weapon_scene.instantiate()
		weapon_holder.add_child(current_weapon_instance)


func _clear_instance() -> void:
	if current_weapon_instance and is_instance_valid(current_weapon_instance):
		current_weapon_instance.queue_free()
		current_weapon_instance = null


func _holster() -> void:
	# TODO: Trigger holster animation when AnimationTree is wired.
	await get_tree().create_timer(holster_time).timeout


func _draw() -> void:
	# TODO: Trigger draw animation when AnimationTree is wired.
	await get_tree().create_timer(draw_time).timeout
