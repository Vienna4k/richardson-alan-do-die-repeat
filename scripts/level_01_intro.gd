extends Node2D

func _ready() -> void:
	var player := $"F-Player" as FPlayer
	var door_sprite := $"EntryDoor/DoorSheet" as Sprite2D
	var door_col := $"EntryDoor/CollisionShape2D" as CollisionShape2D
	player.play_entry_cutscene(door_sprite, door_col)
