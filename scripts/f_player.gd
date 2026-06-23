class_name FPlayer
extends CharacterBody2D

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

# IK Targets and RayCasts
@onready var left_target: Node2D = $LeftTarget
@onready var right_target: Node2D = $RightTarget
@onready var left_ray: RayCast2D = $LeftRay
@onready var right_ray: RayCast2D = $RightRay

# Physical Arm Nodes
@onready var left_arm: RigidBody2D = $LeftArm
@onready var right_arm: RigidBody2D = $RightArm
@onready var left_shoulder: PinJoint2D = $LeftShoulder
@onready var right_shoulder: PinJoint2D = $RightShoulder

# Movement Variables
const MAX_SPEED: float = 300.0
const ACCELERATION: float = 1200.0
const FRICTION: float = 1200.0
const JUMP_VELOCITY: float = -400.0

# Procedural Stepping Variables
const STEP_DISTANCE: float = 10.0    # How far the raycast can get before foot must step
const STEP_SPEED: float = 0.1       # How fast the step Tween is
const STEP_HEIGHT: float = 15.0      # How high the foot arcs up into the air

var is_left_stepping: bool = false
var is_right_stepping: bool = false

var left_tween: Tween
var right_tween: Tween
var left_tween_y: Tween
var right_tween_y: Tween

var is_dead: bool = false
var was_on_floor: bool = true
var spawn_position: Vector2
var bob_time: float = 0.0

var death_charge: float = 0.0
const DEATH_CHARGE_MAX: float = 1.0 # Requires holding the key for 1 second

var carried_corpse: FPlayer = null
var is_carried: bool = false

func _ready() -> void:
	add_to_group("players") # Ensure the main body triggers buttons!
	spawn_position = global_position # Save our initial spawn point
	animated_sprite.animation_finished.connect(_on_animation_finished)
	_start_blink_timer()
	
	# Detach the foot targets from the body.
	left_target.top_level = true
	right_target.top_level = true
	
	# Place the targets exactly on the floor initially so they don't spawn hovering!
	left_ray.force_raycast_update()
	right_ray.force_raycast_update()
	left_target.global_position = left_ray.get_collision_point() if left_ray.is_colliding() else left_ray.to_global(left_ray.target_position)
	right_target.global_position = right_ray.get_collision_point() if right_ray.is_colliding() else right_ray.to_global(right_ray.target_position)

	# Instantly snap the camera if there is one on the player (prevents scene load flash/wig out)
	for child in get_children():
		if child is Camera2D:
			var cam := child as Camera2D
			cam.reset_smoothing()
			break

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
	add_to_group("corpses")
	
	if left_arm: left_arm.hide()
	if right_arm: right_arm.hide()
	
	if carried_corpse:
		carried_corpse.is_carried = false
		carried_corpse.collision_layer |= 6
		carried_corpse = null
	
	# Close eyes for the corpse
	animated_sprite.play("die")
	
	# Hide the IK legs so it's just a dead block body
	var skeleton := get_node_or_null("Skeleton2D") as Skeleton2D
	if skeleton: skeleton.hide()
	

	var stilts := get_node_or_null("LegCollider") as CollisionShape2D
	if stilts: stilts.queue_free()
	
	collision_layer |= 6 
	
	# Wait a bit so the player gets to stare at their failure
	await get_tree().create_timer(1.0).timeout

	var gm: GameManager = get_tree().get_first_node_in_group("game_manager") as GameManager
	
	gm.register_death()
	
	# If we are out of lives, abort the respawn process!
	if gm.current_deaths <= 0:
		print("loser")
		return
	
	# Instantiate a completely new player
	var player_scene: PackedScene = load("res://prefabs/f_player.tscn") as PackedScene
	var new_player: FPlayer = player_scene.instantiate() as FPlayer
	
	# Check the scene for a dedicated SpawnPoint node
	var spawn_points: Array[Node] = get_tree().get_nodes_in_group("spawnpoint")
	
	if spawn_points.size() > 0:
		# Cast the generic Node to a Marker2D so the compiler knows it has a global_position
		var marker: Marker2D = spawn_points[0] as Marker2D
		
		if marker:
			new_player.global_position = marker.global_position
		else:
			new_player.global_position = spawn_position # Fallback if cast fails
	else:
		# Fallback if no spawn points exist
		new_player.global_position = spawn_position
	
	# Move the camera from the old body to the new one smoothly!
	var camera: Camera2D = null
	for child in get_children():
		if child is Camera2D:
			camera = child
			break 
			
	if camera:
		# Detach the camera completely from the corpse
		remove_child(camera)
		
		# Add it securely onto the new player
		new_player.add_child(camera)
		camera.position = Vector2.ZERO
		
		new_player.ready.connect(func() -> void:
			# Force the camera to snap immediately to the new player, killing any trailing smoothing!
			camera.reset_smoothing()
		)
			
	# Safely add the new player to the game world during physics processing
	get_parent().call_deferred("add_child", new_player)

