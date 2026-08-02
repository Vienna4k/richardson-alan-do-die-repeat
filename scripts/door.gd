extends StaticBody2D

enum GateType {None, Or, Nor, Xor, Xnor, And, Nand}
@export var gateType : GateType

@export var channel: Array[int] = []
@onready var door_sound_open : AudioStreamPlayer = $"DoorOpen"
@onready var door_sound_close : AudioStreamPlayer = $"DoorClose"
@onready var door_anim : AnimationPlayer = $AnimationPlayer

var isOpen : bool = false
var connected_buttons: Array[GameButton] = []

func _ready() -> void:
	var buttons: Array[Node] = get_tree().get_nodes_in_group("buttons")
	for node in buttons:
		var my_button: GameButton = node as GameButton
		if my_button.channel in channel:
			connected_buttons.append(my_button)
			var pressed_sig: Signal = my_button.button_pressed
			var released_sig: Signal = my_button.button_released
			
			if not pressed_sig.is_connected(_on_button_pressed):
				pressed_sig.connect(_on_button_pressed)
			if not released_sig.is_connected(_on_button_released):
				released_sig.connect(_on_button_released)
				
	call_deferred("evaluate_gate")

func evaluate_gate() -> void:
	if connected_buttons.is_empty():
		return
		
	var is_condition_met := false
	var total_buttons_pressed := 0
	var total_buttons := connected_buttons.size()

	for b in connected_buttons:
		if b.is_pressed:
			total_buttons_pressed += 1

	match gateType:
		GateType.None, GateType.Or:
			is_condition_met = total_buttons_pressed > 0
		GateType.Nor:
			is_condition_met = total_buttons_pressed == 0
		GateType.Xor:
			is_condition_met = (total_buttons_pressed % 2 == 1)
		GateType.Xnor:
			is_condition_met = (total_buttons_pressed % 2 == 0)
		GateType.And:
			is_condition_met = total_buttons_pressed == total_buttons
		GateType.Nand:
			is_condition_met = total_buttons_pressed < total_buttons

	if is_condition_met and not isOpen:
		door_anim.play("open")
		door_sound_open.play()
		isOpen = true
	elif not is_condition_met and isOpen:
		door_anim.play_backwards("open")
		door_sound_close.play()
		isOpen = false

func _on_button_pressed(_button_channel: int) -> void:
	evaluate_gate()

func _on_button_released(_button_channel: int) -> void:
	evaluate_gate()
