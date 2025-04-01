extends CharacterBody3D

"""
Player Controller System:
Handles all player interactions including:
- 3D movement and physics (walking, sprinting, jumping)
- Camera controls (rotation, shaking effects)
- Stamina management system
- Sound effects (footsteps, ambient sounds, music)
- Interaction system (raycast-based)
- Pause menu functionality
"""

## Base movement speed when walking (units/s)
const SPEED := 2.5
## Movement speed multiplier when sprinting (added to SPEED)
const SPRINT_SPEED := 5.0
## Initial vertical velocity when jumping (units/s)
const JUMP_VELOCITY := 3.0
## Time between footstep sounds when moving (seconds)
const FOOTSTEP_INTERVAL := 0.0

## Maximum stamina value
const MAX_STAMINA := 100.0
## Stamina consumed per second when sprinting
const STAMINA_DRAIN := 20.0
## Stamina regenerated per second when not sprinting
const STAMINA_REGEN := 10.0

## Minimum delay between ambient sounds (seconds)
@export var min_delay := 30.0
## Maximum delay between ambient sounds (seconds)
@export var max_delay := 60.0
## Minimum delay between music tracks (seconds)
@export var music_min_delay := 60.0
## Maximum delay between music tracks (seconds)
@export var music_max_delay := 120.0

# Node References
@onready var neck := $Neck as Node3D
@onready var camera := $Neck/Camera3D as Camera3D
@onready var footstep_audio := $FootstepAudio as AudioStreamPlayer3D
@onready var footstep_run_audio := $FootstepRunAudio as AudioStreamPlayer3D
@onready var after_running_audio := $AfterRunningAudio as AudioStreamPlayer
@onready var ray_cast_3d := $Neck/Camera3D/RayCast3D as RayCast3D
@onready var audio_front := $Front as AudioStreamPlayer3D
@onready var audio_back := $Behind as AudioStreamPlayer3D
@onready var audio_left := $Left as AudioStreamPlayer3D
@onready var audio_right := $Right as AudioStreamPlayer3D
@onready var music_player := $Ambient as AudioStreamPlayer

# State Variables
var stamina := MAX_STAMINA
var can_sprint := true
var is_moving := false
var footstep_timer := 0.0
var timer := 0.0
var next_play_time := 0.0
var music_timer := 0.0
var next_music_time := 0.0

# Camera Shake System
var noise := FastNoiseLite.new()
var noise_y := 0.0
var shake_intensity := 0.0

# Pause System
var menu_pause_scene := load("res://GUI/settings.tscn") as PackedScene
var menu_pause_instance := menu_pause_scene.instantiate() as Control

signal interact_object(collider: Object)

func _ready() -> void:
	"""
	Initializes all player systems:
	- Adds pause menu to scene tree (hidden by default)
	- Configures viewport input handling
	- Sets up camera reference and mouse capture
	- Initializes noise generator for camera shake
	- Sets initial random timers for ambient sounds
	"""
	add_child(menu_pause_instance)
	menu_pause_instance.hide()
	
	_setup_viewport()
	_setup_camera()
	_setup_noise()
	
	next_play_time = randf_range(min_delay, max_delay)
	next_music_time = randf_range(music_min_delay, music_max_delay)
	
	debug_print("Player controller initialized")

func _setup_viewport() -> void:
	"""
	Configures viewport input handling:
	- Enables local input processing if inside SubViewportContainer
	- Logs viewport configuration status
	"""
	if get_viewport().get_parent() is SubViewportContainer:
		get_viewport().handle_input_locally = true
		debug_print("Viewport input handling set to local")

func _setup_camera() -> void:
	"""
	Initializes camera system:
	- Gets reference to active 3D camera
	- Captures mouse input
	- Verifies camera setup
	"""
	camera = get_viewport().get_camera_3d()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	debug_print("Camera setup complete")

func _setup_noise() -> void:
	"""
	Configures noise generator for camera shake:
	- Sets random seed
	- Adjusts frequency for natural-looking shake
	- Logs initialization status
	"""
	noise.seed = randi()
	noise.frequency = 0.1
	debug_print("Noise generator initialized")

