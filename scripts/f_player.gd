extends CharacterBody2D
class_name FPlayer

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var death_sound: AudioStreamPlayer = $AudioStreamPlayer

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
const STEP_DISTANCE: float = 10.0
const STEP_SPEED: float = 0.1
const STEP_HEIGHT: float = 15.0

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
const DEATH_CHARGE_MAX: float = 1.0 

var carried_corpse: FPlayer = null
var is_carried: bool = false

var facing_direction: int = 1 

@onready var spawn_points: Array[Checkpoint] = []
var currentCheckpoint: Checkpoint

# ==== NEW: Variables to store the base leg spacing ====
var left_ray_base_x: float
var right_ray_base_x: float
var left_ray_target_base_x: float
var right_ray_target_base_x: float

func _ready() -> void:
	add_to_group("players") 
	spawn_position = global_position 
	animated_sprite.animation_finished.connect(_on_animation_finished)
	_start_blink_timer()
	
	# ==== NEW: Save the initial offset of the raycasts ====
	left_ray_base_x = left_ray.position.x
	right_ray_base_x = right_ray.position.x
	left_ray_target_base_x = left_ray.target_position.x
	right_ray_target_base_x = right_ray.target_position.x
	
	left_target.top_level = true
	right_target.top_level = true
	
	left_ray.force_raycast_update()
	right_ray.force_raycast_update()
	left_target.global_position = left_ray.get_collision_point() if left_ray.is_colliding() else left_ray.to_global(left_ray.target_position)
	right_target.global_position = right_ray.get_collision_point() if right_ray.is_colliding() else right_ray.to_global(right_ray.target_position)

	for child in get_children():
		if child is Camera2D:
			var cam := child as Camera2D
			cam.reset_smoothing()
			break
	
	for node in get_tree().get_nodes_in_group("spawnpoint"):
		if node is Checkpoint:
			spawn_points.append(node)
	
	currentCheckpoint = spawn_points[0]

func _start_blink_timer() -> void:
	var wait_time: float = randf_range(5.0, 20.0)
	get_tree().create_timer(wait_time).timeout.connect(_play_blink_animation)

func _play_blink_animation() -> void:
	if is_dead: return 
	animated_sprite.play("blink")

func _on_animation_finished() -> void:
	if animated_sprite.animation == "blink":
		if not is_dead: 
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
	
	animated_sprite.play("die")
	death_sound.play()

	var skeleton := get_node_or_null("Skeleton2D") as Skeleton2D
	if skeleton: skeleton.hide()

	var stilts := get_node_or_null("LegCollider") as CollisionShape2D
	if stilts: stilts.queue_free()
	
	collision_layer |= 6 
	
	await get_tree().create_timer(1.0).timeout

	var gm: GameManager = get_tree().get_first_node_in_group("game_manager") as GameManager
	
	gm.register_death()
	
	if gm.current_deaths <= 0:
		print("loser")
		return
	
	var player_scene : PackedScene = load("res://prefabs/f_player.tscn")
	var new_player : FPlayer = player_scene.instantiate() as FPlayer
	
	if spawn_points.size() > 0:
		for checkpoint in spawn_points:
			if checkpoint.isMostRecentCheckpoint:
				currentCheckpoint = checkpoint
		
		if currentCheckpoint:
			new_player.global_position = currentCheckpoint.global_position
		else:
			new_player.global_position = spawn_position
	else:
		new_player.global_position = spawn_position
	
	var camera: Camera2D = null
	for child in get_children():
		if child is Camera2D:
			camera = child
			break 
			
	if camera:
		remove_child(camera)
		new_player.add_child(camera)
		camera.position = Vector2.ZERO
		
		new_player.ready.connect(func() -> void:
			camera.reset_smoothing()
			if not camera.get("is_map_open"):
				camera.make_current()
		)
			
	get_parent().call_deferred("add_child", new_player)

func setNewCheckpoint(node: Checkpoint) -> void:
	for _checkpoint in spawn_points:
		_checkpoint.isMostRecentCheckpoint = false
	
	node.isMostRecentCheckpoint = true

