## SocialMemory: Tracks an NPC's feelings and knowledge about another entity.
## Modeled after Rain World's Dynamic Relationships system.
## Each NPC maintains a Dictionary of target_id -> SocialMemory.
class_name SocialMemory
extends RefCounted

## Persistent positive feeling (0-1). Builds from gifts, help, sparing.
var like: float = 0.0
## Persistent negative feeling (0-1). Builds from attacks, threats, betrayal.
var fear: float = 0.0
## Short-term positive (0-1). Decays each cycle. Recent kindness.
var temp_like: float = 0.0
## Short-term negative (0-1). Decays each cycle. Recent threat/violence.
var temp_fear: float = 0.0
## Familiarity (0-1). Increases with any interaction. Affects trust and recognition.
var know: float = 0.0

## Timestamp of last interaction (game clock hours)
var last_interaction_time: float = 0.0
## Number of total interactions
var interaction_count: int = 0


## Effective disposition: positive = friendly, negative = hostile, 0 = neutral.
## Range roughly -1.0 to 1.0.
func get_disposition() -> float:
	var positive := like + temp_like * 0.7
	var negative := fear + temp_fear * 0.7
	return clampf(positive - negative, -1.0, 1.0)


## Effective trust: combines disposition with familiarity.
## You can like someone you don't know, but you won't trust them.
func get_trust() -> float:
	return get_disposition() * know


## Record a positive interaction.
func add_positive(amount: float, current_time: float) -> void:
	temp_like = clampf(temp_like + amount, 0.0, 1.0)
	like = clampf(like + amount * 0.3, 0.0, 1.0)  # Persistent grows slower
	know = clampf(know + 0.05, 0.0, 1.0)
	last_interaction_time = current_time
	interaction_count += 1


## Record a negative interaction.
func add_negative(amount: float, current_time: float) -> void:
	temp_fear = clampf(temp_fear + amount, 0.0, 1.0)
	fear = clampf(fear + amount * 0.3, 0.0, 1.0)  # Persistent grows slower
	know = clampf(know + 0.05, 0.0, 1.0)
	last_interaction_time = current_time
	interaction_count += 1


## Decay temporary values. Call once per game cycle/hour.
func decay(rate: float = 0.1) -> void:
	temp_like = maxf(temp_like - rate, 0.0)
	temp_fear = maxf(temp_fear - rate, 0.0)
	# Slight natural forgiveness on persistent fear (Rain World pattern)
	if fear > 0.0 and like <= 0.01:
		fear = maxf(fear - rate * 0.02, 0.0)


func to_dict() -> Dictionary:
	return {
		"like": snappedf(like, 0.01),
		"fear": snappedf(fear, 0.01),
		"temp_like": snappedf(temp_like, 0.01),
		"temp_fear": snappedf(temp_fear, 0.01),
		"know": snappedf(know, 0.01),
		"disposition": snappedf(get_disposition(), 0.01),
		"trust": snappedf(get_trust(), 0.01),
	}


static func from_dict(data: Dictionary) -> SocialMemory:
	var mem := SocialMemory.new()
	mem.like = data.get("like", 0.0)
	mem.fear = data.get("fear", 0.0)
	mem.temp_like = data.get("temp_like", 0.0)
	mem.temp_fear = data.get("temp_fear", 0.0)
	mem.know = data.get("know", 0.0)
	return mem
