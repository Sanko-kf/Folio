extends CharacterBody3D
## AI Monster Controller - Surveillance Variant
## Handles:
## - Player detection and observation behavior
## - Sound communication system
## - Coordinated tracking with other monsters
## - Paper collection alerts

# Movement parameters
@export var speed: float = 2.0
@export var rotation_speed: float = 5.0
@export var player_look_speed: float = 2.0

# Sound system parameters
@export var sound_cooldown: float = 2.0
@export var sound_probability: float = 0.5
var can_play_sound: bool = true

# Node references
@onready var navigation_agent: NavigationAgent3D = $NavigationAgent3D
@onready var raycast: RayCast3D = $RayCast3D
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var sound_players = {
	"watch": $Watching,
	"comm": $Communication,
	"random": $Random
}

# State variables
var player_detected: bool = false
var player_position: Vector3 = Vector3.ZERO
var temp_player_position: Vector3 = Vector3.ZERO
var player_ref: Node3D = null

# Signals
signal player_spotted(player_position: Vector3)

func _ready() -> void:
	"""Initialize monster connections and set random target"""
	_connect_to_monster_network()
	_connect_to_paper_system()
	_set_random_target()
	_retry_connect_to_monsters()
	animation_player.play("Walking")

func _process(delta: float) -> void:
	"""Update player tracking in real-time"""
	if player_detected and player_ref:
		player_position = player_ref.global_position
		player_position.y = 0  # Maintain ground level tracking

func _physics_process(delta: float) -> void:
	"""Main behavior loop"""
	if !_is_navigation_ready():
		return
	
	_handle_y_level()  # Fix any floating issues
	
	if player_detected:
		_handle_player_detected_state(delta)
	else:
		_handle_normal_state(delta)
	
	move_and_slide()
	_connect_to_monster_network()
# Region: Public Methods
func get_player_position() -> Vector3:
	"""Returns last known player position"""
	return player_position

# Region: Signal Handlers
func _on_detector_body_entered(body: Node3D) -> void:
	"""Handle player entering detection zone"""
	if body.is_in_group("player"):
		_start_player_tracking(body)
		player_spotted.emit(body.global_position)  

func _on_detector_body_exited(body: Node3D) -> void:
	"""Handle player leaving detection zone"""
	if body.is_in_group("player"):
		_stop_player_tracking(body)
		player_spotted.emit(body.global_position)  

func _on_player_spotted(reported_position: Vector3) -> void:
	"""Handle player reports from other monsters"""
	navigation_agent.target_position = reported_position

func _on_player_entered_paper_zone(paper_position: Vector3) -> void:
	"""Handle paper collection alerts"""
	navigation_agent.target_position = paper_position

# Region: Private Implementation
func _connect_to_monster_network() -> void:
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

func _connect_to_paper_system() -> void:
	"""Connect to paper tracking system"""
	for paper in get_tree().get_nodes_in_group("papers"):
		paper.player_entered_paper_zone.connect(_on_player_entered_paper_zone)

func _set_random_target() -> void:
	"""Set new random navigation target"""
	navigation_agent.target_position = Vector3(
		randf_range(-500, 500), 
		0, 
		randf_range(-500, 500)
	)

func _is_navigation_ready() -> bool:
	"""Check if navigation system is initialized"""
	return NavigationServer3D.map_get_iteration_id(navigation_agent.get_navigation_map()) > 0

func _handle_y_level() -> void:
	"""Fix any vertical positioning issues"""
	global_position.y = 0
	temp_player_position.y = 0

func _handle_player_detected_state(delta: float) -> void:
	"""Behavior when player is detected"""
	velocity = Vector3.ZERO
	animation_player.play("Idle")
	_look_at_player(delta)
	_play_sound("watch")
	

func _handle_normal_state(delta: float) -> void:
	"""Default wandering behavior"""
	if temp_player_position != Vector3.ZERO:
		_investigate_last_position()
	
	_play_sound("random")
	
	if navigation_agent.is_navigation_finished():
		_set_random_target()
	
	animation_player.play("Walking")
	_follow_navigation_path()

func _look_at_player(delta: float) -> void:
	"""Smooth rotation toward detected player"""
	var direction = (player_position - global_position).normalized()
	var target_angle = atan2(direction.x, direction.z)
	rotation.y = lerp_angle(rotation.y, target_angle, player_look_speed * delta)

func _follow_navigation_path() -> void:
	"""Move along calculated navigation path"""
	var next_pos = navigation_agent.get_next_path_position()
	var direction = (next_pos - global_position).normalized()
	velocity = direction * speed
	
	look_at(next_pos, Vector3.UP)
	rotation.x = 0
	rotate_object_local(Vector3.UP, PI)  # Correct model orientation
	
	if raycast.is_colliding():
		_set_random_target()

func _start_player_tracking(player: Node3D) -> void:
	"""Initialize player tracking"""
	player_detected = true
	player_ref = player
	player_position = player.global_position
	_play_sound("watch")
	player_spotted.emit(player.global_position)

func _stop_player_tracking(player: Node3D) -> void:
	"""Terminate player tracking"""
	player_detected = false
	player_ref = null
	temp_player_position = player.global_position

func _investigate_last_position() -> void:
	"""Check last known player position"""
	navigation_agent.target_position = temp_player_position
	temp_player_position = Vector3.ZERO
	_play_sound("comm")

func _play_sound(sound_type: String) -> void:
	"""Manage sound playback with cooldown"""
	if !can_play_sound or sound_players[sound_type].playing:
		return
	
	if randf() < sound_probability:
		sound_players[sound_type].play()
		can_play_sound = false
		await get_tree().create_timer(sound_cooldown).timeout
		can_play_sound = true
		
func _retry_connect_to_monsters() -> void:
	await get_tree().create_timer(1.0).timeout  # Attends 1 seconde
	_connect_to_monster_network()  # Retente la connexion
