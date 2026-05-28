extends Node2D

var all_coins : Array = []


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	all_coins = get_tree().get_nodes_in_group("coins")

func _on_coin_collected() -> void:
	pass
