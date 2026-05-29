class_name levelManager
extends Node2D

var all_coins : Array = []


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	all_coins = get_tree().get_nodes_in_group("coins")

func _process(delta: float) -> void:
	if all_coins.is_empty():
		print("Good Job!")
		#set_process(false) # Let's disable _process here so it doesn't spam the print statement every frame

func _on_coin_collected(coin: Node2D) -> void:
	if coin in all_coins:
		all_coins.erase(coin)

