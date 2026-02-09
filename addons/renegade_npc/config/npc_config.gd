## NPCConfig: Central read-only game data for the Renegade NPC system.
## All tunable constants live here — faction IDs, scoring weights, thresholds.
## Access via NPCConfig.Factions.LA_MIRADA, NPCConfig.Threat.GUNFIRE_DECAY, etc.
class_name NPCConfig
extends RefCounted


# ==========================================================================
# FACTIONS
# ==========================================================================
class Factions:
	const LA_MIRADA: String = "la_mirada"
	const LOS_ANGELES_DEATH_SQUAD: String = "los_angeles_death_squad"
	const LAPD: String = "lapd"
	const CIVILIAN: String = "civilian"
	const PLAYER: String = "player"
	const NONE: String = "none"

	static var DISPLAY_NAMES: Dictionary = {
		LA_MIRADA: "La Mirada",
		LOS_ANGELES_DEATH_SQUAD: "L.A. Death Squad",
		LAPD: "LAPD Officer",
		CIVILIAN: "Citizen",
		PLAYER: "Player",
		NONE: "Unaffiliated",
	}

	## Default faction-to-faction dispositions: [factionA, factionB, value].
	## -1.0 = hostile, 0 = neutral, 1.0 = allied.
	static var DEFAULT_DISPOSITIONS: Array = [
		[LA_MIRADA, LAPD, -0.8],
		[LA_MIRADA, LOS_ANGELES_DEATH_SQUAD, -0.6],
		[LAPD, LOS_ANGELES_DEATH_SQUAD, -0.7],
		[CIVILIAN, LA_MIRADA, -0.2],
		[CIVILIAN, LOS_ANGELES_DEATH_SQUAD, -0.3],
		[CIVILIAN, LAPD, 0.3],
		[PLAYER, LA_MIRADA, 0.0],
		[PLAYER, LAPD, 0.1],
		[PLAYER, CIVILIAN, 0.2],
	]


# ==========================================================================
# DRIVES
# ==========================================================================
class Drives:
	const IDLE: String = "idle"
	const PATROL: String = "patrol"
	const SOCIALIZE: String = "socialize"
	const WORK: String = "work"
	const DEAL: String = "deal"
	const GUARD: String = "guard"
	const FLEE: String = "flee"
	const THREAT: String = "threat"


# ==========================================================================
# ARCHETYPE PRESETS
# ==========================================================================
class Archetypes:
	static var PRESETS: Dictionary = {
		"Gang": {
			"display_name": "La Mirada",
			"faction": Factions.LA_MIRADA,
			"is_combatant": true,
			"aggression_bias": 0.7,
			"activity_preferences": {
				"idle": 0.3, "patrol": 0.8, "socialize": 0.6,
				"deal": 0.7, "guard": 0.5,
			},
		},
		"Cop": {
			"display_name": "LAPD Officer",
			"faction": Factions.LAPD,
			"is_combatant": true,
			"aggression_bias": 0.4,
			"activity_preferences": {
				"idle": 0.3, "patrol": 0.9, "guard": 0.6,
			},
		},
		"Civilian": {
			"display_name": "Citizen",
			"faction": Factions.CIVILIAN,
			"is_combatant": false,
			"aggression_bias": 0.1,
			"activity_preferences": {
				"idle": 0.8, "socialize": 0.5, "work": 0.4,
			},
		},
		"Vendor": {
			"display_name": "Street Vendor",
			"faction": Factions.CIVILIAN,
			"is_combatant": false,
			"aggression_bias": 0.05,
			"activity_preferences": {
				"work": 1.0, "idle": 0.2,
			},
		},
		"Story": {
			"display_name": "Story NPC",
			"faction": Factions.NONE,
			"is_combatant": false,
			"aggression_bias": 0.0,
			"activity_preferences": {
				"idle": 1.0,
			},
		},
	}


# ==========================================================================
# CITY BLOCKS
# ==========================================================================
class Blocks:
	static var DOWNTOWN_EAST: Dictionary = {
		"crime_level": 0.7,
		"commerce_level": 0.4,
		"police_presence": 0.3,
		"gang_territory": {Factions.LA_MIRADA: 0.8, Factions.LOS_ANGELES_DEATH_SQUAD: 0.1},
		"connections": [
			{"block_id": "market_district", "crime_level": 0.3, "commerce_level": 0.9,
			 "police_presence": 0.5, "gang_territory": {}},
		],
	}
	static var MARKET_DISTRICT: Dictionary = {
		"crime_level": 0.3,
		"commerce_level": 0.9,
		"police_presence": 0.5,
		"gang_territory": {},
		"connections": [
			{"block_id": "downtown_east", "crime_level": 0.7, "commerce_level": 0.4,
			 "police_presence": 0.3, "gang_territory": {Factions.LA_MIRADA: 0.8}},
		],
	}

	## All blocks keyed by ID. Used by demo/game setup to register blocks with NPCManager.
	static var ALL: Dictionary = {
		"downtown_east": DOWNTOWN_EAST,
		"market_district": MARKET_DISTRICT,
	}


