extends TileMapLayer

# Define tile IDs (replace with your actual IDs from the TileSet)
const GENERIC_ID = 1
const WALL_ID = 2
const WAYPOINT_ID = 3
const END_ID = 4
const SPAWN_ID = 5

var spawn_position : Vector2
var waypoint_positions : Array = []
var end_position : Vector2

func _ready():
	# Scan all used cells in the TileMap
	for cell in get_used_cells():
		var tile_id = get_cell_source_id(cell) # Gets the tile ID at this cell
		var world_pos = map_to_local(cell)     # Converts cell to world coordinates
		if tile_id == SPAWN_ID:
			spawn_position = world_pos
		elif tile_id == WAYPOINT_ID:
			waypoint_positions.append(world_pos)
		elif tile_id == END_ID:
			end_position = world_pos
	
	# Print for debugging
	print("Spawn Position:", spawn_position)
	print("Waypoint Positions:", waypoint_positions)
	print("End Position:", end_position)
