extends TileMapLayer

# Define tile IDs (replace with your actual IDs from the TileSet)
const GENERIC = 1 # Assuming generic path tiles have an ID, adjust if needed
const WALL = 2
const WAYPOINT = 3
const END = 4
const SPAWN = 5

signal path_updated(new_path: Array) # Pass the new path with the signal

# Dictionary to keep track of tiles occupied by towers/obstacles
var occupied_tiles = {}

var spawn_position : Vector2i # Use Vector2i for tile coordinates
var waypoint_positions : Array[Vector2i] = [] # Type hint for clarity
var end_position : Vector2i

var mob_path: Array[Vector2i] = [] # Type hint for clarity

func _ready():
	# Clear previous data if _ready might be called again
	waypoint_positions.clear()
	occupied_tiles.clear() # Assuming towers aren't placed before _ready
	mob_path.clear()

	for cell in get_used_cells(): # Specify layer 0, adjust if needed
		# Use get_cell_tile_data instead for potentially more robust info,
		# but get_cell_source_id is okay if your IDs are simple source IDs.
		var source_id = get_cell_source_id(cell) # Check source ID

		# You might need to adjust this logic depending on how your TileSet is structured.
		# This assumes the source_id DIRECTLY corresponds to your constants.
		# If you use atlas coords or custom data, the logic here needs changing.
		# Let's assume source_id works for now based on your original code.

		match source_id:
			SPAWN:
				spawn_position = cell
			WAYPOINT:
				# Check if already found to avoid duplicates if tile spans multiple cells? Unlikely here.
				if not waypoint_positions.has(cell):
					waypoint_positions.append(cell)
			END:
				end_position = cell
			# WALL and GENERIC tiles don't need special storage here
			
	if not is_instance_valid(find_child("PathTimer", false)): # Avoid duplicate timers if scene reloads
		var timer = Timer.new()
		timer.name = "PathTimer"
		timer.wait_time = 0.1 # Small delay
		timer.one_shot = true
		timer.timeout.connect(generate_mob_path) # Connect timeout signal
		add_child(timer)
		timer.start()
	#else:
		# Optionally regenerate path immediately if needed without timer
		# generate_mob_path()


	# Sort waypoints by y-coordinate (top to bottom), then x if y is equal
	waypoint_positions.sort_custom(func(a: Vector2i, b: Vector2i):
		if a.y == b.y:
			return a.x < b.x
		return a.y < b.y)

	# Generate the path using BFS - MOVED TO TIMER CALLBACK OR CALLED DIRECTLY
	# generate_mob_path() # Call this after a short delay or directly


func place_tower(tile_pos: Vector2i):
	if is_valid_tower_spot(tile_pos):
		occupied_tiles[tile_pos] = true
		# Optionally: You might want to recalculate the mob path here
		# if placing a tower could potentially block the existing path.
		# Be careful, recalculating often can be expensive.
		generate_mob_path()
		return true
	return false

func remove_tower(tile_pos: Vector2i):
	if occupied_tiles.has(tile_pos):
		occupied_tiles.erase(tile_pos)
		# Optionally recalculate path if removing a tower might open up
		# a shorter path (less common requirement).
		generate_mob_path()
		return true
	return false

func is_tile_occupied(tile_pos: Vector2i) -> bool:
	return occupied_tiles.has(tile_pos)

# Checks if a tile is suitable for placing a tower
func is_valid_tower_spot(tile_pos: Vector2i) -> bool:
	if not has_tile(tile_pos): # Check if the tile actually exists in the map layer
		return false
	var source_id = get_cell_source_id(tile_pos)
	# Can't place on Walls, Waypoints, Spawn, End, or already occupied tiles
	# Allow placing on GENERIC tiles (adjust if needed)
	if source_id == WALL or \
	   source_id == WAYPOINT or \
	   source_id == SPAWN or \
	   source_id == END:
		# print("Invalid spot: Tile type restricted at ", tile_pos, " (ID: ", source_id, ")") # Debug
		return false
	# Can't place on already occupied tiles (by other towers)
	if is_tile_occupied(tile_pos):
		# print("Invalid spot: Tile already occupied at ", tile_pos) # Debug
		return false
	
	# Mob Overlap Check ---
	# 1. Calculate the world-space rectangle for the tile
	var tile_world_rect = get_tile_world_rect(tile_pos)
	if tile_world_rect == Rect2(): # Check if calculation failed
		printerr("Could not calculate world rect for tile: ", tile_pos)
		return false # Treat as invalid if we can't check

	# 2. Get all nodes currently in the "mobs" group
	var mobs_in_group = get_tree().get_nodes_in_group("mobs")

	# 3. Check if any mob's position is inside the tile's rectangle
	for mob in mobs_in_group:
		# Ensure the node is valid (might have been freed) and is a Node2D
		if is_instance_valid(mob) and mob is Node2D:
			if tile_world_rect.has_point(mob.global_position):
				# print("Invalid spot: Mob '", mob.name, "' overlaps tile ", tile_pos) # Debug
				return false # Found a mob overlapping, spot is invalid

	# --- All Checks Passed ---
	# print("Valid spot at ", tile_pos) # Debug
	return true

# New function: Checks if a tile is traversable for mob pathfinding (BFS)
func is_traversable(tile_pos: Vector2i) -> bool:
	if not has_tile(tile_pos): # Must be a tile on the map
		return false
	var source_id = get_cell_source_id(tile_pos)
	# Can traverse any tile EXCEPT walls and tiles currently occupied by towers
	return source_id != WALL and not is_tile_occupied(tile_pos)


