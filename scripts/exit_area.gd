class_name ExitArea
extends Area2D

@export var next_scene: PackedScene

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body is FPlayer:
		var player := body as FPlayer
		if not player.is_dead:
			if next_scene:
				call_deferred("_change_scene")
			else:
				push_warning("ExitArea touched, but no next_scene assigned in the Inspector!")

func _change_scene() -> void:
	get_tree().change_scene_to_packed(next_scene)