func _physics_process(delta: float) -> void:
	if is_dead:
		if is_carried:
			return 
			
		if not is_on_floor():
			velocity += get_gravity() * delta
		else:
			velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)
		move_and_slide()
		return

	if Input.is_action_pressed("kill"):
		death_charge += delta
		var shake_intensity: float = (death_charge / DEATH_CHARGE_MAX) * 5.0
		animated_sprite.position = Vector2(randf_range(-shake_intensity, shake_intensity), randf_range(-shake_intensity, shake_intensity))
		
		animated_sprite.modulate = Color(1.0, 1.0 - (death_charge / DEATH_CHARGE_MAX), 1.0 - (death_charge / DEATH_CHARGE_MAX))
		
		if death_charge >= DEATH_CHARGE_MAX:
			animated_sprite.position = Vector2.ZERO 
			animated_sprite.modulate = Color.WHITE 
			die()
			return
	else:
		if death_charge > 0.0:
			death_charge -= delta * 2.0 
			if death_charge <= 0.0:
				death_charge = 0.0
				animated_sprite.modulate = Color.WHITE
			else:
				var shake_intensity: float = (death_charge / DEATH_CHARGE_MAX) * 5.0
				animated_sprite.position = Vector2(randf_range(-shake_intensity, shake_intensity), randf_range(-shake_intensity, shake_intensity))
				animated_sprite.modulate = Color(1.0, 1.0 - (death_charge / DEATH_CHARGE_MAX), 1.0 - (death_charge / DEATH_CHARGE_MAX))
		
		if death_charge == 0.0:
			var bob_speed: float = 10.0 if abs(velocity.x) > 10.0 else 3.0
			var bob_amount: float = 1.0 if abs(velocity.x) > 10.0 else .5
			bob_time += delta * bob_speed
			animated_sprite.position.y = sin(bob_time) * bob_amount
			animated_sprite.position.x = 0.0
			
			if carried_corpse:
				carried_corpse.global_position = global_position + Vector2(27 * facing_direction, 0)
				
				left_arm.freeze = true
				right_arm.freeze = true
				left_arm.global_position = left_shoulder.global_position
				right_arm.global_position = right_shoulder.global_position
				
				left_arm.look_at(carried_corpse.global_position)
				right_arm.look_at(carried_corpse.global_position)
				
				if Input.is_action_just_pressed("pickup"):
					carried_corpse.is_carried = false
					carried_corpse.collision_layer = collision_layer | 6
					carried_corpse.collision_mask = 1 
					carried_corpse = null
					
					left_arm.freeze = false
					right_arm.freeze = false
			else:
				if Input.is_action_just_pressed("pickup"):
					var closest := _get_closest_corpse(30.0)
					if closest:
						carried_corpse = closest
						carried_corpse.is_carried = true
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
		var new_facing: int = sign(direction)
		if new_facing != facing_direction:
			_flip_player(new_facing)
			
		velocity.x = move_toward(velocity.x, direction * MAX_SPEED, ACCELERATION * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)

	move_and_slide()
	_handle_procedural_legs()
	was_on_floor = is_on_floor()

func _flip_player(new_dir: int) -> void:
	facing_direction = new_dir
	
	animated_sprite.flip_h = (facing_direction == -1)
	
	var skeleton := get_node_or_null("Skeleton2D") as Skeleton2D
	if skeleton:
		skeleton.scale.x = facing_direction
		
	# ==== UPDATED: Safely multiply the base values by the facing direction ====
	left_ray.position.x = left_ray_base_x * facing_direction
	right_ray.position.x = right_ray_base_x * facing_direction
	left_ray.target_position.x = left_ray_target_base_x * facing_direction
	right_ray.target_position.x = right_ray_target_base_x * facing_direction

func _handle_procedural_legs() -> void:
	left_ray.force_raycast_update()
	right_ray.force_raycast_update()
	
	var l_hit: Vector2 = left_ray.get_collision_point() if left_ray.is_colliding() else left_ray.to_global(left_ray.target_position)
	var r_hit: Vector2 = right_ray.get_collision_point() if right_ray.is_colliding() else right_ray.to_global(right_ray.target_position)
	
	var l_dist := left_target.global_position.distance_to(l_hit)
	var r_dist := right_target.global_position.distance_to(r_hit)
	
	if not is_on_floor():
		if left_tween and left_tween.is_valid(): left_tween.kill()
		if right_tween and right_tween.is_valid(): right_tween.kill()
		if left_tween_y and left_tween_y.is_valid(): left_tween_y.kill()
		if right_tween_y and right_tween_y.is_valid(): right_tween_y.kill()
		
		left_target.global_position = left_target.global_position.lerp(l_hit, 20.0 * get_physics_process_delta_time())
		right_target.global_position = right_target.global_position.lerp(r_hit, 20.0 * get_physics_process_delta_time())
		
		is_left_stepping = false
		is_right_stepping = false
		return
		
	if is_on_floor() and not was_on_floor:
		left_target.global_position = l_hit
		right_target.global_position = r_hit
		return
	
	if l_dist > STEP_DISTANCE and not is_left_stepping:
		if not is_right_stepping or l_dist > STEP_DISTANCE * 1.5:
			_step_leg(left_target, l_hit, true)
			
	if r_dist > STEP_DISTANCE and not is_right_stepping:
		if not is_left_stepping or r_dist > STEP_DISTANCE * 1.5:
			_step_leg(right_target, r_hit, false)

func _step_leg(target_node: Node2D, base_target_pos: Vector2, is_left: bool) -> void:
	var overstep: float = 0.0
	if is_on_floor():
		overstep = clamp(velocity.x * (STEP_SPEED * 1.2), -30.0, 30.0)
		
	var final_target_x: float = base_target_pos.x + overstep
	
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
		var corpse := node as FPlayer
		if corpse and corpse != self:
			var d := global_position.distance_to(corpse.global_position)
			if d < best_dist:
				best_dist = d
				closest = corpse
				
	return closest