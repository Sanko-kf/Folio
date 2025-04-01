extends CharacterBody3D
## AI Monster Controller
## Handles:
## - Navigation and pathfinding
## - Player detection and chasing
## - Sound and animation systems
## - Inter-monster communication

# Movement parameters
@export var walk_speed: float = 2.0
@export var run_speed: float = 3.3
@export var rotation_speed: float = 5.0

# Sound system parameters
@export var sound_cooldown: float = 2.0
@export var sound_probability: float = 0.5

# Node references
@onready var navigation_agent: NavigationAgent3D = $NavigationAgent3D
@onready var raycast: RayCast3D = $RayCast3D
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var chase_music = {
	"start": $Chase_Start,
	"loop": $Chase_Loop,
	"end": $Chase_End
}
@onready var random_sound: AudioStreamPlayer3D = $Random

# State variables
enum State {WANDERING, CHASING, RUNNING, ATTACKING}
var current_state: State = State.WANDERING
var current_speed: float = walk_speed
var target_player: Node3D = null
var can_play_sound: bool = true
var is_player_spotted: bool = false

# Signals
signal player_spotted(player_position: Vector3)
signal player_caught()

func _ready() -> void:
	"""Initialize with navigation safety check"""
	await get_tree().process_frame  # Wait one frame for navigation to initialize
	_connect_to_other_monsters()
	_connect_to_papers()
	_set_random_target_position()
	_retry_connect_to_monsters()


func _physics_process(delta: float) -> void:
	"""Main loop with navigation safety"""
	if NavigationServer3D.map_get_iteration_id(navigation_agent.get_navigation_map()) == 0:
		return  # Skip if navigation isn't ready
	
	_update_animation()
	_handle_sound_system()
	_connect_to_other_monsters()
	
	match current_state:
		State.WANDERING:
			_handle_wandering_state()
		State.CHASING:
			_handle_chasing_state()
		State.RUNNING:
			_handle_running_state()
		State.ATTACKING:
			pass
	
	_move_character()


func _on_detection_zone_body_entered(body: Node3D) -> void:
	"""Handle player entering detection zone"""
	if body.is_in_group("player"):
		_start_chasing(body)


func _on_detection_zone_body_exited(body: Node3D) -> void:
	"""Handle player leaving detection zone"""
	if body.is_in_group("player"):
		_stop_chasing()


func _on_attack_zone_body_entered(body: Node3D) -> void:
	"""Handle player entering attack range"""
	if body.is_in_group("player"):
		_start_attack(body)


func _on_player_spotted(player_position: Vector3) -> void:
	"""Handle player detection from other monsters"""
	if not is_player_spotted:
		navigation_agent.target_position = player_position
		is_player_spotted = true

func _return_to_normal_behavior() -> void:
	"""Return to normal"""
	current_state = State.WANDERING
	current_speed = walk_speed
	_set_random_target_position()

func _on_player_entered_paper_zone(player_position: Vector3) -> void:
	"""Handle paper zone detection"""
	navigation_agent.target_position = player_position
	current_speed = run_speed
	current_state = State.RUNNING


# Private methods
func _connect_to_other_monsters() -> void:
	"""Connect to all monsters with proper signal handling"""
	await get_tree().process_frame  # Important pour la synchronisation
	
	var monsters = get_tree().get_nodes_in_group("monsters")
	for monster in monsters:
		if monster != self and is_instance_valid(monster):
			# Double vérification des connexions
			if not monster.player_spotted.is_connected(_on_player_spotted):
				monster.player_spotted.connect(_on_player_spotted.bind())
			if not self.player_spotted.is_connected(monster._on_player_spotted):
				self.player_spotted.connect(monster._on_player_spotted.bind())


func _connect_to_papers() -> void:
	"""Connect to all paper nodes in the scene"""
	for paper in get_tree().get_nodes_in_group("papers"):
		paper.player_entered_paper_zone.connect(_on_player_entered_paper_zone)


