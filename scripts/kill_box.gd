extends Area2D





func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("players"):
		#if body.has_method("die"):
			#body.die()
		#else:
			get_tree().reload_current_scene()