func _unhandled_input(event: InputEvent) -> void:
	"""
	Processes all unhandled input events:
	- Delegates mouse input to dedicated handler
	- Delegates pause input to dedicated handler
	- Args:
		event: InputEvent - The input event to process
	"""
	_handle_mouse_input(event)
	_handle_pause_input(event)

func _handle_mouse_input(event: InputEvent) -> void:
	"""
	Handles mouse-related input:
	- Captures mouse when clicking
	- Processes mouse movement for camera rotation
	- Clamps vertical camera rotation
	- Args:
		event: InputEvent - The input event to check
	"""
	if event is InputEventMouseButton:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	elif Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED and event is InputEventMouseMotion:
		neck.rotate_y(-event.relative.x * 0.01)
		camera.rotate_x(-event.relative.y * 0.01)
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-60), deg_to_rad(60))

func _handle_pause_input(event: InputEvent) -> void:
	"""
	Manages pause menu toggle:
	- Shows/hides pause menu on ESC press
	- Toggles mouse capture state
	- Hide Game overlay
	- Args:
		event: InputEvent - The input event to check
	"""
	if event.is_action_pressed("ui_cancel"):
		var will_pause = !menu_pause_instance.visible
		menu_pause_instance.visible = will_pause
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE if will_pause else Input.MOUSE_MODE_CAPTURED)
		
		# Cache le label
		var label = get_node_or_null("/root/Node3D/SubViewportContainer/SubViewport/CanvasLayer/Label")
		if label:
			label.visible = !will_pause

func _physics_process(delta: float) -> void:
	"""
	Main physics processing loop (called every frame):
	- Updates ambient sound timers
	- Handles all movement physics
	- Processes object interactions
	- Args:
		delta: float - Time since last frame (seconds)
	"""
	_process_ambient_sounds(delta)
	_process_movement(delta)
	_process_interactions()

func _process_ambient_sounds(delta: float) -> void:
	"""
	Manages ambient sound playback:
	- Updates timers for random sounds
	- Triggers sound playback when timers expire
	- Resets timers with new random intervals
	- Args:
		delta: float - Time since last frame (seconds)
	"""
	timer += delta
	if timer >= next_play_time:
		_play_random_sound()
		timer = 0.0
		next_play_time = randf_range(min_delay, max_delay)
	
	music_timer += delta
	if music_timer >= next_music_time:
		_play_music()
		music_timer = 0.0
		next_music_time = randf_range(music_min_delay, music_max_delay)

func _process_movement(delta: float) -> void:
	"""
	Handles all movement-related processing:
	- Applies gravity and jumping
	- Manages stamina system
	- Calculates movement vectors
	- Updates camera effects
	- Performs final movement
	- Args:
		delta: float - Time since last frame (seconds)
	"""
	_apply_gravity(delta)
	_handle_jump()
	_handle_stamina(delta)
	
	var current_speed = _get_current_speed(delta)
	var direction = _get_movement_direction()
	
	_update_velocity(direction, current_speed)
	_update_footsteps(delta, current_speed)
	_update_camera_shake(delta, current_speed)
	
	move_and_slide()

func _process_interactions() -> void:
	"""
	Handles interaction system:
	- Checks RayCast for collisions
	- Emits interact signal with collider or null
	- Called every physics frame
	"""
	interact_object.emit(ray_cast_3d.get_collider() if ray_cast_3d.is_colliding() else null)

func _apply_gravity(delta: float) -> void:
	"""
	Applies gravity to player:
	- Only affects player when airborne
	- Uses project gravity settings
	- Args:
		delta: float - Time since last frame (seconds)
	"""
	if not is_on_floor():
		velocity += get_gravity() * delta

func _handle_jump() -> void:
	"""
	Handles jump input:
	- Applies vertical velocity when grounded
	- Checks for jump input each frame
	"""
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

