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

const STAND_ANGLE_LEFT: float = deg_to_rad(5.0)  # Splay left leg slightly outward
const STAND_ANGLE_RIGHT: float = deg_to_rad(-5.0)  # Splay right leg slightly outward

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
	
	# Fix the collision layer! Make sure the dead body exists on Layers 2 and 4 
	# so that the next player's legs (which use collision masks 2 and 4) stand on it!
	collision_layer |= 6 # This uses bitwise OR to actively add layers 2 and 3 (values 2 and 4)
	
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
		# Wait for the corpse to organically hit the ground and settle before freezing it!
		if not freeze and linear_velocity.length() < 10.0 and floor_raycast.is_colliding():
			freeze = true
			freeze_mode = RigidBody2D.FREEZE_MODE_STATIC
			
			# Spawn a pure StaticBody2D duplicate just for the legs to stand on cleanly!
			var solid_platform : StaticBody2D = StaticBody2D.new()
			# Put this platform purely on physics layers 2 and 3 so ONLY the player legs stand on it
			# Do NOT put it in the 'players' group so it doesn't double-trigger buttons!
			solid_platform.collision_layer = 6
			solid_platform.collision_mask = 0
			
			# Give it a brand new shape of identical size to the player
			var platform_shape : CollisionShape2D = CollisionShape2D.new()
			var rect := RectangleShape2D.new() as RectangleShape2D
			rect.size = Vector2(16, 16) # From your f_player.tscn shape
			platform_shape.shape = rect
			solid_platform.add_child(platform_shape)
			
			# Give it full traction so the player doesn't slip off
			solid_platform.physics_material_override = PhysicsMaterial.new()
			solid_platform.physics_material_override.friction = 1.0
			
			add_child(solid_platform)
			
			# Now remove the RigidBody's ability to touch the player's legs so they don't fight
			collision_layer &= ~6 # Remove layers 2 and 3 from the main corpse body
				
		# Corpses don't move or take input!
		return

	# Add a self-destruct key for testing the puzzle mechanic!
	if Input.is_action_pressed("kill"):
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
		# 1. Apply assist
		apply_central_force(Vector2(direction * ASSIST_FORCE, 0.0))
		
		# 2. Drive the legs
		run_time += direction * delta * STRIDE_SPEED
		
		# The left leg targets the current motor time, the right leg is permanently offset
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
	
	if direction > 0.0:
		animated_sprite.flip_h = false
	elif direction < 0.0:
		animated_sprite.flip_h = true
