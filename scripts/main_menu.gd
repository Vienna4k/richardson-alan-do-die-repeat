extends Control


func _on_play_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/level_01.tscn")


func _on_options_button_pressed() -> void:
	pass # do nothing for now


func _on_quit_button_pressed() -> void:
	get_tree().quit()
