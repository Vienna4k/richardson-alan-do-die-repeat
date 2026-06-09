class_name FPlayer
extends RigidBody2D

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var left_leg: RigidBody2D = $LeftLeg
@onready var right_leg: RigidBody2D = $RightLeg
@onready var floor_raycast: RayCast2D = $FloorRayCast  # We will use this to detect the floor!

const ASSIST_FORCE: float = 1000.0
const LEG_TORQUE: float = 30000.0
const STAND_TORQUE: float = 30000.0
const JUMP_IMPULSE: float = -1050.0
const STRIDE_SPEED: float = 24.0

const STAND_ANGLE_LEFT: float = deg_to_rad(10.0)  # Splay left leg slightly outward
const STAND_ANGLE_RIGHT: float = deg_to_rad(-10.0)  # Splay right leg slightly outward

var run_time: float = 0.0

var is_dead: bool = false
var spawn_position: Vector2

var death_charge: float = 0.0
const DEATH_CHARGE_MAX: float = 1.0 # Requires holding the key for 1 second

func _ready() -> void:
	add_to_group("players") # Ensure the main body triggers buttons!
	spawn_position = global_position # Save our initial spawn point
	animated_sprite.animation_finished.connect(_on_animation_finished)
	_start_blink_timer()

func _start_blink_timer() -> void:
	var wait_time: float = randf_range(5.0, 20.0)
	get_tree().create_timer(wait_time).timeout.connect(_play_blink_animation)

func _play_blink_animation() -> void:
	if is_dead: return # Do not blink if dead!
	animated_sprite.play("blink")

func _on_animation_finished() -> void:
	if animated_sprite.animation == "blink":
		if not is_dead: # Optionally, corpses could keep blinking, but let's keep them still!
			animated_sprite.play("idle")
			_start_blink_timer()

func die() -> void:
	if is_dead: return
	is_dead = true
	
	# Close eyes for the corpse
	animated_sprite.play("die")
	
	# Destroy the legs and joints so it's just a body block
	if is_instance_valid(left_leg): left_leg.queue_free()
	if is_instance_valid(right_leg): right_leg.queue_free()
	if has_node("LeftHip"): $LeftHip.queue_free()
	if has_node("RightHip"): $RightHip.queue_free()
	
	# Make the corpse much heavier and sluggish so it's a solid puzzle piece
	mass = 60.0
	linear_damp = 15.0
	
	# Give the corpse a frictionless material! In Godot, sliding a 
	# RigidBody on top of another RigidBody catches on the corners and causes 
	# violent physics jitter. Zero friction makes it a smooth platform!
	var mat : PhysicsMaterial = PhysicsMaterial.new()
	mat.friction = 0.0
	physics_material_override = mat
	
	# Instantiate a completely new player at the last spawn position!
	var player_scene: PackedScene = load("res://prefabs/f_player.tscn") as PackedScene
	var new_player: FPlayer = player_scene.instantiate() as FPlayer
	new_player.global_position = spawn_position
	
	# Move the camera from the old body to the new one!
	for child in get_children():
		if child is Camera2D:
			remove_child(child)
			new_player.add_child(child)
			break # Assuming you only have one camera
			
	# Use call_deferred to safely add the new player to the game world during physics processing
	get_parent().call_deferred("add_child", new_player)

func _physics_process(delta: float) -> void:
	if is_dead:
		# Corpses don't move or take input!
		return

	# Add a self-destruct key for testing the puzzle mechanic!
	if Input.is_action_pressed("kill") or Input.is_key_pressed(KEY_K):
		death_charge += delta
		var shake_intensity: float = (death_charge / DEATH_CHARGE_MAX) * 5.0
		animated_sprite.position = Vector2(randf_range(-shake_intensity, shake_intensity), randf_range(-shake_intensity, shake_intensity))
		
		# Give a reddish tint that gets stronger
		animated_sprite.modulate = Color(1.0, 1.0 - (death_charge / DEATH_CHARGE_MAX), 1.0 - (death_charge / DEATH_CHARGE_MAX))
		
		if death_charge >= DEATH_CHARGE_MAX:
			animated_sprite.position = Vector2.ZERO # Reset shake
			animated_sprite.modulate = Color.WHITE # Reset color for the corpse
			die()
			return
	else:
		if death_charge > 0.0:
			death_charge -= delta * 2.0 # Slowly lose charge if released early
			if death_charge <= 0.0:
				death_charge = 0.0
				animated_sprite.position = Vector2.ZERO
				animated_sprite.modulate = Color.WHITE
			else:
				# Continue shaking but with decreasing intensity
				var shake_intensity: float = (death_charge / DEATH_CHARGE_MAX) * 5.0
				animated_sprite.position = Vector2(randf_range(-shake_intensity, shake_intensity), randf_range(-shake_intensity, shake_intensity))
				animated_sprite.modulate = Color(1.0, 1.0 - (death_charge / DEATH_CHARGE_MAX), 1.0 - (death_charge / DEATH_CHARGE_MAX))

	if Input.is_action_just_pressed("jump"):
		# Only jump if the RayCast is actually hitting the floor
		if floor_raycast.is_colliding():
			apply_central_impulse(Vector2(0.0, JUMP_IMPULSE))

	var direction: float = Input.get_axis("left", "right")
	
	if direction != 0.0:
		# 1. Apply the "assist" to the main body
		apply_central_force(Vector2(direction * ASSIST_FORCE, 0.0))
		
		# 2. Drive the legs as synchronized motors! This creates a guaranteed, perfectly timed stride.
		run_time += direction * delta * STRIDE_SPEED
		
		# The left leg targets the current motor time, the right leg is permanently offset by PI (180 degrees)
		var left_target: float = run_time
		var right_target: float = run_time + PI
		
		var left_diff: float = angle_difference(left_leg.rotation, left_target)
		var right_diff: float = angle_difference(right_leg.rotation, right_target)
		
		left_leg.apply_torque(left_diff * LEG_TORQUE)
		right_leg.apply_torque(right_diff * LEG_TORQUE)
		
		# Dampening keeps them tightly synced to the stride timer instead of violently overshooting
		left_leg.apply_torque(-left_leg.angular_velocity * 1000.0)
		right_leg.apply_torque(-right_leg.angular_velocity * 1000.0)
	else:
		# When jumping from a standstill or just turning around, we don't want the legs to snap to 0 immediately
		# Let's reset the run target to whatever the leg average is so that taking off again is smooth
		run_time = (left_leg.rotation + right_leg.rotation) / 2.0
		
		# Stand the legs back up into a stable 'A' frame pose
		var left_diff: float = angle_difference(left_leg.rotation, STAND_ANGLE_LEFT)
		var right_diff: float = angle_difference(right_leg.rotation, STAND_ANGLE_RIGHT)
		
		# Apply a strong corrective torque to push them towards their standing angles
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
