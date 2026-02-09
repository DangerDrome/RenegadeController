## UtilityModule: Base class for all utility AI scoring modules.
## Each module evaluates a single concern (threat, opportunity, social, etc.)
## and returns a score from 0.0 to 1.0. The highest scorer wins control
## of the NPC's behavior each tick.
##
## To create a new module:
##   1. Extend this class
##   2. Override evaluate() to return 0.0 - 1.0
##   3. Override get_drive_name() to return the behavior string
##   4. Optionally override get_module_name() for debugging
class_name UtilityModule
extends RefCounted

## The NPC this module belongs to
var npc: Node = null  ## RealizedNPC reference
var abstract: AbstractNPC = null
var personality: NPCPersonality = null

## Weight multiplier - can be overridden per-archetype via NPCData
var weight: float = 1.0


## Initialize with references. Called by RealizedNPC on setup.
func setup(p_npc: Node, p_abstract: AbstractNPC) -> void:
	npc = p_npc
	abstract = p_abstract
	personality = p_abstract.personality


## Evaluate this concern and return urgency score (0.0 - 1.0).
## Override in subclasses.
func evaluate() -> float:
	return 0.0


## The drive/behavior name this module activates when winning.
## Override in subclasses.
func get_drive_name() -> String:
	return "idle"


## Human-readable name for debugging.
func get_module_name() -> String:
	return "BaseModule"


## Weighted score used for comparison.
func get_weighted_score() -> float:
	return evaluate() * weight
