extends MeshInstance3D

# Background music system:
# - Plays 3D audio stream in loop
# - Automatically restarts when finished

## The 3D audio stream player component
@onready var music: AudioStreamPlayer3D = $AudioStreamPlayer3D


func _ready() -> void:
	"""
	Initializes music when node enters scene tree.
	Starts playback immediately.
	"""
	start_music()
	debug_print("Music system initialized")


func _process(delta: float) -> void:
	"""
	Frame processing (currently unused but maintained for future expansion)
	"""
	pass


func _on_audio_stream_player_3d_finished() -> void:
	"""
	Handles music stream completion.
	Automatically restarts playback for seamless looping.
	"""
	debug_print("Music track finished - restarting")
	start_music()


## Starts music playback
func start_music() -> void:
	"""
	Initiates music playback with error checking.
	"""
	if music:
		music.play()
		debug_print("Music playback started")
	else:
		debug_print("Error: AudioStreamPlayer3D reference missing!")


## Debug print wrapper (removes logs in production)
func debug_print(message: String) -> void:
	print("[MusicSystem] ", message)
