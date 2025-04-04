extends Node2D


@onready var tower_selection_ui: Control = %TowerSelectionUi
@onready var tilemap_layer: TileMapLayer = %TileMapLayer
@onready var towers_container: Node2D = %Towers

# --- State Variables ---
var selected_tower_scene: PackedScene = null
var is_placing_tower: bool = false
var ghost_tower_instance: Node2D = null
# Add player resources later, e.g., var player_gold: int = 100

func _ready():
	# Connect to signals from the UI
	if tower_selection_ui:
		tower_selection_ui.tower_selected.connect(_on_tower_selected_for_placement)
		tower_selection_ui.placement_cancelled.connect(_on_placement_cancelled)
	else:
		printerr("MainGame cannot find TowerSelectionUI node!")

	if not tilemap_layer:
		printerr("MainGame cannot find TileMapLayer node!")
	if not towers_container:
		printerr("MainGame requires a Node2D named 'Towers' to place towers into.")
		
func _process(delta: float) -> void:
	if is_placing_tower:
		if ghost_tower_instance == null and selected_tower_scene != null:
			ghost_tower_instance = selected_tower_scene.instantiate()
			 # Make it look like a ghost (semi-transparent)
			ghost_tower_instance.modulate = Color(1, 1, 1, 0.5)
			 # Add it somewhere temporarily, maybe directly to self
			add_child(ghost_tower_instance)
			
		if ghost_tower_instance != null:
			ghost_tower_instance.targeting_mode = "passive"
			var mouse_pos = get_global_mouse_position()
			var tilemap_local_pos = tilemap_layer.to_local(mouse_pos)
			var cell_coord = tilemap_layer.local_to_map(tilemap_local_pos)
			var cell_center_local = tilemap_layer.map_to_local(cell_coord) # Adjust for center as needed
			ghost_tower_instance.global_position = tilemap_layer.to_global(cell_center_local)

			 # Optional: Change color based on validity
			if tilemap_layer.is_valid_tower_spot(cell_coord):
				ghost_tower_instance.modulate = Color(0,1,0,0.5)
			else:
				ghost_tower_instance.modulate = Color(1, 0, 0, 0.5) # Red tint

# Called when the UI emits 'tower_selected'
func _on_tower_selected_for_placement(tower_scene: PackedScene):
	# Basic check: Do we have enough gold? (Implement later)
	# var tower_cost = tower_scene.instance().price # Need a reliable way to get cost
	# if player_gold >= tower_cost:
	print("Entering placement mode for: ", tower_scene.resource_path)
	selected_tower_scene = tower_scene
	is_placing_tower = true
	# Maybe change mouse cursor here: Input.set_custom_mouse_cursor(...)
	# else:
	#    print("Not enough gold!")
	#    _cancel_placement_mode() # Exit if can't afford

# Called when UI emits 'placement_cancelled' or via input
func _on_placement_cancelled():
	_cancel_placement_mode()
	
	# --- Input Handling for Placement ---
func _unhandled_input(event: InputEvent):
	if not is_placing_tower:
		return # Only handle input if actively placing

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			# --- Try to Place Tower ---
			var mouse_pos = get_global_mouse_position()
			_attempt_tower_placement(mouse_pos)
			# Consume the event so other things don't react to this click
			get_viewport().set_input_as_handled()

		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			# --- Cancel Placement on Right Click ---
			print("Placement cancelled by right-click.")
			_cancel_placement_mode()
			get_viewport().set_input_as_handled()

		elif event.is_action_pressed("ui_cancel"): # Escape key by default
			 # --- Cancel Placement on Escape Key ---
			print("Placement cancelled by Escape key.")
			_cancel_placement_mode()
			get_viewport().set_input_as_handled()

func _attempt_tower_placement(world_position: Vector2):
	if not is_instance_valid(tilemap_layer) or selected_tower_scene == null:
		printerr("Cannot place tower: Tilemap invalid or no tower selected.")
		_cancel_placement_mode()
		return

	# Convert world position to tilemap cell coordinates
	var tilemap_local_pos = tilemap_layer.to_local(world_position)
	var cell_coord = tilemap_layer.local_to_map(tilemap_local_pos)

	print("Attempting placement at cell: ", cell_coord)

	# Ask the TileMapLayer script if this spot is valid
	# You might need to pass the tower size later if towers aren't 1x1
	if tilemap_layer.is_valid_tower_spot(cell_coord):
		 # --- Placement Success ---
		print("Placement valid!")

		# Instantiate the selected tower
		var new_tower = selected_tower_scene.instantiate()

		# Calculate position: map_to_local gives top-left corner, adjust for center
		var cell_center_local = tilemap_layer.map_to_local(cell_coord) # Add half tile size? Check TileMap settings
		# If TileMap Pivot Offset is Center, map_to_local might already be centered. Test this.
		# If top-left, adjust: cell_center_local += tilemap_layer.tile_set.tile_size / 2.0

		new_tower.global_position = tilemap_layer.to_global(cell_center_local)

		# Add to the dedicated container
		towers_container.add_child(new_tower)

		# Tell the tilemap the tile is occupied (important for pathing/future placement)
		tilemap_layer.place_tower(cell_coord) # Ensure place_tower marks tile in occupied_tiles

		# Deduct cost (implement later)
		# player_gold -= tower_cost

		print("Tower placed successfully at ", cell_coord)

		# Exit placement mode
		_cancel_placement_mode()
	else:
		# --- Placement Failed ---
		print("Placement invalid at cell: ", cell_coord)
		# Optional: Play a "cannot place" sound or visual effect


func _cancel_placement_mode():
	if is_placing_tower:
		print("Exiting placement mode.")
		is_placing_tower = false
		selected_tower_scene = null

	# --- Add Ghost Cleanup Here ---
	if is_instance_valid(ghost_tower_instance): # Important: check if it exists and is valid
		ghost_tower_instance.queue_free()
		print("GHOST TOWER INSTANCE:", ghost_tower_instance)
	ghost_tower_instance = null # Always clear the reference
	#
