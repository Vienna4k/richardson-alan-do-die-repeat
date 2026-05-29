extends Area2D

var player:Player
@export var speed_boost : float = 10

@onready var collision_shape_2d : CollisionShape2D = $CollisionShape2D
@onready var animated_sprite : AnimatedSprite2D = $AnimatedSprite2D

@onready var speed_buff : Timer = $SpeedBuff

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("players") :
		player = body as Player

		player.COLLECTED_COINS += 1
		print(player.COLLECTED_COINS)
		print(player.speed)
		player.speed += speed_boost
		
		collision_shape_2d.set_deferred("disabled", true)
		animated_sprite.visible = false
		
		speed_buff.start()
		
		# Reference to levelManager class
		if get_tree().current_scene is levelManager:
			(get_tree().current_scene as levelManager)._on_coin_collected(self)
		elif owner is levelManager:
			(owner as levelManager)._on_coin_collected(self)
		
		queue_free()