func generate_mob_path():
	mob_path.clear() # Clear previous path

	if spawn_position == null or end_position == null:
		printerr("Spawn or End position not found!")
		return

	var current_pos = spawn_position
	mob_path.append(current_pos)

	# Path from Spawn to First Waypoint (if any)
	var target_pos = end_position # Default target is end if no waypoints
	if waypoint_positions.size() > 0:
		target_pos = waypoint_positions[0]

	var path_segment = bfs(current_pos, target_pos)
	if path_segment.is_empty():
		printerr("BFS failed: Spawn to ", target_pos)
		mob_path.clear() # Indicate failure
		return
	mob_path.append_array(path_segment.slice(1)) # Append path, excluding start
	current_pos = target_pos

	# Path between Waypoints
	for i in range(waypoint_positions.size() - 1):
		var wp_start = waypoint_positions[i]
		var wp_end = waypoint_positions[i+1]
		path_segment = bfs(wp_start, wp_end)
		if path_segment.is_empty():
			printerr("BFS failed: Waypoint ", wp_start, " to ", wp_end)
			mob_path.clear() # Indicate failure
			return
		mob_path.append_array(path_segment.slice(1)) # Append path, excluding start
		current_pos = wp_end # Update current position

	# Path from Last Waypoint (or Spawn if no waypoints) to End
	# current_pos is already set correctly from the loops above
	if current_pos != end_position: # Avoid BFS if last waypoint IS the end
		path_segment = bfs(current_pos, end_position)
		if path_segment.is_empty():
			printerr("BFS failed: ", current_pos, " to End ", end_position)
			mob_path.clear() # Indicate failure
			return
		mob_path.append_array(path_segment.slice(1)) # Append path, excluding start

	print("Generated mob path (length ", mob_path.size(), "): ", mob_path)
	path_updated.emit(mob_path) # Emit the signal with the complete path


func bfs(start: Vector2i, end: Vector2i) -> Array[Vector2i]:
	var queue: Array[Vector2i] = [start]
	# Use a dictionary to store visited nodes and their parent for path reconstruction
	var parent: Dictionary = {start: Vector2i(-1, -1)} # Use an invalid Vector2i marker for start's parent
	var directions = [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP] # Use constants

	var visited = {start: true} # Keep track of visited nodes efficiently

	while not queue.is_empty():
		var current = queue.pop_front()

		# Check if we reached the end
		if current == end:
			var path: Array[Vector2i] = []
			var backtrack = current
			# Backtrack using the parent dictionary
			while backtrack != Vector2i(-1,-1): # Backtrack until the marker
				path.push_front(backtrack)
				if parent.has(backtrack):
					backtrack = parent[backtrack]
				else: # Should not happen if start marker is set correctly
					printerr("BFS path reconstruction error!")
					return []
			return path

		# Explore neighbors
		for dir in directions:
			var next_tile = current + dir

			# Check if the next tile is traversable (not wall, not occupied)
			# AND has not been visited yet in this BFS search.
			if is_traversable(next_tile) and not visited.has(next_tile):
				visited[next_tile] = true # Mark as visited
				parent[next_tile] = current # Record parent
				queue.append(next_tile) # Add to queue for exploration

	printerr("BFS: No path found from ", start, " to ", end)
	return [] # No path found

# Helper to check if a tile exists on the layer
func has_tile(cell: Vector2i) -> bool:
	return get_cell_source_id(cell) != -1 # -1 means no tile

# --- Helper function to get tile Rect2 in world coordinates ---
func get_tile_world_rect(tile_pos: Vector2i) -> Rect2:
	if not tile_set:
		printerr("TileSet not available in TileMapLayer!")
		if self.tile_set:
			tile_set = self.tile_set
		else:
			printerr("Cannot determine TileSet.")
			return Rect2()

	var tile_size_pixels = tile_set.tile_size
	if tile_size_pixels == Vector2i.ZERO:
		printerr("TileSet tile_size is zero!")
		return Rect2()

	var local_pos_from_map = map_to_local(tile_pos)

	# --- !!! CRUCIAL ANCHOR ADJUSTMENT !!! ---
	# Set this variable based on your editor setting for
	# TileMap -> Tile Set -> Tile Layout -> Tile Anchor
	var TILE_ANCHOR_IS_CENTER = true # <-- SET THIS TO true or false

	var local_top_left: Vector2
	if TILE_ANCHOR_IS_CENTER:
		local_top_left = local_pos_from_map - (tile_size_pixels / 2.0)
	else: # Assumes TopLeft (0,0) if not Center
		local_top_left = local_pos_from_map
	# --- End Anchor Adjustment ---

	# Create the rectangle in local space using the calculated TOP-LEFT corner
	var local_rect = Rect2(local_top_left, tile_size_pixels)

	# --- Convert the local Rect corners to global space using the '*' operator ---
	var global_top_left     = global_transform * local_rect.position
	var global_bottom_right = global_transform * local_rect.end # Use get_end() for bottom-right corner
	# --- End Conversion ---

	# Create the final rectangle in global space from the transformed points
	# Ensure size is positive
	var world_rect = Rect2(global_top_left, global_bottom_right - global_top_left).abs()

	return world_rect
