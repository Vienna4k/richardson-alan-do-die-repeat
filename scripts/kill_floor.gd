extends Area2D



func _on_body_entered(body: Node2D) -> void:
    # Check if the body that entered is the player
    if body.is_in_group("Players"):
        get_tree().reload_current_scene()

