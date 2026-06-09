class_name GameManager
extends Node
var score : int = 0

@onready var coin_count: Label = %"CoinCount"
@onready var winSFX : AudioStreamPlayer2D
@export var win_label : Label
@onready var win_music : AudioStreamPlayer = $WinMusic

func add_points(amount : int) -> void:
	score += amount
	coin_count.text = str(score)


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("quit"):
		get_tree().quit()


func _on_finish_line_body_entered(body: Node2D) -> void:
	if body.is_in_group("players"):
		print("Good Job!")
		win_label.show()
		win_music.play()
		#grab the background music global and pause the music
		var bgm_player := get_node("/root/Bgm/TimeForAdventure") as AudioStreamPlayer
		bgm_player.stream_paused = true
		Engine.time_scale = 0

		await win_music.finished
		Engine.time_scale = 1
		#resume background music after finish before scene load
		bgm_player.stream_paused = false
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
