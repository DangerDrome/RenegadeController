## Handles weapon instantiation, holstering, drawing, and state.
## Attach as a child of RenegadeCharacter, assign a weapon_holder Node3D.
class_name WeaponManager extends Node3D

## Emitted when weapon switch is complete and weapon is ready to fire. Connect for HUD state updates.
signal weapon_ready
## Emitted when the weapon fires. Connect to trigger muzzle flash, sound, and HUD ammo update.
signal weapon_fired
## Emitted when reload begins. Connect to show reload indicator or play reload animation.
signal reload_started
## Emitted when reload completes. Connect to update HUD ammo counter and hide reload indicator.
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
var _burst_remaining: int = 0
var _trigger_held: bool = false

const BURST_COUNT: int = 3
const BURST_DELAY: float = 0.05


func _process(delta: float) -> void:
	if _fire_cooldown > 0.0:
		_fire_cooldown -= delta

	# Handle full-auto firing while trigger is held
	if _trigger_held and current_weapon and state == State.IDLE:
		if current_weapon.fire_mode == WeaponDefinition.FireMode.FULL_AUTO:
			_try_fire_single()

	# Handle burst fire continuation
	if _burst_remaining > 0 and _fire_cooldown <= 0.0 and state == State.IDLE:
		_fire_burst_shot()


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
## Call this on trigger press. For full-auto, also call set_trigger_held(true).
func fire() -> bool:
	if state != State.IDLE:
		return false
	if current_weapon == null:
		return false

	match current_weapon.fire_mode:
		WeaponDefinition.FireMode.SEMI_AUTO:
			return _try_fire_single()
		WeaponDefinition.FireMode.FULL_AUTO:
			return _try_fire_single()
		WeaponDefinition.FireMode.BURST:
			return _start_burst()

	return false


## Set whether the trigger is being held (for full-auto weapons).
func set_trigger_held(held: bool) -> void:
	_trigger_held = held
	if not held:
		_burst_remaining = 0  # Cancel burst if trigger released


func _try_fire_single() -> bool:
	if _fire_cooldown > 0.0:
		return false
	if ammo_in_magazine <= 0:
		return false

	ammo_in_magazine -= 1
	_fire_cooldown = current_weapon.fire_rate
	weapon_fired.emit()
	return true


func _start_burst() -> bool:
	if _fire_cooldown > 0.0:
		return false
	if ammo_in_magazine <= 0:
		return false
	if _burst_remaining > 0:
		return false  # Already in a burst

	_burst_remaining = BURST_COUNT
	_fire_burst_shot()
	return true


func _fire_burst_shot() -> void:
	if ammo_in_magazine <= 0 or _burst_remaining <= 0:
		_burst_remaining = 0
		return

	ammo_in_magazine -= 1
	_burst_remaining -= 1
	_fire_cooldown = BURST_DELAY
	weapon_fired.emit()

	# Add delay between burst and next burst
	if _burst_remaining <= 0:
		_fire_cooldown = current_weapon.fire_rate


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
