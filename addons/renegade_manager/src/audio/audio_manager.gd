## Manages audio bus volumes, music crossfading, and focus-based muting.
## Uses dual AudioStreamPlayers for seamless music crossfade.
class_name AudioManager extends Node


#region Bus Names
@export_group("Bus Names")
## Name of the master audio bus.
@export var master_bus: String = "Master"

## Name of the music audio bus.
@export var music_bus: String = "Music"

## Name of the SFX audio bus.
@export var sfx_bus: String = "SFX"

## Name of the voice audio bus.
@export var voice_bus: String = "Voice"

## Name of the ambient audio bus.
@export var ambient_bus: String = "Ambient"
#endregion


#region Crossfade
@export_group("Crossfade")
## Duration of music crossfade in seconds.
@export_range(0.0, 5.0, 0.1) var crossfade_duration: float = 1.5
#endregion


#region Focus
@export_group("Focus")
## Mute audio when the game window loses focus.
@export var mute_on_unfocus: bool = true
#endregion


## Dual players for crossfading.
var _music_player_a: AudioStreamPlayer
var _music_player_b: AudioStreamPlayer
var _active_player: AudioStreamPlayer


func _ready() -> void:
	_music_player_a = AudioStreamPlayer.new()
	_music_player_a.bus = music_bus
	add_child(_music_player_a)

	_music_player_b = AudioStreamPlayer.new()
	_music_player_b.bus = music_bus
	add_child(_music_player_b)

	_active_player = _music_player_a


## Set the volume for a named audio bus (0.0 to 1.0).
func set_bus_volume(bus_name: String, volume: float) -> void:
	pass


## Play a music track with crossfade from the current track.
func play_music(stream: AudioStream, fade_duration: float = -1.0) -> void:
	pass


## Stop all music with optional fade-out.
func stop_music(fade_duration: float = -1.0) -> void:
	pass


## Handle window focus changes for mute-on-unfocus.
func _notification(what: int) -> void:
	if not mute_on_unfocus:
		return
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		pass
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		pass
