class_name simple_enemy

extends Node2D

@export var speed : float = 10
@onready var ray_cast_left : RayCast2D = $RayCastLeft
@onready var ray_cast_right : RayCast2D = $RayCastRight
var facing_left : bool = true

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

# Called when the node enters the scene tree for the first time.
func _physics_process(delta: float) -> void:
	if ray_cast_left.is_colliding():
		facing_left = false
		animated_sprite.flip_h = true

	if ray_cast_right.is_colliding():
		facing_left = true
		animated_sprite.flip_h = false

	if facing_left:
		position.x += -speed * delta
	else:
		position.x += speed * delta
	
func stomp() -> void:
	#future stomp anim

	$CollisionShape2D.set_deferred("disabled", true)
	$Hitbox/CollisionShape2D.set_deferred("disabled", true)

	queue_free()