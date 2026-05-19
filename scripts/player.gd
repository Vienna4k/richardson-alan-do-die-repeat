extends CharacterBody2D

const MAX_SPEED = 250.0
const JUMP_VELOCITY = -400.0
const ACCELERATION = 200.0
const FRICTION = 200.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

func _physics_process(delta: float) -> void:
	
	# Add gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle erratic jump: jump height is slightly unpredictable
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		var unpredictable_jump = randf_range(0.7, 1.3)
		velocity.y = JUMP_VELOCITY * unpredictable_jump

	# Get input direction
	var direction := Input.get_axis("ui_left", "ui_right")
	
	if direction:
		# Weird acceleration: sluggishly drift into max speed
		var target_speed = direction * MAX_SPEED
		velocity.x = move_toward(velocity.x, target_speed, ACCELERATION * delta)
		
		animated_sprite.play("walk")
		animated_sprite.flip_h = direction < 0
	else:
		# Loose, slippery deceleration: feels like you have no balance
		velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)
		
		# Only play idle if we are somewhat stable
		animated_sprite.play("idle")

	move_and_slide()

