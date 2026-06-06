extends Area2D

var player:Player

@onready var collision_shape_2d : CollisionShape2D = $CollisionShape2D
@onready var animated_sprite : AnimatedSprite2D = $AnimatedSprite2D
@onready var game_manager : GameManager = %"GameManager"
@onready var sfxgem : AudioStreamPlayer = %"SfxGem"

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("players") :
		player = body as Player

		game_manager.add_points(10)
		sfxgem.play()

		collision_shape_2d.set_deferred("disabled", true)
		animated_sprite.visible = false
		
		await sfxgem.finished
		queue_free()
