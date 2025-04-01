extends Control

# Video player system:
# - Plays fullscreen video after splash screen
# - Allows skipping with escape key
# - Automatically loads next scene when finished

## The video stream player component
@onready var video_player: VideoStreamPlayer = $VideoStreamPlayer

## Skip availability flag (prevents accidental skipping)
var skip_allowed: bool = false


func _ready() -> void:
	"""
	Initializes video player when node enters scene tree.
	Starts playback after splash screen duration.
	"""
	# Configure initial video size
	video_player.size = get_viewport_rect().size
	
	# Wait for splash screen completion
	var splash_duration = ProjectSettings.get_setting("application/boot_splash/minimum_display_time", 2.0)
	await get_tree().create_timer(splash_duration).timeout
	
	start_video()
	debug_print("Video playback initialized")


func _input(event: InputEvent) -> void:
	"""
	Handles input events.
	Processes escape key press for video skipping.
	"""
	if event.is_action_pressed("ui_cancel") and skip_allowed:
		skip_video()


func _on_video_stream_player_finished() -> void:
	"""
	Handles video completion.
	Automatically loads main scene.
	"""
	debug_print("Video playback completed")
	load_main_scene()


## Starts video playback
func start_video() -> void:
	"""
	Initiates video playback with delay before allowing skips.
	"""
	video_player.play()
	debug_print("Video playback started")
	
	# Enable skipping after brief delay
	await get_tree().create_timer(0.5).timeout
	skip_allowed = true
	debug_print("Skip function enabled")


## Skips current video playback
func skip_video() -> void:
	"""
	Stops video playback and loads main scene immediately.
	"""
	debug_print("Video skipped by user")
	video_player.stop()
	load_main_scene()


## Loads the main game scene
func load_main_scene() -> void:
	"""
	Handles scene transition to main game level.
	Cleans up signal connections.
	"""
	if video_player.finished.is_connected(_on_video_stream_player_finished):
		video_player.finished.disconnect(_on_video_stream_player_finished)
	
	get_tree().change_scene_to_file("res://3dLevel.tscn")
	debug_print("Loading main scene...")


## Debug print wrapper (removes logs in production)
func debug_print(message: String) -> void:
	print("[VideoPlayer] ", message)
