extends Area2D

signal button_pressed
signal button_released

@onready var button_anim : AnimationPlayer = $AnimationPlayer

var is_pressed := false

func _ready() -> void:
	# Connect the signals from the Area2D's body enter/exit
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("players"):
		# We check if it's already pressed in case enemies or multiple bodies enter
		if not is_pressed:
			is_pressed = true
			button_anim.play("press_down")
			button_pressed.emit() # Send a signal out to your Portal or GameManager

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("players"):
		# Optional: If you want it to pop back up when the player leaves
		# Check to ensure no other 'Player' bodies are still inside the area if doing multiplayer
		if get_overlapping_bodies().filter(func(b: Node2D) -> bool: return b.is_in_group("players") or b.is_in_group("Player") and b != body).is_empty():
			is_pressed = false
			button_anim.play_backwards("press_down") # Or play a separate "release" animation
			button_released.emit()