func _physics_process(delta: float) -> void:
	if is_dead:
		if is_carried:
			return # Do not fall or collide while carried
			
		# Corpses should plummet to the earth, sliding to a halt!
		if not is_on_floor():
			velocity += get_gravity() * delta
		else:
			# Skidding friction for a falling corpse
			velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)
		move_and_slide()
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
				animated_sprite.modulate = Color.WHITE
			else:
				# Continue shaking but with decreasing intensity
				var shake_intensity: float = (death_charge / DEATH_CHARGE_MAX) * 5.0
				animated_sprite.position = Vector2(randf_range(-shake_intensity, shake_intensity), randf_range(-shake_intensity, shake_intensity))
				animated_sprite.modulate = Color(1.0, 1.0 - (death_charge / DEATH_CHARGE_MAX), 1.0 - (death_charge / DEATH_CHARGE_MAX))
		
		# If we aren't exploding, do a breathing/walking headbob!
		if death_charge == 0.0:
			var bob_speed: float = 10.0 if abs(velocity.x) > 10.0 else 3.0
			var bob_amount: float = 1.0 if abs(velocity.x) > 10.0 else .5
			bob_time += delta * bob_speed
			animated_sprite.position.y = sin(bob_time) * bob_amount
			animated_sprite.position.x = 0.0
			
			# Arm / carry logic
			if carried_corpse:
				carried_corpse.global_position = global_position + Vector2(20, 0)
				
				# Lock arms and point them at the corpse
				left_arm.freeze = true
				right_arm.freeze = true
				left_arm.global_position = left_shoulder.global_position
				right_arm.global_position = right_shoulder.global_position
				
				left_arm.look_at(carried_corpse.global_position)
				right_arm.look_at(carried_corpse.global_position)
				
				# Drop corpse
				if Input.is_action_just_pressed("pickup"):
					carried_corpse.is_carried = false
					# Restore collisions so it hits the floor and can be stepped on!
					carried_corpse.collision_layer = collision_layer | 6
					carried_corpse.collision_mask = 1 # (Assuming your floor is on Mask 1)
					carried_corpse = null
					
					# Turn physics back on!
					left_arm.freeze = false
					right_arm.freeze = false
			else:
				# Pick up corpse
				if Input.is_action_just_pressed("pickup"):
					var closest := _get_closest_corpse(30.0)
					if closest:
						carried_corpse = closest
						carried_corpse.is_carried = true
						# Completely turn off all collisions so it doesn't act as a ceiling
						carried_corpse.collision_layer = 0
						carried_corpse.collision_mask = 0 
						carried_corpse.velocity = Vector2.ZERO

	# ==== MOVEMENT ====
	if not is_on_floor():
		velocity += get_gravity() * delta

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	var direction: float = Input.get_axis("left", "right")
	
	if direction != 0.0:
		# Slippery acceleration
		velocity.x = move_toward(velocity.x, direction * MAX_SPEED, ACCELERATION * delta)
	else:
		# Slippery deceleration
		velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)

	move_and_slide()
	_handle_procedural_legs()
	was_on_floor = is_on_floor()

