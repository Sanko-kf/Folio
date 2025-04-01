extends Control

## Game Over Menu Controller
## Handles:
## - Scene restart functionality
## - Application quit functionality
func _on_restart_pressed() -> void:
	"""
	Handles restart button press:
	- Reloads the main 3D level scene
	- Uses scene tree's safe change method
	"""
	get_tree().change_scene_to_file("res://3dLevel.tscn")


func _on_quit_pressed() -> void:
	"""
	Handles quit button press:
	- Safely terminates the application
	- Works across all platforms
	"""
	get_tree().quit()
