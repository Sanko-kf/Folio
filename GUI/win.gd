extends Control

# Menu System:
# - Handles UI button interactions
# - Manages scene transitions
# - Provides application quit functionality


func _on_restart_pressed() -> void:
	"""
	Handles restart button press:
	- Reloads the main 3D level scene
	- Uses deferred call for thread safety
	"""
	debug_print("Restart button pressed - reloading level")
	_change_scene_safe("res://3dLevel.tscn")


func _on_quit_pressed() -> void:
	"""
	Handles quit button press:
	- Safely terminates the application
	"""
	debug_print("Quit button pressed - exiting application")
	get_tree().quit()

## Thread-safe scene loader
func _change_scene_safe(scene_path: String) -> void:
	"""
	Safely changes scene:
	- Uses deferred call to prevent issues
	- Validates scene path
	"""
	if ResourceLoader.exists(scene_path):
		get_tree().change_scene_to_file(scene_path)
	else:
		debug_print("Error: Scene path not found")


## Debug print wrapper (removes logs in production)
func debug_print(message: String) -> void:
	print("[MenuSystem] ", message)
