class_name Player

extends CharacterBody2D


@export var speed: float = 200.0
@export var jump_velocity: float = -300.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

var COLLECTED_COINS : int = 0




func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var direction := Input.get_axis("left", "right")
	if direction:
		velocity.x = direction * speed
		animated_sprite.play("walk")
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		animated_sprite.play("idle")

	# Flip the sprite depending on direction
	if direction > 0:
		animated_sprite.flip_h = false
	elif direction < 0:
		animated_sprite.flip_h = true

	move_and_slide()
