extends Node3D

# Car interaction system:
# - Locks/unlocks based on collected papers
# - Triggers victory when player enters while unlocked

## Whether the car is unlocked (default: false)
var is_unlocked := false
## Flag to prevent multiple victory triggers
var victory_triggered := false


func _ready() -> void:
	"""
	Initializes car state when added to scene.
	Automatically unlocks if player has collected papers.
	"""
	var game_manager = get_node("/root/Node3D/SubViewportContainer/SubViewport/GameManager")
	if game_manager.collected_papers >= 1:
		unlock()
	debug_print("Car ready for interaction")


## Unlocks the car and enables victory condition
func unlock() -> void:
	is_unlocked = true
	debug_print("Car unlocked !")


func _on_area_3d_body_entered(body: Node3D) -> void:
	"""
	Handles player interaction with car:
	- Checks if player has collection requirement
	- Triggers victory sequence when conditions met
	"""
	debug_print("Entity entered car interaction zone")
	
	if not body.is_in_group("player"):
		return
	
	debug_print("Player detected")
	
	if victory_triggered:
		return
	
	if is_unlocked:
		debug_print("Victory achieved via car !")
		victory_triggered = true
		trigger_victory()
	else:
		debug_print("Missing required papers to use car")


## Initiates game victory sequence
func trigger_victory() -> void:
	"""
	Handles post-victory actions:
	- Shows mouse cursor
	- Loads victory screen
	"""
	_disable_all_monsters()
	debug_print("Congratulations! You won!")
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	# Use deferred call for thread-safe scene transition
	call_deferred("_change_scene_safe")

## Disable all monsters
func _disable_all_monsters():
	"""
	Handle post-victory condition:
	- Disable monsters (If not it crash before the victory due to the permanent monsters communication)
	"""
	var monsters = get_tree().get_nodes_in_group("monsters")
	for monster in monsters:
		monster.set_process_mode(Node.PROCESS_MODE_DISABLED)
		monster.queue_free()

## Thread-safe scene loader
func _change_scene_safe() -> void:
	get_tree().change_scene_to_file("res://GUI/win.tscn")


## Debug print wrapper (removes logs in production)
func debug_print(message: String) -> void:
	print("[CarSystem] ", message)
