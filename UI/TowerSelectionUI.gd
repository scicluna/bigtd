# TowerSelectionUI.gd
extends Control

# Signal remains the same: emitted when a tower button is pressed.
signal tower_selected(tower_scene: PackedScene)
signal placement_cancelled() # Keep this too

# --- Configuration ---
# Path to the SPECIFIC builder directory to load towers from.
# Set this path in the Godot Inspector for the TowerSelectionUI node.
# Example: "res://Towers/Builders/TestBuilder"
@export_dir var builder_path: String = "res://Towers/Builders/TestBuilder"

# Naming convention for the main placeable scene within each tower folder
# Assumption: Scene name matches the folder name (e.g., ArrowTower.tscn inside ArrowTower/)
# If different, you'll need to adjust the logic.

# --- Node References ---
@onready var button_container: BoxContainer = $ButtonContainer # Get the HBox or VBox

func _ready():
	if builder_path.is_empty():
		printerr("TowerSelectionUI: Builder Path is not set in the Inspector!")
		return
	populate_tower_buttons()

# Scans the SPECIFIED builder directory and creates buttons
func populate_tower_buttons():
	# Clear any existing buttons first
	for child in button_container.get_children():
		child.queue_free()

	# --- Access the Specific Builder Directory ---
	var dir = DirAccess.open(builder_path)
	if not dir:
		printerr("TowerSelectionUI: Could not open specified builder directory: ", builder_path)
		return

	# --- List Subdirectories (These are the actual tower folders) ---
	var tower_folders = dir.get_directories()
	if tower_folders.is_empty():
		print("TowerSelectionUI: No tower folders found in builder directory: ", builder_path)
		return

	# --- Process Each Tower Subdirectory ---
	for tower_folder_name in tower_folders:
		# Construct the expected path to the main tower scene
		# Assumes scene name matches folder name (e.g., ArrowTower.tscn)
		var scene_file_name = tower_folder_name + ".tscn"
		var scene_path = builder_path.path_join(tower_folder_name).path_join(scene_file_name)

		# --- Check if the Main Scene File Exists ---
		if FileAccess.file_exists(scene_path):
			# --- Load the Scene ---
			var packed_scene = load(scene_path) as PackedScene
			if not packed_scene:
				printerr("TowerSelectionUI: Failed to load scene: ", scene_path)
				continue # Skip this tower

			# --- Create the Button ---
			var button = Button.new()

			# Set button text (use folder name, maybe format it later)
			button.text = tower_folder_name # Basic name formatting

			# Connect the button's pressed signal
			# Use .bind() to pass the loaded PackedScene when the signal is emitted
			button.pressed.connect(_on_tower_button_pressed.bind(packed_scene))

			# Add the button to the container
			button_container.add_child(button)

			print("TowerSelectionUI: Added button for tower '", tower_folder_name, "' from builder '", builder_path, "'")
		else:
			print("TowerSelectionUI: Skipping folder '", tower_folder_name, "' in builder '", builder_path,"'. Main scene not found at: ", scene_path)


# --- Signal Handler (No changes needed here) ---
func _on_tower_button_pressed(selected_scene: PackedScene):
	if selected_scene:
		print("UI requested placement of: ", selected_scene.resource_path)
		tower_selected.emit(selected_scene)
	else:
		printerr("Tower button pressed, but no scene was bound!")
		
# --- Cancellation Logic (No changes needed here) ---
func _cancel_placement():
	print("UI requested placement cancel.")
	placement_cancelled.emit()
