extends Node3D

# A 3D audio player that loops a music track seamlessly.
# When the music ends, it automatically restarts.

@onready var music: AudioStreamPlayer3D = $AudioStreamPlayer3D

func _ready() -> void:
	"""
	Called when the node enters the scene tree.
	Starts playing the music immediately.
	"""
	_play_music()

func _on_audio_stream_player_3d_finished() -> void:
	"""
	Called when the music track finishes playing.
	Restarts the music to create a seamless loop.
	"""
	_play_music()

func _play_music() -> void:
	"""
	Plays the music if the AudioStreamPlayer3D node is valid.
	Avoids errors if the node is missing or misconfigured.
	"""
	if music and music.stream:
		music.play()
	else:
		push_warning("Music player or audio stream not properly set up.")
