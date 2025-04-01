extends CharacterBody3D
## AI Monster Controller - Enhanced Version
## Handles:
## - Navigation and pathfinding with improved state management
## - Player detection with multiple zones (detection, running, attack)
## - Sound system with footsteps, screams and attack sounds
## - Inter-monster communication system

# Movement parameters
@export var walk_speed: float = 2.0
@export var run_speed: float = 3.3
@export var rotation_speed: float = 5.0
@export var temp_speed: float = 0.0  # Temporary speed storage

# Sound system parameters
@export var footstep_interval: float = 0.9
@export var running_footstep_interval: float = 0.4
@export var scream_duration: float = 5.0

# Node references
@onready var navigation_agent: NavigationAgent3D = $NavigationAgent3D
@onready var raycast: RayCast3D = $RayCast3D
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var sound_players = {
	"attack": $Attack,
	"scream": $Screaming,
	"footsteps": [
		$Walking1,
		$Walking2,
		$Walking3,
		$Walking4
	]
}

# State management
enum State {WANDERING, CHASING, RUNNING, ATTACKING, SCREAMING}
var current_state: State = State.WANDERING
var current_speed: float = walk_speed
var footstep_index: int = 0
var footstep_timer: float = 0.0

# Player tracking
var player_ref: Node3D = null
var is_player_spotted: bool = false
var last_player_position: Vector3 = Vector3.ZERO

# Signals
signal player_spotted(player_position: Vector3)
signal player_caught()

func _ready() -> void:
	"""Initialize monster with proper connections and initial state"""
	await get_tree().process_frame
	_initialize_connections()
	_set_random_target()
	animation_player.play("Walking")

func _physics_process(delta: float) -> void:
	"""Main physics processing loop"""
	if !_is_navigation_ready():
		return
	
	_update_footsteps(delta)
	_update_state_machine(delta)
	_update_animation()
	_move_character()
	_connect_to_monsters()

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
			animation_player.play("Punch")

func _update_state_machine(delta: float) -> void:
	"""Handle state-specific behavior"""
	match current_state:
		State.WANDERING:
			_handle_wandering_state()
		State.CHASING:
			_handle_chasing_state()
		State.RUNNING:
			_handle_running_state()
		State.ATTACKING:
			pass  # Handled by animation
		State.SCREAMING:
			pass  # Handled by timer

func _handle_y_level() -> void:
	"""Fix any vertical positioning issues"""
	global_position.y = 0
	last_player_position.y = 0

# Region: State Handlers
func _handle_wandering_state() -> void:
	"""Behavior when no player is detected"""
	if navigation_agent.is_navigation_finished():
		_set_random_target()
	
	if raycast.is_colliding():
		_set_random_target()

func _handle_chasing_state() -> void:
	"""Behavior when chasing player normally"""
	if player_ref:
		navigation_agent.target_position = player_ref.global_position

func _handle_running_state() -> void:
	"""Behavior when running fast toward player"""
	if player_ref:
		navigation_agent.target_position = player_ref.global_position
	elif navigation_agent.is_navigation_finished():
		_return_to_normal_behavior()

# Region: Movement System
func _move_character() -> void:
	"""Handle character movement and rotation"""
	var next_pos = navigation_agent.get_next_path_position()
	var direction = (next_pos - global_position).normalized()
	
	velocity = direction * current_speed
	_rotate_toward_target(next_pos)
	move_and_slide()

func _rotate_toward_target(target_pos: Vector3) -> void:
	"""Smooth rotation toward target position"""
	look_at(target_pos, Vector3.UP)
	rotation.x = 0
	rotate_object_local(Vector3.UP, PI)  # Fix model orientation

# Region: Sound System
func _update_footsteps(delta: float) -> void:
	"""Handle footstep sound timing"""
	if velocity.length() > 0.1:
		footstep_timer += delta
		var interval = running_footstep_interval if current_state == State.RUNNING else footstep_interval
		
		if footstep_timer >= interval:
			footstep_timer = 0.0
			_play_footstep()

