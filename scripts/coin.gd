extends Area2D



func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("Players") :
		var playerref:Player
		playerref = body as Player

		playerref.COLLECTED_COINS += 1
		
		# Reference to levelManager class
		if get_tree().current_scene is levelManager:
			(get_tree().current_scene as levelManager)._on_coin_collected(self)
		elif owner is levelManager:
			(owner as levelManager)._on_coin_collected(self)
		
		queue_free()
