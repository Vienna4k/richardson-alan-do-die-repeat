extends RigidBody2D

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

# Grab references to the new leg bodies. 
# (Make sure these names exactly match what you named them in the editor!)
@onready var left_leg: RigidBody2D = $LeftLeg
@onready var right_leg: RigidBody2D = $RightLeg

# Feel free to adjust these values in the editor or here to make it feel right
const ASSIST_FORCE: float = 600.0
const LEG_TORQUE: float = 12000.0
const STAND_TORQUE: float = 20000.0
const JUMP_IMPULSE: float = -350.0

func _ready() -> void:
	animated_sprite.animation_finished.connect(_on_animation_finished)
	_start_blink_timer()

func _start_blink_timer() -> void:
	var wait_time: float = randf_range(5.0, 20.0)
	get_tree().create_timer(wait_time).timeout.connect(_play_blink_animation)

func _play_blink_animation() -> void:
	animated_sprite.play("blink")

func _on_animation_finished() -> void:
	if animated_sprite.animation == "blink":
		animated_sprite.play("idle")
		_start_blink_timer()

func _physics_process(delta: float) -> void:
	# RigidBody2D applies gravity automatically, so we skip the gravity addition here!

	# Handle jump (Using a basic velocity check since RigidBody2D doesn't have `is_on_floor()`)
	# Later, if the jumping feels inconsistent, we can add a RayCast2D pointing down to act as floor detection.
	if Input.is_action_just_pressed("jump"):
		# If the character is not falling/rising super fast, let them jump
		if abs(linear_velocity.y) < 20.0:
			apply_central_impulse(Vector2(0.0, JUMP_IMPULSE))

	var direction: float = Input.get_axis("left", "right")
	
	if direction != 0.0:
		# 1. Apply the "assist" to the main body
		apply_central_force(Vector2(direction * ASSIST_FORCE, 0.0))
		
		# 2. Spin the legs! Applying torque will rotate the rigidbodies around their center mass / joints
		# Depending on the friction and shape, spinning them moves the player QWOP-style
		left_leg.apply_torque(direction * LEG_TORQUE)
		right_leg.apply_torque(direction * LEG_TORQUE)
	else:
		# Stand the legs back up when not moving!
		# angle_difference finds the shortest path to 0 rotation (straight down)
		var left_diff: float = angle_difference(left_leg.rotation, 0.0)
		var right_diff: float = angle_difference(right_leg.rotation, 0.0)
		
		# Apply a strong corrective torque to push them towards 0
		left_leg.apply_torque(left_diff * STAND_TORQUE)
		right_leg.apply_torque(right_diff * STAND_TORQUE)
		
		# Apply some artificial breaking (dampening) to stop them from swinging endlessly
		left_leg.apply_torque(-left_leg.angular_velocity * 1000.0)
		right_leg.apply_torque(-right_leg.angular_velocity * 1000.0)
		
	# Flip the sprite visually so they face the right way
	if direction > 0.0:
		animated_sprite.flip_h = false
	elif direction < 0.0:
		animated_sprite.flip_h = true

	# We do NOT run `move_and_slide()` anymore because the physics engine handles RigidBody2D movement!