func _play_footstep() -> void:
	"""Play next footstep sound in sequence"""
	if sound_players["footsteps"].size() > 0:
		sound_players["footsteps"][footstep_index].play()
		footstep_index = (footstep_index + 1) % sound_players["footsteps"].size()

# Region: Player Detection
func _on_detection_zone_body_entered(body: Node3D) -> void:
	"""Handle player entering detection zone"""
	if body.is_in_group("player"):
		_start_chasing(body)

func _on_detection_zone_body_exited(body: Node3D) -> void:
	"""Handle player leaving detection zone"""
	if body.is_in_group("player"):
		_stop_chasing()

func _on_running_zone_body_entered(body: Node3D) -> void:
	"""Handle player entering running zone"""
	if body.is_in_group("player"):
		_start_screaming()

func _on_running_zone_body_exited(body: Node3D) -> void:
	"""Handle player leaving running zone"""
	if body.is_in_group("player"):
		_stop_screaming()

# Region: Behavior Transitions
func _start_chasing(player: Node3D) -> void:
	"""Begin chase behavior"""
	current_state = State.CHASING
	current_speed = walk_speed
	player_ref = player
	is_player_spotted = true
	player_spotted.emit(player.global_position)

func _stop_chasing() -> void:
	"""End chase behavior"""
	current_state = State.WANDERING
	current_speed = walk_speed
	player_ref = null
	is_player_spotted = false

func _start_screaming() -> void:
	"""Begin scream behavior"""
	current_state = State.SCREAMING
	current_speed = 0.0
	animation_player.play("Scream")
	sound_players["scream"].play()
	await get_tree().create_timer(5.0).timeout
	current_state = State.RUNNING
	current_speed = run_speed

func _stop_screaming() -> void:
	"""End scream behavior"""
	current_state = State.CHASING
	current_speed = walk_speed

# Region: Attack System
func _on_attack_zone_body_entered(body: Node3D) -> void:
	"""Handle player entering attack zone"""
	if body.is_in_group("player"):
		_start_attack(body)

func _start_attack(player: Node3D) -> void:
	"""Initiate attack sequence"""
	current_state = State.ATTACKING
	sound_players["attack"].play()
	animation_player.play("Punch")
	await get_tree().create_timer(1.0).timeout
	_handle_player_capture(player)

func _handle_player_capture(player: Node3D) -> void:
	"""Process player capture"""
	player_caught.emit()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().change_scene_to_file("res://GUI/game_over.tscn")

# Region: Utility Functions
func _initialize_connections() -> void:
	"""Connect to other monsters and papers"""
	_connect_to_monsters()
	_connect_to_papers()

func _connect_to_monsters() -> void:
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
	"""Connect to all papers in scene"""
	for paper in get_tree().get_nodes_in_group("papers"):
		paper.player_entered_paper_zone.connect(_on_player_entered_paper_zone)

func _is_navigation_ready() -> bool:
	"""Check if navigation system is initialized"""
	return NavigationServer3D.map_get_iteration_id(navigation_agent.get_navigation_map()) > 0

func _set_random_target() -> void:
	"""Set new random navigation target"""
	var target = Vector3(
		randf_range(-500, 500),
		0,
		randf_range(-500, 500)
	)
	navigation_agent.target_position = target

func _return_to_normal_behavior() -> void:
	"""Return to default wandering state"""
	current_state = State.WANDERING
	current_speed = walk_speed
	_set_random_target()
	
func _on_player_spotted(player_position: Vector3) -> void:
	"""Handle player detection from other monsters"""
	if not is_player_spotted:
		navigation_agent.target_position = player_position
		is_player_spotted = true

func _on_player_entered_paper_zone(player_position: Vector3) -> void:
	"""Handle paper zone detection"""
	navigation_agent.target_position = player_position
	current_speed = run_speed
	current_state = State.RUNNING
