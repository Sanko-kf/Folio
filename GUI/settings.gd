extends Control

# Settings control system:
# - Manages audio volume changes
# - Handles FOV adjustments
# - Handles Full Screen mode
# - Provides application quit functionality

## Minimum/Maximum volume range in dB
const VOLUME_RANGE := Vector2(-10.0, 10.0)
## Minimum/Maximum FOV range in degrees
const FOV_RANGE := Vector2(75.0, 120.0)


func _on_volume_value_changed(value: float) -> void:
	"""
	Handles volume slider changes:
	- Clamps value to valid range
	- Updates audio bus volume
	"""
	value = clamp(value, VOLUME_RANGE.x, VOLUME_RANGE.y)
	AudioServer.set_bus_volume_db(0, value)
	debug_print("Volume set to: %.1f dB" % value)


func _on_fov_value_changed(value: float) -> void:
	"""
	Handles FOV slider changes:
	- Clamps value to valid range
	- Updates active 3D camera FOV
	"""
	value = clamp(value, FOV_RANGE.x, FOV_RANGE.y)
	
	var camera = get_viewport().get_camera_3d()
	if camera:
		camera.fov = value
		debug_print("FOV set to: %.1f degrees" % value)
	else:
		debug_print("Error: No active 3D camera found")


func _on_button_pressed() -> void:
	"""
	Handles quit button press:
	- Safely terminates application
	"""
	debug_print("Quit button pressed - exiting application")
	get_tree().quit()


## Debug print wrapper (removes logs in production)
func debug_print(message: String) -> void:
	print("[SettingsSystem] ", message)


func _on_check_box_toggled(toggled_on: bool) -> void:
	"""
	Handles full screen button toggle:
	- Change full screen or window mode
	"""
	if toggled_on:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
