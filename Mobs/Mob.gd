extends Node2D

@export var hp: int = 100
@export var armor_type: String = "normal"
@export var speed: float = 50.0
@export var movement: String = "ground"
@export var boss: bool = false

@onready var map: TileMapLayer = get_parent()
var path: Array[Vector2i] = []
var current_path_index: int = 0
var current_target_world_pos: Vector2

const REACH_TOLERANCE = 2.0 # How close (in pixels) the mob needs to be to the target tile center

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if not is_instance_valid(map):
		printerr("Mob cannot find TileMapLayer as parent")
		set_process(false) # Disable processing if map is invalid
		return
	
	# Connect to the map's signal BEFORE potentially getting the initial path
	map.path_updated.connect(update_path)
		
	# Get the initial path *after* connecting, in case it's emitted during map's _ready
	update_path(map.mob_path) # Use the update function to set the initial path

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if path.is_empty() or current_path_index >= path.size():
		# End of path logic
		return
	
	var direction = (current_target_world_pos - global_position).normalized()
	var distance_to_target = global_position.distance_to(current_target_world_pos)
	var move_distance = speed * delta

	if move_distance >= distance_to_target:
		# Reached or passed the target waypoint
		global_position = current_target_world_pos # Snap to target precisely
		_advance_path_index()
	else:
		# Move towards the target
		global_position += direction * move_distance

func _advance_path_index():
	current_path_index += 1
	if current_path_index >= path.size():
		print("Mob reached the end!")
		queue_free() # Example: Destroy mob when it reaches the end
		# Alternatively, emit a signal, disable processing, etc.
	else:
		# set next world position
		var next_tile = path[current_path_index]
		if is_instance_valid(map):
			current_target_world_pos = map.to_global(map.map_to_local(next_tile))
		else:
			set_process(false)
	
func update_path(new_path: Array):
	print("Mob received updated path.")
	path = new_path # Store the new path
	
	if path.is_empty():
		#Logic if no valid paths
		print("Mob received empty path, stopping.")
		current_path_index = 0
		set_process(false) # Nothing to follow
		return
		
	# Find the closest point on the *new* path to the mob's current position
	var min_dist_sq = INF
	var closest_index = 0
		
	if not is_instance_valid(map):
		printerr("Cannot update path, map is invalid.")
		set_process(false)
		return
		
	for i in range(path.size()):
		var tile_pos = path[i]
		var tile_world_pos = map.to_global(map.map_to_local(tile_pos))
		var dist_sq = global_position.distance_squared_to(tile_world_pos)
		if dist_sq < min_dist_sq:
			min_dist_sq = dist_sq
			closest_index = i
			
	print("Closest index on new path: ", closest_index)
	current_path_index = closest_index
	
	# Set the initial target based on the (potentially new) index
	if current_path_index < path.size():
		current_target_world_pos = map.to_global(map.map_to_local(path[current_path_index]))
		set_process(true) # Ensure processing is enabled
	else:
		# This could happen if the closest point IS the end, handle appropriately
		print("Mob is already at or past the end of the new path.")
		# Decide what to do: maybe just queue_free() or stop processing
	
func take_damage(damage: int, damage_type: String):
	# Placeholder for damage logic (consider armor type)
	hp -= damage
	if hp <= 0:
		print("Mob died!")
		queue_free() # Destroy mob when HP reaches 0
