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
	attack_timer.wait_time = attack_speed
	attack_timer.connect("timeout", Callable(self, "_on_attack_timer_timeout"))
	range_area.get_node("CollisionShape2D").shape.radius = attack_range

func _on_range_area_entered(area):
	if area.is_in_group("mobs"):
		targets.append(area.get_parent())

func _on_range_area_exited(area):
	if area.is_in_group("mobs"):
		targets.erase(area.get_parent())

func _on_attack_timer_timeout():
	if targets.size() > 0:
		current_target = select_target()
		attack(current_target)

func select_target() -> Node2D:
	match targeting_mode:
		"first":
			return targets[0]
		# Add other modes like "strongest" here
	return null

func attack(target: Node2D):
	var projectile = projectile_scene.instantiate()
	
	projectile.damage = self.damage
	projectile.damage_type = self.damage_type
	projectile.direction = (target.global_position - global_position).normalized()
	projectile.position = global_position
	
	get_parent().add_child(projectile)
