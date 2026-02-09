## NPCPersonality: Generates deterministic personality from 3 base traits.
## Seeded by NPC ID so the same NPC always has the same personality.
## Inspired by Rain World's personality derivation system.
class_name NPCPersonality
extends RefCounted

## Base traits (0.0 - 1.0) - randomly generated, weighted toward extremes
var grit: float = 0.5      ## Bravery analog - willingness to stand ground
var hustle: float = 0.5    ## Energy analog - activity level, restlessness
var empathy: float = 0.5   ## Sympathy analog - care for others, mercy

## Derived traits (0.0 - 1.0) - computed from base + small randomness
var aggression: float = 0.5   ## Combat eagerness, willingness to escalate
var influence: float = 0.5    ## Leadership weight, dominance in groups
var anxiety: float = 0.5      ## Alertness, flee threshold, nervousness

## The seed used to generate this personality
var _seed: int = 0


static func from_id(npc_id: String, aggression_bias: float = 0.5) -> NPCPersonality:
	var p := NPCPersonality.new()
	p._seed = npc_id.hash()
	p._generate(aggression_bias)
	return p


static func from_seed(seed_value: int, aggression_bias: float = 0.5) -> NPCPersonality:
	var p := NPCPersonality.new()
	p._seed = seed_value
	p._generate(aggression_bias)
	return p


func _generate(aggression_bias: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed
	
	# Base traits - push toward extremes (0 or 1) rather than clustering at 0.5
	grit = _push_from_half(rng.randf(), 2.0)
	hustle = _push_from_half(rng.randf(), 2.0)
	empathy = _push_from_half(rng.randf(), 2.0)
	
	# Derived: Aggression correlates with grit+hustle, inversely with empathy
	var raw_agg := (grit + hustle) * (1.0 - empathy) / 2.0
	aggression = clampf(raw_agg + rng.randf_range(-0.1, 0.1), 0.0, 1.0)
	# Apply archetype bias
	aggression = lerpf(aggression, aggression_bias, 0.3)
	
	# Derived: Influence correlates with grit+hustle+aggression
	influence = clampf((grit + hustle + aggression) / 3.0 + rng.randf_range(-0.1, 0.1), 0.0, 1.0)
	
	# Derived: Anxiety correlates with hustle, inversely with grit
	anxiety = clampf((hustle - grit + 1.0) / 2.0 + rng.randf_range(-0.1, 0.1), 0.0, 1.0)


## Pushes a 0-1 value away from 0.5 toward the extremes.
## Higher power = stronger push.
func _push_from_half(value: float, power: float) -> float:
	var centered := value * 2.0 - 1.0
	var pushed := signf(centered) * pow(absf(centered), 1.0 / power)
	return (pushed + 1.0) / 2.0


## Returns a Dictionary summary for debugging / inspector display.
func to_dict() -> Dictionary:
	return {
		"grit": snappedf(grit, 0.01),
		"hustle": snappedf(hustle, 0.01),
		"empathy": snappedf(empathy, 0.01),
		"aggression": snappedf(aggression, 0.01),
		"influence": snappedf(influence, 0.01),
		"anxiety": snappedf(anxiety, 0.01),
	}


func _to_string() -> String:
	return "Personality(grit=%.2f, hustle=%.2f, empathy=%.2f | agg=%.2f, inf=%.2f, anx=%.2f)" % [
		grit, hustle, empathy, aggression, influence, anxiety
	]
