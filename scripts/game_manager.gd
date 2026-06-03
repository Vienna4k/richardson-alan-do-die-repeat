class_name GameManager
extends Node

var all_coins : Array = []
var score : int = 0

@onready var coin_count: Label = %"CoinCount"

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	all_coins = get_tree().get_nodes_in_group("coins")

func add_points(amount : int) -> void:
	score += amount
	coin_count.text = str(score)


func _process(delta: float) -> void:
	if all_coins.is_empty():
		print("Good Job!")
		#set_process(false) # Let's disable _process here so it doesn't spam the print statement every frame

func _on_coin_collected(coin: Node2D) -> void:
	if coin in all_coins:
		all_coins.erase(coin)
