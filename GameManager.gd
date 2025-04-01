extends Node3D
## Paper collection manager:
## - Tracks collected/total papers
## - Updates UI and unlocks car when requirements are met
## - Emits signals for game state changes

signal papers_updated  # Emitted when collection count changes

@export var total_papers: int = 6  # Total papers required to complete game
var collected_papers: int = 0

# UI Reference (better to use @export and drag in editor)
@onready var ui_label: Label = get_node("/root/Node3D/SubViewportContainer/SubViewport/CanvasLayer/Label")


func _ready() -> void:
	"""Initialize system with starting message"""
	update_ui("Collect papers to unlock the car.")


func collect_paper(paper_id: int) -> void:
	"""
	Handles paper collection:
	- Increments counter
	- Updates UI
	- Checks unlock conditions
	- paper_id: Identifier for collected paper (unused but available)
	"""
	collected_papers += 1
	debug_print("Paper collected! Total: " + str(collected_papers))
	
	if collected_papers >= total_papers:
		update_ui("Return to the car!")
	else:
		update_ui("Papers found: " + str(collected_papers) + " out of " + str(total_papers))
	
	if collected_papers >= 1:
		_try_unlock_car()


func update_ui(message: String) -> void:
	"""Updates the UI label and emits signal"""
	if ui_label:
		ui_label.text = message
	emit_signal("papers_updated")


func _try_unlock_car() -> void:
	"""Attempts to unlock the car when papers are collected"""
	var car = get_node_or_null("/root/Node3D/SubViewportContainer/SubViewport/Car")
	if car and car.has_method("unlock"):
		debug_print("Car unlocked!")
		car.unlock()


## Debug print wrapper (can be disabled in production)
func debug_print(message: String) -> void:
	print("[PaperSystem] ", message)
