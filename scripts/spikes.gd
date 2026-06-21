extends Area2D



func _on_body_entered(body: Node2D) -> void:
    if body.is_in_group("players"):
        if body is FPlayer:
            var player : FPlayer = body

            player.die()

