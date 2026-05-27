extends Area2D



func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("Players") :
		var playerref:Player
		playerref = body as Player

		playerref.COLLECTED_COINS += 1


		queue_free()
