## GameClock: Manages in-game time and emits signals for NPC scheduling.
## Autoloaded by the plugin.
extends Node

## Emitted every in-game hour.
signal hour_changed(hour: int)
## Emitted every in-game day.
signal day_changed(day: int)
## Emitted every game cycle (configurable interval for memory decay, etc.)
signal cycle_tick()

## --- Configuration ---
## How many real seconds per in-game hour.
@export var seconds_per_hour: float = 60.0
## Starting hour (0-23).
@export var start_hour: int = 8
## Starting day.
@export var start_day: int = 1

## --- State ---
var current_hour: int = 8
var current_day: int = 1
var _accumulator: float = 0.0
var _total_hours: float = 0.0
var _paused: bool = false

## How many hours between cycle ticks (memory decay, abstract migration, etc.)
var cycle_interval_hours: int = 6
var _hours_since_cycle: int = 0


func _ready() -> void:
	current_hour = start_hour
	current_day = start_day
	_total_hours = float(start_day * 24 + start_hour)


func _process(delta: float) -> void:
	if _paused:
		return
	
	_accumulator += delta
	
	if _accumulator >= seconds_per_hour:
		_accumulator -= seconds_per_hour
		_advance_hour()


func _advance_hour() -> void:
	current_hour += 1
	_total_hours += 1.0
	_hours_since_cycle += 1
	
	if current_hour >= 24:
		current_hour = 0
		current_day += 1
		day_changed.emit(current_day)
	
	hour_changed.emit(current_hour)
	
	if _hours_since_cycle >= cycle_interval_hours:
		_hours_since_cycle = 0
		cycle_tick.emit()


## Get total elapsed hours since game start.
func get_total_hours() -> float:
	return _total_hours + (_accumulator / seconds_per_hour)


## Get normalized time of day (0.0 = midnight, 0.5 = noon, 1.0 = midnight).
func get_time_normalized() -> float:
	return (float(current_hour) + _accumulator / seconds_per_hour) / 24.0


## Is it currently nighttime? (Between 21:00 and 05:00)
func is_night() -> bool:
	return current_hour >= 21 or current_hour < 5


## Is it currently daytime? (Between 06:00 and 20:00)
func is_day() -> bool:
	return current_hour >= 6 and current_hour < 20


func pause_clock() -> void:
	_paused = true


func resume_clock() -> void:
	_paused = false


func set_time(hour: int, day: int = -1) -> void:
	current_hour = clampi(hour, 0, 23)
	if day >= 0:
		current_day = day
	_total_hours = float(current_day * 24 + current_hour)
	hour_changed.emit(current_hour)


func get_time_string() -> String:
	return "%02d:00 Day %d" % [current_hour, current_day]
