extends StaticBody2D

@export var channel : int = 0
@onready var door_sound_open : AudioStreamPlayer = $"DoorOpen"
@onready var door_sound_close : AudioStreamPlayer = $"DoorClose"
@onready var door_anim : AnimationPlayer = $AnimationPlayer

func _ready() -> void:
	var buttons: Array[Node] = get_tree().get_nodes_in_group("buttons")
	for node in buttons:
		var my_button: GameButton = node as GameButton
		if my_button.channel == channel:
			var pressed_sig: Signal = my_button.button_pressed
			var released_sig: Signal = my_button.button_released
			
			if not pressed_sig.is_connected(_on_button_pressed):
				pressed_sig.connect(_on_button_pressed)
			if not released_sig.is_connected(_on_button_released):
				released_sig.connect(_on_button_released)

func _on_button_pressed(_button_channel: int) -> void:
	door_anim.play("open")
	door_sound_open.play()

func _on_button_released(_button_channel: int) -> void:
	door_anim.play_backwards("open")
	door_sound_close.play()
