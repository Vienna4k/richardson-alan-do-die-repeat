extends Area2D

var player:Player

@onready var collision_shape_2d : CollisionShape2D = $CollisionShape2D
@onready var animated_sprite : AnimatedSprite2D = $AnimatedSprite2D
@onready var game_manager : GameManager = %"GameManager"

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("players") :
		player = body as Player

		game_manager.add_points(1)

		
		collision_shape_2d.set_deferred("disabled", true)
		animated_sprite.visible = false
		
		# Reference to GameManager class
		if get_tree().current_scene is GameManager:
			(get_tree().current_scene as GameManager)._on_coin_collected(self)
		elif owner is GameManager:
			(owner as GameManager)._on_coin_collected(self)
		
		queue_free()
