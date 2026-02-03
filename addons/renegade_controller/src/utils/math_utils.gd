## Static math utility functions for common operations.
## All methods use frame-rate independent exponential damping.
class_name MathUtils extends RefCounted


## Frame-rate independent exponential damping for floats.
## Smoothly interpolates from 'from' toward 'to' at the given speed.
## Uses exponential decay: lerp(a, b, 1.0 - exp(-speed * delta))
static func damp(from: float, to: float, speed: float, delta: float) -> float:
	return lerpf(from, to, 1.0 - exp(-speed * delta))


## Frame-rate independent exponential damping for Vector2.
static func damp_v2(from: Vector2, to: Vector2, speed: float, delta: float) -> Vector2:
	return from.lerp(to, 1.0 - exp(-speed * delta))


## Frame-rate independent exponential damping for Vector3.
static func damp_v3(from: Vector3, to: Vector3, speed: float, delta: float) -> Vector3:
	return from.lerp(to, 1.0 - exp(-speed * delta))


## Frame-rate independent exponential damping for angles (handles wraparound).
static func damp_angle(from: float, to: float, speed: float, delta: float) -> float:
	return lerp_angle(from, to, 1.0 - exp(-speed * delta))


## Frame-rate independent exponential damping for Basis (rotation).
static func damp_basis(from: Basis, to: Basis, speed: float, delta: float) -> Basis:
	return from.slerp(to, 1.0 - exp(-speed * delta))


## Ease-in-out S-curve function for 0-1 progress values.
## Returns a smooth S-curve: slow start, fast middle, slow end.
## Named to avoid collision with Godot's built-in smoothstep(from, to, x).
static func ease_smooth(t: float) -> float:
	return t * t * (3.0 - 2.0 * t)


## Clamp a value with optional smoothing at the boundaries.
static func soft_clamp(value: float, min_val: float, max_val: float, softness: float = 0.1) -> float:
	if value < min_val + softness:
		var t := (value - min_val) / softness
		return min_val + softness * ease_smooth(clampf(t, 0.0, 1.0))
	elif value > max_val - softness:
		var t := (max_val - value) / softness
		return max_val - softness * ease_smooth(clampf(t, 0.0, 1.0))
	return value