func _handle_stamina(delta: float) -> void:
	"""
	Manages stamina system:
	- Regenerates stamina when not sprinting
	- Re-enables sprint when stamina reaches threshold
	- Args:
		delta: float - Time since last frame (seconds)
	"""
	if not Input.is_action_pressed("sprint") or not can_sprint:
		stamina = min(stamina + STAMINA_REGEN * delta, MAX_STAMINA)
		if stamina >= MAX_STAMINA * 0.5:
			can_sprint = true

func _get_current_speed(delta: float) -> float:
	"""
	Calculates current movement speed:
	- Returns sprint speed if conditions met
	- Otherwise returns normal speed
	- Manages stamina drain during sprint
	- Args:
		delta: float - Time since last frame (seconds)
	- Returns: float - Current movement speed
	"""
	if can_sprint and Input.is_action_pressed("sprint") and stamina > 0:
		stamina = max(stamina - STAMINA_DRAIN * delta, 0)
		if stamina <= 0:
			can_sprint = false
			after_running_audio.play()
		return SPRINT_SPEED
	return SPEED

func _get_movement_direction() -> Vector3:
	"""
	Calculates movement direction vector:
	- Gets input from keyboard/gamepad
	- Transforms to world space
	- Returns: Vector3 - Normalized direction vector
	"""
	var input_dir := Input.get_vector("left", "right", "forward", "back")
	return (neck.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

func _update_velocity(direction: Vector3, speed: float) -> void:
	"""
	Updates player velocity:
	- Applies movement when input detected
	- Smoothly stops when no input
	- Updates is_moving state flag
	- Args:
		direction: Vector3 - Movement direction
		speed: float - Current movement speed
	"""
	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
		is_moving = true
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)
		is_moving = false

func _update_footsteps(delta: float, current_speed: float) -> void:
	"""
	Manages footstep sounds:
	- Updates footstep timer
	- Plays appropriate sound when timer expires
	- Args:
		delta: float - Time since last frame (seconds)
		current_speed: float - Used to determine sound type
	"""
	if is_moving and is_on_floor():
		footstep_timer += delta
		if footstep_timer >= FOOTSTEP_INTERVAL:
			footstep_timer = 0.0
			_play_footstep_sound(current_speed == SPRINT_SPEED)

func _update_camera_shake(delta: float, current_speed: float) -> void:
	"""
	Manages camera shake effect:
	- Calculates shake intensity based on movement
	- Applies noise-based offset to camera
	- Args:
		delta: float - Time since last frame (seconds)
		current_speed: float - Determines shake intensity
	"""
	if is_moving and is_on_floor():
		shake_intensity = lerp(shake_intensity, 
							0.1 if current_speed == SPRINT_SPEED else 0.05, 
							delta * 5)
	else:
		shake_intensity = lerp(shake_intensity, 0.0, delta * 5)
	
	noise_y += delta * 10
	camera.position.y = noise.get_noise_1d(noise_y) * shake_intensity
	camera.position.x = 0

func _play_footstep_sound(is_sprinting: bool) -> void:
	"""
	Plays appropriate footstep sound:
	- Chooses between walk and run sounds
	- Prevents sound overlap
	- Args:
		is_sprinting: bool - Determines sound type
	"""
	if is_sprinting:
		if not footstep_run_audio.playing:
			footstep_run_audio.play()
	else:
		if not footstep_audio.playing:
			footstep_audio.play()

func _play_random_sound() -> void:
	"""
	Plays random ambient sound:
	- Selects random audio player
	- Prevents sound overlap
	- Only plays if no other sounds are playing
	"""
	if not (audio_front.playing or audio_back.playing or audio_left.playing or audio_right.playing):
		match randi() % 4:
			0: audio_front.play()
			1: audio_back.play()
			2: audio_left.play()
			3: audio_right.play()

func _play_music() -> void:
	"""
	Plays background music:
	- Starts music player if not already playing
	- Prevents music overlap
	"""
	if not music_player.playing:
		music_player.play()

func debug_print(message: String) -> void:
	"""
	Outputs debug messages with system prefix:
	- Prepends [PlayerController] to messages
	- Can be disabled in production
	- Args:
		message: String - The message to display
	"""
	print("[PlayerController] ", message)