func _set_random_target_position() -> void:
	"""Thread-safe position setting"""
	var safe_position = Vector3(
		randf_range(-500, 500),
		0,
		randf_range(-500, 500)
	)
	
	# Verify navigation map is ready
	if NavigationServer3D.map_get_iteration_id(navigation_agent.get_navigation_map()) > 0:
		navigation_agent.target_position = safe_position
	else:
		call_deferred("_set_random_target_position")  # Try again next frame


func _update_animation() -> void:
	"""Play appropriate animation based on state"""
	match current_state:
		State.WANDERING:
			animation_player.play("Walking")
		State.CHASING:
			animation_player.play("Walking")
		State.RUNNING:
			animation_player.play("Running")
		State.ATTACKING:
			animation_player.play("Attack")

func _handle_y_level() -> void:
	"""Fix any vertical positioning issues"""
	global_position.y = 0

func _handle_sound_system() -> void:
	"""Manage random sound playback"""
	if can_play_sound and not random_sound.playing:
		if randf() < sound_probability:
			random_sound.play()
			can_play_sound = false
			await get_tree().create_timer(sound_cooldown).timeout
			can_play_sound = true


func _handle_wandering_state() -> void:
	"""Safe wandering behavior with navigation checks"""
	if navigation_agent.is_navigation_finished():
		_set_random_target_position()
	
	if raycast.is_colliding():
		_set_random_target_position()


func _handle_chasing_state() -> void:
	"""Behavior when chasing player"""
	if target_player:
		navigation_agent.target_position = target_player.global_position

func _handle_running_state() -> void:
	"""Behavior when running chasing player"""
	if is_player_spotted == false:
		if navigation_agent.is_navigation_finished():
			_return_to_normal_behavior()


func _move_character() -> void:
	"""Handle actual movement and rotation"""
	var next_position = navigation_agent.get_next_path_position()
	var direction = (next_position - global_position).normalized()
	
	velocity = direction * current_speed
	look_at(next_position, Vector3.UP)
	rotation.x = 0
	rotate_object_local(Vector3.UP, PI)  # Fix model orientation
	
	move_and_slide()


func _start_chasing(player: Node3D) -> void:
	"""Begin chase behavior"""
	current_state = State.CHASING
	current_speed = walk_speed
	target_player = player
	is_player_spotted = true
	
	if not chase_music["start"].playing and not chase_music["loop"].playing:
		chase_music["start"].play()
		await chase_music["start"].finished
		chase_music["loop"].play()
	
	player_spotted.emit(player.global_position)


func _stop_chasing() -> void:
	"""End chase behavior"""
	current_state = State.WANDERING
	current_speed = walk_speed
	target_player = null
	is_player_spotted = false
	
	chase_music["loop"].stop()
	chase_music["end"].play()


func _start_attack(player: Node3D) -> void:
	"""Initiate attack sequence"""
	current_state = State.ATTACKING
	await get_tree().create_timer(2.0).timeout
	_handle_player_capture(player)


func _handle_player_capture(player: Node3D) -> void:
	"""Process player capture"""
	player_caught.emit()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().change_scene_to_file("res://GUI/game_over.tscn")

func _on_running_zone_body_entered(body: Node3D) -> void:
	"""Handle player entering running detection zone"""
	if body.is_in_group("player"):
		_start_running(body)
	
func _on_running_zone_body_exited(body: Node3D) -> void:
	"""Handle player leaving running detection zone"""
	if body.is_in_group("player"):
		_stop_running(body)
		
func _start_running(player: Node3D) -> void:
	"""Begin running chase behavior"""
	current_state = State.RUNNING
	current_speed = run_speed
	target_player = player
	
func _stop_running(player: Node3D) -> void:
	"""End running chase behavior"""
	current_state = State.CHASING
	current_speed = walk_speed

func _retry_connect_to_monsters() -> void:
	await get_tree().create_timer(1.0).timeout  # Attends 1 seconde
	_connect_to_other_monsters()  # Retente la connexion
