extends Area3D

# Paper collection system:
# - Emits signal when player collects paper
# - Notifies GameManager of collection
# - Self-destructs after collection

## Unique identifier for this paper (default: 5)
@export var paper_id: int = 5
## Flag to prevent multiple collection triggers
var collected := false

signal player_entered_paper_zone(player_position: Vector3)


func _ready() -> void:
	"""
	Initializes paper when added to scene.
	Sets up collision detection.
	"""
	connect("body_entered", _on_body_entered)
	debug_print("Paper %d ready for collection" % paper_id)


func _on_body_entered(body: Node3D) -> void:
	"""
	Handles player interaction with paper:
	- Verifies interacting body is player
	- Notifies GameManager of collection
	- Emits player position signal
	- Self-destructs
	"""
	debug_print("Entity entered paper collection zone")
	
	if not body.is_in_group("player"):
		return
	
	debug_print("Player detected")
	
	if collected:
		return
	
	collected = true
	process_collection(body.global_position)
	queue_free()


## Handles collection logic
func process_collection(player_position: Vector3) -> void:
	"""
	Executes post-collection actions:
	- Notifies GameManager
	- Emits position signal
	"""
	var game_manager = get_node("/root/Node3D/SubViewportContainer/SubViewport/GameManager")  
	if game_manager:
		game_manager.collect_paper(paper_id)
		debug_print("Paper %d collected successfully" % paper_id)
	else:
		debug_print("Error: GameManager not found!")
	
	emit_signal("player_entered_paper_zone", player_position)


## Debug print wrapper (removes logs in production)
func debug_print(message: String) -> void:
	print("[PaperSystem] ", message)