func _handle_procedural_legs() -> void:
	# Force the raycasts to update to the current frame's position immediately
	left_ray.force_raycast_update()
	right_ray.force_raycast_update()
	
	# Get the ideal resting place from where the RayCast hits the floor.
	# If in the air, making them reach for the end of the raycast lets them dangle down naturally!
	var l_hit: Vector2 = left_ray.get_collision_point() if left_ray.is_colliding() else left_ray.to_global(left_ray.target_position)
	var r_hit: Vector2 = right_ray.get_collision_point() if right_ray.is_colliding() else right_ray.to_global(right_ray.target_position)
	
	# How far the foot currently is from where it SHOULD be
	var l_dist := left_target.global_position.distance_to(l_hit)
	var r_dist := right_target.global_position.distance_to(r_hit)
	
	if not is_on_floor():
		# When in the air, legs just dangle smoothly towards the raycast tips
		if left_tween and left_tween.is_valid(): left_tween.kill()
		if right_tween and right_tween.is_valid(): right_tween.kill()
		if left_tween_y and left_tween_y.is_valid(): left_tween_y.kill()
		if right_tween_y and right_tween_y.is_valid(): right_tween_y.kill()
		
		left_target.global_position = left_target.global_position.lerp(l_hit, 20.0 * get_physics_process_delta_time())
		right_target.global_position = right_target.global_position.lerp(r_hit, 20.0 * get_physics_process_delta_time())
		
		# Reset any active step states so they instantly start stepping again when landing
		is_left_stepping = false
		is_right_stepping = false
		return
		
	if is_on_floor() and not was_on_floor:
		# We just landed! Snap the legs directly to the floor instantly without triggering a stepping animation.
		# They were already dangling right above it, so this connects them seamlessly.
		left_target.global_position = l_hit
		right_target.global_position = r_hit
		return
	
	# We want them to take turns, BUT if one gets extremely far behind while the other is stepping,
	# it is allowed to step simultaneously so it doesn't get ripped off!
	if l_dist > STEP_DISTANCE and not is_left_stepping:
		if not is_right_stepping or l_dist > STEP_DISTANCE * 1.5:
			_step_leg(left_target, l_hit, true)
			
	if r_dist > STEP_DISTANCE and not is_right_stepping:
		if not is_left_stepping or r_dist > STEP_DISTANCE * 1.5:
			_step_leg(right_target, r_hit, false)

func _step_leg(target_node: Node2D, base_target_pos: Vector2, is_left: bool) -> void:
	var overstep: float = 0.0
	if is_on_floor():
		# Dynamic stride! The faster we go, the further ahead we reach, but capped so we don't break the IK
		overstep = clamp(velocity.x * (STEP_SPEED * 1.2), -30.0, 30.0)
		
	var final_target_x: float = base_target_pos.x + overstep
	
	# Lift the foot UP (ease out), then slam it DOWN (ease in) for a realistic arc
	var height_bonus : float = STEP_HEIGHT if is_on_floor() else 2.0
	var mid_y: float = min(target_node.global_position.y, base_target_pos.y) - height_bonus
	
	if is_left:
		is_left_stepping = true
		if left_tween and left_tween.is_valid(): left_tween.kill()
		if left_tween_y and left_tween_y.is_valid(): left_tween_y.kill()
		
		left_tween = create_tween()
		left_tween_y = create_tween()
		
		left_tween.tween_property(target_node, "global_position:x", final_target_x, STEP_SPEED)
		left_tween_y.tween_property(target_node, "global_position:y", mid_y, STEP_SPEED / 2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		left_tween_y.tween_property(target_node, "global_position:y", base_target_pos.y, STEP_SPEED / 2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		
		left_tween.finished.connect(func() -> void: is_left_stepping = false)
	else:
		is_right_stepping = true
		if right_tween and right_tween.is_valid(): right_tween.kill()
		if right_tween_y and right_tween_y.is_valid(): right_tween_y.kill()
		
		right_tween = create_tween()
		right_tween_y = create_tween()
		
		right_tween.tween_property(target_node, "global_position:x", final_target_x, STEP_SPEED)
		right_tween_y.tween_property(target_node, "global_position:y", mid_y, STEP_SPEED / 2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		right_tween_y.tween_property(target_node, "global_position:y", base_target_pos.y, STEP_SPEED / 2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		
		right_tween.finished.connect(func() -> void: is_right_stepping = false)

func _get_closest_corpse(max_dist: float) -> FPlayer:
	var closest: FPlayer = null
	var best_dist: float = max_dist
	
	for node in get_tree().get_nodes_in_group("corpses"):
		# Explicitly cast the generic Node to your FPlayer class
		var corpse := node as FPlayer
		
		# Check if the cast was successful (it is an FPlayer) and not self
		if corpse and corpse != self:
			var d := global_position.distance_to(corpse.global_position)
			if d < best_dist:
				best_dist = d
				closest = corpse
				
	return closest
