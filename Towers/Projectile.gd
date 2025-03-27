# Projectile.gd
extends Area2D

# Variables set by the tower when the projectile is created
var damage: int
var damage_type: String
var speed: float = 10.0  # Default speed, can be overridden by the tower
var direction: Vector2

func _ready():
	# Connect the body_entered signal to detect collisions
	connect("body_entered", Callable(self, "_on_body_entered"))
	# Optional: Add a timer here if you want the projectile to self-destruct after a time

func _process(delta):
	# Move the projectile in the specified direction at the given speed
	position += direction * speed * delta

func _on_body_entered(body):
	# Check if the collided body is an enemy
	if body.is_in_group("mobs"):
		# Apply damage to the enemy
		body.take_damage(damage, damage_type)
		# Destroy the projectile after hitting
		queue_free()
