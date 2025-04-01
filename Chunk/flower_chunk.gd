extends Node3D

# Grid-based chunk loading system:
# - Dynamically loads/unloads chunks around player
# - Preserves original cell states (item + orientation)
# - Optimizes rendering by only showing nearby chunks

## Size of each chunk in grid cells (default: 16x1x16)
@export var chunk_size := Vector3i(16, 1, 16)
## Number of chunks to render around player (default: 2)
@export var render_distance := 2

@onready var gridmap: GridMap = $Flower
@onready var player: Node3D = $"../player"

# Stores currently loaded chunks
var loaded_chunks = {}
# Stores original cell states (item + orientation)
var cell_states = {}


func _ready() -> void:
	"""
	Initializes the chunk system:
	- Captures original grid state
	- Hides all cells initially
	"""
	_capture_original_grid_state()
	_hide_all_cells()
	debug_print("Chunk system ready")


## Captures original gridmap state (items + orientations)
func _capture_original_grid_state() -> void:
	"""
	Saves the initial state of all used cells:
	- Stores both item ID and orientation
	- Used to restore cells when chunks reload
	"""
	for cell in gridmap.get_used_cells():
		cell_states[cell] = {
			"item": gridmap.get_cell_item(cell),
			"orientation": gridmap.get_cell_item_orientation(cell)
		}


func _process(_delta: float) -> void:
	"""
	Main update loop:
	- Tracks player position in grid coordinates
	- Manages chunk loading/unloading
	- Skips if required nodes aren't ready
	"""
	if !player || !gridmap:
		return
	
	var player_chunk = _get_player_chunk_position()
	_update_chunk_visibility(player_chunk)


## Gets current player position in chunk coordinates
func _get_player_chunk_position() -> Vector3i:
	"""
	Converts player position to chunk coordinates:
	- Uses gridmap's local_to_map for accurate conversion
	- Accounts for chunk size in calculations
	"""
	var player_cell = gridmap.local_to_map(player.position)
	return Vector3i(
		floor(player_cell.x / float(chunk_size.x)),
		floor(player_cell.y / float(chunk_size.y)),
		floor(player_cell.z / float(chunk_size.z))
	)


## Updates chunk visibility based on player position
func _update_chunk_visibility(player_chunk: Vector3i) -> void:
	"""
	Manages chunk visibility:
	- Unloads distant chunks
	- Loads nearby chunks
	- Maintains loaded chunks dictionary
	"""
	_unload_distant_chunks(player_chunk)
	_load_nearby_chunks(player_chunk)


## Unloads chunks beyond render distance
func _unload_distant_chunks(player_chunk: Vector3i) -> void:
	"""
	Handles chunk unloading:
	- Hides cells in distant chunks
	- Removes from loaded chunks tracking
	"""
	for chunk_pos in loaded_chunks.keys():
		if chunk_pos.distance_to(player_chunk) > render_distance:
			_set_chunk_visibility(chunk_pos, false)
			loaded_chunks.erase(chunk_pos)


## Loads chunks within render distance
func _load_nearby_chunks(player_chunk: Vector3i) -> void:
	"""
	Handles chunk loading:
	- Checks all positions within render distance
	- Only loads unloaded chunks
	"""
	for x in range(-render_distance, render_distance + 1):
		for z in range(-render_distance, render_distance + 1):
			var chunk_pos = Vector3i(
				player_chunk.x + x,
				player_chunk.y,
				player_chunk.z + z
			)
			if !loaded_chunks.has(chunk_pos):
				_set_chunk_visibility(chunk_pos, true)
				loaded_chunks[chunk_pos] = true


## Sets visibility for all cells in a chunk
func _set_chunk_visibility(chunk_pos: Vector3i, visible: bool) -> void:
	"""
	Toggles chunk visibility:
	- When visible: restores original cell state
	- When hidden: clears cells (-1)
	- Only affects cells with saved state
	"""
	var start = chunk_pos * chunk_size
	var end = start + chunk_size
	
	for x in range(start.x, end.x):
		for y in range(start.y, end.y):
			for z in range(start.z, end.z):
				var cell = Vector3i(x, y, z)
				if cell_states.has(cell):
					if visible:
						gridmap.set_cell_item(
							cell, 
							cell_states[cell].item,
							cell_states[cell].orientation
						)
					else:
						gridmap.set_cell_item(cell, -1)


## Hides all gridmap cells initially
func _hide_all_cells() -> void:
	"""
	Initial grid cleanup:
	- Clears all cells that were originally populated
	- Prepares for dynamic loading
	"""
	for cell in gridmap.get_used_cells():
		gridmap.set_cell_item(cell, -1)


## Debug print wrapper (removes logs in production)
func debug_print(message: String) -> void:
	print("[ChunkLoader] ", message)
