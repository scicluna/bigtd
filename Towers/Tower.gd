extends Node2D

# Properties
@export var price: int = 10
@export var attack_range: int = 200
@export var attack_speed: float = 1.0
@export var damage: int = 10
@export var damage_type: String = "physical"
@export var effects: Array = []
@export var size: Vector2 = Vector2(2, 2)
@export var targeting_mode: String = "first"
@export var projectile_scene: PackedScene = null

# Nodes
@onready var range_area: Area2D = $RangeArea
@onready var attack_timer: Timer = $AttackTimer
@onready var sprite: Sprite2D = $Sprite

var targets: Array = []
var current_target: Node2D = null

func _ready():
	print("Base Tower _ready() called for: ", name) # Check if this runs

	attack_timer.wait_time = attack_speed
	# Ensure timer connection happens ONLY ONCE (check avoids reconnect on reload)
	if not attack_timer.timeout.is_connected(_on_attack_timer_timeout):
		attack_timer.timeout.connect(_on_attack_timer_timeout)

	if range_area:
		print("RangeArea found: ", range_area.name)
		range_area.get_node("CollisionShape2D").shape.radius = attack_range

		# Connect Area signals
		if not range_area.area_entered.is_connected(_on_range_area_entered):
			print("Connecting area_entered...")
			var err = range_area.area_entered.connect(_on_range_area_entered)
			if err != OK: printerr("Failed to connect area_entered: ", err)
		else:
			print("area_entered already connected.")

		if not range_area.area_exited.is_connected(_on_range_area_exited):
			print("Connecting area_exited...")
			var err = range_area.area_exited.connect(_on_range_area_exited)
			if err != OK: printerr("Failed to connect area_exited: ", err)
		else:
			print("area_exited already connected.")
	else:
		printerr("RangeArea node NOT FOUND for tower: ", name) # Check path if this prints

	print("Base Tower _ready() finished for: ", name)

func _on_range_area_entered(area: Area2D):
	if area.is_in_group("mobs"):
		print("Mob entered range: ", area.name) # Debug print
		if not targets.has(area): # Avoid adding duplicates
			targets.append(area)
			 # Start timer only if it wasn't running and we now have targets
			if targets.size() == 1 and attack_timer.is_stopped():
				attack_timer.start()

func _on_range_area_exited(area: Area2D):
	if area.is_in_group("mobs"):
		print("Mob exited range: ", area.name) # Debug print
		targets.erase(area)
		# Stop timer if no targets left
		if targets.is_empty():
			attack_timer.stop()

func _on_attack_timer_timeout():
	if targets.size() > 0:
		current_target = select_target()
		attack(current_target)

func select_target() -> Node2D:
	match targeting_mode:
		"first":
			return targets[0]
		# Add other modes like "strongest" here
		"stopped":
			return null
	return null

func attack(target: Node2D):
	if projectile_scene == null:
		printerr("Projectile scene is not set for tower ", name)
		return
		
	# Ensure target is still valid right before firing
	if not is_instance_valid(target):
		print("Target became invalid right before projectile creation.")
		# Maybe try selecting a new target? For now, just skip.
		targets.erase(target) # Clean up list
		return
		
	print("Attacking target: ", target.name)
	var projectile = projectile_scene.instantiate()
	
	# Instead of direction, pass the target node itself
	projectile.target = target
	projectile.damage = self.damage
	projectile.damage_type = self.damage_type
	projectile.global_position = global_position # Start at tower center
	# --- End Changes ---

	# Add to a safe place (root is often simplest for projectiles)
	get_tree().root.add_child(projectile)
