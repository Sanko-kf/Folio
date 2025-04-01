extends AudioStreamPlayer

# Ambient Sound System:
# - Plays random ambient sounds at intervals
# - Handles sound file validation
# - Manages timing between sounds

## Minimum time between ambient sounds (seconds)
@export var min_ambient_time: float = 30.0
## Maximum time between ambient sounds (seconds) 
@export var max_ambient_time: float = 60.0

var time_until_next_ambient: float = 0.0


func _ready() -> void:
	"""
	Initializes ambient sound system:
	- Validates audio stream
	- Sets first playback timer
	"""
	if not _validate_audio_stream():
		return
	
	_reset_ambient_timer()
	debug_print("Ambient sound system initialized")


func _process(delta: float) -> void:
	"""
	Handles ambient sound timing:
	- Counts down to next playback
	- Triggers sound when timer expires
	"""
	time_until_next_ambient -= delta
	
	if time_until_next_ambient <= 0:
		play_ambient_sound()
		_reset_ambient_timer()


## Plays the ambient sound if valid
func play_ambient_sound() -> void:
	"""
	Attempts to play ambient sound:
	- Validates stream exists
	- Starts playback
	"""
	if not _validate_audio_stream():
		return
	
	play()
	debug_print("Playing ambient sound")


## Resets the timer for next ambient sound
func _reset_ambient_timer() -> void:
	"""
	Sets random time until next ambient sound
	within configured min/max range
	"""
	time_until_next_ambient = randf_range(min_ambient_time, max_ambient_time)
	debug_print("Next ambient sound in %.1f seconds" % time_until_next_ambient)


## Validates the audio stream is properly configured
func _validate_audio_stream() -> bool:
	"""
	Checks audio stream configuration:
	- Returns true if valid
	- Logs error and returns false if invalid
	"""
	if not stream:
		debug_print("Error: No audio stream assigned")
		return false
	return true


## Debug print wrapper with error handling
func debug_print(message: String) -> void:
	print("[AmbientSound] ", message)
