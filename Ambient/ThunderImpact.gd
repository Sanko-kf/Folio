extends DirectionalLight3D

# Lightning System:
# - Manages random lightning flashes with sound
# - Handles smooth light intensity transitions
# - Configurable timing and intensity parameters

## Minimum time between lightning flashes (seconds)
@export var min_wait_time: float = 30.0
## Maximum time between lightning flashes (seconds)
@export var max_wait_time: float = 120.0
## Minimum light intensity during normal state
@export var min_intensity: float = 0.0
## Maximum light intensity during flash
@export var max_intensity: float = 2.0
## Transition speed for intensity changes
@export var transition_speed: float = 2.0
## Duration of lightning flash at max intensity (seconds)
@export var flash_duration: float = 0.2

var target_intensity: float = min_intensity
var time_until_next_flash: float = 0.0

## Reference to thunder sound effect
@onready var thunder_sound: AudioStreamPlayer = $ThunderImpact


func _ready() -> void:
	"""
	Initializes lightning system:
	- Sets first flash timer
	- Ensures initial state
	"""
	_reset_flash_timer()
	light_energy = min_intensity
	debug_print("Lightning system initialized")


func _process(delta: float) -> void:
	"""
	Handles lightning system updates:
	- Counts down to next flash
	- Manages light intensity transitions
	"""
	_update_flash_timing(delta)
	_update_light_intensity(delta)


## Updates flash timing logic
func _update_flash_timing(delta: float) -> void:
	"""
	Manages countdown to next lightning flash:
	- Triggers flash when timer expires
	- Resets timer after flash
	"""
	time_until_next_flash -= delta
	
	if time_until_next_flash <= 0:
		trigger_lightning()
		_reset_flash_timer()


## Updates light intensity smoothly
func _update_light_intensity(delta: float) -> void:
	"""
	Interpolates light energy toward target:
	- Creates smooth transitions
	- Uses configured transition speed
	"""
	light_energy = lerp(light_energy, target_intensity, transition_speed * delta)


## Triggers a lightning flash sequence
func trigger_lightning() -> void:
	"""
	Executes lightning flash sequence:
	- Sets max light intensity
	- Plays thunder sound
	- Returns to normal after duration
	"""
	target_intensity = max_intensity
	_play_thunder_sound()
	debug_print("Lightning flash triggered")
	
	await get_tree().create_timer(flash_duration).timeout
	target_intensity = min_intensity


## Plays thunder sound effect
func _play_thunder_sound() -> void:
	"""
	Handles thunder sound playback:
	- Validates sound node exists
	- Plays impact sound
	"""
	if thunder_sound:
		thunder_sound.play()
	else:
		debug_print("Error: Thunder sound node missing")


## Resets timer for next lightning flash
func _reset_flash_timer() -> void:
	"""
	Sets random time until next flash:
	- Uses configured min/max wait times
	"""
	time_until_next_flash = randf_range(min_wait_time, max_wait_time)
	debug_print("Next flash in %.1f seconds" % time_until_next_flash)


## Debug print wrapper with error handling
func debug_print(message: String) -> void:
	print("[LightningSystem] ", message)
	
