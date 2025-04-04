extends Node2D

@export var hp: int = 100
@export var armor_type: String = "normal"
@export var speed: float = 50.0
@export var movement: String = "ground"
@export var boss: bool = false

@onready var map: TileMapLayer = get_parent()
@onready var health_bar: ProgressBar = $HealthBar

var path: Array[Vector2i] = []
var current_path_index: int = 0
var current_target_world_pos: Vector2
var max_hp: int

const REACH_TOLERANCE_SQ = 2.0 * 2.0 # Use squared distance
const REJOIN_DISTANCE_THRESHOLD_SQ = 100.0 * 100.0 # Example: 100 pixels radius squared

# --- Helper function for consistent world position calculation ---
# Ensures centering logic is applied the same way everywhere.
func _get_world_pos_for_cell(cell: Vector2i) -> Vector2:
	if not is_instance_valid(map):
		return Vector2.ZERO # Or handle error appropriately

	var local_pos = map.map_to_local(cell)
	# --- Apply Centering Offset IF NEEDED ---
	# Check your TileMap -> Tile Set -> Tile Layout -> Tile Anchor property.
	# If it's not Center, you likely need to offset.
	# Example for Top-Left anchor:
	# local_pos += map.tile_set.tile_size / 2.0
	# --- End Centering Offset ---
	return map.to_global(local_pos)
# --- End Helper ---

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	max_hp = hp
	# --- Initialize Health Bar ---
	if health_bar: # Check if node exists
		health_bar.max_value = max_hp
		health_bar.value = hp
		# Optional: Hide bar if HP is full initially
		# health_bar.visible = (hp < max_hp)
	else:
		printerr("Mob ", name, " cannot find HealthBar node!")
	
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
	
	if current_target_world_pos == Vector2.ZERO: # Or some other invalid state check
		printerr("Mob ", name, " has invalid target position.")
		set_process(false) # Stop processing if state is bad
		return

	var direction = (current_target_world_pos - global_position).normalized()
	var distance_sq_to_target = global_position.distance_squared_to(current_target_world_pos)
	var move_distance = speed * delta

	if move_distance * move_distance >= distance_sq_to_target or distance_sq_to_target < REACH_TOLERANCE_SQ:
		global_position = current_target_world_pos # Snap to target
		_advance_path_index()
	else:
		global_position += direction * move_distance

func _advance_path_index():
	current_path_index += 1
	if current_path_index >= path.size():
		print("Mob reached the end!")
		queue_free() # Example: Destroy mob when it reaches the end
	else:
		# set next world position
		var next_tile = path[current_path_index]
		if is_instance_valid(map):
			current_target_world_pos = map.to_global(map.map_to_local(next_tile))
		else:
			set_process(false)
	
# --- Updated Path Update Logic ---
func update_path(new_path: Array):
	if not is_instance_valid(map):
		printerr("Mob ", name, " cannot update path, map is invalid.")
		path = []; set_process(false); return

	# Avoid redundant updates if the path hasn't actually changed
	if path == new_path:
		# print("Mob ", name, ": Path unchanged, skipping update.") # Optional debug
		return

	print("Mob ", name, " received updated path. (Length: ", new_path.size(), ")")
	path = new_path # Store the new path

	if path.is_empty():
		print("Mob ", name, " received empty path, stopping.")
		current_path_index = 0; current_target_world_pos = Vector2.ZERO; set_process(false); return

	# --- Strategy ---
	var current_cell = map.local_to_map(map.to_local(global_position))
	var found_index = path.find(current_cell)
	var target_index = -1

	if found_index != -1:
		# --- Case A: Current cell IS on the new path ---
		print("Mob ", name, ": Current cell ", current_cell, " found on new path at index ", found_index)
		target_index = found_index
	else:
		# --- Case B: Current cell IS NOT on the new path (must jump) ---
		print("Mob ", name, ": Current cell ", current_cell, " NOT on new path. Finding best nearby rejoin point.")

		var best_candidate_index = -1        # Index of the best nearby point found so far
		var min_dist_sq_overall = INF      # Min distance for super-fallback
		var closest_geometric_index = -1   # Index of absolute closest for super-fallback

		for i in range(path.size()):
			var tile_pos = path[i]
			var tile_world_pos = _get_world_pos_for_cell(tile_pos)
			if tile_world_pos == Vector2.ZERO: continue # Skip error

			var dist_sq = global_position.distance_squared_to(tile_world_pos)

			# Update overall closest point (for super-fallback)
			if dist_sq < min_dist_sq_overall:
				min_dist_sq_overall = dist_sq
				closest_geometric_index = i

			# Check if this point is within the reasonable rejoin distance
			if dist_sq < REJOIN_DISTANCE_THRESHOLD_SQ:
				# Is this candidate better (further along the path) than the previous best?
				if i > best_candidate_index: # Prioritize higher index among nearby points
					best_candidate_index = i
					# print("Mob ", name, ": Found potential rejoin candidate at index ", i) # Debug

		# Decide which index to use for the jump
		if best_candidate_index != -1:
			# Found a suitable nearby point, prioritizing the one furthest along path
			target_index = best_candidate_index
			print("Mob ", name, ": Jumping - Selected nearby candidate with highest index: ", target_index)
		elif closest_geometric_index != -1:
			# Super-Fallback: No points were nearby, jump to the absolute closest one
			target_index = closest_geometric_index
			print("Mob ", name, ": Jumping - No nearby candidates found, using geometrically closest index: ", target_index)
		else:
			# Error case: Path not empty, but failed to find any point (shouldn't happen)
			printerr("Mob ", name, ": Failed to find any target index in non-empty path!")
			target_index = -1 # Ensure it remains -1


	# --- Set final index and target position ---
	if target_index != -1:
		current_path_index = target_index
		if current_path_index >= path.size():
			print("Mob ", name, ": Calculated path index is at or beyond end of new path (", current_path_index, "). Reached end.")
			current_target_world_pos = Vector2.ZERO
			queue_free() # Reached end immediately
			return
		else:
			current_target_world_pos = _get_world_pos_for_cell(path[current_path_index])
			if current_target_world_pos == Vector2.ZERO:
				printerr("Mob ", name, " failed to get world pos for target index ", current_path_index)
				set_process(false)
			else:
				set_process(true)
				print("Mob ", name, ": New target index=", current_path_index, ", world_pos=", current_target_world_pos)
	else:
		printerr("Mob ", name, ": Failed to determine a target index on the new path.")
		path = []; current_target_world_pos = Vector2.ZERO; set_process(false)
		
func take_damage(damage: int, damage_type: String):
	# Add any armor logic here before applying damage if needed
	var actual_damage = damage # Placeholder for armor calculations
	hp -= actual_damage
	hp = max(0, hp) # Ensure HP doesn't go below 0

	print("Mob ", name, " took ", actual_damage, " damage. HP left: ", hp)

	# --- Update Health Bar ---
	if health_bar:
		health_bar.value = hp
		# Optional: Show bar when damaged, hide if healed to full (unlikely in TD)
		health_bar.visible = true # Usually want to see it once damaged
		# Or keep the logic to hide when full:
		# health_bar.visible = (hp < max_hp) and hp > 0

	if hp <= 0:
		print("Mob ", name, " died!")
		# Optional: Hide bar immediately on death if you have a death animation
		# if health_bar:
		#     health_bar.visible = false
		queue_free()
