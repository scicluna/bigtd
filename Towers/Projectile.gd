# Projectile.gd
extends Node2D

# Variables set by the tower when the projectile is created
var damage: int
var damage_type: String
var speed: float = 250.0  # Default/Fallback speed (can be set by tower)
var target: Node2D = null # Store the target node

@onready var hit_box = $HitBox
@onready var sprite: Sprite2D = $Sprite2D # Assuming your visual node is named Sprite

const HIT_THRESHOLD_SQ = 10.0 * 10.0 # Use squared distance for efficiency

func _ready():
	pass
	
func _process(delta):
	# 1. Check if the target is still valid
	if not is_instance_valid(target):
		# Target destroyed or removed, projectile should probably disappear
		print("Projectile target lost.")
		queue_free()
		return # Stop processing

	# 2. Calculate direction towards the target's CURRENT position
	var direction_to_target = (target.global_position - global_position).normalized()

	# 3. Rotate to face the target
	#    look_at points the Node2D's +Y axis towards the target.
	#    If your sprite points RIGHT (+X) when Node2D rotation is 0, add PI/2.
	#    If your sprite points UP (+Y) when Node2D rotation is 0, use look_at directly.
	#    If your sprite points diagonally, ADJUST the sprite node's rotation within
	#    the Projectile scene so it points UP or RIGHT, then use one of the below.

	# Option A: If sprite points UP (+Y) when rotation=0
	look_at(target.global_position)

	# Option B: If sprite points RIGHT (+X) when rotation=0
	# rotation = direction_to_target.angle()

	# --- Choose Option A or B based on your sprite's orientation ---
	# Assuming Option A (Sprite points UP) for now. Delete Option B if using A.

	# 4. Move towards the target
	global_position += direction_to_target * speed * delta

	# 5. Optional: Check proximity in _process as a backup hit detection
	#    Useful if physics frames/Area2D checks somehow miss a fast target/projectile
	var distance_sq = global_position.distance_squared_to(target.global_position)
	if distance_sq < HIT_THRESHOLD_SQ:
		print("Projectile hit target (proximity check).")
		_hit_target(target) # Call the hit function
		
func _hit_target(target: Node2D):
	var mob_hit = target.get_parent()
	# Apply damage (make sure mob has take_damage)
	if mob_hit.has_method("take_damage"):
		mob_hit.take_damage(damage, damage_type)
	else:
		printerr("Hit object ", mob_hit.name, " does not have take_damage method!")

	# Destroy the projectile
	queue_free()
