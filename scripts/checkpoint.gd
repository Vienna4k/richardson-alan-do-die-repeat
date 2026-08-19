extends Marker2D
class_name Checkpoint

@export var isMostRecentCheckpoint : bool = false
@export var offSprite : Sprite2D
@export var onSprite : Sprite2D

func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.is_in_group("players"):
		var player : FPlayer = body as FPlayer
		if player:
			player.setNewCheckpoint(self)