# ==========================================================================
# THREAT MODULE SCORING
# ==========================================================================
class Threat:
	const GUNFIRE_DECAY: float = 5.0
	const PROXIMITY_WEIGHT: float = 0.4
	const HEALTH_WEIGHT: float = 0.3
	const HEALTH_THRESHOLD: float = 0.5
	const GUNFIRE_WEIGHT: float = 0.5
	const ANXIETY_MULT: float = 0.3
	const GRIT_REDUCER: float = 0.2
	const HOSTILE_DISP_THRESHOLD: float = -0.3
	const PLAYER_HOSTILE_THRESHOLD: float = -0.5


# ==========================================================================
# FLEE MODULE SCORING
# ==========================================================================
class Flee:
	const CRITICAL_HP_THRESHOLD: float = 0.3
	const CRITICAL_HP_URGENCY: float = 0.6
	const MODERATE_HP_THRESHOLD: float = 0.5
	const MODERATE_HP_URGENCY: float = 0.2
	const PERSONALITY_BASE: float = 0.6
	const ANXIETY_MULT: float = 0.4
	const GRIT_REDUCER: float = 0.2
	const NONCOMBATANT_MULT: float = 1.4


# ==========================================================================
# IDLE MODULE SCORING
# ==========================================================================
class Idle:
	const BASE_SCORE: float = 0.15
	const ENERGY_MODIFIER: float = 0.3
	const CLAMP_MIN: float = 0.05
	const CLAMP_MAX: float = 0.3


# ==========================================================================
# SOCIAL MODULE SCORING
# ==========================================================================
class Social:
	const PER_ALLY: float = 0.15
	const MAX_ALLIES: float = 0.5
	const BASE_WEIGHT: float = 0.3
	const EMPATHY_WEIGHT: float = 0.5
	const HUSTLE_WEIGHT: float = 0.2
	const LONELY_EMPATHY_BOOST: float = 0.15
	const EMPATHY_THRESHOLD: float = 0.6
	const COMBATANT_REDUCER: float = 0.6


# ==========================================================================
# OPPORTUNITY MODULE SCORING
# ==========================================================================
class Opportunity:
	const DISTANCE_LIMIT: float = 50.0
	const HUSTLE_MULT: float = 0.5
	static var ARCHETYPE_BOOSTS: Dictionary = {
		"Gang": {"base": 0.7, "agg_mult": 0.6},
		"Vendor": {"base": 1.2, "agg_mult": 0.0},
		"Cop": {"base": 0.8, "agg_mult": 0.0},
	}


# ==========================================================================
# REALIZED NPC
# ==========================================================================
class Realized:
	const UTILITY_EVAL_INTERVAL: float = 0.25
	const EMOTION_DECAY_RATE: float = 0.04
	## Seconds after completing a timed activity before that type scores again.
	const ACTIVITY_COOLDOWN: float = 30.0
	## Brief pause at each patrol point before moving to the next.
	const PATROL_PAUSE: float = 3.0
	## Seconds before giving up on reaching an unreachable activity node.
	const NAV_TIMEOUT: float = 15.0


# ==========================================================================
# REPUTATION THRESHOLDS
# ==========================================================================
class Reputation:
	const HOSTILE_THRESHOLD: float = -30.0
	const NEUTRAL_LOW: float = -30.0
	const NEUTRAL_HIGH: float = 30.0
	const FRIENDLY_THRESHOLD: float = 30.0
	const ALLIED_THRESHOLD: float = 60.0


# ==========================================================================
# ABSTRACT NPC BLOCK SCORING
# ==========================================================================
class BlockScoring:
	const GANG_TERRITORY_MULT: float = 2.0
	const GANG_CRIME_MULT: float = 0.5
	const COP_CRIME_MULT: float = 1.5
	const COP_POLICE_BONUS: float = 0.3
	const VENDOR_COMMERCE_MULT: float = 2.0
	const VENDOR_CRIME_PENALTY: float = 0.5
	const HOME_BLOCK_BONUS: float = 0.5
