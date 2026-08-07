extends Camera2D

@onready var player: CharacterBody2D = $"F-Player"
@export var mapCam : Camera2D


var is_map_open: bool = false

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("toggleMap"):
		toggle_map_view()

#func _unhandled_input(event: InputEvent) -> void:
#	if event.is_action_pressed("toggleMap"):
#		toggle_map_view()

func toggle_map_view() -> void:
	is_map_open = !is_map_open
	
	if is_map_open:
		mapCam.make_current()
	else:
		self.make_current()
